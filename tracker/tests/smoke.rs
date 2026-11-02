//! Starts the real program, the way a user does.

use std::process::Command;

#[test]
fn the_program_starts_and_names_itself() {
    let output = Command::new(env!("CARGO_BIN_EXE_blm-tracker"))
        .output()
        .expect("the program starts");

    assert!(output.status.success(), "exit status {}", output.status);
    let text = String::from_utf8(output.stdout).expect("the output is text");
    let version = concat!("blm-tracker ", env!("CARGO_PKG_VERSION"));
    assert!(text.contains(version), "output was: {text}");
}
