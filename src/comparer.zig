const mem    = @import("std").mem;
const assert = @import("std").debug.assert;
const TypeId = @import("builtin").TypeId;

pub const Cmp = @import("std").math.Cmp;

/// Get the default comparer function for many standard types.
pub fn defaultComparerForType(comptime T: type) -> fn(&const T, &const T) -> Cmp {
    const Comparer = struct {
        fn compare(a: &const T, b: &const T) -> Cmp {
            switch (@typeId(T)) {
                TypeId.Int, TypeId.Float, 
                TypeId.FloatLiteral, TypeId.IntLiteral => {
                    if (*a < *b) return Cmp.Less;
                    if (*a > *b) return Cmp.Greater;
                    return Cmp.Equal;
                },
                TypeId.Pointer => {
                    const cmp = defaultComparerForType(usize);
                    return cmp(@ptrToInt(*a), @ptrToInt(*b));
                },
                TypeId.Bool => {
                    const cmp = defaultComparerForType(u8);
                    return cmp(u8(*a), u8(*b));
                },
                TypeId.Nullable => {
                    // Null is less that all none null values. Do we want this?
                    if (*a == null and *b == null) return Cmp.Equal;
                    var a_not_null = *a ?? return Cmp.Less;
                    var b_not_null = *b ?? return Cmp.Greater;

                    const cmp = defaultComparerForType(T.Child);
                    return cmp(a_not_null, b_not_null);
                },
                TypeId.NullLiteral => {
                    return Cmp.Equal;
                },
                TypeId.Array => {
                    return mem.cmp(T.Child, *a, *b);
                },
                TypeId.Error => {
                    const ValueType = @IntType(false, @sizeOf(T) * 8);
                    const cmp = defaultComparerForType(ValueType);
                    return cmp(ValueType(*a), ValueType(*b));
                },
                // TODO:
                // When we have better reflection in Zig, then comparing structs is probably a
                // good idea. For now, we have to compare the memory of the structs, which can
                // give different results based on platform/optimization.
                //TypeId.Struct, TypeId.Enum, TypeId.Union, TypeId.ErrorUnion => {
                //    @compileLog("T: ", T, @typeId(T));
                //    return mem.cmp(u8, ([]const u8)(a[0..1]), ([]const u8)(b[0..1]));
                //},
                else => {
                    @compileLog("Cannot get a default comparer for ", T);
                    return Cmp.Equal;
                }
            }
        }
    };

    return Comparer.compare;
}

test "Example: defaultComparerForType" {
    const debug = @import("std").debug;
    const sort  = @import("std").sort;

    var iarr = []i32 { 5, 3, 1, 2, 4 };
    var farr = []f32 { 5, 3, 1, 2, 4 };

    // Idk why "comptime" is needed
    // ZIG STD LIBRARY BUG: sort.sort does not sort this example correctly
    sort.sort_stable(i32, iarr[0..], comptime defaultComparerForType(i32));
    sort.sort_stable(f32, farr[0..], comptime defaultComparerForType(f32));

    debug.assert(mem.eql(i32, iarr, []i32 { 1, 2, 3, 4, 5 }));
    debug.assert(mem.eql(f32, farr, []f32 { 1, 2, 3, 4, 5 }));
}

test "defaultComparerForType(u64)" {
    const u64c = defaultComparerForType(u64);
    assert(u64c(1, 2) == Cmp.Less);
    assert(u64c(1, 1) == Cmp.Equal);
    assert(u64c(1, 0) == Cmp.Greater);
}

test "defaultComparerForType(i64)" {
    const i64c = defaultComparerForType(i64);
    assert(i64c(0,  1) == Cmp.Less);
    assert(i64c(0,  0) == Cmp.Equal);
    assert(i64c(0, -1) == Cmp.Greater);
}

// ZIG COMPILER BUG: zsh: segmentation fault (core dumped)  zig test main.zig
//test "defaultComparerForType(@typeOf(0))" {
//    const ilitc = defaultComparerForType(@typeOf(0));
//    assert(ilitc(0,  1) == Cmp.Less);
//    assert(ilitc(0,  0) == Cmp.Equal);
//    assert(ilitc(0, -1) == Cmp.Greater);
//}

test "defaultComparerForType(f64)" {
    const if64c = defaultComparerForType(f64);
    assert(if64c(0,  1) == Cmp.Less);
    assert(if64c(0,  0) == Cmp.Equal);
    assert(if64c(0, -1) == Cmp.Greater);
}

// ZIG COMPILER BUG: zsh: segmentation fault (core dumped)  zig test main.zig
//test "defaultComparerForType(@typeOf(0.0))" {
//    const flitc = defaultComparerForType(@typeOf(0.0));
//    assert(flitc(0.0,  1.0) == Cmp.Less);
//    assert(flitc(0.0,  0.0) == Cmp.Equal);
//    assert(flitc(0.0, -1.0) == Cmp.Greater);
//}

error TestError1;
error TestError2;
test "defaultComparerForType(error)" {
    const errc = defaultComparerForType(error);
    assert(errc(error.TestError1, error.TestError1) == Cmp.Equal);

    // We don't really know what value they get assigned, so we can't assert for Greater or Less
    _ = errc(error.TestError1, error.TestError2);
}

test "defaultComparerForType(&i32)" {
    var a : i32 = undefined;
    var b : i32 = undefined;
    const ptrc = defaultComparerForType(&i32);
    assert(ptrc(&a, &a) == Cmp.Equal);

    // We don't really know what value they get assigned, so we can't assert for Greater or Less
    _ = ptrc(&a, &b); 
}

test "defaultComparerForType(bool)" {
    const boolc = defaultComparerForType(bool);
    assert(boolc(false, true ) == Cmp.Less);
    assert(boolc(true , true ) == Cmp.Equal);
    assert(boolc(true , false) == Cmp.Greater);
}
    
test "defaultComparerForType(?i64)" {
    const nul : ?i64 = null;
    const nullablec = defaultComparerForType(?i64);
    assert(nullablec(0,  1) == Cmp.Less);
    assert(nullablec(0,  0) == Cmp.Equal);
    assert(nullablec(0, -1) == Cmp.Greater);
    assert(nullablec(nul, 0  ) == Cmp.Less);
    assert(nullablec(nul, nul) == Cmp.Equal);
    assert(nullablec(0  , nul) == Cmp.Greater);
}

test "defaultComparerForType(@typeOf(null))" {
    const nullc = defaultComparerForType(@typeOf(null));
    assert(nullc(&null, &null) == Cmp.Equal);
}

test "defaultComparerForType([1]u8)" {
    const arrc = defaultComparerForType([1]u8);
    assert(arrc("1", "2") == Cmp.Less);
    assert(arrc("1", "1") == Cmp.Equal);
    assert(arrc("1", "0") == Cmp.Greater);
}

// How do we check if type is a slice?
//test "defaultComparerForType([]const u8)" {
//    const arrc = defaultComparerForType([]const u8);
//    assert(arrc("1"[0..], "2"[0..]) == Cmp.Less);
//    // assert(arrc("1"[0..], "1"[0..]) == Cmp.Equal);
//    // assert(arrc("1"[0..], "0"[0..]) == Cmp.Greater);
//}


/// Reverses the input compare function.
pub fn reverseComparer(comptime T: type, comptime comparer: fn(&const T, &const T) -> Cmp) -> fn(&const T, &const T) -> Cmp {
    const Comparer = struct {
        fn compare(a: &const T, b: &const T) -> Cmp {
            return comparer(b, a);
        }
    };

    return Comparer.compare;
}

test "Example: reverseComparer" {
    const debug = @import("std").debug;
    const sort  = @import("std").sort;

    var iarr = []i32 { 5, 3, 1, 2, 4 };
    var farr = []f32 { 5, 3, 1, 2, 4 };

    // Idk why "comptime" is needed
    // ZIG STD LIBRARY BUG: sort.sort does not sort this example correctly
    sort.sort_stable(i32, iarr[0..], comptime reverseComparer(i32, defaultComparerForType(i32)));
    sort.sort_stable(f32, farr[0..], comptime reverseComparer(f32, defaultComparerForType(f32)));

    debug.assert(mem.eql(i32, iarr, []i32 { 5, 4, 3, 2, 1 }));
    debug.assert(mem.eql(f32, farr, []f32 { 5, 4, 3, 2, 1 }));
}