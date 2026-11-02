# blm-tracker

Background playtime tracker for the Backlog Manager, written in Rust. The concept and the stages are in [`docs/TRACKER.md`](../docs/TRACKER.md).

## Start

Install Rust with [rustup](https://rustup.rs), then from the repository root:

```bash
task tracker:run      # build and run
task tracker:test     # run the tests
task tracker:lint     # clippy, warnings fail
task tracker:format   # rustfmt
```

`src/main.rs` is a small starting point with one function and its tests, and `tests/smoke.rs` starts the real program, so `task tracker:test` shows whether it still runs. Stage 1 begins there: add `sysinfo` with `cargo add sysinfo` and print the running processes.

For learning: [The Rust Book](https://doc.rust-lang.org/book/), [Rustlings](https://rustlings.rust-lang.org/) and `cargo doc --open` for the crates in use.

## Configuration

Copy `tracker.example.toml` to `tracker.toml`, which git ignores, once stage 2 reads it.
