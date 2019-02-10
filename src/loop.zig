const std = @import("std");
const debug = std.debug;
const testing = std.testing;

pub fn to(n: usize) []void {
    return ([*]void)(undefined)[0..n];
}

test "loop.to" {
    var j: usize = 0;
    for (to(10)) |_, i| {
        testing.expectEqual(j, i);
        j += 1;
    }
}
