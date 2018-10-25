const std = @import("std");
const debug = std.debug;
const mem = std.mem;

/// Given a [N]T, returns [N+1]T, where the first N items are a copy
/// of "arr", and the last value is a copy of item.
fn append(comptime arr: var, comptime item: var) [arr.len + 1]@typeOf(item) {
    return arr ++ []@typeOf(item).{item};
}

/// Determin the runtime size requirement of N types continues in memory (in bytes).
fn runtimeSize(comptime types: []const type) comptime_int {
    var res = 0;
    for (types) |T|
        res += @sizeOf(T);

    return res;
}

pub fn Tuple(comptime types: var) type {
    return struct.{
        /// The number of items in the tuple.
        pub const len = types.len;

        // In order for us to store the tuples values, we have
        // to type erase away the values, and store them as bytes.
        data: [runtimeSize(types)]u8,

        /// Returns the Ns item in the tuple.
        pub fn at(tuple: @This(), comptime i: usize) types[i] {
            const T = types[i];
            const offset = runtimeSize(types[0..i]);
            const item_bytes = tuple.data[offset..][0..@sizeOf(T)];
            return @bytesToSlice(T, item_bytes)[0];
        }

        pub fn set(tuple: *@This(), comptime i: usize, item: var) void {
            const T = types[i];
            const offset = runtimeSize(types[0..i]);
            const item_bytes = tuple.data[offset..][0..@sizeOf(T)];
            @bytesToSlice(T, item_bytes)[0] = item;
        }

        pub fn At(comptime i: usize) type {
            return types[i];
        }

        pub fn add(t: @This(), item: var) Add(@typeOf(item)) {
            const Res = Add(@typeOf(item));
            const T = @typeOf(item);

            const item_arr = []T.{item};
            const item_bytes = @sliceToBytes(item_arr[0..]);
            var res = Res.{ .data = undefined };

            mem.copy(u8, res.data[0..], t.data);
            mem.copy(u8, res.data[t.data.len..], item_bytes);
            return res;
        }

        pub fn Add(comptime item: type) type {
            return Tuple(append(types, item));
        }
    };
}

/// Tuple with no items:
pub const Unit = Tuple([]type.{}).{ .data = []u8.{} };

test "tuple" {
    const t = Unit.add(u8(22)).add(f32(33)).add("333");
    const a = t.at(0);
    const b = t.at(1);
    const c = t.at(2);
    debug.assert(a == 22);
    debug.assert(b == 33.0);
    debug.assert(mem.eql(u8, c, "333"));
}
