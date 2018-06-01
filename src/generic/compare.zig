const mem = @import("std").mem;
const assert = @import("std").debug.assert;
const TypeId = @import("builtin").TypeId;

/// Generates a lessThan function from ::T
pub fn lessThan(comptime T: type) fn (*const T, *const T) bool {
    const LessThanStruct = struct {
        fn lt(a_ptr: *const T, b_ptr: *const T) bool {
            const a = a_ptr.*;
            const b = b_ptr.*;
            const info = @typeInfo(T);
            switch (info) {
                TypeId.Int, TypeId.Float, TypeId.FloatLiteral, TypeId.IntLiteral => return a < b,
                TypeId.Bool => return u8(a) < u8(b),

                TypeId.Nullable => |nullable| {
                    const a_value = a ?? {
                        return if (b) |_| true else false;
                    };
                    const b_value = b ?? return false;

                    return lessThan(nullable.child)(a_value, b_value);
                },
                TypeId.ErrorUnion => |err_union| {
                    const a_value = a catch |a_err| {
                        if (b) |_| {
                            return true;
                        } else |b_err| {
                            return lessThan(err_union.error_set)(a_err, b_err);
                        }
                    };
                    const b_value = b catch return false;

                    return lessThan(err_union.payload)(a_value, b_value);
                },

                TypeId.Array => |arr| return mem.lessThan(arr.child, a, b),
                TypeId.Slice => |slice| return mem.lessThan(slice.child, a, b),
                TypeId.Enum => |e| return e.tag_type(a) < e.tag_type(b),
                TypeId.ErrorSet => return u32(a) < u32(b),
                TypeId.Pointer => return @ptrToInt(a) < @ptrToInt(b),

                TypeId.NullLiteral, TypeId.Void, TypeId.UndefinedLiteral => return false,

                TypeId.Type, TypeId.NoReturn, TypeId.Fn, TypeId.Namespace, TypeId.Block, TypeId.BoundFn, TypeId.ArgTuple, TypeId.Opaque, TypeId.Promise, TypeId.Struct, TypeId.Union => {
                    @compileError("Cannot get a default less than for " ++ @typeName(T));
                    return false;
                },
            }
        }
    };

    return LessThanStruct.lt;
}

test "generic.compare.Example: compare.lessThan" {
    const sort = @import("std").sort;

    var iarr = []i32{ 5, 3, 1, 2, 4 };
    var farr = []f32{ 5, 3, 1, 2, 4 };

    sort.sort(i32, iarr[0..], comptime lessThan(i32));
    sort.sort(f32, farr[0..], comptime lessThan(f32));

    assert(mem.eql(i32, iarr, []i32{ 1, 2, 3, 4, 5 }));
    assert(mem.eql(f32, farr, []f32{ 1, 2, 3, 4, 5 }));
}

test "generic.compare.lessThan(u64)" {
    const u64LessThan = lessThan(u64);
    assert(u64LessThan(1, 2));
    assert(!u64LessThan(1, 1));
    assert(!u64LessThan(1, 0));
}

test "generic.compare.lessThan(i64)" {
    const i64LessThan = lessThan(i64);
    assert(i64LessThan(0, 1));
    assert(!i64LessThan(0, 0));
    assert(!i64LessThan(0, -1));
}

// ZIG COMPILER BUG: zsh: segmentation fault (core dumped)  zig test main.zig
// https://github.com/zig-lang/zig/issues/623
//test "lessThan(@typeOf(0))" {
//    const ilitLessThan = lessThan(@typeOf(0));
//    assert( ilitLessThan(0,  1));
//    assert(!ilitLessThan(0,  0));
//    assert(!ilitLessThan(0, -1));
//}

test "generic.compare.lessThan(f64)" {
    const f64LessThan = lessThan(f64);
    assert(f64LessThan(0, 1));
    assert(!f64LessThan(0, 0));
    assert(!f64LessThan(0, -1));
}

// ZIG COMPILER BUG: zsh: segmentation fault (core dumped)  zig test main.zig
// https://github.com/zig-lang/zig/issues/623
//test "default(@typeOf(0.0))" {
//    const flitLessThan = lessThan(@typeOf(0.0));
//    assert( flitLessThan(0.0,  1.0));
//    assert(!flitLessThan(0.0,  0.0));
//    assert(!flitLessThan(0.0, -1.0));
//}

test "generic.compare.lessThan(bool)" {
    const boolLessThan = lessThan(bool);
    assert(boolLessThan(false, true));
    assert(!boolLessThan(true, true));
    assert(!boolLessThan(true, false));
}

test "generic.compare.lessThan(?i64)" {
    const nul: ?i64 = null;
    const nullableLessThan = lessThan(?i64);
    assert(nullableLessThan(0, 1));
    assert(!nullableLessThan(0, 0));
    assert(!nullableLessThan(0, -1));
    assert(nullableLessThan(nul, 0));
    assert(!nullableLessThan(nul, nul));
    assert(!nullableLessThan(0, nul));
}

//allocation failed
//[1]    5171 abort (core dumped)  zig test src/index.zig
//test "generic.compare.lessThan(error!i64)" {
//    const err : error!i64 = error.No;
//    const erruniLessThan = lessThan(error!i64);
//    assert( erruniLessThan(0,  1));
//    assert(!erruniLessThan(0,  0));
//    assert(!erruniLessThan(0, -1));
//    assert( erruniLessThan(err, 0  ));
//    assert(!erruniLessThan(err, err));
//    assert(!erruniLessThan(0  , err));
//}

test "generic.compare.lessThan([1]u8)" {
    const arrLessThan = lessThan([1]u8);
    assert(arrLessThan("1", "2"));
    assert(!arrLessThan("1", "1"));
    assert(!arrLessThan("1", "0"));
}

test "generic.compare.lessThan(enum)" {
    const E = enum {
        A = 0,
        B = 1,
    };
    const enumLessThan = lessThan(E);
    assert(enumLessThan(E.A, E.B));
    assert(!enumLessThan(E.B, E.B));
    assert(!enumLessThan(E.B, E.A));
}

//allocation failed
//[1]    5171 abort (core dumped)  zig test src/index.zig
//test "generic.compare.lessThan(error)" {
//    const errLessThan = lessThan(error);
//    assert( errLessThan(error.A, error.B));
//    assert(!errLessThan(error.B, error.B));
//    assert(!errLessThan(error.B, error.A));
//}

test "generic.compare.lessThan(&i64)" {
    var b: i64 = undefined;
    var a: i64 = undefined;
    const ptrLessThan = lessThan(*i64);
    assert(ptrLessThan(&a, &b) == (@ptrToInt(&a) < @ptrToInt(&b)));
    assert(ptrLessThan(&b, &b) == (@ptrToInt(&b) < @ptrToInt(&b)));
    assert(ptrLessThan(&b, &a) == (@ptrToInt(&b) < @ptrToInt(&a)));
}

test "generic.compare.lessThan(null)" {
    const ptrLessThan = lessThan(@typeOf(null));
    assert(!ptrLessThan(&null, &null));
}

test "generic.compare.lessThan(void)" {
    const ptrLessThan = lessThan(void);
    assert(!ptrLessThan(void{}, void{}));
}

test "generic.compare.lessThan(undefined)" {
    const ptrLessThan = lessThan(@typeOf(undefined));
    assert(!ptrLessThan(undefined, undefined));
}

test "generic.compare.lessThan([]const u8)" {
    const sliceLessThan = lessThan([]const u8);
    assert(sliceLessThan("1", "2"));
    assert(!sliceLessThan("1", "1"));
    assert(!sliceLessThan("1", "0"));
}

pub fn equal(comptime T: type) fn (*const T, *const T) bool {
    const EqualStruct = struct {
        fn eql(a_ptr: *const T, b_ptr: *const T) bool {
            const a = a_ptr.*;
            const b = b_ptr.*;
            const info = @typeInfo(T);
            switch (info) {
                TypeId.Int, TypeId.Float, TypeId.FloatLiteral, TypeId.IntLiteral, TypeId.Enum, TypeId.ErrorSet, TypeId.Pointer, TypeId.Type, TypeId.Void, TypeId.Fn, TypeId.NullLiteral, TypeId.Bool => return a == b,
                TypeId.UndefinedLiteral => return true,
                TypeId.Array, TypeId.Slice => {
                    if (a.len != b.len)
                        return false;

                    for (a) |_, i| {
                        if (!equal(T.Child)(a[i], b[i]))
                            return false;
                    }

                    return true;
                },
                TypeId.Nullable => |nullable| {
                    const a_value = a ?? {
                        return if (b) |_| false else true;
                    };
                    const b_value = b ?? return false;

                    return equal(nullable.child)(a_value, b_value);
                },
                TypeId.ErrorUnion => |err_union| {
                    const a_value = a catch |a_err| {
                        if (b) |_| {
                            return false;
                        } else |b_err| {
                            return equal(err_union.error_set)(a_err, b_err);
                        }
                    };
                    const b_value = b catch return false;

                    return equal(err_union.payload)(a_value, b_value);
                },
                TypeId.Struct => |struct_info| {
                    inline for (struct_info.fields) |field| {
                        if (!fieldsEql(field.name, a, b))
                            return false;
                    }

                    return true;
                },

                TypeId.NoReturn, TypeId.Namespace, TypeId.Block, TypeId.BoundFn, TypeId.ArgTuple, TypeId.Opaque, TypeId.Promise, TypeId.Union => {
                    @compileError("Cannot get a default equal for " ++ @typeName(T));
                    return false;
                },
            }
        }

        fn fieldsEql(comptime field: []const u8, a: *const T, b: *const T) bool {
            const af = @field(a, field);
            const bf = @field(b, field);
            return equal(@typeOf(af))(af, bf);
        }
    };

    return EqualStruct.eql;
}

test "generic.compare.equal(i32)" {
    const i32Equal = equal(i32);
    assert(i32Equal(1, 1));
    assert(!i32Equal(0, 1));
}

//test "equal(@typeOf(0))" {
//    const ilitEqual = equal(@typeOf(0));
//    assert( ilitEqual(1, 1));
//    assert(!ilitEqual(0, 1));
//}

test "generic.compare.equal(f32)" {
    const f32Equal = equal(f32);
    assert(f32Equal(1, 1));
    assert(!f32Equal(0, 1));
}

//test "equal(@typeOf(0.0))" {
//    const flitEqual = equal(@typeOf(0.0));
//    assert( flitEqual(1.1, 1.1));
//    assert(!flitEqual(0.0, 1.1));
//}

test "generic.compare.equal(bool)" {
    const boolEqual = equal(bool);
    assert(boolEqual(true, true));
    assert(!boolEqual(true, false));
}

// Require pointer reform
// src/generic/compare.zig:306:27: error: expected type '&const type', found 'type'
//        assert( typeEqual(u8, u8));
//test "generic.compare.equal(type)" {
//    comptime {
//        const typeEqual = equal(type);
//        assert( typeEqual(u8, u8));
//        assert(!typeEqual(u16, u8));
//    }
//}

test "generic.compare.equal(enum)" {
    const E = enum {
        A,
        B,
    };
    const enumEqual = equal(E);
    assert(enumEqual(E.A, E.A));
    assert(!enumEqual(E.A, E.B));
}

//allocation failed
//[1]    4686 abort (core dumped)  zig test src/index.zig
//test "generic.compare.equal(error)" {
//    const errorEqual = equal(error);
//    assert( errorEqual(error.A, error.A));
//    assert(!errorEqual(error.A, error.B));
//}

test "generic.compare.equal(&i64)" {
    var a: i64 = undefined;
    var b: i64 = undefined;
    const ptrEqual = equal(*i64);
    assert(ptrEqual(&a, &a));
    assert(!ptrEqual(&a, &b));
}

test "generic.compare.equal(?i64)" {
    var nul: ?i64 = null;
    const nullableEqual = equal(?i64);
    assert(nullableEqual(1, 1));
    assert(nullableEqual(nul, nul));
    assert(!nullableEqual(1, 0));
    assert(!nullableEqual(1, nul));
}

//allocation failed
//[1]    4686 abort (core dumped)  zig test src/index.zig
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
    const arrayEqual = equal([1]u8);
    assert(arrayEqual("1", "1"));
    assert(!arrayEqual("1", "0"));
}

test "generic.compare.equal(null)" {
    const nullEqual = equal(@typeOf(null));
    assert(nullEqual(&null, &null));
}

test "generic.compare.equal(void)" {
    const voidEqual = equal(void);
    assert(voidEqual(void{}, void{}));
}

test "generic.compare.equal(undefined)" {
    const undefEqual = equal(@typeOf(undefined));
    assert(undefEqual(undefined, undefined));
}

test "generic.compare.equal(struct)" {
    const Struct = packed struct {
        a: u3,
        b: u3,
    };
    const structEqual = equal(Struct);
    assert(structEqual(Struct{ .a = 1, .b = 1 }, Struct{ .a = 1, .b = 1 }));
    assert(!structEqual(Struct{ .a = 0, .b = 0 }, Struct{ .a = 1, .b = 1 }));
}

test "equal([]const u8)" {
    const sliceEqual = equal([]const u8);
    assert(sliceEqual("1", "1"));
    assert(!sliceEqual("1", "0"));
}

//unreachable
//[1]    6911 abort (core dumped)  zig test src/index.zig
//test "equal(fn()void)" {
//    const T = struct {
//        fn a() void {}
//        fn b() void {}
//    };
//
//    const fnEqual = equal(fn()void);
//    assert( fnEqual(T.a, T.a));
//    assert(!fnEqual(T.a, T.b));
//}
