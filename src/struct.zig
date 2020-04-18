const std = @import("std");
const debug = std.debug;
const mem = std.mem;
const testing = std.testing;

/// Determin the runtime size requirement of N types continues in memory (in bytes).
fn runtimeSize(comptime fields: var) comptime_int {
    var res = 0;
    for (fields) |field| {
        res += @sizeOf(field.Value);
    }

    return res;
}

pub fn Field(comptime T: type) type {
    return struct {
        key: T,
        Value: type,

        pub fn init(key: T, comptime Value: type) @This() {
            return @This(){
                .key = key,
                .Value = Value,
            };
        }
    };
}

pub fn Struct(comptime Key: type, comptime field_array: var) type {
    for (field_array) |a, i| {
        for (field_array[i + 1 ..]) |b| {
            // TODO: Abitrary key equal
            debug.assert(a.key != b.key);
        }
    }

    return struct {
        pub const fields = field_array;

        // In order for us to store the tuples values, we have
        // to type erase away the values, and store them as bytes.
        data: [runtimeSize(fields)]u8,

        pub fn field(s: @This(), comptime key: Key) GetField(key).Value {
            return s.ptrConst(key).*;
        }

        pub fn ptr(s: *@This(), comptime key: Key) *align(1) GetField(key).Value {
            const i = comptime index(key);
            const offset = comptime runtimeSize(fields[0..i]);
            return &std.mem.bytesAsSlice(GetField(key).Value, s.data[offset..])[0];
        }

        pub fn ptrConst(s: *const @This(), comptime key: Key) *align(1) const GetField(key).Value {
            const i = comptime index(key);
            const offset = comptime runtimeSize(fields[0..i]);
            return &std.mem.bytesAsSlice(GetField(key).Value, s.data[offset..])[0];
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

test "struct" {
    const T = Struct(u8, [_]Field(u8){
        Field(u8).init(0, u8),
        Field(u8).init(1, u16),
        Field(u8).init(2, f32),
    });

    const s = blk: {
        var res: T = undefined;
        res.ptr(0).* = 11;
        res.ptr(1).* = 22;
        res.ptr(2).* = 33;
        break :blk res;
    };
    testing.expectEqual(s.field(0), 11);
    testing.expectEqual(s.field(1), 22);
    testing.expectEqual(s.field(2), 33);
}
