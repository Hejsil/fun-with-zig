const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const debug = std.debug;

pub const BytesToSliceError = error.{SizeMismatch};

pub fn bytesToSlice(comptime Element: type, bytes: var) BytesToSliceError!@typeOf(@bytesToSlice(Element, bytes)) {
    if (bytes.len % @sizeOf(Element) != 0)
        return BytesToSliceError.SizeMismatch;

    return @bytesToSlice(Element, bytes);
}

test "generic.slice.bytesToSlice" {
    const S = packed struct.{
        a: u8,
        b: u8,
    };

    {
        const a = []u8.{1};
        const b = []u8.{ 1, 2 };

        if (bytesToSlice(S, a[0..])) |_| unreachable else |_| {}
        const v = bytesToSlice(S, b[0..]) catch unreachable;
        comptime debug.assert(@typeOf(v) == []align(1) const S);
        debug.assert(v.len == 1);
        debug.assert(v[0].a == 1);
        debug.assert(v[0].b == 2);

        const v2 = bytesToSlice(S, &b) catch unreachable;
        comptime debug.assert(@typeOf(v2) == []align(1) const S);
        debug.assert(v2.len == 1);
        debug.assert(v2[0].a == 1);
        debug.assert(v2[0].b == 2);
    }

    {
        var a = []u8.{1};
        var b = []u8.{ 1, 2 };

        if (bytesToSlice(S, a[0..])) |_| unreachable else |_| {}
        const v = bytesToSlice(S, b[0..]) catch unreachable;
        comptime debug.assert(@typeOf(v) == []align(1) S);
        debug.assert(v.len == 1);
        debug.assert(v[0].a == 1);
        debug.assert(v[0].b == 2);

        const v2 = bytesToSlice(S, &b) catch unreachable;
        comptime debug.assert(@typeOf(v2) == []align(1) S);
        debug.assert(v2.len == 1);
        debug.assert(v2[0].a == 1);
        debug.assert(v2[0].b == 2);
    }
}

pub fn bytesToSliceTrim(comptime Element: type, bytes: var) @typeOf(@bytesToSlice(Element, bytes)) {
    const rem = bytes.len % @sizeOf(Element);
    return @bytesToSlice(Element, bytes[0 .. bytes.len - rem]);
}

test "generic.slice.bytesToSliceTrim" {
    const S = packed struct.{
        a: u8,
        b: u8,
    };

    {
        const a = []u8.{1};
        const b = []u8.{ 1, 2 };
        const v1 = bytesToSliceTrim(S, a[0..]);
        const v2 = bytesToSliceTrim(S, b[0..]);
        //const v3 = bytesToSliceTrim(S, &a);
        //const v4 = bytesToSliceTrim(S, &b);

        comptime debug.assert(@typeOf(v1) == []align(1) const S);
        comptime debug.assert(@typeOf(v2) == []align(1) const S);
        //debug.assert(@typeOf(v3) == *const [0]S);
        //debug.assert(@typeOf(v4) == *const [1]S);
        debug.assert(v1.len == 0);
        debug.assert(v2.len == 1);
        //debug.assert(v3.len == 0);
        //debug.assert(v4.len == 1);
        debug.assert(v2[0].a == 1);
        debug.assert(v2[0].b == 2);
        //debug.assert(v4[0].a == 1);
        //debug.assert(v4[0].b == 2);
    }

    {
        var a = []u8.{1};
        var b = []u8.{ 1, 2 };
        const v1 = bytesToSliceTrim(S, a[0..]);
        const v2 = bytesToSliceTrim(S, b[0..]);
        const v3 = bytesToSliceTrim(S, &a);
        const v4 = bytesToSliceTrim(S, &b);

        comptime debug.assert(@typeOf(v1) == []S);
        comptime debug.assert(@typeOf(v2) == []S);
        comptime debug.assert(@typeOf(v3) == []S);
        comptime debug.assert(@typeOf(v4) == []S);
        debug.assert(v1.len == 0);
        debug.assert(v2.len == 1);
        debug.assert(v3.len == 0);
        debug.assert(v4.len == 1);
        debug.assert(v2[0].a == 1);
        debug.assert(v2[0].b == 2);
        debug.assert(v4[0].a == 1);
        debug.assert(v4[0].b == 2);
    }
}

/// Slices ::s from ::start to ::end.
/// Returns errors instead of doing runtime asserts when ::start or ::end are out of bounds,
/// or when ::end is less that ::start.
pub fn slice(s: var, start: usize, end: usize) !@typeOf(s[0..]) {
    if (end < start)
        return error.EndLessThanStart;
    if (s.len < start or s.len < end)
        return error.OutOfBound;

    return s[start..end];
}

test "generic.slice.slice" {
    const a = []u8.{ 1, 2 };
    const b = slice(a[0..], 0, 1) catch unreachable;
    const c = slice(a[0..], 1, 2) catch unreachable;
    const d = slice(a[0..], 0, 2) catch unreachable;
    const e = slice(a[0..], 2, 2) catch unreachable;
    const f = slice(&a, 1, 2) catch unreachable;

    debug.assert(mem.eql(u8, b, []u8.{1}));
    debug.assert(mem.eql(u8, c, []u8.{2}));
    debug.assert(mem.eql(u8, d, []u8.{ 1, 2 }));
    debug.assert(mem.eql(u8, e, []u8.{}));
    debug.assert(mem.eql(u8, f, []u8.{2}));

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

    const q1 = []u8.{ 1, 2 };
    var q2 = []u8.{ 1, 2 };

    const q11 = slice(q1[0..], 0, 2) catch unreachable;
    const q21 = slice(q2[0..], 0, 2) catch unreachable;
    comptime debug.assert(@typeOf(q11) == []const u8);
    comptime debug.assert(@typeOf(q21) == []u8);

    const q12 = slice(&q1, 0, 2) catch unreachable;
    const q22 = slice(&q2, 0, 2) catch unreachable;
    comptime debug.assert(@typeOf(q12) == []const u8);
    comptime debug.assert(@typeOf(q22) == []u8);
}

/// Returns a pointer to the item at ::index in ::s.
/// Returns an error instead of doing a runtime assert when ::index is out of bounds.
pub fn at(s: var, index: usize) !@typeOf(&s[0]) {
    if (s.len <= index)
        return error.OutOfBound;

    return &s[index];
}

test "generic.slice.at" {
    const a = []u8.{ 1, 2 };
    const b = at(a[0..], 0) catch unreachable;
    const c = at(a[0..], 1) catch unreachable;
    const d = at(a[0..], 1) catch unreachable;

    debug.assert(b.* == 1);
    debug.assert(c.* == 2);
    debug.assert(d.* == 2);

    if (at(a[0..], 2)) |_|
        unreachable
    else |err|
        debug.assert(err == error.OutOfBound);

    const q1 = []u8.{ 1, 2 };
    var q2 = []u8.{ 1, 2 };

    const q11 = at(q1[0..], 0) catch unreachable;
    const q21 = at(q2[0..], 0) catch unreachable;
    comptime debug.assert(@typeOf(q11) == *const u8);
    comptime debug.assert(@typeOf(q21) == *u8);

    const q31 = at(&q1, 0) catch unreachable;
    const q41 = at(&q2, 0) catch unreachable;
    comptime debug.assert(@typeOf(q31) == *const u8);
    comptime debug.assert(@typeOf(q41) == *u8);
}

pub fn all(s: var, predicate: fn (@typeOf(s[0])) bool) bool {
    for (s) |v| {
        if (!predicate(v)) return false;
    }

    return true;
}

test "generic.slice.all" {
    const s = "aaa"[0..];
    debug.assert(all(s, struct.{
        fn l(c: u8) bool {
            return c == 'a';
        }
    }.l));
    debug.assert(!all(s, struct.{
        fn l(c: u8) bool {
            return c != 'a';
        }
    }.l));
}

pub fn any(s: var, predicate: fn (@typeOf(s[0])) bool) bool {
    for (s) |v| {
        if (predicate(v)) return true;
    }

    return false;
}

test "generic.slice.any" {
    const s = "abc";
    debug.assert(any(s, struct.{
        fn l(c: u8) bool {
            return c == 'a';
        }
    }.l));
    debug.assert(!any(s, struct.{
        fn l(c: u8) bool {
            return c == 'd';
        }
    }.l));
}

pub fn populate(s: var, value: @typeOf(s[0])) void {
    for (s) |*v| {
        v.* = value;
    }
}

test "generic.slice.populate" {
    var arr: [4]u8 = undefined;
    populate(arr[0..], 'a');
    debug.assert(mem.eql(u8, "aaaa", arr));
}

pub fn transform(s: var, transformer: fn (@typeOf(s[0])) @typeOf(s[0])) void {
    for (s) |*v| {
        v.* = transformer(v.*);
    }
}

test "generic.slice.transform" {
    var arr = "abcd";
    transform(arr[0..], struct.{
        fn l(c: u8) u8 {
            return if ('a' <= c and c <= 'z') c - ('a' - 'A') else c;
        }
    }.l);
    debug.assert(mem.eql(u8, "ABCD", arr));
}
