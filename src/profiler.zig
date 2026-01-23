const std = @import("std");

pub const Profiler = struct {
    start_tick: i128,

    pub fn init() Profiler {
        return Profiler{
            .start_tick = std.time.nanoTimestamp(),
        };
    }

    pub fn reset(self: *Profiler) void {
        self.start_tick = std.time.nanoTimestamp();
    }

    pub fn nanos(self: *Profiler) u64 {
        const now = std.time.nanoTimestamp();
        return @as(i64, now - self.start_tick);
    }

    pub fn micros(self: *Profiler) f64 {
        const now = std.time.nanoTimestamp();
        return @as(f64, @floatFromInt(now - self.start_tick)) / 1000.0;
    }

    pub fn millis(self: *Profiler) f64 {
        const now = std.time.nanoTimestamp();
        return @as(f64, @floatFromInt(now - self.start_tick)) / 1_000_000.0;
    }

    pub fn seconds(self: *Profiler) f64 {
        const now = std.time.nanoTimestamp();
        return @as(f64, @floatFromInt(now - self.start_tick)) / 1_000_000_000.0;
    }

    pub fn string(self: *Profiler) ![]const u8 {
        const now = std.time.nanoTimestamp();
        const diff_ns = now - self.start_tick;

        var buffer: [64]u8 = undefined;
        var writer: std.io.Writer = .fixed(&buffer);

        if (diff_ns < 1_000) {
            // Nanoseconds
            try writer.print("{} ns", .{diff_ns});
        } else if (diff_ns < 1_000_000) {
            // Microseconds
            try writer.print("{:.3} μs", .{@as(f64, @floatFromInt(diff_ns)) / 1_000.0});
        } else if (diff_ns < 1_000_000_000) {
            // Milliseconds
            try writer.print("{:.3} ms", .{@as(f64, @floatFromInt(diff_ns)) / 1_000_000.0});
        } else {
            // Seconds
            try writer.print("{:.3} s", .{@as(f64, @floatFromInt(diff_ns)) / 1_000_000_000.0});
        }

        return writer.buffered();
    }
};
