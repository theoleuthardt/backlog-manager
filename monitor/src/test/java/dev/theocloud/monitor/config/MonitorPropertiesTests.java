package dev.theocloud.monitor.config;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Duration;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.boot.test.context.ConfigDataApplicationContextInitializer;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;
import org.springframework.context.annotation.Configuration;

class MonitorPropertiesTests {

    @Configuration(proxyBeanMethods = false)
    @EnableConfigurationProperties(MonitorProperties.class)
    static class PropertiesOnly {}

    private final ApplicationContextRunner runner = new ApplicationContextRunner()
            .withUserConfiguration(PropertiesOnly.class)
            .withPropertyValues(
                    "monitor.scheduler-tick=5s",
                    "monitor.http-default-timeout=10s",
                    "monitor.retention-days=30",
                    "monitor.push-message-max-length=200");

    @Test
    void bindsValidSettings() {
        runner.withPropertyValues("monitor.scheduler-tick=2s", "monitor.retention-days=7")
                .run(context -> {
                    assertThat(context).hasNotFailed();
                    MonitorProperties properties = context.getBean(MonitorProperties.class);
                    assertThat(properties.schedulerTick()).isEqualTo(Duration.ofSeconds(2));
                    assertThat(properties.httpDefaultTimeout()).isEqualTo(Duration.ofSeconds(10));
                    assertThat(properties.retentionDays()).isEqualTo(7);
                    assertThat(properties.pushMessageMaxLength()).isEqualTo(200);
                });
    }

    @Test
    void takesTheDefaultsFromApplicationYaml() {
        new ApplicationContextRunner()
                .withUserConfiguration(PropertiesOnly.class)
                .withInitializer(new ConfigDataApplicationContextInitializer())
                .run(context -> {
                    assertThat(context).hasNotFailed();
                    MonitorProperties properties = context.getBean(MonitorProperties.class);
                    assertThat(properties.schedulerTick()).isEqualTo(Duration.ofSeconds(5));
                    assertThat(properties.httpDefaultTimeout()).isEqualTo(Duration.ofSeconds(10));
                    assertThat(properties.retentionDays()).isEqualTo(30);
                    assertThat(properties.pushMessageMaxLength()).isEqualTo(200);
                });
    }

    @ParameterizedTest
    @ValueSource(
            strings = {
                "monitor.scheduler-tick=0s",
                "monitor.scheduler-tick=2h",
                "monitor.http-default-timeout=0s",
                "monitor.http-default-timeout=5m",
                "monitor.retention-days=0",
                "monitor.retention-days=400",
                "monitor.push-message-max-length=0",
                "monitor.push-message-max-length=600"
            })
    void refusesToStartWithAnInvalidSetting(String setting) {
        runner.withPropertyValues(setting)
                .run(context -> assertThat(context)
                        .hasFailed()
                        .getFailure()
                        .rootCause()
                        .hasMessageContaining(setting.substring("monitor.".length(), setting.indexOf('='))));
    }

    @Test
    void refusesToStartWithoutASetting() {
        new ApplicationContextRunner()
                .withUserConfiguration(PropertiesOnly.class)
                .run(context -> assertThat(context).hasFailed());
    }
}
