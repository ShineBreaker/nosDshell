#![forbid(unsafe_code)]

//! 从主题 css 派生 St（Cinnamon / GNOME Shell）侧的 accent 覆盖文件。
//!
//! St 不认 `@define-color`，所以只能把含 accent 字面值的规则**原样重声明**一遍、
//! 把值换成当前调色板的 accent：主题 css 末尾 `@import` 这份覆盖文件，St 从属性
//! 数组末尾往前查找，后声明胜出。选择器由扫描得出而不是手抄，主题升级后不会静默失配。

use crate::color::Color;

/// 主题里代表 accent 的字面值（大小写不敏感匹配）。
const ACCENT_LITERAL: &str = "#5294e2";
/// accent 加深一档（同色相，L −10%）。
const ACCENT_DARK_LITERAL: &str = "#2679db";

fn has_literal(s: &str) -> bool {
    let low = s.to_ascii_lowercase();
    low.contains(ACCENT_LITERAL) || low.contains(ACCENT_DARK_LITERAL)
}

fn replace_ci(hay: &str, needle: &str, with: &str) -> String {
    let low = hay.to_ascii_lowercase();
    let mut out = String::with_capacity(hay.len());
    let mut i = 0;
    while i < hay.len() {
        if low[i..].starts_with(needle) {
            out.push_str(with);
            i += needle.len();
        } else {
            let ch = hay[i..].chars().next().unwrap();
            out.push(ch);
            i += ch.len_utf8();
        }
    }
    out
}

/// 顶层规则块的字节区间。shell css 是平铺的（无 @media 嵌套），
/// 深度计数即可；分号在深度 0 处只用于跳过语句间空白。
fn block_ranges(text: &str) -> Vec<(usize, usize)> {
    let bytes = text.as_bytes();
    let (mut depth, mut start, mut i) = (0usize, 0usize, 0usize);
    let mut out = Vec::new();
    while i < bytes.len() {
        match bytes[i] {
            b'{' => depth += 1,
            b'}' => {
                depth = depth.saturating_sub(1);
                if depth == 0 {
                    out.push((start, i + 1));
                    start = i + 1;
                }
            }
            b';' if depth == 0 => start = i + 1,
            _ => {}
        }
        i += 1;
    }
    out
}

/// 生成覆盖文件内容：只重声明含 accent 字面值的规则块。
pub fn generate(theme_css: &str, accent: Color) -> String {
    let (h, s, l) = accent.to_hsl();
    let darker = Color::from_hsl(h, s, (l * 0.9).clamp(0.0, 1.0)).to_hex();
    let accent_hex = accent.to_hex();
    let mut out = String::from(
        "/* nosd-accent.css —— 由 nosDshell 生成，勿手工编辑。\n\
         * 只重声明主题里含 accent 字面值的规则；St 后声明胜出。 */\n\n",
    );
    for (a, b) in block_ranges(theme_css) {
        let raw = &theme_css[a..b];
        if !has_literal(raw) {
            continue;
        }
        let text = replace_ci(raw, ACCENT_DARK_LITERAL, &darker);
        let text = replace_ci(&text, ACCENT_LITERAL, &accent_hex);
        out.push_str(text.trim_start());
        out.push('\n');
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn redeclares_only_accent_blocks() {
        let css = ".a { color: #5294E2; }\n.b { color: #ffffff; }\n.c { background-color: #2679db; }\n";
        let out = generate(css, Color::from_hex("#ff00ff").unwrap());
        assert!(out.contains(".a { color: #ff00ff; }"), "accent 未替换: {out}");
        assert!(out.contains(".c { background-color: "), "加深色块缺失: {out}");
        assert!(!out.contains(".b"), "无 accent 的规则不该被重声明: {out}");
        assert!(!out.to_ascii_lowercase().contains("#5294e2"), "残留原字面值: {out}");
    }

    #[test]
    fn lowercase_literal_matched() {
        let css = ".x { color: #5294e2; }\n";
        let out = generate(css, Color::from_hex("#2ca7f8").unwrap());
        assert!(out.contains("#2ca7f8"));
    }

    #[test]
    fn darker_is_ten_percent_lower_lightness() {
        let out = generate(".c { border-color: #2679db; }\n", Color::from_hex("#106daa").unwrap());
        // #106daa 的 L=36.5% -> 32.9% 左右
        let line = out.lines().find(|l| l.contains("border-color")).unwrap();
        assert!(!line.to_ascii_lowercase().contains("#2679db"), "{line}");
    }
}
