const mem    = @import("std").mem;
const assert = @import("std").debug.assert;
const TypeId = @import("builtin").TypeId;

/// Get the default less than function for a type.
/// NOTE: Not all types have a obviouse or useful default. These types give a comptime error.
pub fn lessThan(comptime T: type) fn(&const T, &const T) bool {
    const LessThanStruct = struct {
        fn lt(a: &const T, b: &const T) bool {
            switch (@typeId(T)) {
                TypeId.Int, TypeId.Float,
                TypeId.FloatLiteral, TypeId.IntLiteral => {
                    return *a < *b;
                },
                TypeId.Bool => {
                    return u8(*a) < u8(*b);
                },
                TypeId.Nullable => {
                    // Null is less than all none null values. Do we want this?
                    if (*a == null and *b == null) return false;
                    const a_not_null = *a ?? return true;
                    const b_not_null = *b ?? return false;

                    return lessThan(T.Child)(a_not_null, b_not_null);
                },
                TypeId.Array => {
                    return mem.lessThan(T.Child, *a, *b);
                },

                // These types have no obviouse or useful default order, so we don't provide
                // a default less than for them.
                // TypeId.Struct, TypeId.Enum, TypeId.Union, TypeId.ErrorUnion, TypeId.Error,
                // TypeId.NullLiteral, TypeId.Pointer
                else => {
                    @compileLog("Cannot get a default less than for ", T);
                    @compileError("Cannot get a default less than");
                    return false;
                }
            }
        }
    };

    return LessThanStruct.lt;
}

test "comparer.Example: comparer.lessThan" {
    const sort  = @import("std").sort;

    var iarr = []i32 { 5, 3, 1, 2, 4 };
    var farr = []f32 { 5, 3, 1, 2, 4 };

    sort.sort(i32, iarr[0..], comptime lessThan(i32));
    sort.sort(f32, farr[0..], comptime lessThan(f32));

    assert(mem.eql(i32, iarr, []i32 { 1, 2, 3, 4, 5 }));
    assert(mem.eql(f32, farr, []f32 { 1, 2, 3, 4, 5 }));
}

test "comparer.lessThan(u64)" {
    const u64LessThan = lessThan(u64);
    assert( u64LessThan(1, 2));
    assert(!u64LessThan(1, 1));
    assert(!u64LessThan(1, 0));
}

test "comparer.lessThan(i64)" {
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

test "comparer.lessThan(f64)" {
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

test "comparer.lessThan(bool)" {
    const boolLessThan = lessThan(bool);
    assert( boolLessThan(false, true ));
    assert(!boolLessThan(true , true ));
    assert(!boolLessThan(true , false));
}

test "comparer.lessThan(?i64)" {
    const nul : ?i64 = null;
    const nullableLessThan = lessThan(?i64);
    assert( nullableLessThan(0,  1));
    assert(!nullableLessThan(0,  0));
    assert(!nullableLessThan(0, -1));
    assert( nullableLessThan(nul, 0  ));
    assert(!nullableLessThan(nul, nul));
    assert(!nullableLessThan(0  , nul));
}

test "comparer.lessThan([1]u8)" {
    const arrLessThan = lessThan([1]u8);
    assert( arrLessThan("1", "2"));
    assert(!arrLessThan("1", "1"));
    assert(!arrLessThan("1", "0"));
}

// How do we check if type is a slice?
// test "comparer.lessThan([]const u8)" {
//     const sliceLessThan = lessThan([]const u8);
//     assert( sliceLessThan("1", "2"));
//     assert(!sliceLessThan("1", "1"));
//     assert(!sliceLessThan("1", "0"));
// }

// Should probably be in some other library or something
fn toBytes(comptime T: type, value: &const T) []const u8 {
    return ([]const u8)(value[0..1]);
}

test "comparer.toBytes" {
    const v : u32 = 0x12345678;
    // TODO: What about endianess
    assert(mem.eql(u8, toBytes(u32, v), []u8 { 0x78, 0x56, 0x34, 0x12 }));
}

fn isError(comptime T: type, value: &const %T) bool {
    return if (*value) |v| false else |err| true;
}

/// Get the default equal function for a type.
pub fn equal(comptime T: type) fn(&const T, &const T) bool {
    const EqualStruct = struct {
        fn eql(a: &const T, b: &const T) bool {
            switch (@typeId(T)) {
                TypeId.Int, TypeId.Float, TypeId.Bool,
                TypeId.FloatLiteral, TypeId.IntLiteral,
                TypeId.Error, TypeId.Pointer,
                TypeId.NullLiteral, TypeId.Type => {
                    return *a == *b;
                },
                TypeId.Void => {
                    // Do we give compiler error here, or??
                    return true;
                },
                TypeId.Array => {
                    // NOTE: mem.eql does not support struct equality, so we can't use it here.
                    for (*a) |item, index| {
                        if (!equal(T.Child)(item, (*b)[index])) return false;
                    }
                    return true;
                },
                TypeId.Struct, TypeId.Enum, TypeId.Union => {
                    return mem.eql(u8, toBytes(T, a), toBytes(T, b));
                },
                TypeId.ErrorUnion => {
                    const a_not_err = *a catch |err1| {
                        return if (*b) |_| false else |err2| err1 == err2;
                    };
                    const b_not_err = *b catch return false;

                    return equal(T.Child)(a_not_err, b_not_err);
                },
                TypeId.Nullable => {
                    // Equal operator might not be supported by child type, so we have
                    // to unwrap the pointers if they are both not null.
                    if (*a == null and *b == null) return true;
                    const a_not_null = *a ?? return false;
                    const b_not_null = *b ?? return false;

                    return equal(T.Child)(a_not_null, b_not_null);
                },
                else => {
                    @compileLog("Cannot get a default equal for ", T);
                    @compileError("Cannot get a default equal.");
                    return false;
                }
            }
        }
    };

    return EqualStruct.eql;
}

test "comparer.equal(i32)" {
    const i32Equal = equal(i32);
    assert( i32Equal(1, 1));
    assert(!i32Equal(0, 1));
}

//test "equal(@typeOf(0))" {
//    const ilitEqual = equal(@typeOf(0));
//    assert( ilitEqual(1, 1));
//    assert(!ilitEqual(0, 1));
//}

test "comparer.equal(f32)" {
    const f32Equal = equal(f32);
    assert( f32Equal(1, 1));
    assert(!f32Equal(0, 1));
}

//test "equal(@typeOf(0.0))" {
//    const flitEqual = equal(@typeOf(0.0));
//    assert( flitEqual(1.1, 1.1));
//    assert(!flitEqual(0.0, 1.1));
//}

test "comparer.equal(bool)" {
    const boolEqual = equal(bool);
    assert( boolEqual(true, true));
    assert(!boolEqual(true, false));
}

error TestError1;
error TestError2;
test "comparer.equal(error)" {
    const errorEqual = equal(error);
    assert( errorEqual(error.TestError1, error.TestError1));
    assert(!errorEqual(error.TestError2, error.TestError1));
}

test "comparer.equal(%i32)" {
    const a : %i32 = 1;
    const b : %i32 = error.TestError1;
    const errorEqual = equal(%i32);
    assert( errorEqual(a, (%i32)(1)));
    assert(!errorEqual(a, (%i32)(0)));
    assert(!errorEqual(a, (%i32)(error.TestError1)));
    assert( errorEqual(b, (%i32)(error.TestError1)));
    assert(!errorEqual(b, (%i32)(error.TestError2)));
    assert(!errorEqual(b, (%i32)(0)));
}

test "comparer.equal(&i32)" {
    var a : i32 = undefined;
    var b : i32 = undefined;
    const errorEqual = equal(&i32);
    assert( errorEqual(&&a, &&a));
    assert(!errorEqual(&&a, &&b));
}

test "comparer.equal([1]u8)" {
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

test "comparer.equal(struct)" {
    const Struct = struct { a: i64, b: f64 };
    const structEqual = equal(Struct);
    assert( structEqual(Struct{ .a = 1, .b = 1.1 }, Struct{ .a = 1, .b = 1.1 }));
    assert(!structEqual(Struct{ .a = 0, .b = 0.1 }, Struct{ .a = 1, .b = 1.1 }));
}

//TypeId.Enum,
//TypeId.Union,
//TypeId.Nullable
//TypeId.NullLiteral