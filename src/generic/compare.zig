const mem    = @import("std").mem;
const assert = @import("std").debug.assert;
const TypeId = @import("builtin").TypeId;

/// Generates a lessThan function from ::T
pub fn lessThan(comptime T: type) fn(&const T, &const T) bool {
    const LessThanStruct = struct {
        fn lt(a_ptr: &const T, b_ptr: &const T) bool {
            const a = *a_ptr;
            const b = *b_ptr;
            const info = @typeInfo(T);
            switch (info) {
                TypeId.Int,
                TypeId.Float,
                TypeId.FloatLiteral,
                TypeId.IntLiteral => return a < b,
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
                TypeId.Enum => |e| return e.tag_type(a) < e.tag_type(b),
                TypeId.ErrorSet => return u32(a) < u32(b),
                TypeId.Pointer => return @ptrToInt(a) < @ptrToInt(b),

                TypeId.NullLiteral,
                TypeId.Void,
                TypeId.UndefinedLiteral => return false,

                TypeId.Type,
                TypeId.NoReturn,
                TypeId.Fn,
                TypeId.Namespace,
                TypeId.Block,
                TypeId.BoundFn,
                TypeId.ArgTuple,
                TypeId.Opaque,
                TypeId.Promise,
                TypeId.Struct,
                TypeId.Union => {
                    @compileError("Cannot get a default less than for " ++ @typeName(T));
                    return false;
                }
            }
        }
    };

    return LessThanStruct.lt;
}

test "generic.compare.Example: compare.lessThan" {
    const sort  = @import("std").sort;

    var iarr = []i32 { 5, 3, 1, 2, 4 };
    var farr = []f32 { 5, 3, 1, 2, 4 };

    sort.sort(i32, iarr[0..], comptime lessThan(i32));
    sort.sort(f32, farr[0..], comptime lessThan(f32));

    assert(mem.eql(i32, iarr, []i32 { 1, 2, 3, 4, 5 }));
    assert(mem.eql(f32, farr, []f32 { 1, 2, 3, 4, 5 }));
}

test "generic.compare.lessThan(u64)" {
    const u64LessThan = lessThan(u64);
    assert( u64LessThan(1, 2));
    assert(!u64LessThan(1, 1));
    assert(!u64LessThan(1, 0));
}

test "generic.compare.lessThan(i64)" {
    const i64LessThan = lessThan(i64);
    assert( i64LessThan(0,  1));
    assert(!i64LessThan(0,  0));
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
    assert( f64LessThan(0,  1));
    assert(!f64LessThan(0,  0));
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
    assert( boolLessThan(false, true ));
    assert(!boolLessThan(true , true ));
    assert(!boolLessThan(true , false));
}

test "generic.compare.lessThan(?i64)" {
    const nul : ?i64 = null;
    const nullableLessThan = lessThan(?i64);
    assert( nullableLessThan(0,  1));
    assert(!nullableLessThan(0,  0));
    assert(!nullableLessThan(0, -1));
    assert( nullableLessThan(nul, 0  ));
    assert(!nullableLessThan(nul, nul));
    assert(!nullableLessThan(0  , nul));
}

test "generic.compare.lessThan([1]u8)" {
    const arrLessThan = lessThan([1]u8);
    assert( arrLessThan("1", "2"));
    assert(!arrLessThan("1", "1"));
    assert(!arrLessThan("1", "0"));
}

// How do we check if type is a slice?
// test "generic.compare.lessThan([]const u8)" {
//     const sliceLessThan = lessThan([]const u8);
//     assert( sliceLessThan("1", "2"));
//     assert(!sliceLessThan("1", "1"));
//     assert(!sliceLessThan("1", "0"));
// }


pub fn equal(comptime T: type) fn(&const T, &const T) bool {
    const EqualStruct = struct {
        fn eql(a_ptr: &const T, b_ptr: &const T) bool {
            const a = *a_ptr;
            const b = *b_ptr;
            const info = @typeInfo(T);
            switch (info) {
                TypeId.Int,
                TypeId.Float,
                TypeId.FloatLiteral,
                TypeId.IntLiteral,
                TypeId.Enum,
                TypeId.ErrorSet,
                TypeId.Pointer,
                TypeId.Bool => return a == b,
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
                TypeId.Array => |arr| return mem.eql(arr.child, a, b),

                TypeId.NullLiteral,
                TypeId.Void,
                TypeId.UndefinedLiteral => return true,

                TypeId.Type,
                TypeId.NoReturn,
                TypeId.Fn,
                TypeId.Namespace,
                TypeId.Block,
                TypeId.BoundFn,
                TypeId.ArgTuple,
                TypeId.Opaque,
                TypeId.Promise,
                TypeId.Struct,
                TypeId.Union => {
                    @compileError("Cannot get a default equal for " ++ @typeName(T));
                    return false;
                }
            }
        }
    };

    return EqualStruct.eql;
}

test "generic.compare.equal(i32)" {
    const i32Equal = equal(i32);
    assert( i32Equal(1, 1));
    assert(!i32Equal(0, 1));
}

//test "equal(@typeOf(0))" {
//    const ilitEqual = equal(@typeOf(0));
//    assert( ilitEqual(1, 1));
//    assert(!ilitEqual(0, 1));
//}

test "generic.compare.equal(f32)" {
    const f32Equal = equal(f32);
    assert( f32Equal(1, 1));
    assert(!f32Equal(0, 1));
}

//test "equal(@typeOf(0.0))" {
//    const flitEqual = equal(@typeOf(0.0));
//    assert( flitEqual(1.1, 1.1));
//    assert(!flitEqual(0.0, 1.1));
//}

test "generic.compare.equal(bool)" {
    const boolEqual = equal(bool);
    assert( boolEqual(true, true));
    assert(!boolEqual(true, false));
}



//test "generic.compare.equal(error)" {
//    const errorEqual = equal(error);
//    assert( errorEqual(error.TestError1, error.TestError1));
//    assert(!errorEqual(error.TestError2, error.TestError1));
//}

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

test "generic.compare.equal(&i32)" {
    var a : i32 = undefined;
    var b : i32 = undefined;
    const errorEqual = equal(&i32);
    assert( errorEqual(&&a, &&a));
    assert(!errorEqual(&&a, &&b));
}

test "generic.compare.equal([1]u8)" {
    // We ensure that we are testing arrays with different memory locations
    var a : [1]u8 = undefined; a[0] = '1';
    const arrayEqual = equal([1]u8);
    assert( arrayEqual(a, "1"));
    assert(!arrayEqual(a, "0"));
}

// test "equal([]const u8)" {
//     // We ensure that we are testing slice with different memory locations,
//     // as slices are seen as TypeId.Struct right now, so we want this test
//     // to fail, while this is true.
//     var a = "1";
//     const sliceEqual = equal([]const u8);
//     assert( sliceEqual(a, "1"));
//     assert(!sliceEqual(a, "0"));
// }

//test "generic.compare.equal(struct)" {
//    const Struct = struct { a: i64, b: f64 };
//    const structEqual = equal(Struct);
//    assert( structEqual(Struct{ .a = 1, .b = 1.1 }, Struct{ .a = 1, .b = 1.1 }));
//    assert(!structEqual(Struct{ .a = 0, .b = 0.1 }, Struct{ .a = 1, .b = 1.1 }));
//}
