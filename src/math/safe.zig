const std = @import("std");
const interval = @import("interval.zig");

const debug = std.debug;

// TODO: We can't use comptime_int, because then all the methods on Interval don't compile
const Interval = interval.Interval(i128);

fn MakeInt(int: Interval) type {
    comptime var i = 1;

    // TODO: Naive loop to find the type that can contain the interval.
    //       We can probably use log2 somehow to get the bitcount but meh.
    while (true) : (i += 1) {
        inline for ([]bool{ false, true }) |is_signed| {
            const Int = @IntType(is_signed, i);
            if (@minValue(Int) <= int.min and int.max <= @maxValue(Int))
                return Int;
        }
    }
}

fn toInterval(comptime T: type) Interval {
    return Interval{
        .min = @minValue(T),
        .max = @maxValue(T),
    };
}

fn Result(comptime A: type, comptime B: type, comptime operation: @typeOf(Interval.add)) type {
    const a = toInterval(A);
    const b = toInterval(B);
    return MakeInt(operation(a, b));
}

pub fn add(a: var, b: var) Result(@typeOf(a), @typeOf(b), Interval.add) {
    const Res = @typeOf(this).ReturnType;
    return Res(a) + Res(b);
}

test "math.safe.add" {
    const u64_max: u64 = @maxValue(u64);
    const u64_min: u64 = @minValue(u64);
    const i64_max: i64 = @maxValue(i64);
    const i64_min: i64 = @minValue(i64);
    debug.assert(add(u64_max, u64_max) == @maxValue(u64) + @maxValue(u64));
    debug.assert(add(u64_max, u64_min) == @maxValue(u64) + @minValue(u64));
    debug.assert(add(u64_max, i64_max) == @maxValue(u64) + @maxValue(i64));
    debug.assert(add(u64_max, i64_min) == @maxValue(u64) + @minValue(i64));

    debug.assert(add(u64_min, u64_min) == @minValue(u64) + @minValue(u64));
    debug.assert(add(u64_min, i64_max) == @minValue(u64) + @maxValue(i64));
    debug.assert(add(u64_min, i64_min) == @minValue(u64) + @minValue(i64));

    debug.assert(add(i64_max, i64_max) == @maxValue(i64) + @maxValue(i64));
    debug.assert(add(i64_max, i64_min) == @maxValue(i64) + @minValue(i64));

    debug.assert(add(i64_min, i64_min) == @minValue(i64) + @minValue(i64));
}


pub fn sub(a: var, b: var) Result(@typeOf(a), @typeOf(b), Interval.sub) {
    const Res = @typeOf(this).ReturnType;
    return Res(a) - Res(b);
}

test "math.safe.sub" {
    const u64_max: u64 = @maxValue(u64);
    const u64_min: u64 = @minValue(u64);
    const i64_max: i64 = @maxValue(i64);
    const i64_min: i64 = @minValue(i64);
    debug.assert(sub(u64_max, u64_max) == @maxValue(u64) - @maxValue(u64));
    debug.assert(sub(u64_max, u64_min) == @maxValue(u64) - @minValue(u64));
    debug.assert(sub(u64_max, i64_max) == @maxValue(u64) - @maxValue(i64));
    debug.assert(sub(u64_max, i64_min) == @maxValue(u64) - @minValue(i64));

    debug.assert(sub(u64_min, u64_min) == @minValue(u64) - @minValue(u64));
    debug.assert(sub(u64_min, i64_max) == @minValue(u64) - @maxValue(i64));
    debug.assert(sub(u64_min, i64_min) == @minValue(u64) - @minValue(i64));

    debug.assert(sub(i64_max, i64_max) == @maxValue(i64) - @maxValue(i64));
    debug.assert(sub(i64_max, i64_min) == @maxValue(i64) - @minValue(i64));

    debug.assert(sub(i64_min, i64_min) == @minValue(i64) - @minValue(i64));
}


pub fn mul(a: var, b: var) Result(@typeOf(a), @typeOf(b), Interval.mul) {
    const Res = @typeOf(this).ReturnType;
    return Res(a) * Res(b);
}

// TODO: Because we can only have Interval(i128), then u64 values might overflow the
//       Interval.
test "math.safe.mul" {
    const u32_max: u32 = @maxValue(u32);
    const u32_min: u32 = @minValue(u32);
    const i32_max: i32 = @maxValue(i32);
    const i32_min: i32 = @minValue(i32);
    debug.assert(mul(u32_max, u32_max) == @maxValue(u32) * @maxValue(u32));
    debug.assert(mul(u32_max, u32_min) == @maxValue(u32) * @minValue(u32));
    //debug.assert(mul(u32_max, i32_max) == @maxValue(u32) * @maxValue(i32));
    //debug.assert(mul(u32_max, i32_min) == @maxValue(u32) * @minValue(i32));

    debug.assert(mul(u32_min, u32_min) == @minValue(u32) * @minValue(u32));
    //debug.assert(mul(u32_min, i32_max) == @minValue(u32) * @maxValue(i32));
    //debug.assert(mul(u32_min, i32_min) == @minValue(u32) * @minValue(i32));

    //debug.assert(mul(i32_max, i32_max) == @maxValue(i32) * @maxValue(i32));
    //debug.assert(mul(i32_max, i32_min) == @maxValue(i32) * @minValue(i32));

    //debug.assert(mul(i32_min, i32_min) == @minValue(i32) * @minValue(i32));
}
