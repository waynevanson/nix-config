fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() < 2 {
        eprintln!("usage: nixnest <file.nix>...");
        std::process::exit(1);
    }

    let mut failed = false;
    for path in &args[1..] {
        let src = match std::fs::read_to_string(path) {
            Ok(s) => s,
            Err(e) => {
                eprintln!("{}: read error: {}", path, e);
                failed = true;
                continue;
            }
        };
        match nixnest::format(&src) {
            Ok(out) => {
                if let Err(e) = std::fs::write(path, out) {
                    eprintln!("{}: write error: {}", path, e);
                    failed = true;
                }
            }
            Err(e) => {
                eprintln!("{}: format error: {}", path, e);
                failed = true;
            }
        }
    }

    if failed {
        std::process::exit(1);
    }
}
