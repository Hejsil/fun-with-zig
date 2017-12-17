const debug = @import("std").debug;
const assert = debug.assert;

pub fn all(comptime T: type, data: []const T, predicate: fn(&const T) -> bool) -> bool {    
    for (data) |*item| {
        if (!predicate(item)) return false;
    }

    return true;
}

pub fn allWithContext(comptime TData: type, comptime TContext: type, 
    data: []const TData, context: &const TContext,
    predicate: fn(&const TData, &const TContext) -> bool) -> bool {
    for (data) |*item| {
        if (!predicate(item, context)) return false;
    }

    return true;
}


const Expected = enum { Greater, Equal, Lesser, Empty, None };

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

const AllResult = struct {
    less: bool,
    equal: bool,
    greater: bool
};

fn assertAllResult(expected: Expected, result: &const AllResult) {
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

test "algorithm.search.all" {
    const tests = []AllTest {
        AllTest.init([]i64{  },   Expected.Empty),
        AllTest.init([]i64{  1 }, Expected.Greater),
        AllTest.init([]i64{ -1 }, Expected.Lesser),
        AllTest.init([]i64{  0 }, Expected.Equal),
        AllTest.init([]i64{  1,  2,  3,  4 }, Expected.Greater),
        AllTest.init([]i64{ -1, -2, -3, -4 }, Expected.Lesser),
        AllTest.init([]i64{  0,  0,  0,  0 }, Expected.Equal),
        AllTest.init([]i64{ -1,  0,  1,  4 }, Expected.None)
    };

    for (tests) |tst, i| {
        assertAllResult(tst.allAre,
            AllResult {
                .less    = all(i64, tst.values, isLessThan0),
                .equal   = all(i64, tst.values, isEqual0),
                .greater = all(i64, tst.values, isGreaterThan0)
            });
    }
}

test "algorithm.search.allWtihContext" {
    const lessThan     = comptime @import("../comparer.zig").lessThan(i64);
    const equal        = comptime @import("../comparer.zig").equal(i64);
    const greaterThan  = comptime @import("../functional.zig").reverse(&const i64, bool, lessThan);

    const tests = []AllTest {
        AllTest.init([]i64{  },   Expected.Empty),
        AllTest.init([]i64{  1 }, Expected.Greater),
        AllTest.init([]i64{ -1 }, Expected.Lesser),
        AllTest.init([]i64{  0 }, Expected.Equal),
        AllTest.init([]i64{  1,  2,  3,  4 }, Expected.Greater),
        AllTest.init([]i64{ -1, -2, -3, -4 }, Expected.Lesser),
        AllTest.init([]i64{  0,  0,  0,  0 }, Expected.Equal),
        AllTest.init([]i64{ -1,  0,  1,  4 }, Expected.None)
    };

    for (tests) |tst, i| {
        assertAllResult(tst.allAre,
            AllResult {
                .less    = allWithContext(i64, i64, tst.values, 0, lessThan),
                .equal   = allWithContext(i64, i64, tst.values, 0, equal),
                .greater = allWithContext(i64, i64, tst.values, 0, greaterThan)
            });
    }

}