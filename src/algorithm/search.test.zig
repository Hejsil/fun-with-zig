use @import("search.zig");
const SliceIter = @import("../iterator.zig").SliceIter;
const debug = @import("std").debug;
const assert = debug.assert;

const Expected = enum { Greater, Equal, Lesser, Empty, None };

const AllAnyResult = struct {
    less: bool,
    equal: bool,
    greater: bool
};

const AllTest = struct { 
    values: []const i64, 
    allAre: Expected,

    fn init(values: []const i64, allAre: Expected) -> AllTest {
        return AllTest {
            .values = values,
            .allAre = allAre
        };
    } 
};

fn assertAllResult(expected: Expected, result: &const AllAnyResult) {
    switch (expected) {
        Expected.Empty => {
            assert(result.less);
            assert(result.equal);
            assert(result.greater);
        },
        Expected.None => {
            assert(!result.less);
            assert(!result.equal);
            assert(!result.greater);
        },
        Expected.Greater => {
            assert(!result.less);
            assert(!result.equal);
            assert( result.greater);
        },
        Expected.Equal => {
            assert(!result.less);
            assert( result.equal);
            assert(!result.greater);
        },
        Expected.Lesser => {
            assert( result.less);
            assert(!result.equal);
            assert(!result.greater);
        }
    }
}

fn isLessThan0(v: &const i64) -> bool { return *v < 0; }
fn isEqual0(v: &const i64) -> bool { return *v == 0; }
fn isGreaterThan0(v: &const i64) -> bool { return *v > 0; }


const allTests = []AllTest {
    AllTest.init([]i64{  },   Expected.Empty),
    AllTest.init([]i64{  1 }, Expected.Greater),
    AllTest.init([]i64{ -1 }, Expected.Lesser),
    AllTest.init([]i64{  0 }, Expected.Equal),
    AllTest.init([]i64{  1,  2,  3,  4 }, Expected.Greater),
    AllTest.init([]i64{ -1, -2, -3, -4 }, Expected.Lesser),
    AllTest.init([]i64{  0,  0,  0,  0 }, Expected.Equal),
    AllTest.init([]i64{ -1,  0,  1,  4 }, Expected.None)
};

test "algorithm.search.all" {
    for (allTests) |tst, i| {
        assertAllResult(tst.allAre,
            AllAnyResult {
                .less    = all(i64, &SliceIter(i64).init(tst.values).iter, isLessThan0),
                .equal   = all(i64, &SliceIter(i64).init(tst.values).iter, isEqual0),
                .greater = all(i64, &SliceIter(i64).init(tst.values).iter, isGreaterThan0)
            });
    }
}

test "algorithm.search.allWithContext" {
    const lessThan     = comptime @import("../comparer.zig").lessThan(i64);
    const equal        = comptime @import("../comparer.zig").equal(i64);
    const greaterThan  = comptime @import("../functional.zig").reverse(&const i64, bool, lessThan);

    for (allTests) |tst, i| {
        assertAllResult(tst.allAre,
            AllAnyResult {
                .less    = allC(i64, i64, &SliceIter(i64).init(tst.values).iter, 0, lessThan),
                .equal   = allC(i64, i64, &SliceIter(i64).init(tst.values).iter, 0, equal),
                .greater = allC(i64, i64, &SliceIter(i64).init(tst.values).iter, 0, greaterThan)
            });
    }
}




const AnyTest = struct { 
    values: []const i64, 
    result: AllAnyResult,

    fn init(values: []const i64, result: &const AllAnyResult) -> AnyTest {
        return AnyTest {
            .values = values,
            .result = *result
        };
    } 
};


const anyTests = []AnyTest {
    AnyTest.init([]i64{  }  ,             AllAnyResult { .less = false, .equal = false, .greater = false }),
    AnyTest.init([]i64{  1 },             AllAnyResult { .less = false, .equal = false, .greater = true  }),
    AnyTest.init([]i64{ -1 },             AllAnyResult { .less = true,  .equal = false, .greater = false }),
    AnyTest.init([]i64{  0 },             AllAnyResult { .less = false, .equal = true,  .greater = false }),
    AnyTest.init([]i64{  1,  2,  3,  4 }, AllAnyResult { .less = false, .equal = false, .greater = true  }),
    AnyTest.init([]i64{ -1, -2, -3, -4 }, AllAnyResult { .less = true,  .equal = false, .greater = false }),
    AnyTest.init([]i64{  0,  0,  0,  0 }, AllAnyResult { .less = false, .equal = true,  .greater = false }),
    AnyTest.init([]i64{ -1,  0,  1,  4 }, AllAnyResult { .less = true,  .equal = true,  .greater = true  })
};

test "algorithm.search.any" {
    for (anyTests) |tst, i| {
        assert(tst.result.less    == any(i64, &SliceIter(i64).init(tst.values).iter, isLessThan0));
        assert(tst.result.equal   == any(i64, &SliceIter(i64).init(tst.values).iter, isEqual0));
        assert(tst.result.greater == any(i64, &SliceIter(i64).init(tst.values).iter, isGreaterThan0));
    }

}

test "algorithm.search.anyWithContext" {
    const lessThan     = comptime @import("../comparer.zig").lessThan(i64);
    const equal        = comptime @import("../comparer.zig").equal(i64);
    const greaterThan  = comptime @import("../functional.zig").reverse(&const i64, bool, lessThan);

    for (anyTests) |tst, i| {
        assert(tst.result.less    == anyC(i64, i64, &SliceIter(i64).init(tst.values).iter, 0, lessThan));
        assert(tst.result.equal   == anyC(i64, i64, &SliceIter(i64).init(tst.values).iter, 0, equal));
        assert(tst.result.greater == anyC(i64, i64, &SliceIter(i64).init(tst.values).iter, 0, greaterThan));
    }
}