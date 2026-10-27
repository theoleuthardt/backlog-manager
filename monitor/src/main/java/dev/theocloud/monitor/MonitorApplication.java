package dev.theocloud.monitor;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;

/**
 * Entry point of the Monitor, the status and alerting service of the homelab. The design it grows into is described in
 * {@code docs/MONITOR_ARCHITECTURE.md}.
 */
@SpringBootApplication
@ConfigurationPropertiesScan
public class MonitorApplication {

    public static void main(String[] args) {
        SpringApplication.run(MonitorApplication.class, args);
    }
}
