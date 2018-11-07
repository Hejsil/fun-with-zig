pub const compare = @import("compare.zig");
pub const slice = @import("slice.zig");

const std = @import("std");
const debug = std.debug;
const mem = std.mem;

test "generic" {
    _ = compare;
    _ = slice;
}
