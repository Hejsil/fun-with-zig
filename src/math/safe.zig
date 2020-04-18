const std = @import("std");
const interval = @import("interval.zig");

const debug = std.debug;
const math = std.math;
const testing = std.testing;

// TODO: We can't use comptime_int, because then all the methods on Interval don't compile
const Interval = interval.Interval(i128);

fn toInterval(comptime T: type) Interval {
    return Interval{
        .min = math.minInt(T),
        .max = math.maxInt(T),
    };
}

fn Result(comptime A: type, comptime B: type, comptime operation: @TypeOf(Interval.add)) type {
    const a = toInterval(A);
    const b = toInterval(B);
    const res = operation(a, b);
    return math.IntFittingRange(res.min, res.max);
}

pub fn add(a: var, b: var) Result(@TypeOf(a), @TypeOf(b), Interval.add) {
    const Res = Result(@TypeOf(a), @TypeOf(b), Interval.add);
    return @as(Res, a) + @as(Res, b);
}

fn testAdd() void {
    const u64_max: u64 = math.maxInt(u64);
    const u64_min: u64 = math.minInt(u64);
    const i64_max: i64 = math.maxInt(i64);
    const i64_min: i64 = math.minInt(i64);
    testing.expectEqual(add(u64_max, u64_max), math.maxInt(u64) + math.maxInt(u64));
    testing.expectEqual(add(u64_max, u64_min), math.maxInt(u64) + math.minInt(u64));
    testing.expectEqual(add(u64_max, i64_max), math.maxInt(u64) + math.maxInt(i64));
    testing.expectEqual(add(u64_max, i64_min), math.maxInt(u64) + math.minInt(i64));

    testing.expectEqual(add(u64_min, u64_min), math.minInt(u64) + math.minInt(u64));
    testing.expectEqual(add(u64_min, i64_max), math.minInt(u64) + math.maxInt(i64));
    testing.expectEqual(add(u64_min, i64_min), math.minInt(u64) + math.minInt(i64));

    testing.expectEqual(add(i64_max, i64_max), math.maxInt(i64) + math.maxInt(i64));
    testing.expectEqual(add(i64_max, i64_min), math.maxInt(i64) + math.minInt(i64));

    testing.expectEqual(add(i64_min, i64_min), math.minInt(i64) + math.minInt(i64));
}

test "math.safe.add" {
    comptime testAdd();
    testAdd();
}

pub fn sub(a: var, b: var) Result(@TypeOf(a), @TypeOf(b), Interval.sub) {
    const Res = Result(@TypeOf(a), @TypeOf(b), Interval.sub);
    return @as(Res, a) - @as(Res, b);
}

fn testSub() void {
    const u64_max: u64 = math.maxInt(u64);
    const u64_min: u64 = math.minInt(u64);
    const i64_max: i64 = math.maxInt(i64);
    const i64_min: i64 = math.minInt(i64);
    testing.expectEqual(sub(u64_max, u64_max), math.maxInt(u64) - math.maxInt(u64));
    testing.expectEqual(sub(u64_max, u64_min), math.maxInt(u64) - math.minInt(u64));
    testing.expectEqual(sub(u64_max, i64_max), math.maxInt(u64) - math.maxInt(i64));
    testing.expectEqual(sub(u64_max, i64_min), math.maxInt(u64) - math.minInt(i64));

    testing.expectEqual(sub(u64_min, u64_min), math.minInt(u64) - math.minInt(u64));
    testing.expectEqual(sub(u64_min, i64_max), math.minInt(u64) - math.maxInt(i64));
    testing.expectEqual(sub(u64_min, i64_min), math.minInt(u64) - math.minInt(i64));

    testing.expectEqual(sub(i64_max, i64_max), math.maxInt(i64) - math.maxInt(i64));
    testing.expectEqual(sub(i64_max, i64_min), math.maxInt(i64) - math.minInt(i64));

    testing.expectEqual(sub(i64_min, i64_min), math.minInt(i64) - math.minInt(i64));
}

test "math.safe.sub" {
    comptime testSub();
    testSub();
}

pub fn mul(a: var, b: var) Result(@TypeOf(a), @TypeOf(b), Interval.mul) {
    const Res = Result(@TypeOf(a), @TypeOf(b), Interval.mul);
    return @as(Res, a) * @as(Res, b);
}

fn testMul() void {
    // TODO: Because we can only have Interval(i128), then u64 values might overflow the
    //       Interval.
    const u32_max: u32 = math.maxInt(u32);
    const u32_min: u32 = math.minInt(u32);
    const i32_max: i32 = math.maxInt(i32);
    const i32_min: i32 = math.minInt(i32);
    testing.expectEqual(mul(u32_max, u32_max), math.maxInt(u32) * math.maxInt(u32));
    testing.expectEqual(mul(u32_max, u32_min), math.maxInt(u32) * math.minInt(u32));
    //testing.expectEqual(mul(u32_max, i32_max) , math.maxInt(u32) * math.maxInt(i32));
    //testing.expectEqual(mul(u32_max, i32_min) , math.maxInt(u32) * math.minInt(i32));

    testing.expectEqual(mul(u32_min, u32_min), math.minInt(u32) * math.minInt(u32));
    //testing.expectEqual(mul(u32_min, i32_max) , math.minInt(u32) * math.maxInt(i32));
    //testing.expectEqual(mul(u32_min, i32_min) , math.minInt(u32) * math.minInt(i32));

    //testing.expectEqual(mul(i32_max, i32_max) , math.maxInt(i32) * math.maxInt(i32));
    //testing.expectEqual(mul(i32_max, i32_min) , math.maxInt(i32) * math.minInt(i32));

    //testing.expectEqual(mul(i32_min, i32_min) , math.minInt(i32) * math.minInt(i32));
}

test "math.safe.mul" {
    comptime testMul();
    testMul();
}
