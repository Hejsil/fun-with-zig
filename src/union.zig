const std = @import("std");
const compare = @import("../src/generic");
const debug = std.debug;
const mem = std.mem;
const math = std.math;
const testing = std.testing;

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
    return struct {
        key: T,
        Payload: type,

        pub fn init(key: T, comptime Payload: type) @This() {
            return @This(){
                .key = key,
                .Payload = Payload,
            };
        }
    };
}

pub fn Union(comptime Key: type, comptime field_array: var) type {
    for (field_array) |a, i| {
        for (field_array[i + 1 ..]) |b| {
            // TODO: Abitrary key equal
            debug.assert(a.key != b.key);
        }
    }

    return struct {
        pub const fields = field_array;

        // In order for us to store the eithers values, we have
        // to type erase away the values, and store them as bytes.
        payload: [runtimeSize(fields)]u8,

        key: usize, // TODO: Log2Int

        pub fn init(comptime key: Key, value: GetField(key).Payload) @This() {
            var res: @This() = undefined;
            res.key = comptime index(key);
            res.ptr(key).?.* = value;
            return res;
        }

        pub fn field(u: @This(), comptime key: Key) ?GetField(key).Payload {
            if (u.ptrConst(key)) |p|
                return p.*;

            return null;
        }

        pub fn ptr(u: *@This(), comptime key: Key) ?*align(1) GetField(key).Payload {
            const i = comptime index(key);
            if (u.key != i)
                return null;

            return &@bytesToSlice(GetField(key).Payload, u.payload[0..])[0];
        }

        pub fn ptrConst(u: *const @This(), comptime key: Key) ?*align(1) const GetField(key).Payload {
            const i = comptime index(key);
            if (u.key != i)
                return null;

            return &@bytesToSlice(GetField(key).Payload, u.payload[0..])[0];
        }

        fn GetField(comptime key: Key) Field(Key) {
            return fields[index(key)];
        }

        fn index(comptime key: Key) usize {
            inline for (fields) |f, i| {
                if (f.key == key)
                    return i;
            }

            unreachable;
        }
    };
}

test "union" {
    const T = Union(u8, []Field(u8){
        Field(u8).init(0, u8),
        Field(u8).init(1, u16),
        Field(u8).init(2, f32),
    });
    const a = T.init(0, 11);
    const b = T.init(1, 22);
    const c = T.init(2, 33);
    testing.expectEqual(a.field(0).?, 11);
    testing.expectEqual(b.field(0), null);
    testing.expectEqual(c.field(0), null);
    testing.expectEqual(a.field(1), null);
    testing.expectEqual(b.field(1).?, 22);
    testing.expectEqual(c.field(1), null);
    testing.expectEqual(a.field(2), null);
    testing.expectEqual(b.field(2), null);
    testing.expectEqual(c.field(2).?, 33);
}
