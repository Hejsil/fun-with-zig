const std = @import("std");
const builtin = @import("builtin");

const mem = std.mem;
const testing = std.testing;

const TypeId = builtin.TypeId;
const TypeInfo = builtin.TypeInfo;

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

        TypeId.Vector,
        TypeId.Undefined,
        TypeId.Type,
        TypeId.NoReturn,
        TypeId.Fn,
        TypeId.BoundFn,
        TypeId.ArgTuple,
        TypeId.Opaque,
        TypeId.Promise,
        TypeId.Struct,
        TypeId.Union,
        TypeId.Pointer,
        => {
            @compileError("Cannot get a default less than for " ++ @typeName(T));
            return false;
        },
    }
}

test "generic.compare.lessThan(u64)" {
    testing.expect(lessThan(u64, 1, 2));
    testing.expect(!lessThan(u64, 1, 1));
    testing.expect(!lessThan(u64, 1, 0));
}

test "generic.compare.lessThan(i64)" {
    testing.expect(lessThan(i64, 0, 1));
    testing.expect(!lessThan(i64, 0, 0));
    testing.expect(!lessThan(i64, 0, -1));
}

test "generic.compare.lessThan(comptime_int)" {
    testing.expect(lessThan(comptime_int, 0, 1));
    testing.expect(!lessThan(comptime_int, 0, 0));
    testing.expect(!lessThan(comptime_int, 0, -1));
}

test "generic.compare.lessThan(f64)" {
    testing.expect(lessThan(f64, 0, 1));
    testing.expect(!lessThan(f64, 0, 0));
    testing.expect(!lessThan(f64, 0, -1));
}

test "generic.compare.lessThan(comptime_float)" {
    testing.expect(lessThan(comptime_float, 0.0, 1.0));
    testing.expect(!lessThan(comptime_float, 0.0, 0.0));
    testing.expect(!lessThan(comptime_float, 0.0, -1.0));
}

test "generic.compare.lessThan(bool)" {
    testing.expect(lessThan(bool, false, true));
    testing.expect(!lessThan(bool, true, true));
    testing.expect(!lessThan(bool, true, false));
}

test "generic.compare.lessThan(?i64)" {
    const nul: ?i64 = null;
    testing.expect(lessThan(?i64, 0, 1));
    testing.expect(!lessThan(?i64, 0, 0));
    testing.expect(!lessThan(?i64, 0, -1));
    testing.expect(lessThan(?i64, nul, 0));
    testing.expect(!lessThan(?i64, nul, nul));
    testing.expect(!lessThan(?i64, 0, nul));
}

//TODO implement @typeInfo for global error set
//test "generic.compare.lessThan(error!i64)" {
//    const err : error!i64 = error.No;
//    testing.expect( lessThan(error!i64, 0,  1));
//    testing.expect(!lessThan(error!i64, 0,  0));
//    testing.expect(!lessThan(error!i64, 0, -1));
//    testing.expect( lessThan(error!i64, err, 0  ));
//    testing.expect(!lessThan(error!i64, err, err));
//    testing.expect(!lessThan(error!i64, 0  , err));
//}

test "generic.compare.lessThan([1]u8)" {
    testing.expect(lessThan([1]u8, "1", "2"));
    testing.expect(!lessThan([1]u8, "1", "1"));
    testing.expect(!lessThan([1]u8, "1", "0"));
}

test "generic.compare.lessThan(enum)" {
    const E = enum {
        A = 0,
        B = 1,
    };
    testing.expect(lessThan(E, E.A, E.B));
    testing.expect(!lessThan(E, E.B, E.B));
    testing.expect(!lessThan(E, E.B, E.A));
}

//TODO implement @typeInfo for global error set
//test "generic.compare.lessThan(error)" {
//    testing.expect( lessThan(error, error.A, error.B));
//    testing.expect(!lessThan(error, error.B, error.B));
//    testing.expect(!lessThan(error, error.B, error.A));
//}

//test "generic.compare.lessThan(null)" {
//    comptime testing.expect(!lessThan(@typeOf(null), null, null));
//}

test "generic.compare.lessThan(void)" {
    testing.expect(!lessThan(void, void{}, void{}));
}

pub fn equal(comptime T: type, a: T, b: T) bool {
    const info = @typeInfo(T);
    switch (info) {
        TypeId.Int,
        TypeId.Float,
        TypeId.ComptimeInt,
        TypeId.ComptimeFloat,
        TypeId.Enum,
        TypeId.ErrorSet,
        TypeId.Type,
        TypeId.Void,
        TypeId.Fn,
        TypeId.Null,
        TypeId.Bool,
        => return a == b,
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

        TypeId.Vector,
        TypeId.Undefined,
        TypeId.NoReturn,
        TypeId.BoundFn,
        TypeId.ArgTuple,
        TypeId.Opaque,
        TypeId.Promise,
        TypeId.Union,
        => {
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
    testing.expect(equal(i32, 1, 1));
    testing.expect(!equal(i32, 0, 1));
}

test "generic.compare.equal(comptime_int)" {
    testing.expect(equal(comptime_int, 1, 1));
    testing.expect(!equal(comptime_int, 0, 1));
}

test "generic.compare.equal(f32)" {
    testing.expect(equal(f32, 1, 1));
    testing.expect(!equal(f32, 0, 1));
}

test "generic.compare.equal(comptime_float)" {
    testing.expect(equal(comptime_float, 1.1, 1.1));
    testing.expect(!equal(comptime_float, 0.0, 1.1));
}

test "generic.compare.equal(bool)" {
    testing.expect(equal(bool, true, true));
    testing.expect(!equal(bool, true, false));
}

test "generic.compare.equal(type)" {
    comptime {
        testing.expect(equal(type, u8, u8));
        testing.expect(!equal(type, u16, u8));
    }
}

test "generic.compare.equal(enum)" {
    const E = enum {
        A,
        B,
    };
    testing.expect(equal(E, E.A, E.A));
    testing.expect(!equal(E, E.A, E.B));
}

//TODO implement @typeInfo for global error set
//test "generic.compare.equal(error)" {
//    testing.expect( equal(error, error.A, error.A));
//    testing.expect(!equal(error, error.A, error.B));
//}

test "generic.compare.equal(&i64)" {
    var a: i64 = undefined;
    var b: i64 = undefined;
    testing.expect(equal(*i64, &a, &a));
    testing.expect(!equal(*i64, &a, &b));
}

test "generic.compare.equal(?i64)" {
    var nul: ?i64 = null;
    testing.expect(equal(?i64, 1, 1));
    testing.expect(equal(?i64, nul, nul));
    testing.expect(!equal(?i64, 1, 0));
    testing.expect(!equal(?i64, 1, nul));
}

//TODO implement @typeInfo for global error set
//test "generic.compare.equal(%i32)" {
//    const a : error!i32 = 1;
//    const b : error!i32 = error.TestError1;
//    const errorEqual = equal(error!i32);
//    testing.expect( errorEqual(a, (error!i32)(1)));
//    testing.expect(!errorEqual(a, (error!i32)(0)));
//    testing.expect(!errorEqual(a, (error!i32)(error.TestError1)));
//    testing.expect( errorEqual(b, (error!i32)(error.TestError1)));
//    testing.expect(!errorEqual(b, (error!i32)(error.TestError2)));
//    testing.expect(!errorEqual(b, (error!i32)(0)));
//}

test "generic.compare.equal([1]u8)" {
    testing.expect(equal([1]u8, "1", "1"));
    testing.expect(!equal([1]u8, "1", "0"));
}

test "generic.compare.equal(null)" {
    comptime testing.expect(equal(@typeOf(null), null, null));
}

test "generic.compare.equal(void)" {
    testing.expect(equal(void, void{}, void{}));
}

test "generic.compare.equal(struct)" {
    const Struct = packed struct {
        a: u3,
        b: u3,
    };
    testing.expect(equal(Struct, Struct{ .a = 1, .b = 1 }, Struct{ .a = 1, .b = 1 }));
    testing.expect(!equal(Struct, Struct{ .a = 0, .b = 0 }, Struct{ .a = 1, .b = 1 }));
}

test "generic.compare.equal([]const u8)" {
    const a = "1";
    const b = "0";
    testing.expect(equal([]const u8, a, a));
    testing.expect(!equal([]const u8, a, b));
}

//unreachable
//[1]    6911 abort (core dumped)  zig test src/index.zig
//test "equal(fn()void)" {
//    const T = struct {
//        fn a() void {}
//        fn b() void {}
//    };
//
//    testing.expect( equal(fn()void, T.a, T.a));
//    testing.expect(!equal(fn()void, T.a, T.b));
//}
