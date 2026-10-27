package dev.theocloud.monitor.config;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import java.time.Duration;
import org.hibernate.validator.constraints.time.DurationMax;
import org.hibernate.validator.constraints.time.DurationMin;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

/**
 * The Monitor's own settings under the prefix {@code monitor}, defaults in {@code application.yaml}, each overridable
 * by an environment variable ({@code MONITOR_SCHEDULER_TICK}, ...). They are validated when the application starts, so
 * an invalid value stops the start instead of surfacing later.
 *
 * @param schedulerTick how often the scheduler looks for due checks
 * @param httpDefaultTimeout the timeout of an HTTP check whose monitor sets none
 * @param retentionDays how long check results are kept
 * @param pushMessageMaxLength the longest message a push may carry
 */
@Validated
@ConfigurationProperties("monitor")
public record MonitorProperties(
        @NotNull @DurationMin(seconds = 1) @DurationMax(hours = 1)
        Duration schedulerTick,

        @NotNull @DurationMin(seconds = 1) @DurationMax(seconds = 60)
        Duration httpDefaultTimeout,

        @Min(1) @Max(365) int retentionDays,
        @Min(1) @Max(500) int pushMessageMaxLength) {}
