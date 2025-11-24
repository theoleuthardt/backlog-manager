mod server;

use std::sync::Arc;
use tauri::Manager;
use log::{info, error};

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
  tauri::Builder::default()
    .setup(|app| {
      // Setup logging first
      app.handle().plugin(
        tauri_plugin_log::Builder::default()
          .level(log::LevelFilter::Info)
          .build(),
      )?;

      // Try to get resource directory
      let resource_dir = match app.path().resource_dir() {
        Ok(dir) => dir,
        Err(e) => {
          error!("Failed to get resource directory: {}", e);
          return Ok(()); // Continue without server
        }
      };

      // Try different possible server locations
      let possible_paths = vec![
        resource_dir.join("resources").join("server"), // Production bundle
        resource_dir.join("server"),                    // Alternative location
        resource_dir.clone(),                           // Dev mode (server.js in root)
      ];

      let mut server_path = None;
      for path in possible_paths {
        if path.join("server.js").exists() {
          info!("Found server at: {:?}", path);
          server_path = Some(path);
          break;
        }
      }

      let server_path = match server_path {
        Some(path) => path,
        None => {
          error!("Server files not found in any expected location");
          error!("Checked paths:");
          error!("  - {:?}", resource_dir.join("resources").join("server"));
          error!("  - {:?}", resource_dir.join("server"));
          error!("  - {:?}", resource_dir);
          error!("Contents of resource directory:");
          if let Ok(entries) = std::fs::read_dir(&resource_dir) {
            for entry in entries.flatten().take(10) {
              info!("  - {:?}", entry.path());
            }
          }
          return Ok(());
        }
      };

      info!("Using server path: {:?}", server_path);

      // Try to start the server
      let mut server_manager = server::ServerManager::new();
      let server_path_str = match server_path.to_str() {
        Some(s) => s,
        None => {
          error!("Invalid server path (non-UTF8)");
          return Ok(());
        }
      };

      match server_manager.start(server_path_str) {
        Ok(_port) => {
          let server_url = server_manager.get_url();
          info!("Server started successfully at: {}", server_url);

          app.manage(Arc::new(server_manager));
            
          info!("Waiting for server to be ready...");
          let max_attempts = 60; // 30 seconds total
          let mut server_ready = false;

          for attempt in 1..=max_attempts {
            std::thread::sleep(std::time::Duration::from_millis(500));

            match ureq::get(&server_url).timeout(std::time::Duration::from_secs(2)).call() {
              Ok(response) => {
                if response.status() == 200 || response.status() == 404 {
                  info!("Server is responding with status {} (attempt {})", response.status(), attempt);
                  server_ready = true;
                  break;
                }
              }
              Err(e) => {
                if attempt % 10 == 0 {
                  info!("Server not ready yet (attempt {}/{}): {}", attempt, max_attempts, e);
                }
              }
            }
          }

          if server_ready {
            info!("Server is ready! The loading screen will navigate automatically.");
          } else {
            error!("Server did not become ready within timeout");
            if let Some(window) = app.get_webview_window("main") {
              let _ = window.eval(
                "window.updateStatus('Server failed to start', true)"
              );
            }
          }
        }
        Err(e) => {
          error!("Failed to start embedded server: {}", e);
          if let Some(window) = app.get_webview_window("main") {
            let error_msg = format!("Failed to start server: {}", e);
            let _ = window.eval(&format!(
              "document.getElementById('status').textContent = '{}'; document.getElementById('status').style.color = 'red';",
              error_msg.replace("'", "\\'")
            ));
          }
        }
      }

      Ok(())
    })
    .run(tauri::generate_context!())
    .expect("error while running tauri application");
}
