pub const compare = @import("compare.zig");

const std = @import("std");
const debug = std.debug;
const mem = std.mem;
const fmt = std.fmt;

const TypeId = @import("builtin").TypeId;
const TypeInfo = @import("builtin").TypeInfo;

test "generic" {
    _ = compare;
}

fn isSlice(comptime T: type) bool {
    const info = @typeInfo(T);
    return info == TypeId.Pointer and
        info.Pointer.size == TypeInfo.Pointer.Size.Slice;
}

fn isArray(comptime T: type) bool {
    const info = @typeInfo(T);
    return info == TypeId.Array;
}

fn isArrayPtr(comptime T: type) bool {
    const info = @typeInfo(T);
    return info == TypeId.Pointer and
        info.Pointer.size == TypeInfo.Pointer.Size.One and
        isArray(info.Pointer.child);
}

fn isConstPtr(comptime T: type) bool {
    const info = @typeInfo(T);
    return info == TypeId.Pointer and
        info.Pointer.is_const;
}

pub const WidenError = error {
    WideningSizeMismatch,
};

fn WidenReturn(comptime In: type, comptime Out: type) type {
    const Result = WidenTrimReturn(In, Out);

    // If we are an array pointer, then we catch the widen mismatch at comptime instead of
    if (isArrayPtr(In)) {
        const Array = In.Child;
        const Child = Array.Child;
        const old_len = Array.len * @sizeOf(Child);
        if (old_len % @sizeOf(Out) != 0) {
            const in_name = "'" ++ @typeName(In) ++ "'";
            const out_name = "'*[?]" ++ @typeName(Out) ++ "'";
            @compileError("Widening size mismatch: " ++ in_name ++ " to " ++ out_name);
        }
    }

    return Result;
}

/// Widens ::s.
/// If the widening is a size mismatch, an error is returned instead of doing a
/// runtime assert.
pub fn widen(s: var, comptime Out: type) WidenError!WidenReturn(@typeOf(s), Out) {
    const Res = @typeOf(this).ReturnType.Payload;
    const T = @typeOf(s);

    if (comptime isSlice(T)) {
        const old_len = s.len * @sizeOf(T.Child);
        const new_len = s.len / @sizeOf(Out);
        if (old_len % @sizeOf(Out) != 0)
            return error.WideningSizeMismatch;

        const res = (Res)(s);
        debug.assert(res.len == new_len);
        return res;
    }

    if (comptime isArrayPtr(T)) {
        return @ptrCast(Res, s);
    }

    @compileError("This should never happen!");
}

test "generic.widen" {
    const S = packed struct {
        a: u8,
        b: u8,
    };

    {
        const a = []u8{1};
        const b = []u8{ 1, 2 };

        if (widen(a[0..], S)) |_| unreachable else |_| {}
        const v = widen(b[0..], S) catch unreachable;
        debug.assert(@typeOf(v) == []const S);
        debug.assert(v.len == 1);
        debug.assert(v[0].a == 1);
        debug.assert(v[0].b == 2);

        const v2 = widen(b, S) catch unreachable;
        debug.assert(@typeOf(v2) == *const [1]S);
        debug.assert(v2.len == 1);
        debug.assert(v2[0].a == 1);
        debug.assert(v2[0].b == 2);
    }

    {
        var a = []u8{1};
        var b = []u8{ 1, 2 };

        if (widen(a[0..], S)) |_| unreachable else |_| {}
        const v = widen(b[0..], S) catch unreachable;
        debug.assert(@typeOf(v) == []S);
        debug.assert(v.len == 1);
        debug.assert(v[0].a == 1);
        debug.assert(v[0].b == 2);

        const v2 = widen(&b, S) catch unreachable;
        debug.assert(@typeOf(v2) == *[1]S);
        debug.assert(v2.len == 1);
        debug.assert(v2[0].a == 1);
        debug.assert(v2[0].b == 2);
    }
}

fn WidenTrimReturn(comptime In: type, comptime Out: type) type {
    if (isSlice(In)) {
        return if (isConstPtr(In)) []const Out else []Out;
    }
    if (isArrayPtr(In)) {
        const Array = In.Child;
        const Child = Array.Child;
        const old_len = Array.len * @sizeOf(Child);
        const new_len = old_len / @sizeOf(Out);
        return if (isConstPtr(In)) *const [new_len]Out else *[new_len]Out;
    }


    @compileError("Expected 'Slice' or 'Array pointer' found '" ++ @typeName(In) ++ "'");
}

/// Widens ::s.
/// If the widening is a size mismatch, then ::s will be trimmed to nearest fit.
pub fn widenTrim(s: var, comptime Out: type) WidenTrimReturn(@typeOf(s), Out) {
    const Res = @typeOf(this).ReturnType;
    const T = @typeOf(s);
    const Child = if (comptime isSlice(T)) T.Child else T.Child.Child;

    const old_len = s.len * @sizeOf(Child);
    const new_len = old_len / @sizeOf(Out);
    if (comptime isSlice(T)) {
        const Bytes = if (comptime isConstPtr(T)) []const u8 else []u8;
        const bytes = (Bytes)(s);
        const res = (Res)(bytes[0.. new_len * @sizeOf(Out)]);
        debug.assert(res.len == new_len);
        return res;
    }

    if (comptime isArrayPtr(T)) {
        // TODO: If *[0]T, then compiler crash. See https://github.com/ziglang/zig/issues/960
        return @ptrCast(Res, s);
    }

    @compileError("This should never happen!");
}

test "generic.widenTrim" {
    const S = packed struct {
        a: u8,
        b: u8,
    };

    {
        const a = []u8{1};
        const b = []u8{ 1, 2 };
        const v1 = widenTrim(a[0..], S);
        const v2 = widenTrim(b[0..], S);
        //const v3 = widenTrim(a, S);
        const v4 = widenTrim(b, S);

        debug.assert(@typeOf(v1) == []const S);
        debug.assert(@typeOf(v2) == []const S);
        //debug.assert(@typeOf(v3) == *const [0]S);
        debug.assert(@typeOf(v4) == *const [1]S);
        debug.assert(v1.len == 0);
        debug.assert(v2.len == 1);
        //debug.assert(v3.len == 0);
        debug.assert(v4.len == 1);
        debug.assert(v2[0].a == 1);
        debug.assert(v2[0].b == 2);
        debug.assert(v4[0].a == 1);
        debug.assert(v4[0].b == 2);
    }

    {
        var a = []u8{1};
        var b = []u8{ 1, 2 };
        const v1 = widenTrim(a[0..], S);
        const v2 = widenTrim(b[0..], S);
        //const v3 = widenTrim(&a, S);
        const v4 = widenTrim(&b, S);

        debug.assert(@typeOf(v1) == []S);
        debug.assert(@typeOf(v2) == []S);
        //debug.assert(@typeOf(v3) == *[0]S);
        debug.assert(@typeOf(v4) == *[1]S);
        debug.assert(v1.len == 0);
        debug.assert(v2.len == 1);
        //debug.assert(v3.len == 0);
        debug.assert(v4.len == 1);
        debug.assert(v2[0].a == 1);
        debug.assert(v2[0].b == 2);
        debug.assert(v4[0].a == 1);
        debug.assert(v4[0].b == 2);
    }
}

fn SliceReturn(comptime T: type) type {
    if (isSlice(T))
        return if (isConstPtr(T)) []const T.Child else []T.Child;
    if (isArrayPtr(T))
        return if (isConstPtr(T)) []const T.Child.Child else []T.Child.Child;

    @compileError("Expected 'Slice' or 'Array pointer' found '" ++ @typeName(T) ++ "'");
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
    const a = []u8{ 1, 2 };
    const b = slice(a[0..], 0, 1) catch unreachable;
    const c = slice(a[0..], 1, 2) catch unreachable;
    const d = slice(a[0..], 0, 2) catch unreachable;
    const e = slice(a[0..], 2, 2) catch unreachable;
    const f = slice(a, 1, 2) catch unreachable;

    debug.assert(mem.eql(u8, b, []u8{1}));
    debug.assert(mem.eql(u8, c, []u8{2}));
    debug.assert(mem.eql(u8, d, []u8{ 1, 2 }));
    debug.assert(mem.eql(u8, e, []u8{}));
    debug.assert(mem.eql(u8, f, []u8{2}));

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

    const q1 = []u8{ 1, 2 };
    var q2 = []u8{ 1, 2 };

    const q11 = slice(q1[0..], 0, 2) catch unreachable;
    const q21 = slice(q2[0..], 0, 2) catch unreachable;
    debug.assert(@typeOf(q11) == []const u8);
    debug.assert(@typeOf(q21) == []u8);

    const q12 = slice(q1, 0, 2) catch unreachable;
    const q22 = slice(q2, 0, 2) catch unreachable;
    debug.assert(@typeOf(q12) == []const u8);
    debug.assert(@typeOf(q22) == []u8);
}

fn AtReturn(comptime T: type) type {
    if (isSlice(T))
        return if (isConstPtr(T)) *const T.Child else *T.Child;
    if (isArrayPtr(T))
        return if (isConstPtr(T)) *const T.Child.Child else *T.Child.Child;

    @compileError("Expected 'Slice' or 'Array pointer' found '" ++ @typeName(T) ++ "'");
}

/// Returns a pointer to the item at ::index in ::s.
/// Returns an error instead of doing a runtime assert when ::index is out of bounds.
pub fn at(s: var, index: usize) !AtReturn(@typeOf(s)) {
    if (s.len <= index)
        return error.OutOfBound;

    return &s[index];
}

test "generic.at" {
    const a = []u8{ 1, 2 };
    const b = at(a[0..], 0) catch unreachable;
    const c = at(a[0..], 1) catch unreachable;
    const d = at(a, 1) catch unreachable;

    debug.assert(b.* == 1);
    debug.assert(c.* == 2);
    debug.assert(d.* == 2);

    if (at(a[0..], 2)) |_|
        unreachable
    else |err|
        debug.assert(err == error.OutOfBound);

    const q1 = []u8{ 1, 2 };
    var q2 = []u8{ 1, 2 };

    const q11 = at(q1[0..], 0) catch unreachable;
    const q21 = at(q2[0..], 0) catch unreachable;
    debug.assert(@typeOf(q11) == *const u8);
    debug.assert(@typeOf(q21) == *u8);

    const q31 = at(q1, 0) catch unreachable;
    const q41 = at(q2, 0) catch unreachable;
    debug.assert(@typeOf(q31) == *const u8);
    debug.assert(@typeOf(q41) == *u8);
}
