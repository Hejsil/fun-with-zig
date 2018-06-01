pub const compare = @import("compare.zig");

const std = @import("std");
const debug = std.debug;
const mem = std.mem;

const TypeId = @import("builtin").TypeId;

test "generic" {
    _ = compare;
}

fn WidenReturn(comptime InSlice: type, comptime Out: type) type {
    switch (@typeInfo(InSlice)) {
        TypeId.Slice => |s| {
            return if (s.is_const) []const Out else []Out;
        },
        else => @compileError("Expected 'Slice' found '" ++ @typeName(InSlice) ++ "'"),
    }
}

/// Widens ::s.
/// If the widening is a size mismatch, an error is returned instead of doing a
/// runtime assert.
pub fn widen(s: var, comptime Out: type) !WidenReturn(@typeOf(s), Out) {
    const Res = @typeOf(this).ReturnType.Payload;
    if (s.len % @sizeOf(Out) != 0) return error.WideningSizeMismatch;
    return (Res)(s);
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


/// Widens ::s.
/// If the widening is a size mismatch, then ::s will be trimmed to nearest fit.
pub fn widenTrim(s: var, comptime Out: type) WidenReturn(@typeOf(s), Out) {
    const Res = @typeOf(this).ReturnType;
    return (Res)(s[0..s.len - (s.len % @sizeOf(Out))]);
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


fn SliceReturn(comptime Slice: type) type {
    switch (@typeInfo(Slice)) {
        TypeId.Slice => |s| {
            return if (s.is_const) []const s.child else []s.child;
        },
        else => @compileError("Expected 'Slice' found '" ++ @typeName(Slice) ++ "'"),
    }
}

/// Slices ::s from ::start to ::end.
/// Returns errors instead of doing runtime asserts when ::start or ::end are out of bounds,
/// or when ::end is less that ::start.
pub fn slice(s: var, start: usize, end: usize) !SliceReturn(@typeOf(s)) {
    if (end < start)
        return error.EndLessThanStart;
    if (s.len < start or s.len < end)
        return error.OutOfBound;

    return s[start..end];
}

test "generic.slice" {
    const a = []u8{1,2};
    const b = slice(a[0..], 0, 1) catch unreachable;
    const c = slice(a[0..], 1, 2) catch unreachable;
    const d = slice(a[0..], 0, 2) catch unreachable;
    const e = slice(a[0..], 2, 2) catch unreachable;

    debug.assert(mem.eql(u8, b, []u8{1}));
    debug.assert(mem.eql(u8, c, []u8{2}));
    debug.assert(mem.eql(u8, d, []u8{1,2}));
    debug.assert(mem.eql(u8, e, []u8{}));

    if (slice(a[0..], 0, 3)) |_|
        unreachable
    else |err|
        debug.assert(err == error.OutOfBound);

    if (slice(a[0..], 3, 3)) |_|
        unreachable
    else |err|
        debug.assert(err == error.OutOfBound);

    if (slice(a[0..], 1, 0)) |_|
        unreachable
    else |err|
        debug.assert(err == error.EndLessThanStart);

    const q1 = []u8{1,2};
    var q2 = []u8{1,2};

    const q11 = slice(q1[0..], 0, 2) catch unreachable;
    const q21 = slice(q2[0..], 0, 2) catch unreachable;
    debug.assert(@typeOf(q11) == []const u8);
    debug.assert(@typeOf(q21) == []u8);
}


// These function are needed because we don't have pointer reform yet
fn Ptr(comptime T: type) type { return &T; }
fn ConstPtr(comptime T: type) type { return &const T; }

fn AtReturn(comptime Slice: type) type {
    switch (@typeInfo(Slice)) {
        TypeId.Slice => |s| {
            return if (s.is_const) ConstPtr(s.child) else Ptr(s.child);
        },
        else => @compileError("Expected 'Slice' found '" ++ @typeName(Slice) ++ "'"),
    }
}

/// Returns a pointer to the item at ::index in ::s.
/// Returns an error instead of doing a runtime assert when ::index is out of bounds.
pub fn at(s: var, index: usize) !AtReturn(@typeOf(s)) {
    if (s.len <= index)
        return error.OutOfBound;

    return &s[index];
}

test "generic.slice" {
    const a = []u8{1,2};
    const b = at(a[0..], 0) catch unreachable;
    const c = at(a[0..], 1) catch unreachable;

    debug.assert(b.* == 1);
    debug.assert(c.* == 2);

    if (at(a[0..], 2)) |_|
        unreachable
    else |err|
        debug.assert(err == error.OutOfBound);

    const q1 = []u8{1,2};
    var q2 = []u8{1,2};

    const q11 = at(q1[0..], 0) catch unreachable;
    const q21 = at(q2[0..], 0) catch unreachable;
    debug.assert(@typeOf(q11) == &const u8);
    debug.assert(@typeOf(q21) == &u8);
}
