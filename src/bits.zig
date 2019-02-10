const std = @import("std");

const math = std.math;
const testing = std.testing;

pub fn set(comptime Int: type, num: Int, bit: math.Log2Int(Int)) Int {
    return num | (Int(1) << bit);
}

test "bits.set" {
    const v = u8(0b10);
    testing.expectEqual(u8(0b11), set(u8, v, 0));
    testing.expectEqual(u8(0b10), set(u8, v, 1));
}

pub fn clear(comptime Int: type, num: Int, bit: math.Log2Int(Int)) Int {
    return num & ~(Int(1) << bit);
}

test "bits.clear" {
    const v = u8(0b10);
    testing.expectEqual(u8(0b10), clear(u8, v, 0));
    testing.expectEqual(u8(0b00), clear(u8, v, 1));
}

pub fn isSet(comptime Int: type, num: Int, bit: math.Log2Int(Int)) bool {
    return ((num >> bit) & 1) != 0;
}

test "bits.isSet" {
    const v = u8(0b10);
    testing.expect(!isSet(u8, v, 0));
    testing.expect(isSet(u8, v, 1));
}

pub fn toggle(comptime Int: type, num: Int, bit: math.Log2Int(Int)) Int {
    return num ^ (Int(1) << bit);
}

test "bits.toggle" {
    const v = u8(0b10);
    testing.expectEqual(u8(0b11), toggle(u8, v, 0));
    testing.expectEqual(u8(0b00), toggle(u8, v, 1));
}

pub fn count(comptime Int: type, num: Int) usize {
    var tmp = num;
    var res: usize = 0;
    while (tmp != 0) : (res += 1)
        tmp &= tmp - 1;

    return res;
}

test "bits.count" {
    testing.expectEqual(usize(0), count(u8, 0b0));
    testing.expectEqual(usize(1), count(u8, 0b1));
    testing.expectEqual(usize(2), count(u8, 0b101));
    testing.expectEqual(usize(4), count(u8, 0b11011));
}
