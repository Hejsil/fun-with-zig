pub const compare = @import("compare.zig");

const std = @import("std");
const debug = std.debug;

const TypeId = @import("builtin").TypeId;

test "generic" {
    _ = compare;
}

fn WidenReturn(comptime InSlice: type, comptime Out: type) type {
    switch (@typeInfo(InSlice)) {
        TypeId.Slice => |s| {
            return if (s.is_const) []const Out else []Out;
        },
        else => @compileError("Expected 'slice' found '" ++ @typeName(InSlice) ++ "'"),
    }
}

/// Widens ::slice.
/// If the widening is a size mismatch, an error is returned instead of doing a
/// runtime assert.
pub fn widen(slice: var, comptime Out: type) !WidenReturn(@typeOf(slice), Out) {
    const Res = @typeOf(this).ReturnType.Payload;
    if (slice.len % @sizeOf(Out) != 0) return error.WideningSizeMismatch;
    return (Res)(slice);
}

test "generic.widen" {
    const S = packed struct { a: u8, b: u8 };

    {
        const a = []u8{1};
        const b = []u8{1,2};

        if (widen(a[0..], S)) |_| unreachable else |_| {}
        const v = widen(b[0..], S) catch unreachable;
        debug.assert(@typeOf(v) == []const S);
        debug.assert(v.len == 1);
        debug.assert(v[0].a == 1);
        debug.assert(v[0].b == 2);
    }

    {
        var a = []u8{1};
        var b = []u8{1,2};

        if (widen(a[0..], S)) |_| unreachable else |_| {}
        const v = widen(b[0..], S) catch unreachable;
        debug.assert(@typeOf(v) == []S);
        debug.assert(v.len == 1);
        debug.assert(v[0].a == 1);
        debug.assert(v[0].b == 2);
    }
}


/// Widens ::slice.
/// If the widening is a size mismatch, then ::slice will be trimmed to nearest fit.
pub fn widenTrim(slice: var, comptime Out: type) WidenReturn(@typeOf(slice), Out) {
    const Res = @typeOf(this).ReturnType;
    return (Res)(slice[0..slice.len - (slice.len % @sizeOf(Out))]);
}

test "generic.widenTrim" {
    const S = packed struct { a: u8, b: u8 };

    {
        const a = []u8{1};
        const b = []u8{1,2};
        const v1 = widenTrim(a[0..], S);
        const v2 = widenTrim(b[0..], S);

        debug.assert(@typeOf(v1) == []const S);
        debug.assert(@typeOf(v2) == []const S);
        debug.assert(v1.len == 0);
        debug.assert(v2.len == 1);
        debug.assert(v2[0].a == 1);
        debug.assert(v2[0].b == 2);
    }

    {
        var a = []u8{1};
        var b = []u8{1,2};
        const v1 = widenTrim(a[0..], S);
        const v2 = widenTrim(b[0..], S);

        debug.assert(@typeOf(v1) == []S);
        debug.assert(@typeOf(v2) == []S);
        debug.assert(v1.len == 0);
        debug.assert(v2.len == 1);
        debug.assert(v2[0].a == 1);
        debug.assert(v2[0].b == 2);
    }
}
