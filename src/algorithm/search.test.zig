const iter        = @import("../iterator.zig").SliceIter(i64).init;
const testing     = @import("../testing.zig");
const debug       = @import("std").debug;
const comparer    = @import("../comparer.zig");
const functional  = @import("../functional.zig");
const lessThan    = comptime comparer.lessThan(i64);
const equal       = comptime comparer.equal(i64);
const greaterThan = comptime @import("../functional.zig").reverse(&const i64, bool, lessThan);
const assert      = debug.assert;

use @import("search.zig");

fn isLessThan0(v: &const i64) -> bool { return *v < 0; }
fn isEqual0(v: &const i64) -> bool { return *v == 0; }
fn isGreaterThan0(v: &const i64) -> bool { return *v > 0; }

const Result = struct {
    less: bool,
    equal: bool,
    greater: bool,

    fn init(less: bool, eql: bool, greater: bool) -> Result {
        return Result {
            .less = less,
            .equal = eql,
            .greater = greater,
        };
    }
};

const AllAnyCase = testing.TestCase([]const i64, Result);
const allTests = []AllAnyCase {
    AllAnyCase.init([]i64{  },               Result.init(true , true , true )),
    AllAnyCase.init([]i64{  1 },             Result.init(false, false, true )),
    AllAnyCase.init([]i64{ -1 },             Result.init(true , false, false)),
    AllAnyCase.init([]i64{  0 },             Result.init(false, true , false)),
    AllAnyCase.init([]i64{  1,  2,  3,  4 }, Result.init(false, false, true )),
    AllAnyCase.init([]i64{ -1, -2, -3, -4 }, Result.init(true , false, false)),
    AllAnyCase.init([]i64{  0,  0,  0,  0 }, Result.init(false, true , false)),
    AllAnyCase.init([]i64{ -1,  0,  1,  4 }, Result.init(false, false, false))
};

fn runAllTest(in: &const []const i64) -> Result {
    return Result {
        .less    = all(i64, &iter(*in).iter, isLessThan0),
        .equal   = all(i64, &iter(*in).iter, isEqual0),
        .greater = all(i64, &iter(*in).iter, isGreaterThan0)
    };
}

test "algorithm.search.all" {
    for (allTests) |tst| {
        tst.runDefaultEql(runAllTest);
    }
}

fn runAllCTest(in: &const []const i64) -> Result {
    return Result {
        .less    = allC(i64, i64, &iter(*in).iter, 0, lessThan),
        .equal   = allC(i64, i64, &iter(*in).iter, 0, equal),
        .greater = allC(i64, i64, &iter(*in).iter, 0, greaterThan)
    };
}

test "algorithm.search.allC" {
    for (allTests) |tst| {
        tst.runDefaultEql(runAllCTest);
    }
}





const anyTests = []AllAnyCase {
    AllAnyCase.init([]i64{  },               Result.init(false, false, false)),
    AllAnyCase.init([]i64{  1 },             Result.init(false, false, true )),
    AllAnyCase.init([]i64{ -1 },             Result.init(true , false, false)),
    AllAnyCase.init([]i64{  0 },             Result.init(false, true , false)),
    AllAnyCase.init([]i64{  1,  2,  3,  4 }, Result.init(false, false, true )),
    AllAnyCase.init([]i64{ -1, -2, -3, -4 }, Result.init(true , false, false)),
    AllAnyCase.init([]i64{  0,  0,  0,  0 }, Result.init(false, true , false)),
    AllAnyCase.init([]i64{ -1,  0,  1,  4 }, Result.init(true , true , true ))
};

fn runAnyTest(in: &const []const i64) -> Result {
    return Result {
        .less    = any(i64, &iter(*in).iter, isLessThan0),
        .equal   = any(i64, &iter(*in).iter, isEqual0),
        .greater = any(i64, &iter(*in).iter, isGreaterThan0)
    };
}

test "algorithm.search.any" {
    for (anyTests) |tst| {
        tst.runDefaultEql(runAnyTest);
    }
}

fn runAnyCTest(in: &const []const i64) -> Result {
    return Result {
        .less    = anyC(i64, i64, &iter(*in).iter, 0, lessThan),
        .equal   = anyC(i64, i64, &iter(*in).iter, 0, equal),
        .greater = anyC(i64, i64, &iter(*in).iter, 0, greaterThan)
    };
}

test "algorithm.search.anyC" {
    for (anyTests) |tst, i| {
        tst.runDefaultEql(runAnyCTest);
    }
}




const FirstResult = struct {
    less:    ?i64,
    equal:   ?i64,
    greater: ?i64,

    fn init(less: ?i64, eql: ?i64, greater: ?i64) -> FirstResult {
        return FirstResult {
            .less = less,
            .equal = eql,
            .greater = greater,
        };
    }
};

const FirstCase = testing.TestCase([]const i64, FirstResult);
const firstTests = []FirstCase {
    FirstCase.init([]i64{  }  ,             FirstResult.init(null, null, null)),
    FirstCase.init([]i64{  1 },             FirstResult.init(null, null, 1   )),
    FirstCase.init([]i64{ -1 },             FirstResult.init(-1  , null, null)),
    FirstCase.init([]i64{  0 },             FirstResult.init(null, 0   , null)),
    FirstCase.init([]i64{  1,  2,  3,  4 }, FirstResult.init(null, null, 1   )),
    FirstCase.init([]i64{ -1, -2, -3, -4 }, FirstResult.init(-1  , null, null)),
    FirstCase.init([]i64{  0,  0,  0,  0 }, FirstResult.init(null, 0   , null)),
    FirstCase.init([]i64{ -1,  0,  1,  4 }, FirstResult.init(-1  , 0   , 1   ))
};

fn runFirstTest(in: &const []const i64) -> FirstResult {
    return FirstResult {
        .less    = first(i64, &iter(*in).iter, isLessThan0),
        .equal   = first(i64, &iter(*in).iter, isEqual0),
        .greater = first(i64, &iter(*in).iter, isGreaterThan0)
    };
}

test "algorithm.search.first" {
    for (firstTests) |tst| {
        tst.runDefaultEql(runFirstTest);
    }
}

fn runFirstCTest(in: &const []const i64) -> FirstResult {
    return FirstResult {
        .less    = firstC(i64, i64, &iter(*in).iter, 0, lessThan),
        .equal   = firstC(i64, i64, &iter(*in).iter, 0, equal),
        .greater = firstC(i64, i64, &iter(*in).iter, 0, greaterThan)
    };
}

test "algorithm.search.firstC" {
    for (firstTests) |tst, i| {
        tst.runDefaultEql(runFirstCTest);
    }
}
