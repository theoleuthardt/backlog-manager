use std::path::PathBuf;

fn main() {
  // The Next.js standalone server is copied to resources/server
  // by the prepare-tauri.js script during npm run build:tauri

  // Tell Cargo to re-run if resources change
  let resources_dir = PathBuf::from("resources");
  if resources_dir.exists() {
    println!("cargo:rerun-if-changed=resources");
  }

  tauri_build::build()
}
