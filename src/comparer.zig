const mem    = @import("std").mem;
const assert = @import("std").debug.assert;
const TypeId = @import("builtin").TypeId;

/// Get the default less than function for many standard types.
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
                    var a_not_null = *a ?? return true;
                    var b_not_null = *b ?? return false;

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