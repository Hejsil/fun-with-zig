const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const meta = std.meta;
const debug = std.debug;
const testing = std.testing;

const TypeInfo = builtin.TypeInfo;
const TypeId = builtin.TypeId;

fn ByteToSliceResult(comptime Elem: type, comptime SliceOrArray: type) type {
    if (@typeInfo(SliceOrArray) != TypeId.Pointer)
        @compileError("EWRRWRESEDR");

    const ptr = @typeInfo(SliceOrArray).Pointer;
    if (ptr.is_const and ptr.is_volatile)
        return []align(ptr.alignment) const volatile Elem;
    if (ptr.is_const)
        return []align(ptr.alignment) const Elem;
    if (ptr.is_volatile)
        return []align(ptr.alignment) volatile Elem;

    return []align(ptr.alignment) Elem;
}

pub fn bytesToSlice(comptime Element: type, bytes: var) error{SizeMismatch}!ByteToSliceResult(Element, @typeOf(bytes)) {
    if (bytes.len % @sizeOf(Element) != 0)
        return error.SizeMismatch;

    return @bytesToSlice(Element, bytes);
}

test "generic.slice.bytesToSlice" {
    const S = packed struct {
        a: u8,
        b: u8,
    };

    {
        const a = [_]u8{1};
        const b = [_]u8{ 1, 2 };

        if (bytesToSlice(S, a[0..])) |_| unreachable else |_| {}
        const v = bytesToSlice(S, b[0..]) catch unreachable;
        comptime testing.expectEqual([]align(1) const S, @typeOf(v));
        testing.expectEqual(usize(1), v.len);
        testing.expectEqual(u8(1), v[0].a);
        testing.expectEqual(u8(2), v[0].b);

        const v2 = bytesToSlice(S, &b) catch unreachable;
        comptime testing.expectEqual([]align(1) const S, @typeOf(v2));
        testing.expectEqual(usize(1), v2.len);
        testing.expectEqual(u8(1), v2[0].a);
        testing.expectEqual(u8(2), v2[0].b);
    }

    {
        var a = [_]u8{1};
        var b = [_]u8{ 1, 2 };

        if (bytesToSlice(S, a[0..])) |_| unreachable else |_| {}
        const v = bytesToSlice(S, b[0..]) catch unreachable;
        comptime testing.expectEqual([]align(1) S, @typeOf(v));
        testing.expectEqual(usize(1), v.len);
        testing.expectEqual(u8(1), v[0].a);
        testing.expectEqual(u8(2), v[0].b);

        const v2 = bytesToSlice(S, &b) catch unreachable;
        comptime testing.expectEqual([]align(1) S, @typeOf(v2));
        testing.expectEqual(usize(1), v2.len);
        testing.expectEqual(u8(1), v2[0].a);
        testing.expectEqual(u8(2), v2[0].b);
    }
}

pub fn bytesToSliceTrim(comptime Element: type, bytes: var) ByteToSliceResult(Element, @typeOf(bytes)) {
    const rem = bytes.len % @sizeOf(Element);
    return @bytesToSlice(Element, bytes[0 .. bytes.len - rem]);
}

test "generic.slice.bytesToSliceTrim" {
    const S = packed struct {
        a: u8,
        b: u8,
    };

    {
        const a = [_]u8{1};
        const b = [_]u8{ 1, 2 };
        const v1 = bytesToSliceTrim(S, a[0..]);
        const v2 = bytesToSliceTrim(S, b[0..]);
        const v3 = bytesToSliceTrim(S, &a);
        const v4 = bytesToSliceTrim(S, &b);

        comptime testing.expect([]align(1) const S == @typeOf(v1));
        comptime testing.expect([]align(1) const S == @typeOf(v2));
        comptime testing.expect([]const S == @typeOf(v3));
        comptime testing.expect([]const S == @typeOf(v4));
        testing.expectEqual(usize(0), v1.len);
        testing.expectEqual(usize(1), v2.len);
        testing.expectEqual(usize(0), v3.len);
        testing.expectEqual(usize(1), v4.len);
        testing.expectEqual(u8(1), v2[0].a);
        testing.expectEqual(u8(2), v2[0].b);
        testing.expectEqual(u8(1), v4[0].a);
        testing.expectEqual(u8(2), v4[0].b);
    }

    {
        var a = [_]u8{1};
        var b = [_]u8{ 1, 2 };
        const v1 = bytesToSliceTrim(S, a[0..]);
        const v2 = bytesToSliceTrim(S, b[0..]);
        const v3 = bytesToSliceTrim(S, &a);
        const v4 = bytesToSliceTrim(S, &b);

        comptime testing.expectEqual([]S, @typeOf(v1));
        comptime testing.expectEqual([]S, @typeOf(v2));
        comptime testing.expectEqual([]S, @typeOf(v3));
        comptime testing.expectEqual([]S, @typeOf(v4));
        testing.expectEqual(usize(0), v1.len);
        testing.expectEqual(usize(1), v2.len);
        testing.expectEqual(usize(0), v3.len);
        testing.expectEqual(usize(1), v4.len);
        testing.expectEqual(usize(1), v2[0].a);
        testing.expectEqual(usize(2), v2[0].b);
        testing.expectEqual(usize(1), v4[0].a);
        testing.expectEqual(usize(2), v4[0].b);
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
    const a = [_]u8{ 1, 2 };
    const b = slice(a[0..], 0, 1) catch unreachable;
    const c = slice(a[0..], 1, 2) catch unreachable;
    const d = slice(a[0..], 0, 2) catch unreachable;
    const e = slice(a[0..], 2, 2) catch unreachable;
    const f = slice(&a, 1, 2) catch unreachable;

    testing.expectEqualSlices(u8, [_]u8{1}, b);
    testing.expectEqualSlices(u8, [_]u8{2}, c);
    testing.expectEqualSlices(u8, [_]u8{ 1, 2 }, d);
    testing.expectEqualSlices(u8, [_]u8{}, e);
    testing.expectEqualSlices(u8, [_]u8{2}, f);

    testing.expectError(error.OutOfBound, slice(a[0..], 0, 3));
    testing.expectError(error.OutOfBound, slice(a[0..], 3, 3));
    testing.expectError(error.EndLessThanStart, slice(a[0..], 1, 0));

    const q1 = [_]u8{ 1, 2 };
    var q2 = [_]u8{ 1, 2 };

    const q11 = slice(q1[0..], 0, 2) catch unreachable;
    const q21 = slice(q2[0..], 0, 2) catch unreachable;
    comptime testing.expectEqual([]const u8, @typeOf(q11));
    comptime testing.expectEqual([]u8, @typeOf(q21));

    const q12 = slice(&q1, 0, 2) catch unreachable;
    const q22 = slice(&q2, 0, 2) catch unreachable;
    comptime testing.expectEqual([]const u8, @typeOf(q12));
    comptime testing.expectEqual([]u8, @typeOf(q22));
}

/// Returns a pointer to the item at ::index in ::s.
/// Returns an error instead of doing a runtime assert when ::index is out of bounds.
pub fn at(s: var, index: usize) !@typeOf(&s[0]) {
    if (s.len <= index)
        return error.OutOfBound;

    return &s[index];
}

test "generic.slice.at" {
    const a = [_]u8{ 1, 2 };
    const b = at(a[0..], 0) catch unreachable;
    const c = at(a[0..], 1) catch unreachable;
    const d = at(a[0..], 1) catch unreachable;

    testing.expectEqual(u8(1), b.*);
    testing.expectEqual(u8(2), c.*);
    testing.expectEqual(u8(2), d.*);
    testing.expectError(error.OutOfBound, at(a[0..], 2));

    const q1 = [_]u8{ 1, 2 };
    var q2 = [_]u8{ 1, 2 };

    const q11 = at(q1[0..], 0) catch unreachable;
    const q21 = at(q2[0..], 0) catch unreachable;
    comptime testing.expectEqual(*const u8, @typeOf(q11));
    comptime testing.expectEqual(*u8, @typeOf(q21));

    const q31 = at(&q1, 0) catch unreachable;
    const q41 = at(&q2, 0) catch unreachable;
    comptime testing.expectEqual(*const u8, @typeOf(q31));
    comptime testing.expectEqual(*u8, @typeOf(q41));
}

pub fn all(s: var, predicate: fn (@typeOf(s[0])) bool) bool {
    for (s) |v| {
        if (!predicate(v)) return false;
    }

    return true;
}

test "generic.slice.all" {
    const s = "aaa"[0..];
    testing.expect(all(s, struct {
        fn l(c: u8) bool {
            return c == 'a';
        }
    }.l));
    testing.expect(!all(s, struct {
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
    testing.expect(any(s, struct {
        fn l(c: u8) bool {
            return c == 'a';
        }
    }.l));
    testing.expect(!any(s, struct {
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
    testing.expectEqualSlices(u8, "aaaa", arr);
}

pub fn transform(s: var, transformer: fn (@typeOf(s[0])) @typeOf(s[0])) void {
    for (s) |*v| {
        v.* = transformer(v.*);
    }
}

test "generic.slice.transform" {
    var arr = "abcd";
    transform(arr[0..], struct {
        fn l(c: u8) u8 {
            return if ('a' <= c and c <= 'z') c - ('a' - 'A') else c;
        }
    }.l);
    testing.expectEqualSlices(u8, "ABCD", arr);
}
