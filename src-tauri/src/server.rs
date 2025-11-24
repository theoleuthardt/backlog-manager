use std::process::{Child, Command, Stdio};
use std::sync::{Arc, Mutex};
use std::io::{BufRead, BufReader};
use log::{info, error};

/// Manages the embedded Node.js server
pub struct ServerManager {
    process: Arc<Mutex<Option<Child>>>,
    port: u16,
}

impl ServerManager {
    /// Create a new server manager
    pub fn new() -> Self {
        Self {
            process: Arc::new(Mutex::new(None)),
            port: 0,
        }
    }

    /// Find an available port starting from 3456
    pub fn find_available_port() -> Result<u16, String> {
        for port in 3456..3556 {
            if !port_check::is_port_reachable(format!("127.0.0.1:{}", port)) {
                return Ok(port);
            }
        }
        Err("No available ports found".to_string())
    }
    
    fn find_node_executable() -> Result<String, String> {
        // Try common locations for node
        let common_paths = vec![
            "node",
            "/usr/local/bin/node",
            "/opt/homebrew/bin/node",
            "/usr/bin/node",
        ];

        for &node_path in &common_paths {
            if let Ok(output) = Command::new(node_path).arg("--version").output() {
                if output.status.success() {
                    info!("Found working node at: {}", node_path);
                    return Ok(node_path.to_string());
                }
            }
        }
        
        if let Ok(home) = std::env::var("HOME") {
            let nvm_base = format!("{}/.nvm/versions/node", home);
            if let Ok(entries) = std::fs::read_dir(&nvm_base) {
                for entry in entries.flatten() {
                    let node_bin = entry.path().join("bin/node");
                    if node_bin.exists() {
                        if let Ok(output) = Command::new(&node_bin).arg("--version").output() {
                            if output.status.success() {
                                info!("Found node at: {:?}", node_bin);
                                return Ok(node_bin.to_string_lossy().to_string());
                            }
                        }
                    }
                }
            }
        }

        Err("Node.js executable not found. Please ensure Node.js is installed.".to_string())
    }

    /// Start the Node.js server
    pub fn start(&mut self, server_path: &str) -> Result<u16, String> {
        info!("Starting embedded Node.js server...");

        // Find node executable
        let node_path = Self::find_node_executable()?;
        info!("Using node executable: {}", node_path);

        // Use the default Next.js port
        self.port = 3000;
        info!("Using port: {}", self.port);

        // Set environment variables
        let port_str = self.port.to_string();

        // Verify server.js exists
        let server_js_path = std::path::Path::new(server_path).join("server.js");
        if !server_js_path.exists() {
            return Err(format!("server.js not found at {:?}", server_js_path));
        }
        info!("Found server.js at: {:?}", server_js_path);

        // Start the Node.js server process with output capture
        let mut child = Command::new(&node_path)
            .arg("server.js")
            .current_dir(server_path)
            .env("PORT", &port_str)
            .env("HOSTNAME", "127.0.0.1")
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn()
            .map_err(|e| format!("Failed to start server: {}", e))?;

        info!("Server process started with PID: {:?}", child.id());

        // Capture and log stdout in a separate thread
        if let Some(stdout) = child.stdout.take() {
            std::thread::spawn(move || {
                let reader = BufReader::new(stdout);
                for line in reader.lines() {
                    if let Ok(line) = line {
                        info!("[Server] {}", line);
                    }
                }
            });
        }

        // Capture and log stderr in a separate thread
        if let Some(stderr) = child.stderr.take() {
            std::thread::spawn(move || {
                let reader = BufReader::new(stderr);
                for line in reader.lines() {
                    if let Ok(line) = line {
                        error!("[Server Error] {}", line);
                    }
                }
            });
        }

        // Store the process handle
        let mut process = self.process.lock().unwrap();
        *process = Some(child);

        // Wait a moment for server to start
        std::thread::sleep(std::time::Duration::from_millis(2000));

        Ok(self.port)
    }

    /// Get the server URL
    pub fn get_url(&self) -> String {
        format!("http://127.0.0.1:{}", self.port)
    }

    /// Stop the server
    pub fn stop(&self) {
        info!("Stopping embedded Node.js server...");
        let mut process = self.process.lock().unwrap();
        if let Some(mut child) = process.take() {
            match child.kill() {
                Ok(_) => info!("Server stopped successfully"),
                Err(e) => error!("Failed to stop server: {}", e),
            }
        }
    }
}

impl Drop for ServerManager {
    fn drop(&mut self) {
        self.stop();
    }
}
