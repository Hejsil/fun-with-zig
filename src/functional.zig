const assert = @import("std").debug.assert;

/// Composes two functions at compile time.
pub fn compose(comptime X: type, comptime Y: type, comptime Z: type, 
    comptime f: fn(X) -> Y, comptime g: fn(Y) -> Z) -> fn(X) -> Z {
    return struct {
        fn composed(x: X) -> Y { g(f(x)) }
    }.composed;
}

fn firstHalf(s: []const u8) -> []const u8 {
    return s[0..s.len / 2];
}

fn secondHalf(s: []const u8) -> []const u8 {
    return s[s.len / 2..];
}

test "Example: compose" {
    const mem = @import("std").mem;
    const str = "12345678";
    const firstOneForth  = compose([]const u8, []const u8, []const u8, firstHalf, firstHalf);
    const secondOneForth = compose([]const u8, []const u8, []const u8, firstHalf, secondHalf);
    const thirdOneForth  = compose([]const u8, []const u8, []const u8, secondHalf, firstHalf);
    const forthOneForth  = compose([]const u8, []const u8, []const u8, secondHalf, secondHalf);

    assert(mem.eql(u8, firstOneForth(str) , "12"));
    assert(mem.eql(u8, secondOneForth(str), "34"));
    assert(mem.eql(u8, thirdOneForth(str) , "56"));
    assert(mem.eql(u8, forthOneForth(str) , "78"));
}