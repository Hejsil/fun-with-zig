const std = @import("std");
const debug = std.debug;
const mem = std.mem;

/// A type, whose value might be known at comptime.
const Type = struct.{
    const Handle = *const @OpaqueType();

    T: type,
    v: ?Handle,

    pub fn runt(comptime T: type) Type {
        return Type.{
            .T = T,
            .v = null,
        };
    }

    pub fn compt(comptime value_ptr: var) Type {
        return Type.{
            .T = @typeOf(value_ptr.*),
            .v = @ptrCast(Handle, value_ptr),
        };
    }

    pub fn comptValue(comptime t: Type) ?t.T {
        if (t.v) |v|
            return @ptrCast(*const t.T, t.v).*;

        return null;
    }
};


/// Given a [N]T, returns [N+1]T, where the first N items are a copy
/// of "arr", and the last value is a copy of item.
fn append(comptime arr: var, comptime item: var) [arr.len + 1]@typeOf(item) {
    return arr ++ []@typeOf(item).{item};
}

/// Determin the runtime size requirement of N Type. Type does not
/// take up any size, if it has a value known at comptime.
fn runtimeSize(comptime types: []const Type) comptime_int {
    var res = 0;
    for (types) |t| {
        if (t.comptValue() == null)
            res += @sizeOf(t.T);
    }

    return res;
}

/// A tuple, which can store both comptime and runtimes values.
/// The comptime values of the tuple is stored in its type.
/// Therefore, two tuples have different types, if one of their
/// comptime values are different.
fn Tuple(comptime types: var) type {
    return struct.{
        /// The number of items in the tuple.
        const len = types.len;

        // In order for us to store the tuples values, we have
        // to types erase away the values, and store them as bytes.
        data: [runtimeSize(types)]u8,

        /// Returns the Ns item in the tuple (runtime only).
        pub fn atr(tuple: @This(), comptime i: usize) types[i].T {
            const t = types[i];
            comptime {
                if (t.comptValue()) |v|
                    @compileError("Value of item N is only known at comptime.");
            }

            const offset = runtimeSize(types[0..i]);
            const item_bytes = tuple.data[offset..][0..@sizeOf(t.T)];
            return @bytesToSlice(t.T, item_bytes)[0];
        }

        /// Returns the Ns item in the tuple (comptime only).
        pub fn atc(comptime i: usize) types[i].T {
            const t = types[i];
            if (t.comptValue()) |v|
                return v;

            @compileError("Value of item N is only known at runtime.");
        }

        /// Determin if the Ns item is only known at runtime.
        pub fn isRuntime(tuple: @This(), comptime i: usize) bool {
            return types[i].comptValue() == null;
        }

        /// Returns a new tuple, which stores the values of "t" +
        /// the value of "item" (item will be stored at runtime).
        pub fn r(t: @This(), item: var) Tuple(append(types, Type.runt(@typeOf(item)))) {
            const Res = Tuple(append(types, Type.runt(@typeOf(item))));
            const T = @typeOf(item);

            const item_arr = []T.{item};
            const item_bytes = @sliceToBytes(item_arr[0..]);
            var res = Res.{ .data = undefined };

            mem.copy(u8, res.data[0..], t.data);
            mem.copy(u8, res.data[t.data.len..], item_bytes);
            return res;
        }

        /// Returns a new tuple, which stores the values of "t" +
        /// the value of "item" (item will be stored at comptime).
        pub fn c(t: @This(), comptime item: var) Tuple(append(types, Type.compt(&item))) {
            const Res = Tuple(append(types, Type.compt(&item)));
            var res = Res.{ .data = undefined };

            mem.copy(u8, res.data[0..], t.data);
            return res;
        }
    };
}

/// Tuple with no items:
const Unit = Tuple([]Type.{}).{ .data = []u8.{} };

test "tuple" {
    const t = Unit.c(22).r(f32(33)).r("333");
    const a = @typeOf(t).atc(0);
    const b = t.atr(1);
    const c = t.atr(2);
    debug.assert(a == 22);
    debug.assert(b == 33.0);
    debug.assert(mem.eql(u8, c, "333"));
}
