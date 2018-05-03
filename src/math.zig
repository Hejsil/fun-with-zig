const std = @import("std");
const math = std.math;
const debug = std.debug;

fn CombineAdditive(comptime A: type, comptime B: type) type {
    const is_signed = A.is_signed or B.is_signed;
    const bit_count = blk: {
        const effective_bits_a = A.bit_count - (1 * u8(A.is_signed));
        const effective_bits_b = B.bit_count - (1 * u8(B.is_signed));
        const effective_bits = math.max(effective_bits_a, effective_bits_b);
        const bit_count_without_sign = effective_bits + 1;
        const bit_count = bit_count_without_sign + (1 * u8(is_signed));
        break :blk bit_count;
    };

    return @IntType(is_signed, bit_count);
}

test "math.CombineAdditive" {
    comptime {
        const u9 = @IntType(false, 9);
        const i9 = @IntType(true, 9);
        const i10 = @IntType(true, 10);
        debug.assert(CombineAdditive(u8, u8) == u9);
        debug.assert(CombineAdditive(i8, i8) == i9);
        debug.assert(CombineAdditive(i8, u8) == i10);
    }
}


fn add(a: var, b: var) CombineAdditive(@typeOf(a), @typeOf(b)) {
    const Res = @typeOf(this).ReturnType;
    return Res(a) + Res(b);
}

test "math.add" {
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
