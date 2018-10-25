const std = @import("std");
const compare = @import("../src/generic");
const debug = std.debug;
const mem = std.mem;
const math = std.math;

/// Determin the max runtime size requirement to a union of N types.
fn runtimeSize(comptime fields: var) comptime_int {
    var res = 0;
    for (fields) |field| {
        if (res < @sizeOf(field.Payload))
            res = @sizeOf(field.Payload);
    }

    return res;
}

pub fn Field(comptime T: type) type {
    return struct.{
        symbol: T,
        Payload: type,

        pub fn init(symbol: T, comptime Payload: type) @This() {
            return @This().{
                .symbol = symbol,
                .Payload = Payload,
            };
        }
    };
}

pub fn Union(comptime Symbol: type, comptime fields: var) type {
    for (fields) |a, i| {
        for (fields[i+1..]) |b| {
            // TODO: Abitrary symbol equal
            debug.assert(a.symbol != b.symbol);
        }
    }

    return struct.{
        // In order for us to store the eithers values, we have
        // to type erase away the values, and store them as bytes.
        payload: [runtimeSize(fields)]u8,

        symbol: usize, // TODO: Log2Int

        pub fn init(comptime symbol: Symbol, value: At(symbol).Payload) @This() {
            var res: @This() = undefined;
            res.symbol = comptime index(symbol);
            res.ptr(symbol).?.* = value;
            return res;
        }

        pub fn field(either: @This(), comptime symbol: Symbol) ?At(symbol).Payload {
            if (either.ptrConst(symbol)) |p|
                return p.*;

            return null;
        }

        pub fn ptr(either: *@This(), comptime symbol: Symbol) ?*At(symbol).Payload {
            const i = comptime index(symbol);
            if (either.symbol != i)
                return null;

            return &@bytesToSlice(At(symbol).Payload, either.payload[0..])[0];
        }

        pub fn ptrConst(either: *const @This(), comptime symbol: Symbol) ?*const At(symbol).Payload {
            const i = comptime index(symbol);
            if (either.symbol != i)
                return null;

            return &@bytesToSlice(At(symbol).Payload, either.payload[0..])[0];
        }

        pub fn At(comptime symbol: Symbol) Field(Symbol) {
            return fields[index(symbol)];
        }

        fn index(comptime symbol: Symbol) usize {
            inline for (fields) |f, i| {
                if (f.symbol == symbol)
                    return i;
            }

            unreachable;
        }
    };
}

test "union" {
    const T = Union(u8, []Field(u8).{
        Field(u8).init(0, u8),
        Field(u8).init(1, u8),
        Field(u8).init(2, u8),
    });
    const a = T.init(0, 11);
    const b = T.init(1, 22);
    const c = T.init(2, 33);
    debug.assert(a.field(0).? == 11);
    debug.assert(b.field(0) == null);
    debug.assert(c.field(0) == null);
    debug.assert(a.field(1) == null);
    debug.assert(b.field(1).? == 22);
    debug.assert(c.field(1) == null);
    debug.assert(a.field(2) == null);
    debug.assert(b.field(2) == null);
    debug.assert(c.field(2).? == 33);
}
