pub const interval = @import("interval.zig");
pub const safe = @import("safe.zig");

const std = @import("std");
const math = std.math;
const debug = std.debug;

test "math" {
    _ = interval;
    _ = safe;
}

fn digits(comptime N: type, comptime base: comptime_int, n: N) usize {
    comptime var res = 0;
    comptime var check = 1;

    inline while (check <= @maxValue(N)) : ({check *= base; res += 1;}) {
        if (n < check)
            return res;
    }

    return res;
}

test "digits" {
    debug.assert(digits(u1, 10, 1) == 1);
    debug.assert(digits(u2, 10, 3) == 1);
    debug.assert(digits(u8, 10, 255) == 3);
    debug.assert(digits(u1, 8, 0o1) == 1);
    debug.assert(digits(u2, 8, 0o3) == 1);
    debug.assert(digits(u8, 8, 0o255) == 3);
    debug.assert(digits(u1, 2, 0b1) == 1);
    debug.assert(digits(u2, 2, 0b11) == 2);
    debug.assert(digits(u8, 2, 0b1111) == 4);
}