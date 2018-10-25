pub const compare = @import("compare.zig");
pub const slice = @import("slice.zig");

const std = @import("std");
const debug = std.debug;
const mem = std.mem;

const TypeId = @import("builtin").TypeId;
const TypeInfo = @import("builtin").TypeInfo;

test "generic" {
    _ = compare;
    _ = slice;
}

/// Returns a mutable byte slice of ::value.
pub fn asBytes(comptime T: type, value: *T) *[@sizeOf(T)]u8 {
    return @ptrCast(*[@sizeOf(T)]u8, value);
}

test "utils.asBytes" {
    const Str = packed struct.{
        a: u8,
        b: u8,
    };
    var str = Str.{ .a = 0x01, .b = 0x02 };
    debug.assert(mem.eql(u8, []u8.{ 0x01, 0x02 }, asBytes(Str, &str)[0..]));
}

/// Converts ::value to a byte array of size @sizeOf(::T).
pub fn toBytes(value: var) [@sizeOf(@typeOf(value))]u8 {
    return @ptrCast(*const [@sizeOf(@typeOf(value))]u8, &value).*;
}

test "utils.toBytes" {
    const Str = packed struct.{
        a: u8,
        b: u8,
    };
    const str = Str.{ .a = 0x01, .b = 0x02 };
    debug.assert(mem.eql(u8, []u8.{ 0x01, 0x02 }, toBytes(str)));
}
