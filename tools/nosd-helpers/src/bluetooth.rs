#![forbid(unsafe_code)]

//! Interactive bluetooth pairing driver.
//! Mirrors Scripts/python/src/network/bluetooth-pair.py: run `bluetoothctl`
//! on a PTY, auto-answer pairing/authorization prompts, relay an optional
//! user PIN from stdin, then trust and connect with retries.
//!
//! The PTY itself comes from the `portable-pty` crate (its internal unsafe
//! is audited upstream); this module stays `forbid(unsafe_code)`. A reader
//! thread plus an mpsc channel emulates the python `select` read windows.

use std::io::{Read, Write};
use std::sync::mpsc;
use std::time::{Duration, Instant};

use portable_pty::{CommandBuilder, PtySize, native_pty_system};

fn log(msg: &str) {
    println!("[pair] {msg}");
    let _ = std::io::stdout().flush();
}

struct Session {
    writer: Box<dyn Write + Send>,
    rx: mpsc::Receiver<String>,
    eof: bool,
}

impl Session {
    fn send(&mut self, cmd: &str) {
        log(&format!("Sending cmd: {cmd}"));
        let _ = writeln!(self.writer, "{cmd}");
        let _ = self.writer.flush();
    }

    /// Drain newly arrived output until `timeout` elapses (mirrors the
    /// python `read_output` select window).
    fn read_output(&mut self, timeout: Duration) -> String {
        if self.eof {
            return String::new();
        }
        let deadline = Instant::now() + timeout;
        let mut out = String::new();
        loop {
            let now = Instant::now();
            if now >= deadline {
                break;
            }
            match self.rx.recv_timeout(deadline - now) {
                Ok(chunk) => out.push_str(&chunk),
                Err(mpsc::RecvTimeoutError::Timeout) => break,
                Err(mpsc::RecvTimeoutError::Disconnected) => {
                    self.eof = true;
                    break;
                }
            }
        }
        out
    }
}

fn contains_any(haystack: &str, needles: &[&str]) -> bool {
    needles.iter().any(|n| haystack.contains(n))
}

pub fn run(args: &[String]) -> i32 {
    if args.len() < 4 {
        log("Usage: bluetooth-pair.py <addr> <pairWaitSeconds> <attempts> <intervalSec>");
        return 2;
    }
    let addr = args[0].clone();
    let mut pair_wait = args[1].parse::<f64>().unwrap_or(45.0);
    if pair_wait < 30.0 {
        log(&format!(
            "Warning: pairWaitSeconds ({pair_wait}s) is too short. Enforcing 45s minimum."
        ));
        pair_wait = 45.0;
    }
    let attempts: usize = args[2].parse().unwrap_or(1);
    let interval = Duration::from_secs_f64(args[3].parse().unwrap_or(1.0));
    if addr.len() < 17 {
        log(&format!("Invalid Bluetooth address: '{addr}'"));
        return 2;
    }

    let pty = match native_pty_system().openpty(PtySize {
        rows: 24,
        cols: 80,
        pixel_width: 0,
        pixel_height: 0,
    }) {
        Ok(p) => p,
        Err(e) => {
            log(&format!("Cannot open pty: {e}"));
            return 1;
        }
    };
    let mut child = match pty.slave.spawn_command(CommandBuilder::new("bluetoothctl")) {
        Ok(c) => c,
        Err(e) => {
            log(&format!("Cannot start bluetoothctl: {e}"));
            return 1;
        }
    };
    let (tx, rx) = mpsc::channel();
    let mut reader = match pty.master.try_clone_reader() {
        Ok(r) => r,
        Err(e) => {
            log(&format!("Cannot read pty: {e}"));
            return 1;
        }
    };
    std::thread::spawn(move || {
        let mut buf = [0u8; 1024];
        loop {
            match reader.read(&mut buf) {
                Ok(0) | Err(_) => break,
                Ok(n) => {
                    let chunk = String::from_utf8_lossy(&buf[..n]).into_owned();
                    if tx.send(chunk).is_err() {
                        break;
                    }
                }
            }
        }
    });
    let writer = match pty.master.take_writer() {
        Ok(w) => w,
        Err(e) => {
            log(&format!("Cannot write pty: {e}"));
            return 1;
        }
    };
    let mut sess = Session { writer, rx, eof: false };

    log("Initializing bluetoothctl...");
    std::thread::sleep(Duration::from_secs(1));
    sess.send("agent on");
    sess.send("default-agent");
    std::thread::sleep(Duration::from_millis(500));

    log(&format!("Attempting to pair with {addr}..."));
    sess.send(&format!("pair {addr}"));

    let start = Instant::now();
    let mut paired = false;
    log("Waiting for pairing sequence start...");
    while start.elapsed().as_secs_f64() < pair_wait {
        let out = sess.read_output(Duration::from_millis(500));
        if out.is_empty() {
            continue;
        }
        print!("{out}");
        let _ = std::io::stdout().flush();

        if contains_any(&out, &[&format!("Device {addr} not available")]) {
            log(&format!("Device {addr} is discovered yet..."));
            pair_wait += 30.0;
        }
        if contains_any(&out, &["Confirm passkey", "yes/no", "Request confirmation"]) {
            log("Detected passkey prompt. Sending 'yes'.");
            sess.send("yes");
        }
        if contains_any(&out, &["Authorize service", "Request authorization"]) {
            log("Detected authorization request. Sending 'yes'.");
            sess.send("yes");
        }
        if contains_any(&out, &["Enter passkey", "Enter PIN code", "Passkey: "]) {
            log("Device requested PIN/Passkey. Waiting for user input...");
            log("PIN_REQUIRED");
            let mut pin = String::new();
            match std::io::stdin().read_line(&mut pin) {
                Ok(_) => {
                    let pin = pin.trim().to_string();
                    if !pin.is_empty() {
                        log(&format!("Received PIN: {pin}, relaying to bluetoothctl..."));
                        sess.send(&pin);
                    }
                }
                Err(e) => {
                    log(&format!("Error reading stdin: {e}"));
                    break;
                }
            }
        }
        if contains_any(&out, &["Pairing successful", "Paired: yes", "Bonded: yes"]) {
            paired = true;
            log("Pairing successful detected in stream.");
            break;
        }
        if out.contains("Failed to pair") {
            log("Pairing failed explicitly.");
            break;
        }
        if contains_any(&out, &["Already joined", "Already exists"]) {
            paired = true;
            log("Device already paired.");
            break;
        }
    }

    if !paired {
        sess.send(&format!("info {addr}"));
        std::thread::sleep(Duration::from_secs(1));
        if sess.read_output(Duration::from_secs(1)).contains("Paired: yes") {
            paired = true;
        }
    }

    let code = if paired {
        log("Device is paired. Trusting...");
        sess.send(&format!("trust {addr}"));
        std::thread::sleep(Duration::from_secs(1));
        log("Connecting...");
        let mut connected = false;
        for i in 0..attempts.max(1) {
            sess.send(&format!("connect {addr}"));
            std::thread::sleep(interval);
            sess.send(&format!("info {addr}"));
            std::thread::sleep(Duration::from_secs(1));
            if sess.read_output(Duration::from_secs(1)).contains("Connected: yes") {
                log("Connected successfully, we are done here.");
                connected = true;
                break;
            }
            log(&format!("Connection attempt {}/{attempts} failed. Retrying...", i + 1));
        }
        if !connected {
            log("Failed to connect after all attempts.");
        }
        sess.send("quit");
        let _ = child.try_wait();
        if connected { 0 } else { 1 }
    } else {
        log("Failed to pair within timeout.");
        sess.send("quit");
        let _ = child.try_wait();
        1
    };
    code
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn detects_markers() {
        assert!(contains_any("Confirm passkey (yes/no): 123", &["Confirm passkey", "yes/no"]));
        assert!(!contains_any("hello", &["Pairing successful"]));
    }

    #[test]
    fn usage_and_bad_addr() {
        assert_eq!(run(&[]), 2);
        assert_eq!(run(&["AA:BB".to_string(), "45".to_string(), "1".to_string(), "1".to_string()]), 2);
    }
}
