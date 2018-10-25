const mem = @import("std").mem;
const assert = @import("std").debug.assert;
const TypeId = @import("builtin").TypeId;
const TypeInfo = @import("builtin").TypeInfo;

pub fn lessThan(comptime T: type, a: T, b: T) bool {
    const info = @typeInfo(T);
    switch (info) {
        TypeId.Int, TypeId.Float, TypeId.ComptimeFloat, TypeId.ComptimeInt => return a < b,
        TypeId.Bool => return @boolToInt(a) < @boolToInt(b),

        TypeId.Optional => |optional| {
            const a_value = a orelse {
                return if (b) |_| true else false;
            };
            const b_value = b orelse return false;

            return lessThan(optional.child, a_value, b_value);
        },
        TypeId.ErrorUnion => |err_union| {
            const a_value = a catch |a_err| {
                if (b) |_| {
                    return true;
                } else |b_err| {
                    return lessThan(err_union.error_set, a_err, b_err);
                }
            };
            const b_value = b catch return false;

            return lessThan(err_union.payload, a_value, b_value);
        },

        // TODO: mem.lessThan is wrong
        TypeId.Array => |arr| return mem.lessThan(arr.child, a, b),
        TypeId.Enum => |e| return @enumToInt(a) < @enumToInt(b),
        TypeId.ErrorSet => return @errorToInt(a) < @errorToInt(b),

        TypeId.Null, TypeId.Void => return false,

        TypeId.Undefined, TypeId.Type, TypeId.NoReturn, TypeId.Fn, TypeId.Namespace, TypeId.BoundFn, TypeId.ArgTuple, TypeId.Opaque, TypeId.Promise, TypeId.Struct, TypeId.Union, TypeId.Pointer => {
            @compileError("Cannot get a default less than for " ++ @typeName(T));
            return false;
        },
    }
}

test "generic.compare.lessThan(u64)" {
    assert(lessThan(u64, 1, 2));
    assert(!lessThan(u64, 1, 1));
    assert(!lessThan(u64, 1, 0));
}

test "generic.compare.lessThan(i64)" {
    assert(lessThan(i64, 0, 1));
    assert(!lessThan(i64, 0, 0));
    assert(!lessThan(i64, 0, -1));
}

test "generic.compare.lessThan(comptime_int)" {
    assert(lessThan(comptime_int, 0, 1));
    assert(!lessThan(comptime_int, 0, 0));
    assert(!lessThan(comptime_int, 0, -1));
}

test "generic.compare.lessThan(f64)" {
    assert(lessThan(f64, 0, 1));
    assert(!lessThan(f64, 0, 0));
    assert(!lessThan(f64, 0, -1));
}

test "generic.compare.lessThan(comptime_float)" {
    assert(lessThan(comptime_float, 0.0, 1.0));
    assert(!lessThan(comptime_float, 0.0, 0.0));
    assert(!lessThan(comptime_float, 0.0, -1.0));
}

test "generic.compare.lessThan(bool)" {
    assert(lessThan(bool, false, true));
    assert(!lessThan(bool, true, true));
    assert(!lessThan(bool, true, false));
}

test "generic.compare.lessThan(?i64)" {
    const nul: ?i64 = null;
    assert(lessThan(?i64, 0, 1));
    assert(!lessThan(?i64, 0, 0));
    assert(!lessThan(?i64, 0, -1));
    assert(lessThan(?i64, nul, 0));
    assert(!lessThan(?i64, nul, nul));
    assert(!lessThan(?i64, 0, nul));
}

//TODO implement @typeInfo for global error set
//test "generic.compare.lessThan(error!i64)" {
//    const err : error!i64 = error.No;
//    assert( lessThan(error!i64, 0,  1));
//    assert(!lessThan(error!i64, 0,  0));
//    assert(!lessThan(error!i64, 0, -1));
//    assert( lessThan(error!i64, err, 0  ));
//    assert(!lessThan(error!i64, err, err));
//    assert(!lessThan(error!i64, 0  , err));
//}

test "generic.compare.lessThan([1]u8)" {
    assert(lessThan([1]u8, "1", "2"));
    assert(!lessThan([1]u8, "1", "1"));
    assert(!lessThan([1]u8, "1", "0"));
}

test "generic.compare.lessThan(enum)" {
    const E = enum.{
        A = 0,
        B = 1,
    };
    assert(lessThan(E, E.A, E.B));
    assert(!lessThan(E, E.B, E.B));
    assert(!lessThan(E, E.B, E.A));
}

//TODO implement @typeInfo for global error set
//test "generic.compare.lessThan(error)" {
//    assert( lessThan(error, error.A, error.B));
//    assert(!lessThan(error, error.B, error.B));
//    assert(!lessThan(error, error.B, error.A));
//}

//test "generic.compare.lessThan(null)" {
//    comptime assert(!lessThan(@typeOf(null), null, null));
//}

test "generic.compare.lessThan(void)" {
    assert(!lessThan(void, void.{}, void.{}));
}

pub fn equal(comptime T: type, a: T, b: T) bool {
    const info = @typeInfo(T);
    switch (info) {
        TypeId.Int, TypeId.Float, TypeId.ComptimeInt, TypeId.ComptimeFloat, TypeId.Enum, TypeId.ErrorSet, TypeId.Type, TypeId.Void, TypeId.Fn, TypeId.Null, TypeId.Bool => return a == b,
        // We don't follow pointers, as this would `lessThan` recursive on recursive types (like LinkedList
        TypeId.Pointer => |ptr| switch (ptr.size) {
            TypeInfo.Pointer.Size.Slice => {
                return a.ptr == b.ptr and a.len == b.len;
            },
            else => return a == b,
        },
        TypeId.Array => {
            if (a.len != b.len)
                return false;

            for (a) |_, i| {
                if (!equal(T.Child, a[i], b[i]))
                    return false;
            }

            return true;
        },
        TypeId.Optional => |optional| {
            const a_value = a orelse {
                return if (b) |_| false else true;
            };
            const b_value = b orelse return false;

            return equal(optional.child, a_value, b_value);
        },
        TypeId.ErrorUnion => |err_union| {
            const a_value = a catch |a_err| {
                if (b) |_| {
                    return false;
                } else |b_err| {
                    return equal(err_union.error_set, a_err, b_err);
                }
            };
            const b_value = b catch return false;

            return equal(err_union.payload, a_value, b_value);
        },
        TypeId.Struct => |struct_info| {
            inline for (struct_info.fields) |field| {
                if (!fieldsEql(T, field.name, a, b))
                    return false;
            }

            return true;
        },

        TypeId.Undefined, TypeId.NoReturn, TypeId.Namespace, TypeId.BoundFn, TypeId.ArgTuple, TypeId.Opaque, TypeId.Promise, TypeId.Union => {
            @compileError("Cannot get a default equal for " ++ @typeName(T));
            return false;
        },
    }
}

fn fieldsEql(comptime T: type, comptime field: []const u8, a: T, b: T) bool {
    const af = @field(a, field);
    const bf = @field(b, field);
    return equal(@typeOf(af), af, bf);
}

test "generic.compare.equal(i32)" {
    assert(equal(i32, 1, 1));
    assert(!equal(i32, 0, 1));
}

test "generic.compare.equal(comptime_int)" {
    assert(equal(comptime_int, 1, 1));
    assert(!equal(comptime_int, 0, 1));
}

test "generic.compare.equal(f32)" {
    assert(equal(f32, 1, 1));
    assert(!equal(f32, 0, 1));
}

test "generic.compare.equal(comptime_float)" {
    assert(equal(comptime_float, 1.1, 1.1));
    assert(!equal(comptime_float, 0.0, 1.1));
}

test "generic.compare.equal(bool)" {
    assert(equal(bool, true, true));
    assert(!equal(bool, true, false));
}

test "generic.compare.equal(type)" {
    comptime {
        assert(equal(type, u8, u8));
        assert(!equal(type, u16, u8));
    }
}

test "generic.compare.equal(enum)" {
    const E = enum.{
        A,
        B,
    };
    assert(equal(E, E.A, E.A));
    assert(!equal(E, E.A, E.B));
}

//TODO implement @typeInfo for global error set
//test "generic.compare.equal(error)" {
//    assert( equal(error, error.A, error.A));
//    assert(!equal(error, error.A, error.B));
//}

test "generic.compare.equal(&i64)" {
    var a: i64 = undefined;
    var b: i64 = undefined;
    assert(equal(*i64, &a, &a));
    assert(!equal(*i64, &a, &b));
}

test "generic.compare.equal(?i64)" {
    var nul: ?i64 = null;
    assert(equal(?i64, 1, 1));
    assert(equal(?i64, nul, nul));
    assert(!equal(?i64, 1, 0));
    assert(!equal(?i64, 1, nul));
}

//TODO implement @typeInfo for global error set
//test "generic.compare.equal(%i32)" {
//    const a : error!i32 = 1;
//    const b : error!i32 = error.TestError1;
//    const errorEqual = equal(error!i32);
//    assert( errorEqual(a, (error!i32)(1)));
//    assert(!errorEqual(a, (error!i32)(0)));
//    assert(!errorEqual(a, (error!i32)(error.TestError1)));
//    assert( errorEqual(b, (error!i32)(error.TestError1)));
//    assert(!errorEqual(b, (error!i32)(error.TestError2)));
//    assert(!errorEqual(b, (error!i32)(0)));
//}

test "generic.compare.equal([1]u8)" {
    assert(equal([1]u8, "1", "1"));
    assert(!equal([1]u8, "1", "0"));
}

test "generic.compare.equal(null)" {
    comptime assert(equal(@typeOf(null), null, null));
}

test "generic.compare.equal(void)" {
    assert(equal(void, void.{}, void.{}));
}

test "generic.compare.equal(struct)" {
    const Struct = packed struct.{
        a: u3,
        b: u3,
    };
    assert(equal(Struct, Struct.{ .a = 1, .b = 1 }, Struct.{ .a = 1, .b = 1 }));
    assert(!equal(Struct, Struct.{ .a = 0, .b = 0 }, Struct.{ .a = 1, .b = 1 }));
}

test "generic.compare.equal([]const u8)" {
    const a = "1";
    const b = "0";
    assert(equal([]const u8, a, a));
    assert(!equal([]const u8, a, b));
}

//unreachable
//[1]    6911 abort (core dumped)  zig test src/index.zig
//test "equal(fn()void)" {
//    const T = struct {
//        fn a() void {}
//        fn b() void {}
//    };
//
//    assert( equal(fn()void, T.a, T.a));
//    assert(!equal(fn()void, T.a, T.b));
//}
