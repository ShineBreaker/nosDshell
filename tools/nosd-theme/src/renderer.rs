#![forbid(unsafe_code)]

//! Matugen-compatible template renderer: {{colors.name.mode.format}} tags,
//! pipe filters, <* for *>/<* if *> blocks, TOML configs, custom colors.
//! Mirrors Scripts/python/src/theming/lib/renderer.py.
//!
//! Parity notes:
//! - All regexes from renderer.py are hand-rolled char scans with the same
//!   anchoring (re.match = prefix anchored; $ = end of stripped command).
//! - Python min/max are first-wins on ties (NaN passes through); py_min/py_max
//!   replicate that instead of f64::min/max.
//! - int() truncates toward zero; int(h)/int(s*100) only see non-negative
//!   values, set_red/green/blue clamp after truncation. Non-finite numeric
//!   args raise in Python (bubbled to a render error); here they log the same
//!   error and leave the color unchanged, keeping the error count identical.
//! - float(arg) accepts underscores ("1_0") in Python but not here; such exotic
//!   args become "requires numeric argument" errors (same error count).
//! - The renderer's inline harmonize moves hue TOWARD the target (correct M3
//!   behavior); it intentionally differs from material::harmonize_color, which
//!   mirrors material.py exactly (see its test).
//! - TOML tables use preserve_order so template order matches tomllib.

use std::collections::HashMap;
use std::path::{Path, PathBuf};

use crate::color::{find_closest_color, py_mod, Color};
use crate::hct::{Hct, TonalPalette};
use crate::material::scheme_by_name;

/// Python first-wins min/max (NaN passes through to the default arm).
fn py_min(a: f64, b: f64) -> f64 {
    if b < a { b } else { a }
}
fn py_max(a: f64, b: f64) -> f64 {
    if b > a { b } else { a }
}
fn py_clamp(v: f64, lo: f64, hi: f64) -> f64 {
    py_max(lo, py_min(hi, v))
}

/// Python str(float) for alpha output: integral floats keep ".0".
fn py_num(v: f64) -> String {
    if v.fract() == 0.0 && v.abs() < 1e15 {
        if v == 0.0 && v.is_sign_negative() {
            "-0.0".to_string()
        } else {
            format!("{}.0", v as i64)
        }
    } else {
        format!("{v}")
    }
}

/// Scope value: loop bindings, map entries, palette dicts.
#[derive(Clone, Debug)]
pub enum Value {
    Str(String),
    Int(i64),
    Bool(bool),
    Dict(Vec<(String, Value)>),
}

impl Value {
    /// Python str(value).
    fn py_str(&self) -> String {
        match self {
            Value::Str(s) => s.clone(),
            Value::Int(i) => i.to_string(),
            Value::Bool(true) => "True".to_string(),
            Value::Bool(false) => "False".to_string(),
            Value::Dict(items) => {
                let inner = items
                    .iter()
                    .map(|(k, v)| format!("'{k}': '{}'", v.py_str()))
                    .collect::<Vec<_>>()
                    .join(", ");
                format!("{{{inner}}}")
            }
        }
    }
}

fn is_truthy(v: &Value) -> bool {
    match v {
        Value::Bool(b) => *b,
        Value::Int(i) => *i != 0,
        _ => {
            let s = v.py_str();
            let t = s.trim().to_lowercase();
            !(t.is_empty() || t == "false" || t == "0" || t == "none")
        }
    }
}

struct Scope {
    stack: Vec<HashMap<String, Value>>,
}

impl Scope {
    fn new() -> Scope {
        Scope { stack: Vec::new() }
    }
    fn push(&mut self, bindings: HashMap<String, Value>) {
        self.stack.push(bindings);
    }
    fn pop(&mut self) {
        self.stack.pop();
    }
    fn set(&mut self, name: &str, value: Value) {
        if let Some(top) = self.stack.last_mut() {
            top.insert(name.to_string(), value);
        }
    }
    fn get(&self, name: &str) -> Option<Value> {
        self.stack.iter().rev().find_map(|s| s.get(name).cloned())
    }
    fn is_active(&self) -> bool {
        !self.stack.is_empty()
    }
}

enum Node {
    Text(String),
    For { vars: Vec<String>, iterable: String, body: Vec<Node> },
    If { cond: String, negated: bool, then_body: Vec<Node>, else_body: Vec<Node> },
}

enum Token {
    Text(String),
    Block(String),
}

enum Items {
    Pairs(Vec<(String, Value)>),
    Singles(Vec<Value>),
}

const KNOWN_FORMATS: &[&str] = &[
    "hex", "hex_stripped", "rgb", "rgb_csv", "rgba", "hsl", "hsla", "red", "green", "blue",
    "alpha", "hue", "saturation", "lightness",
];

const SUPPORTED_ORDER: &str = "auto_lightness, darken, desaturate, grayscale, invert, lighten, \
    saturate, set_alpha, set_blue, set_green, set_hue, set_lightness, set_red, set_saturation";

fn supported_args(name: &str) -> Option<u8> {
    match name {
        "grayscale" | "invert" => Some(0),
        "set_alpha" | "set_lightness" | "set_hue" | "set_saturation" | "set_red"
        | "set_green" | "set_blue" | "lighten" | "darken" | "saturate" | "desaturate"
        | "auto_lightness" => Some(1),
        _ => None,
    }
}

fn is_color_arg_filter(name: &str) -> bool {
    name == "blend" || name == "harmonize"
}

fn is_case_filter(name: &str) -> bool {
    matches!(name, "lower_case" | "camel_case" | "pascal_case" | "snake_case" | "kebab_case")
}

fn is_name_char(b: u8) -> bool {
    b.is_ascii_lowercase() || b == b'_' || b.is_ascii_digit()
}

/// Ordered theme data: mode -> [(name, hex)]. Built from JSON objects to keep
/// insertion order (serde_json preserve_order).
pub type ThemeData = Vec<(String, Vec<(String, String)>)>;

pub struct TemplateRenderer {
    theme_data: ThemeData,
    closest_color: String,
    verbose: bool,
    default_mode: String,
    image_path: Option<String>,
    scheme_type: String,
    current_file: Option<String>,
    error_count: usize,
    colors_map: Option<Vec<(String, Vec<(String, String)>)>>,
}

impl TemplateRenderer {
    pub fn new(theme_data: ThemeData) -> TemplateRenderer {
        TemplateRenderer {
            theme_data,
            closest_color: String::new(),
            verbose: true,
            default_mode: "dark".to_string(),
            image_path: None,
            scheme_type: "content".to_string(),
            current_file: None,
            error_count: 0,
            colors_map: None,
        }
    }

    pub fn with_options(
        theme_data: ThemeData, verbose: bool, default_mode: &str, image_path: Option<String>,
        scheme_type: &str,
    ) -> TemplateRenderer {
        let mut r = TemplateRenderer::new(theme_data);
        r.verbose = verbose;
        r.default_mode = default_mode.to_string();
        r.image_path = image_path;
        r.scheme_type = scheme_type.to_string();
        r
    }

    pub fn error_count(&self) -> usize {
        self.error_count
    }

    fn log_error(&mut self, message: &str, line_hint: &str) {
        self.error_count += 1;
        let prefix = self.current_file.as_deref().unwrap_or("");
        let prefix = if prefix.is_empty() { String::new() } else { format!("[{prefix}] ") };
        let hint = if line_hint.is_empty() { String::new() } else { format!(" near '{line_hint}'") };
        eprintln!("Template error: {prefix}{message}{hint}");
    }

    fn log_warning(&self, message: &str) {
        if self.verbose {
            let prefix = self.current_file.as_deref().unwrap_or("");
            let prefix = if prefix.is_empty() { String::new() } else { format!("[{prefix}] ") };
            eprintln!("Template warning: {prefix}{message}");
        }
    }

    fn mode_data(&self, mode: &str) -> Option<&Vec<(String, String)>> {
        self.theme_data.iter().find(|(m, _)| m == mode).map(|(_, d)| d)
    }

    fn mode_data_mut(&mut self, mode: &str) -> Option<&mut Vec<(String, String)>> {
        self.theme_data.iter_mut().find(|(m, _)| m == mode).map(|(_, d)| d)
    }

    fn lookup(data: &[(String, String)], key: &str) -> Option<String> {
        data.iter().find(|(k, _)| k == key).map(|(_, v)| v.clone())
    }

    // --- Colors map ---

    fn build_colors_map(&mut self) -> Vec<(String, Vec<(String, String)>)> {
        if let Some(m) = &self.colors_map {
            return m.clone();
        }
        let mut names: Vec<String> = Vec::new();
        for (_, data) in &self.theme_data {
            for (k, _) in data {
                if !names.contains(k) {
                    names.push(k.clone());
                }
            }
        }
        names.sort();
        let mut map = Vec::new();
        for name in names {
            let mut modes = Vec::new();
            for (mode, data) in &self.theme_data {
                if let Some(v) = Self::lookup(data, &name) {
                    modes.push((mode.clone(), v));
                }
            }
            if let Some(d) = Self::lookup(&modes, &self.default_mode) {
                modes.push(("default".to_string(), d));
            }
            map.push((name, modes));
        }
        self.colors_map = Some(map.clone());
        map
    }

    // --- Tokenizer / parser ---

    fn tokenize(&self, text: &str) -> Vec<Token> {
        let mut tokens = Vec::new();
        let mut last_end = 0;
        let mut search = 0;
        while let Some(rel) = text[search..].find("<*") {
            let start = search + rel;
            let Some(close_rel) = text[start + 2..].find("*>") else { break };
            let end = start + 2 + close_rel + 2;
            let content = text[start + 2..end - 2].trim().to_string();

            // Standalone line check: only whitespace before on the line.
            let line_start = match text[last_end..start].rfind('\n') {
                Some(i) => last_end + i + 1,
                None => last_end,
            };
            let mut bs = start;
            let mut be = end;
            if text[line_start..start].trim().is_empty() {
                let mut after = end;
                while after < text.len() && (text.as_bytes()[after] == b' ' || text.as_bytes()[after] == b'\t') {
                    after += 1;
                }
                if after < text.len() && text.as_bytes()[after] == b'\n' {
                    bs = line_start;
                    be = after + 1;
                } else if after == text.len() {
                    bs = line_start;
                    be = after;
                }
            }
            if bs > last_end {
                tokens.push(Token::Text(text[last_end..bs].to_string()));
            }
            tokens.push(Token::Block(content));
            last_end = be;
            search = be;
        }
        if last_end < text.len() {
            tokens.push(Token::Text(text[last_end..].to_string()));
        }
        tokens
    }

    fn parse_nodes(&mut self, tokens: &[Token], pos: &mut usize, stop: &[&str]) -> Vec<Node> {
        let mut nodes = Vec::new();
        while *pos < tokens.len() {
            match &tokens[*pos] {
                Token::Text(t) => {
                    if !t.is_empty() {
                        nodes.push(Node::Text(t.clone()));
                    }
                    *pos += 1;
                }
                Token::Block(cmd) => {
                    if stop.iter().any(|kw| cmd.starts_with(kw)) {
                        return nodes;
                    } else if cmd.starts_with("for ") {
                        nodes.push(self.parse_for(tokens, pos));
                    } else if cmd.starts_with("if ") {
                        nodes.push(self.parse_if(tokens, pos));
                    } else {
                        self.log_warning(&format!("Unknown block command: {cmd}"));
                        *pos += 1;
                    }
                }
            }
        }
        nodes
    }

    /// First whitespace-"in"-whitespace split (mirrors non-greedy regex).
    fn split_for(cmd: &str) -> Option<(String, String)> {
        let b = cmd.as_bytes();
        let mut i = 0;
        while i < b.len() {
            if b[i].is_ascii_whitespace() {
                let mut j = i;
                while j < b.len() && b[j].is_ascii_whitespace() {
                    j += 1;
                }
                if cmd[j..].starts_with("in") {
                    let k = j + 2;
                    if k < b.len() && b[k].is_ascii_whitespace() {
                        let mut l = k;
                        while l < b.len() && b[l].is_ascii_whitespace() {
                            l += 1;
                        }
                        return Some((cmd[..i].to_string(), cmd[l..].to_string()));
                    }
                }
                i = j;
            } else {
                i += 1;
            }
        }
        None
    }

    fn parse_for(&mut self, tokens: &[Token], pos: &mut usize) -> Node {
        let cmd = match &tokens[*pos] {
            Token::Block(c) => c.clone(),
            _ => String::new(),
        };
        *pos += 1;
        let rest = cmd[4..].to_string();
        let Some((vars_str, iterable)) = Self::split_for(&rest) else {
            self.log_error(&format!("Invalid for syntax: {cmd}"), "");
            return Node::For { vars: Vec::new(), iterable: String::new(), body: Vec::new() };
        };
        let vars = vars_str.split(',').map(|v| v.trim().to_string()).collect();
        let body = self.parse_nodes(tokens, pos, &["endfor"]);
        if *pos < tokens.len() {
            *pos += 1;
        }
        Node::For { vars, iterable: iterable.trim().to_string(), body }
    }

    fn parse_if(&mut self, tokens: &[Token], pos: &mut usize) -> Node {
        let cmd = match &tokens[*pos] {
            Token::Block(c) => c.clone(),
            _ => String::new(),
        };
        *pos += 1;
        let mut part = cmd[3..].trim().to_string();
        let mut negated = false;
        if part.starts_with("not ") {
            negated = true;
            part = part[4..].trim().to_string();
        }
        // re.match(r'\{\{(.+?)\}\}'): anchored at start, first "}}".
        let cond = if part.starts_with("{{") {
            match part[2..].find("}}") {
                Some(i) => part[2..2 + i].trim().to_string(),
                None => part,
            }
        } else {
            part
        };
        let then_body = self.parse_nodes(tokens, pos, &["else", "endif"]);
        let mut else_body = Vec::new();
        if *pos < tokens.len() {
            if let Token::Block(c) = &tokens[*pos] {
                if c.trim() == "else" {
                    *pos += 1;
                    else_body = self.parse_nodes(tokens, pos, &["endif"]);
                }
            }
        }
        if *pos < tokens.len() {
            *pos += 1;
        }
        Node::If { cond, negated, then_body, else_body }
    }

    // --- Evaluation ---

    fn eval_nodes(&mut self, nodes: &[Node], scope: &mut Scope) -> String {
        let mut parts = Vec::new();
        for node in nodes {
            match node {
                Node::Text(t) => parts.push(self.resolve_text(t, scope)),
                Node::For { vars, iterable, body } => {
                    parts.push(self.eval_for(vars, iterable, body, scope))
                }
                Node::If { cond, negated, then_body, else_body } => {
                    let v = self.resolve_expression(cond, scope);
                    let mut truthy = is_truthy(&v);
                    if *negated {
                        truthy = !truthy;
                    }
                    parts.push(if truthy {
                        self.eval_nodes(then_body, scope)
                    } else {
                        self.eval_nodes(else_body, scope)
                    });
                }
            }
        }
        parts.concat()
    }

    fn eval_for(
        &mut self, vars: &[String], iterable: &str, body: &[Node], scope: &mut Scope,
    ) -> String {
        let items = match self.resolve_iterable(iterable, scope) {
            Some(it)
                if !match &it {
                    Items::Pairs(p) => p.is_empty(),
                    Items::Singles(s) => s.is_empty(),
                } =>
            {
                it
            }
            _ => return String::new(),
        };
        let total = match &items {
            Items::Pairs(p) => p.len(),
            Items::Singles(s) => s.len(),
        };
        let mut out = String::new();
        for index in 0..total {
            let mut bindings = HashMap::new();
            bindings.insert("loop".to_string(), Value::Dict(vec![
                ("index".to_string(), Value::Int(index as i64)),
                ("first".to_string(), Value::Bool(index == 0)),
                ("last".to_string(), Value::Bool(index == total - 1)),
            ]));
            scope.push(bindings);
            match &items {
                Items::Pairs(p) => {
                    let (k, v) = &p[index];
                    if vars.len() >= 2 {
                        scope.set(&vars[0], Value::Str(k.clone()));
                        scope.set(&vars[1], v.clone());
                    } else if vars.len() == 1 {
                        scope.set(&vars[0], Value::Str(k.clone()));
                    }
                }
                Items::Singles(s) => {
                    if !vars.is_empty() {
                        scope.set(&vars[0], s[index].clone());
                    }
                }
            }
            out.push_str(&self.eval_nodes(body, scope));
            scope.pop();
        }
        out
    }

    fn resolve_iterable(&mut self, expr: &str, scope: &Scope) -> Option<Items> {
        // Range "a..b".
        if let Some((a, b)) = expr.split_once("..") {
            if let (Ok(s), Ok(e)) = (a.parse::<i64>(), b.parse::<i64>()) {
                if is_int_lit(a) && is_int_lit(b) {
                    return Some(Items::Singles((s..e).map(Value::Int).collect()));
                }
            }
        }
        if expr == "colors" {
            let pairs = self
                .build_colors_map()
                .into_iter()
                .map(|(k, v)| {
                    (k, Value::Dict(v.into_iter().map(|(m, h)| (m, Value::Str(h))).collect()))
                })
                .collect();
            return Some(Items::Pairs(pairs));
        }
        if let Some(name) = expr.strip_prefix("palettes.") {
            return Some(Items::Singles(self.palette_entries(name)));
        }
        if let Some(v) = scope.get(expr) {
            match v {
                Value::Dict(items) => return Some(Items::Pairs(items)),
                _ => {}
            }
        }
        self.log_warning(&format!("Unknown iterable: {expr}"));
        None
    }

    fn palette_entries(&mut self, name: &str) -> Vec<Value> {
        const TONES: [i64; 18] =
            [0, 5, 10, 15, 20, 25, 30, 35, 40, 50, 60, 70, 80, 90, 95, 98, 99, 100];
        let key = match name {
            "primary" => "primary",
            "secondary" => "secondary",
            "tertiary" => "tertiary",
            "error" => "error",
            "neutral" => "surface",
            "neutral_variant" => "surface_variant",
            _ => {
                self.log_warning(&format!("Unknown palette: {name}"));
                return Vec::new();
            }
        };
        let hex = self
            .mode_data(&self.default_mode.clone())
            .and_then(|d| Self::lookup(d, key));
        let Some(hex) = hex else { return Vec::new() };
        let Some(c) = Color::from_hex(&hex) else { return Vec::new() };
        let mut palette = TonalPalette::from_rgb(c.r, c.g, c.b);
        TONES
            .iter()
            .map(|t| {
                let h = palette.get_hex(*t);
                Value::Dict(vec![
                    ("default".to_string(), Value::Str(h.clone())),
                    ("dark".to_string(), Value::Str(h.clone())),
                    ("light".to_string(), Value::Str(h)),
                ])
            })
            .collect()
    }

    /// Find "{{...}}" tags: content has no '}' or newline (mirrors EXPR_RE).
    fn resolve_text(&mut self, text: &str, scope: &mut Scope) -> String {
        let mut out = String::new();
        let mut i = 0;
        let b = text.as_bytes();
        while i < b.len() {
            if b[i] == b'{' && i + 1 < b.len() && b[i + 1] == b'{' {
                if let Some(rel) = text[i + 2..].find("}}") {
                    let content = &text[i + 2..i + 2 + rel];
                    if !content.contains('}') && !content.contains('\n') {
                        let v = self.resolve_expression(content.trim(), scope);
                        out.push_str(&v.py_str());
                        i = i + 2 + rel + 2;
                        continue;
                    }
                }
                out.push_str("{{");
                i += 2;
            } else {
                let ch = text[i..].chars().next().unwrap();
                out.push(ch);
                i += ch.len_utf8();
            }
        }
        out
    }

    fn split_pipes(expr: &str) -> Vec<String> {
        let mut parts = Vec::new();
        let mut cur = String::new();
        let mut quote: Option<char> = None;
        for ch in expr.chars() {
            if (ch == '"' || ch == '\'') && quote.is_none() {
                quote = Some(ch);
                cur.push(ch);
            } else if Some(ch) == quote {
                quote = None;
                cur.push(ch);
            } else if ch == '|' && quote.is_none() {
                parts.push(cur);
                cur = String::new();
            } else {
                cur.push(ch);
            }
        }
        if !cur.is_empty() {
            parts.push(cur);
        }
        parts
    }

    fn resolve_expression(&mut self, expr: &str, scope: &mut Scope) -> Value {
        let parts = Self::split_pipes(expr);
        if parts.is_empty() {
            return Value::Str(String::new());
        }
        let base = parts[0].trim().to_string();
        let filters: Vec<String> = parts[1..].iter().map(|p| p.trim().to_string()).collect();

        if base == "mode" {
            let mut s = self.default_mode.clone();
            for f in &filters {
                s = self.apply_string_or_color_filter(&s, f, expr);
            }
            return Value::Str(s);
        }
        if let Some(v) = self.resolve_from_scope(&base, scope) {
            // Hex colors stay Color-aware through filters; others are strings.
            let mut s = v.py_str();
            for f in &filters {
                s = self.apply_string_or_color_filter(&s, f, expr);
            }
            return Value::Str(s);
        }
        if base == "image" {
            let mut s = self.image_path.clone().unwrap_or_default();
            for f in &filters {
                s = self.apply_string_or_color_filter(&s, f, expr);
            }
            return Value::Str(s);
        }
        if base.starts_with("colors.") {
            return Value::Str(self.process_color_expression(&base, &filters, expr));
        }
        Value::Str(format!("{{{{{expr}}}}}"))
    }

    fn resolve_from_scope(&mut self, base: &str, scope: &Scope) -> Option<Value> {
        if !scope.is_active() {
            return None;
        }
        let mut parts = base.split('.');
        let first = parts.next()?;
        let mut val = scope.get(first)?;
        for part in parts {
            match &val {
                Value::Dict(items) => {
                    let found = items.iter().find(|(k, _)| k == part).map(|(_, v)| v.clone());
                    val = found?;
                }
                Value::Str(s)
                    if s.starts_with('#') && KNOWN_FORMATS.contains(&part) =>
                {
                    let c = Color::from_hex(s)?;
                    return Some(Value::Str(self.format_color(&c, part)));
                }
                _ => return None,
            }
        }
        Some(val)
    }

    fn valid_color_path(base: &str) -> Option<(String, String, String)> {
        let p: Vec<&str> = base.split('.').collect();
        if p.len() != 4 || p[0] != "colors" {
            return None;
        }
        if p[1..].iter().all(|s| !s.is_empty() && s.bytes().all(is_name_char)) {
            Some((p[1].to_string(), p[2].to_string(), p[3].to_string()))
        } else {
            None
        }
    }

    fn process_color_expression(
        &mut self, base: &str, filters: &[String], raw_expr: &str,
    ) -> String {
        let Some((name, mode, format)) = Self::valid_color_path(base) else {
            self.log_error(
                &format!("Invalid syntax '{base}'. Expected: colors.<name>.<mode>.<format>"),
                raw_expr,
            );
            return format!("{{{{{raw_expr}}}}}");
        };
        let hex = match self.get_hex_color(&name, &mode, base) {
            Some(h) => h,
            None => return format!("{{{{UNKNOWN:{name}.{mode}}}}}"),
        };
        let mut color = match Color::from_hex(&hex) {
            Some(c) => c,
            None => return format!("{{{{UNKNOWN:{name}.{mode}}}}}"),
        };
        for f in filters {
            let (fname, arg) = Self::parse_filter(f);
            if fname == "replace" {
                let formatted = self.format_color(&color, &format);
                return self.apply_replace(&formatted, arg.as_deref(), raw_expr);
            } else if is_color_arg_filter(&fname) {
                let out = self.apply_color_arg_filter(&color.to_hex(), &fname, arg.as_deref(), raw_expr);
                color = Color::from_hex(&out).unwrap_or(color);
            } else if fname == "to_color" {
                // Already a color: no-op.
            } else if supported_args(&fname).is_some() {
                color = self.apply_filter(color, &fname, arg.as_deref(), raw_expr);
            } else if is_case_filter(&fname) {
                let formatted = self.format_color(&color, &format);
                return self.apply_string_or_color_filter(&formatted, f, raw_expr);
            } else {
                self.log_warning(&format!("Unknown filter '{fname}'"));
            }
        }
        let fmt = self.format_color(&color, &format);
        fmt
    }

    fn color_alias(name: &str) -> &str {
        match name {
            "hover" => "surface_container_high",
            "on_hover" => "on_surface",
            _ => name,
        }
    }

    fn get_hex_color(&mut self, name: &str, mode: &str, base: &str) -> Option<String> {
        let key = Self::color_alias(name);
        let data = if mode == "default" {
            // theme_data.get(default) or dark or light.
            let has_default = self.theme_data.iter().any(|(m, _)| m == &self.default_mode);
            let has_dark = self.theme_data.iter().any(|(m, _)| m == "dark");
            if has_default {
                self.mode_data(&self.default_mode.clone())
            } else if has_dark {
                self.mode_data("dark")
            } else {
                self.mode_data("light")
            }
        } else {
            self.theme_data.iter().find(|(m, _)| m == mode).map(|(_, d)| d)
        };
        let Some(data) = data else {
            self.log_error(&format!("Unknown mode '{mode}'"), base);
            return None;
        };
        match Self::lookup(data, key) {
            Some(h) => Some(h),
            None => {
                self.log_error(&format!("Unknown color '{key}'"), base);
                None
            }
        }
    }

    fn format_color(&mut self, color: &Color, format: &str) -> String {
        match format {
            "hex" => color.to_hex(),
            "hex_stripped" => color.to_hex().trim_start_matches('#').to_string(),
            "rgb" => format!("rgb({}, {}, {})", color.r, color.g, color.b),
            "rgb_csv" => format!("{},{},{}", color.r, color.g, color.b),
            "rgba" => format!(
                "rgba({}, {}, {}, {})",
                color.r,
                color.g,
                color.b,
                py_num(color.alpha_value())
            ),
            "hsl" => {
                let (h, s, l) = color.to_hsl();
                format!("hsl({}, {}%, {}%)", h as i64, (s * 100.0) as i64, (l * 100.0) as i64)
            }
            "hsla" => {
                let (h, s, l) = color.to_hsl();
                format!(
                    "hsla({}, {}%, {}%, {})",
                    h as i64,
                    (s * 100.0) as i64,
                    (l * 100.0) as i64,
                    py_num(color.alpha_value())
                )
            }
            "hue" => format!("{}", color.to_hsl().0 as i64),
            "saturation" => format!("{}", (color.to_hsl().1 * 100.0) as i64),
            "lightness" => format!("{}", (color.to_hsl().2 * 100.0) as i64),
            "red" => color.r.to_string(),
            "green" => color.g.to_string(),
            "blue" => color.b.to_string(),
            "alpha" => py_num(color.alpha_value()),
            _ => {
                self.log_error(&format!("Unknown format '{format}'"), "");
                color.to_hex()
            }
        }
    }

    // --- Filters ---

    /// (name, arg); colon syntax first, then first-whitespace split.
    fn parse_filter(filter_str: &str) -> (String, Option<String>) {
        let s = filter_str.trim();
        if let Some(i) = s.find(':') {
            let left = &s[..i];
            let t = left.trim_end();
            if !t.is_empty() && t.bytes().all(|b| b == b'_' || b.is_ascii_lowercase()) {
                let arg = s[i + 1..].trim();
                if !arg.is_empty() {
                    return (t.to_string(), Some(arg.to_string()));
                }
            }
        }
        if let Some(i) = s.find(|c: char| c.is_whitespace()) {
            let name = s[..i].trim().to_string();
            let arg = s[i..].trim();
            if !arg.is_empty() {
                return (name, Some(arg.to_string()));
            }
            return (name, None);
        }
        (s.to_string(), None)
    }

    fn apply_string_or_color_filter(&mut self, value: &str, filter: &str, raw: &str) -> String {
        let (name, arg) = Self::parse_filter(filter);
        if name == "replace" {
            return self.apply_replace(value, arg.as_deref(), raw);
        }
        match name.as_str() {
            "lower_case" => return value.to_lowercase(),
            "camel_case" => return to_camel_case(value),
            "pascal_case" => return to_pascal_case(value),
            "snake_case" => return to_snake_case(value),
            "kebab_case" => return to_kebab_case(value),
            _ => {}
        }
        if name == "to_color" {
            if value.starts_with('#') && (value.len() == 7 || value.len() == 9) {
                return value.to_string();
            }
            self.log_error(&format!("to_color: value '{value}' is not a valid hex color"), raw);
            return value.to_string();
        }
        if is_color_arg_filter(&name) {
            if !(value.starts_with('#') && value.len() == 7) {
                self.log_error(&format!("Filter '{name}' requires a hex color value"), raw);
                return value.to_string();
            }
            return self.apply_color_arg_filter(value, &name, arg.as_deref(), raw);
        }
        if supported_args(&name).is_some() && value.starts_with('#') && value.len() == 7 {
            if let Some(c) = Color::from_hex(value) {
                let out = self.apply_filter(c, &name, arg.as_deref(), raw);
                return out.to_hex();
            }
        }
        self.log_warning(&format!("Cannot apply filter '{name}' to non-color value"));
        value.to_string()
    }

    /// Prefix-anchored: optional quote, #RRGGBB, optional quote, then optional ", rest".
    /// Trailing garbage after a valid prefix is ignored (re.match semantics).
    fn parse_blend_arg(arg: &str) -> Option<(String, Option<String>)> {
        let mut s = arg.trim();
        if s.starts_with('"') || s.starts_with('\'') {
            s = &s[1..];
        }
        let s = s.strip_prefix('#')?;
        if s.len() < 6 || !s.as_bytes()[..6].iter().all(|b| b.is_ascii_hexdigit()) {
            return None;
        }
        let hex = format!("#{}", &s[..6].to_lowercase());
        let mut rest = s[6..].trim_start();
        if rest.starts_with('"') || rest.starts_with('\'') {
            rest = rest[1..].trim_start();
        }
        if let Some(after) = rest.strip_prefix(',') {
            let extra = after.trim();
            if extra.is_empty() {
                return Some((hex, None));
            }
            return Some((hex, Some(extra.to_string())));
        }
        Some((hex, None))
    }

    fn apply_color_arg_filter(
        &mut self, current: &str, name: &str, arg: Option<&str>, raw: &str,
    ) -> String {
        let Some(arg) = arg else {
            self.log_error(&format!("Filter '{name}' requires a color argument"), raw);
            return current.to_string();
        };
        let Some((target_hex, extra)) = Self::parse_blend_arg(arg) else {
            self.log_error(
                &format!("Filter '{name}' requires a hex color argument, got '{arg}'"),
                raw,
            );
            return current.to_string();
        };
        let (Some(src), Some(target)) =
            (Color::from_hex(current), Color::from_hex(&target_hex))
        else {
            return current.to_string();
        };
        let src_hct = Hct::from_rgb(src.r, src.g, src.b);
        let target_hct = Hct::from_rgb(target.r, target.g, target.b);
        // Signed shortest-arc diff in (-180, 180].
        let mut diff = target_hct.hue - src_hct.hue;
        if diff > 180.0 {
            diff -= 360.0;
        } else if diff < -180.0 {
            diff += 360.0;
        }
        let new_hue = if name == "blend" {
            let Some(extra) = extra else {
                self.log_error("blend filter requires amount argument: blend: \"#hex\", 0.5", raw);
                return current.to_string();
            };
            let cleaned: String = extra.trim().trim_matches(|c| c == '"' || c == '\'').to_string();
            let Ok(amount) = cleaned.parse::<f64>() else {
                self.log_error(&format!("blend amount must be numeric, got '{extra}'"), raw);
                return current.to_string();
            };
            let amount = py_clamp(amount, 0.0, 1.0);
            py_mod(src_hct.hue + diff * amount, 360.0)
        } else if name == "harmonize" {
            let mut rotation = py_min(diff.abs() * 0.5, 15.0);
            if diff < 0.0 {
                rotation = -rotation;
            }
            py_mod(src_hct.hue + rotation, 360.0)
        } else {
            return current.to_string();
        };
        let (r, g, b) = Hct::new(new_hue, src_hct.chroma, src_hct.tone).to_rgb();
        Color::new(r, g, b).to_hex()
    }

    fn apply_filter(
        &mut self, color: Color, name: &str, arg: Option<&str>, raw: &str,
    ) -> Color {
        let Some(expected) = supported_args(name) else {
            self.log_error(&format!("Unknown filter '{name}'. Supported: {SUPPORTED_ORDER}"), raw);
            return color;
        };
        if expected > 0 && arg.is_none() {
            self.log_error(&format!("Filter '{name}' requires an argument"), raw);
            return color;
        }
        if expected == 0 && arg.is_some() {
            self.log_warning(&format!(
                "Filter '{}' ignores argument '{}'",
                name,
                arg.unwrap_or("")
            ));
        }
        let mut num: Option<f64> = None;
        if expected > 0 {
            match arg.unwrap_or("").parse::<f64>() {
                Ok(v) => num = Some(v),
                Err(_) => {
                    self.log_error(
                        &format!("Filter '{name}' requires numeric argument, got '{}'", arg.unwrap_or("")),
                        raw,
                    );
                    return color;
                }
            }
        }
        let num = num.unwrap_or(0.0);
        let (h, s, l) = color.to_hsl();
        let mut result = match name {
            "grayscale" => {
                let gray = (0.299 * color.r as f64 + 0.587 * color.g as f64 + 0.114 * color.b as f64) as u8;
                Color::new(gray, gray, gray)
            }
            "invert" => Color::new(255 - color.r, 255 - color.g, 255 - color.b),
            "set_alpha" => {
                let mut c = Color::new(color.r, color.g, color.b);
                c.alpha = Some(py_clamp(num, 0.0, 1.0));
                c
            }
            "set_lightness" => Color::from_hsl(h, s, py_clamp(num / 100.0, 0.0, 1.0)),
            "set_hue" => Color::from_hsl(py_mod(num, 360.0), s, l),
            "set_saturation" => Color::from_hsl(h, py_clamp(num / 100.0, 0.0, 1.0), l),
            "lighten" => Color::from_hsl(h, s, py_clamp(l + num / 100.0, 0.0, 1.0)),
            "darken" => Color::from_hsl(h, s, py_clamp(l - num / 100.0, 0.0, 1.0)),
            "saturate" => Color::from_hsl(h, py_clamp(s + num / 100.0, 0.0, 1.0), l),
            "desaturate" => Color::from_hsl(h, py_clamp(s - num / 100.0, 0.0, 1.0), l),
            "auto_lightness" => {
                let nl = if l < 0.5 { l + num / 100.0 } else { l - num / 100.0 };
                Color::from_hsl(h, s, py_clamp(nl, 0.0, 1.0))
            }
            "set_red" => {
                if !num.is_finite() {
                    self.log_error(&format!("Filter '{name}' requires numeric argument, got '{}'", arg.unwrap_or("")), raw);
                    return color;
                }
                Color::new((num as i64).clamp(0, 255) as u8, color.g, color.b)
            }
            "set_green" => {
                if !num.is_finite() {
                    self.log_error(&format!("Filter '{name}' requires numeric argument, got '{}'", arg.unwrap_or("")), raw);
                    return color;
                }
                Color::new(color.r, (num as i64).clamp(0, 255) as u8, color.b)
            }
            "set_blue" => {
                if !num.is_finite() {
                    self.log_error(&format!("Filter '{name}' requires numeric argument, got '{}'", arg.unwrap_or("")), raw);
                    return color;
                }
                Color::new(color.r, color.g, (num as i64).clamp(0, 255) as u8)
            }
            _ => color,
        };
        if result.alpha.is_none() {
            result.alpha = color.alpha;
        }
        result
    }

    // --- Case conversion ---

    fn apply_replace(&mut self, value: &str, args: Option<&str>, raw: &str) -> String {
        let Some(args) = args else {
            self.log_error("replace filter requires arguments", raw);
            return value.to_string();
        };
        if let Some((find, rep)) = parse_quoted_pair(args, '"') {
            return value.replace(&find, &rep);
        }
        if let Some((find, rep)) = parse_quoted_pair(args, '\'') {
            return value.replace(&find, &rep);
        }
        self.log_error("replace filter syntax: replace: \"find\", \"replacement\"", raw);
        value.to_string()
    }

    // --- Main render ---

    pub fn render(&mut self, template: &str) -> String {
        self.error_count = 0;
        let tokens = self.tokenize(template);
        let mut pos = 0;
        let nodes = self.parse_nodes(&tokens, &mut pos, &[]);
        let mut scope = Scope::new();
        let mut result = self.eval_nodes(&nodes, &mut scope);
        if !self.closest_color.is_empty() {
            result = substitute_closest(&result, &self.closest_color);
        }
        // Matugen-compatible escape: \\ -> \.
        result = result.replace("\\\\", "\\");
        if self.error_count > 0 {
            eprintln!(
                "Template rendering completed with {} error(s)",
                self.error_count
            );
        }
        result
    }

    pub fn render_file(&mut self, input: &Path, output: &Path) -> (bool, bool) {
        self.current_file = Some(input.to_string_lossy().to_string());
        let out = self.render_file_inner(input, output);
        self.current_file = None;
        out
    }

    fn render_file_inner(&mut self, input: &Path, output: &Path) -> (bool, bool) {
        let text = match std::fs::read_to_string(input) {
            Ok(t) => t,
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => {
                self.log_error(&format!("Template file not found: {}", input.display()), "");
                return (false, false);
            }
            Err(e) => {
                self.log_error(&format!("Unexpected error: {e}"), "");
                return (false, false);
            }
        };
        let rendered = self.render(&text);
        if self.error_count > 0 {
            eprintln!("Skipping {}: template has {} error(s)", output.display(), self.error_count);
            return (false, false);
        }
        let out = expand_user(output);
        if let Some(parent) = out.parent() {
            if !parent.as_os_str().is_empty() {
                if let Err(e) = std::fs::create_dir_all(parent) {
                    if e.kind() == std::io::ErrorKind::PermissionDenied {
                        self.log_error(&format!("Permission denied: {}", output.display()), "");
                    } else {
                        self.log_error(&format!("Unexpected error: {e}"), "");
                    }
                    return (false, false);
                }
            }
        }
        if out.is_file() {
            match std::fs::read_to_string(&out) {
                Ok(cur) if cur == rendered => return (true, false),
                Ok(_) => {}
                Err(_) => {}
            }
        }
        match std::fs::write(&out, rendered) {
            Ok(()) => (true, true),
            Err(e) if e.kind() == std::io::ErrorKind::PermissionDenied => {
                self.log_error(&format!("Permission denied: {}", output.display()), "");
                (false, false)
            }
            Err(e) => {
                self.log_error(&format!("Unexpected error: {e}"), "");
                (false, false)
            }
        }
    }

    // --- Custom colors ---

    const CUSTOM_TONES_DARK: [(&str, i64); 4] =
        [("color", 80), ("on_color", 20), ("color_container", 30), ("on_color_container", 90)];
    const CUSTOM_TONES_LIGHT: [(&str, i64); 4] =
        [("color", 40), ("on_color", 100), ("color_container", 90), ("on_color_container", 10)];

    /// Renderer-local M3 harmonize: rotate hue TOWARD the target by
    /// min(|diff| * 0.5, 15). (Differs from material::harmonize_color, which
    /// mirrors material.py exactly.)
    fn harmonize_toward(design: Hct, target: Hct) -> Hct {
        let mut diff = target.hue - design.hue;
        if diff > 180.0 {
            diff -= 360.0;
        } else if diff < -180.0 {
            diff += 360.0;
        }
        let mut rotation = py_min(diff.abs() * 0.5, 15.0);
        if diff < 0.0 {
            rotation = -rotation;
        }
        Hct::new(py_mod(design.hue + rotation, 360.0), design.chroma, design.tone)
    }

    pub fn apply_custom_colors(&mut self, custom: &[(String, String, bool)]) {
        // custom: (name, hex, blend).
        let source_hex = self
            .mode_data(&self.default_mode.clone())
            .and_then(|d| {
                Self::lookup(d, "primary").filter(|s| !s.is_empty()).or_else(|| {
                    Self::lookup(d, "source_color").filter(|s| !s.is_empty())
                })
            });
        for (name, color_hex, blend) in custom {
            if !(color_hex.starts_with('#') && color_hex.len() == 7) {
                self.log_error(&format!("Custom color '{name}' has invalid hex: '{color_hex}'"), "");
                continue;
            }
            let original = match Color::from_hex(color_hex) {
                Some(c) => c,
                None => {
                    self.log_error(&format!("Custom color '{name}' has invalid hex: '{color_hex}'"), "");
                    continue;
                }
            };
            let mut palette_color = original;
            if *blend {
                if let Some(ref src_hex) = source_hex {
                    if let (Some(src), Some(target)) =
                        (Color::from_hex(color_hex), Color::from_hex(src_hex))
                    {
                        let h = Self::harmonize_toward(
                            Hct::from_rgb(src.r, src.g, src.b),
                            Hct::from_rgb(target.r, target.g, target.b),
                        );
                        let (r, g, b) = h.to_rgb();
                        palette_color = Color::new(r, g, b);
                    }
                }
            }
            let palette_hct =
                Hct::from_rgb(palette_color.r, palette_color.g, palette_color.b);
            let mut palettes = scheme_by_name(&self.scheme_type, palette_hct)
                .or_else(|| scheme_by_name("content", palette_hct))
                .expect("content scheme always known");
            let modes: Vec<String> = self.theme_data.iter().map(|(m, _)| m.clone()).collect();
            for mode in modes {
                let tones = match mode.as_str() {
                    "dark" => Some(Self::CUSTOM_TONES_DARK),
                    "light" => Some(Self::CUSTOM_TONES_LIGHT),
                    _ => None,
                };
                let Some(tones) = tones else { continue };
                let tone = |key: &str| {
                    tones.iter().find(|(k, _)| *k == key).map(|(_, t)| *t).unwrap_or(0)
                };
                if let Some(data) = self.mode_data_mut(&mode) {
                    set_token(data, &format!("{name}_source"), &original.to_hex());
                    set_token(data, &format!("{name}_value"), &original.to_hex());
                    set_token(data, name, &palettes.primary.get_hex(tone("color")));
                    set_token(data, &format!("on_{name}"), &palettes.primary.get_hex(tone("on_color")));
                    set_token(data, &format!("{name}_container"), &palettes.primary.get_hex(tone("color_container")));
                    set_token(
                        data,
                        &format!("on_{name}_container"),
                        &palettes.primary.get_hex(tone("on_color_container")),
                    );
                }
            }
        }
        self.colors_map = None;
    }

    // --- Config file ---

    pub fn process_config_file(&mut self, config_path: &Path) {
        let text = match std::fs::read_to_string(config_path) {
            Ok(t) => t,
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => {
                eprintln!("Error: Config file not found: {}", config_path.display());
                return;
            }
            Err(e) => {
                eprintln!("Error processing config file {}: {e}", config_path.display());
                return;
            }
        };
        let data: toml::Table = match text.parse() {
            Ok(v) => v,
            Err(e) => {
                eprintln!("Error processing config file {}: {e}", config_path.display());
                return;
            }
        };
        if let Some(custom) = data
            .get("config")
            .and_then(|c| c.get("custom_colors"))
            .and_then(|c| c.as_table())
        {
            let mut entries = Vec::new();
            for (name, cfg) in custom {
                match cfg {
                    toml::Value::String(hex) => entries.push((name.clone(), hex.clone(), true)),
                    toml::Value::Table(t) => {
                        let hex = t.get("color").and_then(|v| v.as_str()).unwrap_or("").to_string();
                        let blend = t.get("blend").and_then(|v| v.as_bool()).unwrap_or(true);
                        entries.push((name.clone(), hex, blend));
                    }
                    _ => self.log_warning(&format!("Invalid custom_color config for '{name}': {cfg}")),
                }
            }
            self.apply_custom_colors(&entries);
        }
        let empty = toml::map::Map::new();
        let templates = data
            .get("templates")
            .and_then(|t| t.as_table())
            .map(|t| t as &toml::map::Map<String, toml::Value>)
            .unwrap_or(&empty);
        for (name, template) in templates {
            let input = template.get("input_path").and_then(|v| v.as_str());
            let output = template.get("output_path").and_then(|v| v.as_str());
            let (Some(input), Some(output)) = (input, output) else {
                eprintln!("Warning: Template '{name}' missing input_path or output_path");
                continue;
            };
            // Reset per template to avoid state pollution.
            self.closest_color = String::new();
            let colors_to_compare = template
                .get("colors_to_compare")
                .and_then(|v| v.as_array())
                .map(|a| {
                    a.iter()
                        .filter_map(|e| {
                            Some((
                                e.get("name")?.as_str()?.to_string(),
                                e.get("color")?.as_str()?.to_string(),
                            ))
                        })
                        .collect::<Vec<_>>()
                })
                .unwrap_or_default();
            if !colors_to_compare.is_empty() {
                if let Some(compare_to) = template.get("compare_to").and_then(|v| v.as_str()) {
                    let rendered = self.render(compare_to);
                    if Color::from_hex(&rendered).is_none() {
                        eprintln!(
                            "Error processing config file {}: invalid compare_to color '{rendered}'",
                            config_path.display()
                        );
                        return;
                    }
                    let pairs: Vec<(&str, &str)> = colors_to_compare
                        .iter()
                        .map(|(n, c)| (n.as_str(), c.as_str()))
                        .collect();
                    self.closest_color = find_closest_color(&rendered, &pairs);
                }
            }
            let (ok, wrote) = self.render_file(
                &expand_user(Path::new(input)),
                &expand_user(Path::new(output)),
            );
            if !ok {
                continue;
            }
            let out_path = expand_user(Path::new(output));
            let force_hooks =
                name == "kitty" && kitty_needs_current_theme_link(&out_path);
            if !wrote && !force_hooks {
                continue;
            }
            if wrote {
                if let Some(pre) = template.get("pre_hook").and_then(|v| v.as_str()) {
                    let mut hook = pre.to_string();
                    if !self.closest_color.is_empty() {
                        hook = substitute_closest(&hook, &self.closest_color);
                    }
                    hook = self.render(&hook);
                    if let Err(e) = run_shell(&hook) {
                        eprintln!("Error running pre_hook for {name}: {e}");
                    }
                }
            }
            if let Some(post) = template.get("post_hook").and_then(|v| v.as_str()) {
                let mut hook = post.to_string();
                if !self.closest_color.is_empty() {
                    hook = substitute_closest(&hook, &self.closest_color);
                }
                hook = self.render(&hook);
                if let Err(e) = run_shell(&hook) {
                    eprintln!("Error running post_hook for {name}: {e}");
                }
            }
        }
    }
}

fn set_token(data: &mut Vec<(String, String)>, key: &str, value: &str) {
    if let Some(slot) = data.iter_mut().find(|(k, _)| k == key) {
        slot.1 = value.to_string();
    } else {
        data.push((key.to_string(), value.to_string()));
    }
}

fn is_int_lit(s: &str) -> bool {
    let t = s.strip_prefix('-').unwrap_or(s);
    // Mirrors -\d+: ASCII digits (unicode-digit ranges would parse in Python's
    // int() but never appear in real templates).
    !t.is_empty() && t.bytes().all(|b| b.is_ascii_digit())
}

fn expand_user(p: &Path) -> PathBuf {
    let s = p.to_string_lossy();
    if let Some(rest) = s.strip_prefix("~/").or_else(|| (s == "~").then_some("")) {
        if let Ok(home) = std::env::var("HOME") {
            return PathBuf::from(home).join(rest);
        }
    }
    p.to_path_buf()
}

fn kitty_needs_current_theme_link(noctalia_theme_path: &Path) -> bool {
    if !noctalia_theme_path.is_file() {
        return false;
    }
    let Ok(home) = std::env::var("HOME") else { return false };
    !Path::new(&home).join(".config/kitty/current-theme.conf").is_file()
}

fn run_shell(hook: &str) -> std::io::Result<()> {
    std::process::Command::new("sh").arg("-c").arg(hook).status().map(|_| ())
}

/// Substitute {{ closest_color }} (whitespace-tolerant).
fn substitute_closest(text: &str, replacement: &str) -> String {
    let mut out = String::new();
    let mut i = 0;
    let b = text.as_bytes();
    while i < b.len() {
        if b[i] == b'{' && i + 1 < b.len() && b[i + 1] == b'{' {
            if let Some(rel) = text[i + 2..].find("}}") {
                let inner = text[i + 2..i + 2 + rel].trim();
                if inner == "closest_color" {
                    out.push_str(replacement);
                    i = i + 2 + rel + 2;
                    continue;
                }
            }
            out.push_str("{{");
            i += 2;
        } else {
            let ch = text[i..].chars().next().unwrap();
            out.push(ch);
            i += ch.len_utf8();
        }
    }
    out
}

/// Parse `"find", "replacement"` (or single-quoted) prefix, like re.match.
fn parse_quoted_pair(args: &str, q: char) -> Option<(String, String)> {
    let s = args.trim_start();
    let first = s.strip_prefix(q)?;
    let end = first.find(q)?;
    let find = first[..end].to_string();
    let rest = first[end + 1..].trim_start();
    let rest = rest.strip_prefix(',')?.trim_start();
    let second = rest.strip_prefix(q)?;
    let end2 = second.find(q)?;
    Some((find, second[..end2].to_string()))
}

// --- Case conversion ---

fn split_words(s: &str) -> Vec<String> {
    // ASCII camel boundary: a-z followed by A-Z.
    let chars: Vec<char> = s.chars().collect();
    let mut tmp = String::new();
    for (i, &c) in chars.iter().enumerate() {
        tmp.push(c);
        if c.is_ascii_lowercase() {
            if let Some(&n) = chars.get(i + 1) {
                if n.is_ascii_uppercase() {
                    tmp.push('_');
                }
            }
        }
    }
    tmp.split(|c: char| !c.is_alphanumeric())
        .filter(|w| !w.is_empty())
        .map(|w| w.to_string())
        .collect()
}

fn capitalize_word(w: &str) -> String {
    let mut chars = w.chars();
    match chars.next() {
        None => String::new(),
        Some(f) => {
            let rest: String = chars.collect();
            format!("{}{}", f.to_uppercase(), rest.to_lowercase())
        }
    }
}

fn to_camel_case(s: &str) -> String {
    let words = split_words(s);
    if words.is_empty() {
        return s.to_string();
    }
    let mut out = words[0].to_lowercase();
    for w in &words[1..] {
        out.push_str(&capitalize_word(w));
    }
    out
}

fn to_pascal_case(s: &str) -> String {
    let words = split_words(s);
    if words.is_empty() {
        return s.to_string();
    }
    words.iter().map(|w| capitalize_word(w)).collect()
}

fn to_snake_case(s: &str) -> String {
    split_words(s).iter().map(|w| w.to_lowercase()).collect::<Vec<_>>().join("_")
}

fn to_kebab_case(s: &str) -> String {
    split_words(s).iter().map(|w| w.to_lowercase()).collect::<Vec<_>>().join("-")
}

#[cfg(test)]
mod tests {
    use super::*;

    fn theme() -> ThemeData {
        vec![
            ("dark".to_string(), vec![
                ("primary".to_string(), "#7aa2f7".to_string()),
                ("surface".to_string(), "#1a1b26".to_string()),
            ]),
            ("light".to_string(), vec![
                ("primary".to_string(), "#34548a".to_string()),
                ("surface".to_string(), "#d5d6db".to_string()),
            ]),
        ]
    }

    fn render(tpl: &str) -> String {
        TemplateRenderer::new(theme()).render(tpl)
    }

    #[test]
    fn basic_tags_and_modes() {
        assert_eq!(render("{{colors.primary.dark.hex}}"), "#7aa2f7");
        assert_eq!(render("{{colors.primary.light.hex}}"), "#34548a");
        assert_eq!(render("{{colors.primary.default.hex}}"), "#7aa2f7");
        assert_eq!(render("{{colors.primary.dark.hex_stripped}}"), "7aa2f7");
        assert_eq!(render("{{colors.primary.dark.rgb}}"), "rgb(122, 162, 247)");
        assert_eq!(render("{{colors.primary.dark.rgb_csv}}"), "122,162,247");
        assert_eq!(render("{{colors.primary.dark.red}}"), "122");
        assert_eq!(render("{{mode}}"), "dark");
        assert_eq!(render("{{nope}}"), "{{nope}}");
        assert_eq!(render("{{colors.nope.dark.hex}}"), "{{UNKNOWN:nope.dark}}");
    }

    #[test]
    fn filters_match_python() {
        // Oracle values from renderer.py on #7aa2f7.
        assert_eq!(render("{{colors.primary.dark.hex | grayscale}}"), "#9f9f9f");
        assert_eq!(render("{{colors.primary.dark.hex | invert}}"), "#855d08");
        assert_eq!(
            render("{{colors.primary.dark.rgba | set_alpha 0.5}}"),
            "rgba(122, 162, 247, 0.5)"
        );
        assert_eq!(render("{{colors.primary.dark.hex | lighten 10}}"), "#aac4fa");
        assert_eq!(render("{{colors.primary.dark.hex | darken 10}}"), "#4a80f4");
        assert_eq!(render("{{colors.primary.dark.hex | set_red 10}}"), "#0aa2f7");
        assert_eq!(render("{{colors.primary.dark.hsl | replace: \"hsl\", \"HSL\"}}"), "HSL(220, 88%, 72%)");
        assert_eq!(render("{{mode | pascal_case}}"), "Dark");
    }

    #[test]
    fn blend_harmonize_match_python() {
        // Oracle values from renderer.py on #7aa2f7.
        assert_eq!(
            render("{{colors.primary.dark.hex | blend: \"#ff0000\", 0.5}}"),
            "#d289da"
        );
        assert_eq!(
            render("{{colors.primary.dark.hex | harmonize \"#ff0000\"}}"),
            "#949cf8"
        );
    }

    #[test]
    fn blocks_match_python() {
        // Standalone block lines vanish like matugen.
        let out = render("<* for name, value in colors *>\n{{name}}={{value.default}};\n<* endfor *>\n");
        assert_eq!(out, "primary=#7aa2f7;\nsurface=#1a1b26;\n");
        let out = render("<* for i in 0..3 *>{{i}}<* endfor *>");
        assert_eq!(out, "012");
        let out = render("<* for c in palettes.primary *>{{c.dark}} <* endfor *>");
        assert!(out.starts_with("#000000 "), "got {out}");
        assert!(out.ends_with("#ffffff "), "got {out}");
        // Unknown conditions resolve to their {{...}} text, which is truthy.
        let out = render("<* if {{ loop.first }} *>X<* endif *>");
        assert_eq!(out, "X");
        let out = render("<* if {{ nope }} *>X<* else *>Y<* endif *>");
        assert_eq!(out, "X");
        let out = render("<* for i in 0..2 *><* if {{ loop.first }} *>F<* else *>L<* endif *><* endfor *>");
        assert_eq!(out, "FL");
    }

    #[test]
    fn errors_count_and_placeholders() {
        let mut r = TemplateRenderer::new(theme());
        let out = r.render("{{colors.primary.dark.bogus}}");
        assert_eq!(out, "#7aa2f7");
        assert_eq!(r.error_count(), 1);
        let mut r = TemplateRenderer::new(theme());
        let out = r.render("{{colors.primary.Nope.hex}}");
        assert_eq!(out, "{{colors.primary.Nope.hex}}");
        assert_eq!(r.error_count(), 1);
    }


    /// Full-pipeline oracle: composite template exercising tags, loops, ranges,
    /// palettes, if/else, filters, aliases, custom colors, escapes.
    /// Expected output generated by renderer.py (BYTE_IDENTICAL at bake time).
    #[test]
    fn composite_template_matches_python() {
        let theme_json = r##"{"dark": {"primary": "#ffb4a4", "on_primary": "#630e00", "primary_container": "#8c1800", "on_primary_container": "#ffdad3", "surface_tint": "#ffb4a4", "secondary": "#ffb4a4", "on_secondary": "#5b1a0c", "secondary_container": "#783020", "on_secondary_container": "#ffdad3", "tertiary": "#ffb94e", "on_tertiary": "#452b00", "tertiary_container": "#624000", "on_tertiary_container": "#ffddb2", "error": "#ffb4ab", "on_error": "#690005", "error_container": "#93000a", "on_error_container": "#ffdad6", "surface": "#1d100d", "on_surface": "#f7ddd7", "surface_variant": "#5a413b", "on_surface_variant": "#e2bfb7", "surface_container_lowest": "#170b08", "surface_container_low": "#261815", "surface_container": "#2b1c19", "surface_container_high": "#362623", "surface_container_highest": "#41312d", "outline": "#a98a83", "outline_variant": "#5a413b", "shadow": "#000000", "scrim": "#000000", "inverse_surface": "#f7ddd7", "inverse_on_surface": "#3d2d29", "inverse_primary": "#b22c0f", "background": "#1d100d", "on_background": "#f7ddd7", "surface_dim": "#1d100d", "surface_bright": "#463532", "primary_fixed": "#ffdad3", "primary_fixed_dim": "#ffb4a4", "on_primary_fixed": "#3d0600", "on_primary_fixed_variant": "#8c1800", "secondary_fixed": "#ffdad3", "secondary_fixed_dim": "#ffb4a4", "on_secondary_fixed": "#3d0600", "on_secondary_fixed_variant": "#783020", "tertiary_fixed": "#ffddb2", "tertiary_fixed_dim": "#ffb94e", "on_tertiary_fixed": "#291800", "on_tertiary_fixed_variant": "#624000"}, "light": {"primary": "#b22c0f", "on_primary": "#ffffff", "primary_container": "#ffdad3", "on_primary_container": "#3d0600", "surface_tint": "#b22c0f", "secondary": "#964735", "on_secondary": "#ffffff", "secondary_container": "#ffdad3", "on_secondary_container": "#3d0600", "tertiary": "#825500", "on_tertiary": "#ffffff", "tertiary_container": "#ffddb2", "on_tertiary_container": "#291800", "error": "#ba1a1a", "on_error": "#ffffff", "error_container": "#ffdad6", "on_error_container": "#410002", "surface": "#fff8f6", "on_surface": "#261815", "surface_variant": "#ffdad3", "on_surface_variant": "#5a413b", "surface_container_lowest": "#ffffff", "surface_container_low": "#fff0ed", "surface_container": "#ffe9e5", "surface_container_high": "#fde2dd", "surface_container_highest": "#f7ddd7", "outline": "#8e706a", "outline_variant": "#e2bfb7", "shadow": "#000000", "scrim": "#000000", "inverse_surface": "#3d2d29", "inverse_on_surface": "#ffede9", "inverse_primary": "#ffb4a4", "background": "#fff8f6", "on_background": "#261815", "surface_dim": "#efd4cf", "surface_bright": "#fff8f6", "primary_fixed": "#ffdad3", "primary_fixed_dim": "#ffb4a4", "on_primary_fixed": "#3d0600", "on_primary_fixed_variant": "#8c1800", "secondary_fixed": "#ffdad3", "secondary_fixed_dim": "#ffb4a4", "on_secondary_fixed": "#3d0600", "on_secondary_fixed_variant": "#783020", "tertiary_fixed": "#ffddb2", "tertiary_fixed_dim": "#ffb94e", "on_tertiary_fixed": "#291800", "on_tertiary_fixed_variant": "#624000"}}"##;
        let template = r##"bg={{colors.primary.dark.hex}} fg={{colors.on_primary.default.hex_stripped}}
<* for name, value in colors *>
{{name}}: {{value.dark}} / {{value.light}} / {{value.default}}
<* endfor *>
<* for i in 0..3 *>n={{i}};<* endfor *>
<* for t in palettes.primary *>{{t.dark}};<* endfor *>
<* for i in 0..2 *><* if {{ loop.last }} *>last<* else *>mid<* endif *><* endfor *>
filt={{colors.secondary.dark.hex | lighten 5 | saturate 10}}
rep={{colors.tertiary.dark.rgb | replace: "rgb", "RGB"}}
case={{mode | kebab_case}} {{mode | camel_case}}
blend={{colors.primary.dark.hex | blend: "#00ff00", 0.25}}
harm={{colors.error.dark.hex | harmonize "#0000ff"}}
hue={{colors.primary.dark.hue}} sat={{colors.primary.dark.saturation}} light={{colors.primary.dark.lightness}}
csv={{colors.surface.dark.rgb_csv}} hsl={{colors.surface.light.hsl}} hsla={{colors.surface.light.hsla | set_alpha 0.3}}
alias={{colors.hover.dark.hex}} {{colors.on_hover.light.hex}}
custom={{colors.accent.dark.hex}} {{colors.accent_container.light.hex}} {{colors.on_accent.dark.hex}}
closest={{closest_color}}
img={{image}}
esc=a\\b
"##;
        let v: serde_json::Value = serde_json::from_str(theme_json).unwrap();
        let theme: ThemeData = v.as_object().unwrap().iter().map(|(m, d)| {
            (m.clone(), d.as_object().unwrap().iter().map(|(k, h)| {
                (k.clone(), h.as_str().unwrap().to_string())
            }).collect())
        }).collect();
        let mut r = TemplateRenderer::with_options(
            theme, false, "dark", Some("/tmp/wall.jpg".to_string()), "content");
        r.apply_custom_colors(&[("accent".to_string(), "#ff5500".to_string(), true)]);
        let out = r.render(template);
        assert_eq!(r.error_count(), 0);
        assert_eq!(out, r##"bg=#ffb4a4 fg=630e00
accent: #ffb5a0 / #b12e00 / #ffb5a0
accent_container: #872100 / #ffdbd1 / #872100
accent_source: #ff5500 / #ff5500 / #ff5500
accent_value: #ff5500 / #ff5500 / #ff5500
background: #1d100d / #fff8f6 / #1d100d
error: #ffb4ab / #ba1a1a / #ffb4ab
error_container: #93000a / #ffdad6 / #93000a
inverse_on_surface: #3d2d29 / #ffede9 / #3d2d29
inverse_primary: #b22c0f / #ffb4a4 / #b22c0f
inverse_surface: #f7ddd7 / #3d2d29 / #f7ddd7
on_accent: #601400 / #ffffff / #601400
on_accent_container: #ffdbd1 / #3b0900 / #ffdbd1
on_background: #f7ddd7 / #261815 / #f7ddd7
on_error: #690005 / #ffffff / #690005
on_error_container: #ffdad6 / #410002 / #ffdad6
on_primary: #630e00 / #ffffff / #630e00
on_primary_container: #ffdad3 / #3d0600 / #ffdad3
on_primary_fixed: #3d0600 / #3d0600 / #3d0600
on_primary_fixed_variant: #8c1800 / #8c1800 / #8c1800
on_secondary: #5b1a0c / #ffffff / #5b1a0c
on_secondary_container: #ffdad3 / #3d0600 / #ffdad3
on_secondary_fixed: #3d0600 / #3d0600 / #3d0600
on_secondary_fixed_variant: #783020 / #783020 / #783020
on_surface: #f7ddd7 / #261815 / #f7ddd7
on_surface_variant: #e2bfb7 / #5a413b / #e2bfb7
on_tertiary: #452b00 / #ffffff / #452b00
on_tertiary_container: #ffddb2 / #291800 / #ffddb2
on_tertiary_fixed: #291800 / #291800 / #291800
on_tertiary_fixed_variant: #624000 / #624000 / #624000
outline: #a98a83 / #8e706a / #a98a83
outline_variant: #5a413b / #e2bfb7 / #5a413b
primary: #ffb4a4 / #b22c0f / #ffb4a4
primary_container: #8c1800 / #ffdad3 / #8c1800
primary_fixed: #ffdad3 / #ffdad3 / #ffdad3
primary_fixed_dim: #ffb4a4 / #ffb4a4 / #ffb4a4
scrim: #000000 / #000000 / #000000
secondary: #ffb4a4 / #964735 / #ffb4a4
secondary_container: #783020 / #ffdad3 / #783020
secondary_fixed: #ffdad3 / #ffdad3 / #ffdad3
secondary_fixed_dim: #ffb4a4 / #ffb4a4 / #ffb4a4
shadow: #000000 / #000000 / #000000
surface: #1d100d / #fff8f6 / #1d100d
surface_bright: #463532 / #fff8f6 / #463532
surface_container: #2b1c19 / #ffe9e5 / #2b1c19
surface_container_high: #362623 / #fde2dd / #362623
surface_container_highest: #41312d / #f7ddd7 / #41312d
surface_container_low: #261815 / #fff0ed / #261815
surface_container_lowest: #170b08 / #ffffff / #170b08
surface_dim: #1d100d / #efd4cf / #1d100d
surface_tint: #ffb4a4 / #b22c0f / #ffb4a4
surface_variant: #5a413b / #ffdad3 / #5a413b
tertiary: #ffb94e / #825500 / #ffb94e
tertiary_container: #624000 / #ffddb2 / #624000
tertiary_fixed: #ffddb2 / #ffddb2 / #ffddb2
tertiary_fixed_dim: #ffb94e / #ffb94e / #ffb94e
n=0;n=1;n=2;
#000000;#280501;#360e06;#44180f;#512219;#5f2d23;#6c382d;#7a4338;#884f43;#a56759;#c38071;#e19a8a;#ffb4a4;#ffdad3;#ffede9;#fff8f6;#fffbff;#ffffff;
midlastfilt=#ffc9be
rep=RGB(255, 185, 78)
case=dark dark
blend=#f7ba88
harm=#fcb4bd
hue=10 sat=99 light=82
csv=29,16,13 hsl=hsl(13, 100%, 98%) hsla=hsla(13, 100%, 98%, 0.3)
alias=#362623 #261815
custom=#ffb5a0 #ffdbd1 #601400
closest={{closest_color}}
img=/tmp/wall.jpg
esc=a\b
"##);
    }

    #[test]
    fn backslash_escape() {
        assert_eq!(render("a\\\\b"), "a\\b");
    }

    fn scratch_dir(tag: &str) -> std::path::PathBuf {
        let dir = std::env::temp_dir()
            .join(format!("nosd-theme-test-{}-{}", std::process::id(), tag));
        let _ = std::fs::create_dir_all(&dir);
        dir
    }

    #[test]
    fn render_file_skips_identical() {
        let dir = scratch_dir("render");
        let tpl = dir.join("t.tpl");
        let out = dir.join("o.txt");
        std::fs::write(&tpl, "v={{colors.primary.dark.hex}}").unwrap();
        let mut r = TemplateRenderer::new(theme());
        assert_eq!(r.render_file(&tpl, &out), (true, true));
        assert_eq!(std::fs::read_to_string(&out).unwrap(), "v=#7aa2f7");
        // Second run: identical content, no write.
        assert_eq!(r.render_file(&tpl, &out), (true, false));
        // Missing template.
        assert_eq!(r.render_file(&dir.join("nope"), &out), (false, false));
    }

    #[test]
    fn render_file_error_skips_write() {
        let dir = scratch_dir("render-err");
        let tpl = dir.join("t.tpl");
        let out = dir.join("o.txt");
        // Unknown mode -> error -> (false, false), no file.
        std::fs::write(&tpl, "{{colors.primary.night.hex}}").unwrap();
        let mut r = TemplateRenderer::new(theme());
        assert_eq!(r.render_file(&tpl, &out), (false, false));
        assert!(!out.exists());
    }

    #[test]
    fn config_file_end_to_end() {
        let dir = scratch_dir("config");
        let tpl = dir.join("t.tpl");
        let out = dir.join("o.txt");
        let hook_out = dir.join("hook.txt");
        std::fs::write(&tpl, "c={{colors.accent.dark.hex}} m={{mode}}").unwrap();
        let cfg = dir.join("c.toml");
        std::fs::write(
            &cfg,
            format!(
                "[config.custom_colors]\naccent = \"#ff5500\"\n\n\
                 [templates.a]\ninput_path = \"{}\"\noutput_path = \"{}\"\n\
                 post_hook = \"echo hi > {}\"\n",
                tpl.display(),
                out.display(),
                hook_out.display()
            ),
        )
        .unwrap();
        let mut r = TemplateRenderer::with_options(theme(), false, "light", None, "content");
        r.process_config_file(&cfg);
        assert_eq!(r.error_count(), 0);
        let text = std::fs::read_to_string(&out).unwrap();
        assert!(text.starts_with("c=#"), "got {text}");
        assert!(text.contains("m=light"), "got {text}");
        assert_eq!(std::fs::read_to_string(&hook_out).unwrap().trim(), "hi");
    }
}
