use rnix::ast::{self, AttrpathValue, Inherit};
use rnix::{NodeOrToken, SyntaxKind, SyntaxNode};
use rowan::ast::AstNode;
use std::collections::HashMap;

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() != 2 {
        eprintln!("usage: nixnest <file.nix>");
        std::process::exit(1);
    }
    let src = std::fs::read_to_string(&args[1]).unwrap();
    match format(&src) {
        Ok(out) => print!("{}", out),
        Err(e) => {
            eprintln!("{}", e);
            std::process::exit(1);
        }
    }
}

pub fn format(src: &str) -> Result<String, String> {
    let parsed = rnix::Root::parse(src);
    if !parsed.errors().is_empty() {
        return Err(format!("parse errors: {:?}", parsed.errors()));
    }
    Ok(render_node(&parsed.syntax(), "", src))
}

fn render_node(node: &SyntaxNode, indent: &str, src: &str) -> String {
    if let Some(attrset) = ast::AttrSet::cast(node.clone()) {
        render_entries(node, indent, src, BlockKind::AttrSet { rec: attrset.rec_token().is_some() })
    } else if let Some(letin) = ast::LetIn::cast(node.clone()) {
        let body = letin.body().map(|e| e.syntax().clone());
        render_entries(node, indent, src, BlockKind::LetIn { body })
    } else if ast::LegacyLet::cast(node.clone()).is_some() {
        render_entries(node, indent, src, BlockKind::LegacyLet)
    } else {
        let mut out = String::new();
        for child in node.children_with_tokens() {
            match child {
                NodeOrToken::Node(n) => out.push_str(&render_node(&n, indent, src)),
                NodeOrToken::Token(t) => out.push_str(t.text()),
            }
        }
        out
    }
}

enum BlockKind {
    AttrSet { rec: bool },
    LegacyLet,
    LetIn { body: Option<SyntaxNode> },
}

#[derive(Clone)]
struct Item {
    key_path: Vec<String>,
    first_key: String,
    attrpath_text: String,
    value: Option<SyntaxNode>,
    inherit: Option<SyntaxNode>,
    leading: String,
    inline: String,
}

impl Item {
    fn is_inherit(&self) -> bool {
        self.inherit.is_some()
    }
}

fn collect_entries(node: &SyntaxNode) -> (Vec<Item>, String) {
    let mut items: Vec<Item> = Vec::new();
    let mut leading_buf = String::new();
    let mut after_entry = false;
    let mut inline_buf = String::new();

    for child in node.children_with_tokens() {
        match child {
            NodeOrToken::Node(n) => {
                if let Some(av) = AttrpathValue::cast(n.clone()) {
                    let leading = leading_buf.clone();
                    leading_buf.clear();
                    after_entry = true;
                    inline_buf.clear();
                    let attrpath = av.attrpath().expect("attrpath value without path");
                    let attrs: Vec<_> = attrpath.attrs().collect();
                    let key_path: Vec<String> = attrs.iter().map(|a| a.syntax().text().to_string()).collect();
                    let first_key = key_path.first().cloned().unwrap_or_default();
                    let value = av.value().map(|e| e.syntax().clone());
                    items.push(Item {
                        key_path,
                        first_key,
                        attrpath_text: attrpath.syntax().text().to_string(),
                        value,
                        inherit: None,
                        leading,
                        inline: String::new(),
                    });
                } else if let Some(_inh) = Inherit::cast(n.clone()) {
                    let leading = leading_buf.clone();
                    leading_buf.clear();
                    after_entry = true;
                    inline_buf.clear();
                    items.push(Item {
                        key_path: Vec::new(),
                        first_key: String::new(),
                        attrpath_text: String::new(),
                        value: None,
                        inherit: Some(n.clone()),
                        leading,
                        inline: String::new(),
                    });
                } else if after_entry {
                    let text = n.text().to_string();
                    if text.contains('\n') {
                        let idx = text.find('\n').unwrap();
                        inline_buf.push_str(&text[..idx]);
                        if let Some(last) = items.last_mut() {
                            last.inline = take_inline(&inline_buf);
                        }
                        inline_buf.clear();
                        leading_buf.push_str(&text[idx..]);
                        after_entry = false;
                    } else {
                        inline_buf.push_str(&text);
                    }
                }
            }
            NodeOrToken::Token(t) => {
                let text = t.text().to_string();
                if after_entry {
                    if is_structural_token(t.kind()) {
                        if let Some(last) = items.last_mut() {
                            last.inline = take_inline(&inline_buf);
                        }
                        inline_buf.clear();
                        after_entry = false;
                    } else if text.contains('\n') {
                        let idx = text.find('\n').unwrap();
                        inline_buf.push_str(&text[..idx]);
                        if let Some(last) = items.last_mut() {
                            last.inline = take_inline(&inline_buf);
                        }
                        inline_buf.clear();
                        leading_buf.push_str(&text[idx..]);
                        after_entry = false;
                    } else {
                        inline_buf.push_str(&text);
                    }
                } else if !is_structural_token(t.kind()) {
                    leading_buf.push_str(&text);
                }
            }
        }
    }
    if after_entry {
        if let Some(last) = items.last_mut() {
            last.inline = take_inline(&inline_buf);
        }
    }
    (items, leading_buf)
}

fn render_entries(node: &SyntaxNode, indent: &str, src: &str, kind: BlockKind) -> String {
    let inner_indent = format!("{}  ", indent);
    let (items, leading_buf) = collect_entries(node);
    let body = render_items(&items, &inner_indent, src);
    let trailing = extract_comments(&leading_buf);

    match kind {
        BlockKind::AttrSet { rec } => {
            let mut out = String::new();
            if rec {
                out.push_str("rec ");
            }
            out.push_str("{\n");
            out.push_str(&body);
            if !trailing.is_empty() {
                out.push_str(&reindent(&trailing, &inner_indent));
            }
            out.push_str(indent);
            out.push('}');
            out
        }
        BlockKind::LegacyLet => {
            let mut out = String::new();
            out.push_str("{\n");
            out.push_str(&body);
            if !trailing.is_empty() {
                out.push_str(&reindent(&trailing, &inner_indent));
            }
            out.push_str(indent);
            out.push('}');
            out
        }
        BlockKind::LetIn { body: let_body } => {
            let mut out = String::new();
            out.push_str("let\n");
            out.push_str(&body);
            if !trailing.is_empty() {
                out.push_str(&reindent(&trailing, &inner_indent));
            }
            out.push_str(indent);
            out.push_str("in ");
            if let Some(b) = &let_body {
                out.push_str(&render_node(b, indent, src));
            }
            out
        }
    }
}

fn render_items(items: &[Item], indent: &str, src: &str) -> String {
    let inner_indent = format!("{}  ", indent);
    let mut groups: HashMap<String, Vec<usize>> = HashMap::new();
    for (i, item) in items.iter().enumerate() {
        if item.is_inherit() {
            continue;
        }
        let is_attrset_value = item
            .value
            .as_ref()
            .is_some_and(|v| ast::AttrSet::cast(v.clone()).is_some());
        if item.key_path.len() == 1 && !is_attrset_value {
            continue;
        }
        groups.entry(item.first_key.clone()).or_default().push(i);
    }

    let mergeable: HashMap<String, bool> = groups
        .iter()
        .map(|(k, members)| {
            let ok = members.len() >= 2
                && members.iter().all(|&mi| {
                    let m = &items[mi];
                    if m.key_path.len() == 1 {
                        if let Some(v) = &m.value {
                            if let Some(attrset) = ast::AttrSet::cast(v.clone()) {
                                return attrset.rec_token().is_none();
                            }
                        }
                        false
                    } else {
                        true
                    }
                });
            (k.clone(), ok)
        })
        .collect();

    let mut rendered_groups: HashMap<String, bool> = HashMap::new();
    let mut out = String::new();

    for item in items.iter() {
        if item.is_inherit() {
            out.push_str(&reindent(&item.leading, indent));
            out.push_str(indent);
            out.push_str(&item.inherit.as_ref().unwrap().text().to_string());
            out.push_str(&item.inline);
            out.push('\n');
            continue;
        }

        let k = &item.first_key;
        let merge = mergeable.get(k).copied().unwrap_or(false);
        if merge {
            if rendered_groups.get(k).copied().unwrap_or(false) {
                continue;
            }
            rendered_groups.insert(k.clone(), true);
            let members = groups.get(k).unwrap();

            out.push_str(&reindent(&item.leading, indent));
            out.push_str(indent);
            out.push_str(k);
            out.push_str(" = {\n");

            let mut child_items: Vec<Item> = Vec::new();
            for &mi in members {
                let m = &items[mi];
                if m.key_path.len() == 1 {
                    // Merge a base attrset's entries into the group.
                    if let Some(v) = &m.value {
                        let (base_items, _) = collect_entries(v);
                        child_items.extend(base_items);
                    }
                } else {
                    let rest = &m.attrpath_text[m.first_key.len()..];
                    let remaining = rest.strip_prefix('.').unwrap_or(rest);
                    child_items.push(Item {
                        key_path: m.key_path[1..].to_vec(),
                        first_key: m.key_path.get(1).cloned().unwrap_or_default(),
                        attrpath_text: remaining.to_string(),
                        value: m.value.clone(),
                        inherit: None,
                        leading: m.leading.clone(),
                        inline: m.inline.clone(),
                    });
                }
            }

            out.push_str(&render_items(&child_items, &inner_indent, src));
            out.push_str(indent);
            out.push_str("};\n");
            continue;
        }

        out.push_str(&reindent(&item.leading, indent));
        out.push_str(indent);
        out.push_str(&item.attrpath_text);
        out.push_str(" = ");
        if let Some(v) = &item.value {
            out.push_str(&render_node(v, indent, src));
        }
        out.push(';');
        out.push_str(&item.inline);
        out.push('\n');
    }

    out
}

fn is_structural_token(kind: SyntaxKind) -> bool {
    use SyntaxKind::*;
    matches!(
        kind,
        TOKEN_L_BRACE | TOKEN_R_BRACE | TOKEN_REC | TOKEN_LET | TOKEN_IN
    )
}

fn take_inline(buf: &str) -> String {
    if buf.contains('#') {
        buf.to_string()
    } else {
        String::new()
    }
}

fn reindent(raw: &str, indent: &str) -> String {
    let mut out = String::new();
    let mut pending_blank = false;
    for line in raw.split('\n') {
        let trimmed = line.trim_start();
        if trimmed.is_empty() {
            pending_blank = true;
        } else {
            if pending_blank && !out.is_empty() {
                out.push('\n');
            }
            pending_blank = false;
            out.push_str(indent);
            out.push_str(trimmed);
            out.push('\n');
        }
    }
    out
}

fn extract_comments(raw: &str) -> String {
    let mut out = String::new();
    for line in raw.split('\n') {
        let trimmed = line.trim_start();
        if trimmed.is_empty() {
            out.push('\n');
        } else if trimmed.starts_with('#') {
            out.push_str(line);
            out.push('\n');
        }
    }
    out
}

#[cfg(test)]
mod tests {
    use super::format;

    type Fixture = (&'static str, &'static str, &'static str);

    const FIXTURES: &[Fixture] = &[
        ("empty_attrset", "{}", "{\n}"),
        ("simple_attr", "{ a = 1; }", "{\n  a = 1;\n}"),
        ("nested_attrset", "{ a = { b = 1; }; }", "{\n  a = {\n    b = 1;\n  };\n}"),
        (
            "merge_shared_prefix",
            "{ a.b = 1; a.c = 2; }",
            "{\n  a = {\n    b = 1;\n    c = 2;\n  };\n}",
        ),
        (
            "merge_with_base_attrset",
            "{ a = { b = 1; }; a.c = 2; }",
            "{\n  a = {\n    b = 1;\n    c = 2;\n  };\n}",
        ),
        (
            "recursive_base_not_merged",
            "{ a = rec { b = 1; }; a.c = 2; }",
            "{\n  a = rec {\n    b = 1;\n  };\n  a.c = 2;\n}",
        ),
        (
            "nested_merge_three_levels",
            "{ a.b.c = 1; a.b.d = 2; }",
            "{\n  a = {\n    b = {\n      c = 1;\n      d = 2;\n    };\n  };\n}",
        ),
        (
            "let_in_identity",
            "let x = 1; y = 2; in x + y",
            "let\n  x = 1;\n  y = 2;\nin x + y",
        ),
        (
            "let_in_merge",
            "let a.b = 1; a.c = 2; in a",
            "let\n  a = {\n    b = 1;\n    c = 2;\n  };\nin a",
        ),
        (
            "inherit_preserved",
            "{ inherit x y; a = 1; }",
            "{\n  inherit x y;\n  a = 1;\n}",
        ),
        (
            "comments_preserved",
            "# leading\n{ a = 1; }",
            "# leading\n{\n  a = 1;\n}",
        ),
        (
            "trailing_comment",
            "{ a = 1; # side\n  b = 2;\n}",
            "{\n  a = 1; # side\n  b = 2;\n}",
        ),
        (
            "blank_lines_collapsed",
            "{\n\n  a = 1;\n\n  b = 2;\n}",
            "{\n  a = 1;\n  b = 2;\n}",
        ),
        (
            "legacy_let",
            "let { x = 1; body = x; }",
            "{\n  x = 1;\n  body = x;\n}",
        ),
        (
            "single_key_attrset_value_no_merge",
            "{ a = { b = 1; }; }",
            "{\n  a = {\n    b = 1;\n  };\n}",
        ),
    ];

    #[test]
    fn fixtures() {
        for (name, input, expected) in FIXTURES {
            let actual = format(input).unwrap_or_else(|e| panic!("{name}: parse error: {e}"));
            assert_eq!(actual, *expected, "fixture {name} failed");
        }
    }
}
