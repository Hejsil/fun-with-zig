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
        inline for ([]bool{ true, false }) |is_signed| {
            const Int = @IntType(is_signed, i);
            if (int.min < @minValue(Int) and @maxValue(Int) < int.max)
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

fn AddResult(comptime A: type, comptime B: type) type {
    comptime {
        const a = toInterval(A);
        const b = toInterval(B);
        return MakeInt(a.add(b));
    }
}

fn add(a: var, b: var) AddResult(@typeOf(a), @typeOf(b)) {
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
