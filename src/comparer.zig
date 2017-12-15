const mem    = @import("std").mem;
const assert = @import("std").debug.assert;
const TypeId = @import("builtin").TypeId;

/// Get the default less than function for a type.
/// NOTE: Not all types have a obviouse or useful default. These types give a comptime error.
pub fn defaultLessThan(comptime T: type) -> fn(&const T, &const T) -> bool {
    const LessThanStruct = struct {
        fn lessThan(a: &const T, b: &const T) -> bool {
            switch (@typeId(T)) {
                TypeId.Int, TypeId.Float, 
                TypeId.FloatLiteral, TypeId.IntLiteral => {
                    return *a < *b
                },
                TypeId.Bool => {
                    return u8(*a) < u8(*b);
                },
                TypeId.Nullable => {
                    // Null is less than all none null values. Do we want this?
                    if (*a == null and *b == null) return false;
                    const a_not_null = *a ?? return true;
                    const b_not_null = *b ?? return false;

                    const lt = defaultLessThan(T.Child);
                    return lt(a_not_null, b_not_null);
                },
                // ZIG STANDARD LIBRARY BUG: std.mem doesn't compile:
                // std\mem.zig:6:21: error: no member named 'Cmp' in 'std\math\index.zig'
                // pub const Cmp = math.Cmp;
                // TypeId.Array => {
                //     return mem.cmp(T.Child, *a, *b) == mem.Cmp.Less;
                // },

                // These types have no obviouse or useful default order, so we don't provide 
                // a default less than for them.
                // TypeId.Struct, TypeId.Enum, TypeId.Union, TypeId.ErrorUnion, TypeId.Error, 
                // TypeId.NullLiteral, TypeId.Pointer
                else => {
                    @compileLog("Cannot get a default less than for ", T);
                    return false;
                }
            }
        }
    };

    return LessThanStruct.lessThan;
}

test "Example: defaultLessThan" {
    const sort  = @import("std").sort;

    var iarr = []i32 { 5, 3, 1, 2, 4 };
    var farr = []f32 { 5, 3, 1, 2, 4 };

    sort.sort(i32, iarr[0..], comptime defaultLessThan(i32));
    sort.sort(f32, farr[0..], comptime defaultLessThan(f32));

    assert(mem.eql(i32, iarr, []i32 { 1, 2, 3, 4, 5 }));
    assert(mem.eql(f32, farr, []f32 { 1, 2, 3, 4, 5 }));
}

test "defaultLessThan(u64)" {
    const u64LessThan = defaultLessThan(u64);
    assert( u64LessThan(1, 2));
    assert(!u64LessThan(1, 1));
    assert(!u64LessThan(1, 0));
}

test "defaultLessThan(i64)" {
    const i64LessThan = defaultLessThan(i64);
    assert( i64LessThan(0,  1));
    assert(!i64LessThan(0,  0));
    assert(!i64LessThan(0, -1));
}

// ZIG COMPILER BUG: zsh: segmentation fault (core dumped)  zig test main.zig
// https://github.com/zig-lang/zig/issues/623
//test "defaultLessThan(@typeOf(0))" {
//    const ilitLessThan = defaultLessThan(@typeOf(0));
//    assert( ilitLessThan(0,  1));
//    assert(!ilitLessThan(0,  0));
//    assert(!ilitLessThan(0, -1));
//}

test "defaultLessThan(f64)" {
    const f64LessThan = defaultLessThan(f64);
    assert( f64LessThan(0,  1));
    assert(!f64LessThan(0,  0));
    assert(!f64LessThan(0, -1));
}

// ZIG COMPILER BUG: zsh: segmentation fault (core dumped)  zig test main.zig
// https://github.com/zig-lang/zig/issues/623
//test "default(@typeOf(0.0))" {
//    const flitLessThan = defaultLessThan(@typeOf(0.0));
//    assert( flitLessThan(0.0,  1.0));
//    assert(!flitLessThan(0.0,  0.0));
//    assert(!flitLessThan(0.0, -1.0));
//}

test "defaultLessThan(bool)" {
    const boolLessThan = defaultLessThan(bool);
    assert( boolLessThan(false, true ));
    assert(!boolLessThan(true , true ));
    assert(!boolLessThan(true , false));
}
    
test "defaultLessThan(?i64)" {
    const nul : ?i64 = null;
    const nullableLessThan = defaultLessThan(?i64);
    assert( nullableLessThan(0,  1));
    assert(!nullableLessThan(0,  0));
    assert(!nullableLessThan(0, -1));
    assert( nullableLessThan(nul, 0  ));
    assert(!nullableLessThan(nul, nul));
    assert(!nullableLessThan(0  , nul));
}

// Se bug comment in defaultLessThan
// test "defaultLessThan([1]u8)" {
//     const arrLessThan = defaultLessThan([1]u8);
//     assert( arrLessThan("1", "2"));
//     assert(!arrLessThan("1", "1"));
//     assert(!arrLessThan("1", "0"));
// }

// How do we check if type is a slice?
// test "defaultLessThan([]const u8)" {
//     const sliceLessThan = defaultLessThan([]const u8);
//     assert( sliceLessThan("1", "2"));
//     assert(!sliceLessThan("1", "1"));
//     assert(!sliceLessThan("1", "0"));
// }

// Should probably be in some other library or something
fn toBytes(comptime T: type, value: &const T) -> []const u8 {
    return ([]const u8)(value[0..1]); 
}

test "toBytes" {
    const v : u32 = 0x12345678;
    // TODO: What about endianess
    assert(mem.eql(u8, toBytes(u32, v), []u8 { 0x78, 0x56, 0x34, 0x12 }));
}

fn isError(comptime T: type, value: &const %T) -> bool {
    return if (*value) |v| false else |err| true;
}

/// Get the default equal function for a type.
pub fn defaultEqual(comptime T: type) -> fn(&const T, &const T) -> bool {
    const EqualStruct = struct {
        fn equal(a: &const T, b: &const T) -> bool {
            switch (@typeId(T)) {
                TypeId.Int, TypeId.Float, TypeId.Bool,
                TypeId.FloatLiteral, TypeId.IntLiteral,
                TypeId.Error, TypeId.Pointer, 
                TypeId.NullLiteral, TypeId.Type => {
                    return *a == *b
                },
                TypeId.Void => {
                    // Do we give compiler error here, or??
                    return true;
                },
                TypeId.Array => {
                    const eq = defaultEqual(T.Child);

                    // NOTE: mem.eql does not support struct equality, so we can't use it here.
                    for (*a) |item, index| {
                        if (!eq(item, (*b)[index])) return false;
                    }
                    return true;
                },
                TypeId.Struct, TypeId.Enum, TypeId.Union => {
                    return mem.eql(u8, toBytes(T, a), toBytes(T, b));
                },
                TypeId.ErrorUnion => {
                    const eq = defaultEqual(T.Child);

                    const a_not_err = *a %% |err1| {
                        return if (*b) |_| false else |err2| err1 == err2;
                    };
                    const b_not_err = *b %% return false;

                    return eq(a_not_err, b_not_err);
                },
                TypeId.Nullable => {
                    // Equal operator might not be supported by child type, so we have
                    // to unwrap the pointers if they are both not null.
                    if (*a == null and *b == null) return true;
                    const a_not_null = *a ?? return false;
                    const b_not_null = *b ?? return false;

                    const eq = defaultEqual(T.Child);
                    return eq(a_not_null, b_not_null);
                },
                else => {
                    @compileLog("Cannot get a default equal for ", T);
                    return false;
                }
            }
        }
    };

    return EqualStruct.equal;
}

test "defaultEqual(i32)" {
    const i32Equal = defaultEqual(i32);
    assert( i32Equal(1, 1));
    assert(!i32Equal(0, 1));
}

//test "defaultEqual(@typeOf(0))" {
//    const ilitEqual = defaultEqual(@typeOf(0));
//    assert( ilitEqual(1, 1));
//    assert(!ilitEqual(0, 1));
//}

test "defaultEqual(f32)" {
    const f32Equal = defaultEqual(f32);
    assert( f32Equal(1, 1));
    assert(!f32Equal(0, 1));
}

//test "defaultEqual(@typeOf(0.0))" {
//    const flitEqual = defaultEqual(@typeOf(0.0));
//    assert( flitEqual(1.1, 1.1));
//    assert(!flitEqual(0.0, 1.1));
//}

test "defaultEqual(bool)" {
    const boolEqual = defaultEqual(bool);
    assert( boolEqual(true, true));
    assert(!boolEqual(true, false));
}

error TestError1;
error TestError2;
test "defaultEqual(error)" {
    const errorEqual = defaultEqual(error);
    assert( errorEqual(error.TestError1, error.TestError1));
    assert(!errorEqual(error.TestError2, error.TestError1));
}

test "defaultEqual(%i32)" {
    const a : %i32 = 1; 
    const b : %i32 = error.TestError1;
    const errorEqual = defaultEqual(%i32);
    assert( errorEqual(a, (%i32)(1)));
    assert(!errorEqual(a, (%i32)(0)));
    assert(!errorEqual(a, (%i32)(error.TestError1)));
    assert( errorEqual(b, (%i32)(error.TestError1)));
    assert(!errorEqual(b, (%i32)(error.TestError2)));
    assert(!errorEqual(b, (%i32)(0)));
}

test "defaultEqual(&i32)" {
    var a : i32 = undefined;
    var b : i32 = undefined;
    const errorEqual = defaultEqual(&i32);
    assert( errorEqual(&&a, &&a));
    assert(!errorEqual(&&a, &&b));
}

test "defaultEqual([1]u8)" {
    // We ensure that we are testing arrays with different memory locations
    var a : [1]u8 = undefined; a[0] = '1';
    const arrayEqual = defaultEqual([1]u8);
    assert( arrayEqual(a, "1"));
    assert(!arrayEqual(a, "0"));
}

// test "defaultEqual([]const u8)" {
//     // We ensure that we are testing slice with different memory locations,
//     // as slices are seen as TypeId.Struct right now, so we want this test
//     // to fail, while this is true.
//     var a = "1";
//     const sliceEqual = defaultEqual([]const u8);
//     assert( sliceEqual(a, "1"));
//     assert(!sliceEqual(a, "0"));
// }

test "defaultEqual(struct)" {
    const Struct = struct { a: i64, b: f64 };
    const structEqual = defaultEqual(Struct);
    assert( structEqual(Struct{ .a = 1, .b = 1.1 }, Struct{ .a = 1, .b = 1.1 }));
    assert(!structEqual(Struct{ .a = 0, .b = 0.1 }, Struct{ .a = 1, .b = 1.1 }));
}

//TypeId.Enum, 
//TypeId.Union,
//TypeId.Nullable
//TypeId.NullLiteral