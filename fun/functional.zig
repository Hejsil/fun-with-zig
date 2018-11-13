const assert = @import("std").debug.assert;

/// Composes two functions at compile time.
pub fn compose(
    comptime X: type,
    comptime Y: type,
    comptime Z: type,
    comptime f: fn (X) Y,
    comptime g: fn (Y) Z,
) fn (X) Z {
    return struct {
        fn composed(x: X) Y {
            return g(f(x));
        }
    }.composed;
}

fn firstHalf(s: []const u8) []const u8 {
    return s[0 .. s.len / 2];
}

fn secondHalf(s: []const u8) []const u8 {
    return s[s.len / 2 ..];
}

test "functional.Example: functional.compose" {
    const mem = @import("std").mem;
    const str = "12345678";
    const firstOneForth = compose([]const u8, []const u8, []const u8, firstHalf, firstHalf);
    const secondOneForth = compose([]const u8, []const u8, []const u8, firstHalf, secondHalf);
    const thirdOneForth = compose([]const u8, []const u8, []const u8, secondHalf, firstHalf);
    const forthOneForth = compose([]const u8, []const u8, []const u8, secondHalf, secondHalf);

    assert(mem.eql(u8, firstOneForth(str), "12"));
    assert(mem.eql(u8, secondOneForth(str), "34"));
    assert(mem.eql(u8, thirdOneForth(str), "56"));
    assert(mem.eql(u8, forthOneForth(str), "78"));
}

pub fn reverse(comptime X: type, comptime Y: type, comptime f: fn (X, X) Y) fn (X, X) Y {
    return struct {
        fn reversed(a: X, b: X) Y {
            return f(b, a);
        }
    }.reversed;
}

pub fn reverseSimple(comptime T: type, comptime f: fn (T, T) T) fn (T, T) T {
    return reverse(T, T, f);
}

fn lt(a: i32, b: i32) bool {
    return a < b;
}

test "functional.Example: functional.reverse" {
    const sort = @import("std").sort;
    const mem = @import("std").mem;

    var iarr = []i32{ 5, 3, 1, 2, 4 };
    sort.sort(i32, iarr[0..], comptime reverse(i32, bool, lt));

    assert(mem.eql(i32, iarr, []i32{ 5, 4, 3, 2, 1 }));
}
