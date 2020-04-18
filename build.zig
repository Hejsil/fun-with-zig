const builtin = @import("builtin");
const std = @import("std");

const Builder = std.build.Builder;
const Mode = builtin.Mode;

pub fn build(b: *Builder) void {
    const test_all_step = b.step("test", "Run all tests in all modes.");
    inline for ([_]Mode{ Mode.Debug, Mode.ReleaseFast, Mode.ReleaseSafe, Mode.ReleaseSmall }) |test_mode| {
        const mode_str = comptime modeToString(test_mode);

        const t = b.addTest("fun.zig");
        t.setBuildMode(test_mode);
        t.setNamePrefix(mode_str ++ " ");

        const test_step = b.step("test-" ++ mode_str, "Run all tests in " ++ mode_str ++ ".");
        test_step.dependOn(&t.step);
        test_all_step.dependOn(test_step);
    }

    const fmt_step = b.addFmt(&[_][]const u8{
        "build.zig",
        "fun",
        "fun.zig",
        "src",
    });

    b.default_step.dependOn(&fmt_step.step);
    b.default_step.dependOn(test_all_step);
}

fn modeToString(mode: Mode) []const u8 {
    return switch (mode) {
        .Debug => "debug",
        .ReleaseFast => "release-fast",
        .ReleaseSafe => "release-safe",
        .ReleaseSmall => "release-small",
    };
}
