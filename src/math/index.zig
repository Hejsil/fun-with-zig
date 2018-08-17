pub const interval = @import("interval.zig");
pub const safe = @import("safe.zig");

const std = @import("std");
const math = std.math;

test "math" {
    _ = interval;
    _ = safe;
}
