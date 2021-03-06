pub const interval = @import("math/interval.zig");
pub const safe = @import("math/safe.zig");

const std = @import("std");
const math = std.math;
const debug = std.debug;
const testing = std.testing;

test "math" {
    _ = interval;
    _ = safe;
}

fn digits(comptime N: type, comptime base: comptime_int, n: N) usize {
    comptime var res = 1;
    comptime var check = base;

    inline while (check <= math.maxInt(N)) : ({
        check *= base;
        res += 1;
    }) {
        if (n < check)
            return res;
    }

    return res;
}

test "math.digits" {
    testing.expectEqual(digits(u1, 10, 0), 1);
    testing.expectEqual(digits(u1, 10, 1), 1);
    testing.expectEqual(digits(u2, 10, 3), 1);
    testing.expectEqual(digits(u8, 10, 255), 3);
    testing.expectEqual(digits(u1, 8, 0o0), 1);
    testing.expectEqual(digits(u1, 8, 0o1), 1);
    testing.expectEqual(digits(u2, 8, 0o3), 1);
    testing.expectEqual(digits(u8, 8, 0o255), 3);
    testing.expectEqual(digits(u1, 2, 0b0), 1);
    testing.expectEqual(digits(u1, 2, 0b1), 1);
    testing.expectEqual(digits(u2, 2, 0b11), 2);
    testing.expectEqual(digits(u8, 2, 0b1111), 4);
}
