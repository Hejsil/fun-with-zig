const std = @import("std");
const debug = std.debug;
const mem = std.mem;
const testing = std.testing;

// TODO: If we get functions with capture one day, then "comptime nextFn fn (&Context) ?Result" wont work, because then those
//       can't be used. We could store the function in the iterator. The iterator will then just grow a little in size every
//       time you construct iterators from other iterators.

/// A generic iterator which uses ::nextFn to iterate over a ::TContext.
pub fn Iterator(comptime TContext: type, comptime TResult: type, comptime nextFn: fn (*TContext) ?TResult) type {
    return struct {
        const Result = TResult;
        const Context = TContext;
        const Self = @This();

        context: Context,

        pub fn init(context: Context) Self {
            return Self{ .context = context };
        }

        pub fn next(it: *Self) ?Result {
            return nextFn(&it.context);
        }

        /// NOTE: append we can do with no allocations, because we can make a new iterator type
        ///       and store the last element in its context.
        pub fn append(it: Self, item: Result) void {
            comptime @panic("TODO: Implement append!");
        }

        pub fn concat(it: Self, other: var) ConcatIterator(@typeOf(other)) {
            const OtherIterator = @typeOf(other);
            return ConcatIterator(OtherIterator).init(IteratorPair(OtherIterator){ .it1 = it, .it2 = other });
        }

        pub fn intersect(it: Self, other: var) void {
            comptime @panic("TODO: Implement except!");
        }

        /// NOTE: prepend we can do with no allocations, because we can make a new iterator type
        ///       and store the last element in its context.
        pub fn prepend(it: Self, item: Result) void {
            comptime @panic("TODO: Implement append!");
        }

        pub fn select(it: Self, comptime SelectResult: type, comptime selector: fn (Result) SelectResult) SelectIterator(SelectResult, selector) {
            return SelectIterator(SelectResult, selector).init(it.context);
        }

        pub fn skip(it: Self, count: u64) Self {
            var res = it;
            var i = u64(0);
            while (i < count) : (i += 1) {
                _ = res.next() orelse return res;
            }

            return res;
        }

        pub fn take(it: Self, count: u64) TakeIterator() {
            return TakeIterator().init(TakeContext{ .it = it, .count = count });
        }

        pub fn where(it: Self, comptime predicate: fn (Result) bool) WhereIterator(predicate) {
            return WhereIterator(predicate).init(it.context);
        }

        pub fn zip(it: Self, other: var) ZipIterator(@typeOf(other)) {
            const OtherIterator = @typeOf(other);
            return ZipIterator(OtherIterator).init(IteratorPair(OtherIterator){ .it1 = it, .it2 = other });
        }

        fn IteratorPair(comptime OtherIterator: type) type {
            return struct {
                it1: Self,
                it2: OtherIterator,
            };
        }

        fn ConcatIterator(comptime OtherIterator: type) type {
            const OtherResult = @typeOf(OtherIterator.next).ReturnType.Child;

            return Iterator(IteratorPair(OtherIterator), Result, struct {
                fn whereNext(context: *IteratorPair(OtherIterator)) ?Result {
                    return context.it1.next() orelse {
                        return context.it2.next();
                    };
                }
            }.whereNext);
        }

        fn SelectIterator(comptime SelectResult: type, comptime selector: fn (Result) SelectResult) type {
            return Iterator(Context, SelectResult, struct {
                fn selectNext(context: *Context) ?SelectResult {
                    const item = nextFn(context) orelse return null;
                    return selector(item);
                }
            }.selectNext);
        }

        const TakeContext = struct {
            it: Self,
            count: u64,
        };

        fn TakeIterator() type {
            return Iterator(TakeContext, Result, struct {
                fn takeNext(context: *TakeContext) ?Result {
                    if (context.count == 0) return null;

                    context.count -= 1;
                    return context.it.next();
                }
            }.takeNext);
        }

        fn WhereIterator(comptime predicate: fn (Result) bool) type {
            return Iterator(Context, Result, struct {
                fn whereNext(context: *Context) ?Result {
                    while (nextFn(context)) |item| {
                        if (predicate(item)) return item;
                    }

                    return null;
                }
            }.whereNext);
        }

        fn ZipIterator(comptime OtherIterator: type) type {
            const OtherResult = @typeOf(OtherIterator.next).ReturnType.Child;
            const ZipPair = struct {
                first: Result,
                second: OtherResult,
            };

            return Iterator(IteratorPair(OtherIterator), ZipPair, struct {
                fn whereNext(context: *IteratorPair(OtherIterator)) ?ZipPair {
                    const first = context.it1.next() orelse return null;
                    const second = context.it2.next() orelse return null;
                    return ZipPair{ .first = first, .second = second };
                }
            }.whereNext);
        }
    };
}

pub fn SliceIterator(comptime T: type) type {
    const NextFn = struct {
        fn next(context: *[]const T) ?T {
            if (context.len != 0) {
                defer context.* = (context.*)[1..];
                return (context.*)[0];
            }

            return null;
        }
    };

    return Iterator([]const T, T, NextFn.next);
}

pub fn SliceMutableIterator(comptime T: type) type {
    const NextFn = struct {
        fn next(context: *[]T) ?*T {
            if (context.len != 0) {
                defer context.* = (context.*)[1..];
                return &(context.*)[0];
            }

            return null;
        }
    };

    return Iterator([]T, *T, NextFn.next);
}

fn RangeIterator(comptime T: type) type {
    const RangeContext = struct {
        current: T,
        count: T,
        step: T,
    };
    const NextFn = struct {
        fn next(context: *RangeContext) ?T {
            if (context.count == 0) return null;
            defer context.count -= 1;
            defer context.current += context.step;
            return context.current;
        }
    };

    return Iterator(RangeContext, T, NextFn.next);
}

pub fn range(comptime T: type, start: T, count: T, step: T) RangeIterator(T) {
    const Context = RangeIterator(T).Context;
    return RangeIterator(T).init(Context{ .current = start, .count = count, .step = step });
}

fn RepeatIterator(comptime T: type) type {
    const NextFn = struct {
        fn next(context: *T) ?T {
            return context.*;
        }
    };

    return Iterator(T, T, NextFn.next);
}

pub fn repeat(comptime T: type, v: T) RepeatIterator(T) {
    return RepeatIterator(T).init(v);
}

fn EmptyIterator(comptime T: type) type {
    const NextFn = struct {
        fn next(context: *u8) ?T {
            return null;
        }
    };

    // TODO: The context can't be "void" because of https://github.com/zig-lang/zig/issues/838
    return Iterator(u8, T, NextFn.next);
}

pub fn empty(comptime T: type) EmptyIterator(T) {
    return EmptyIterator(T).init(0);
}

pub fn aggregate(it: var, func: fn (@typeOf(it).Result, @typeOf(it).Result) @typeOf(it).Result) ?@typeOf(it).Result {
    return aggregateAcc(it, it.next() orelse return null, @typeOf(it.*).Result, func);
}

pub fn aggregateAcc(it: var, acc: var, func: fn (@typeOf(acc), @typeOf(it).Result) @typeOf(acc)) ?@typeOf(acc) {
    var _it = it;
    var result = acc;
    while (_it.next()) |item| {
        result = func(result, item);
    }

    return result;
}

pub fn all(it: var, predicate: fn (@typeOf(it).Result) bool) bool {
    var _it = it;
    while (_it.next()) |item| {
        if (!predicate(item)) return false;
    }

    return true;
}

pub fn any(it: var, predicate: fn (@typeOf(it).Result) bool) bool {
    var _it = it;
    while (_it.next()) |item| {
        if (predicate(item)) return true;
    }

    return false;
}

pub fn countIf(it: var, predicate: fn (@typeOf(it).Result) bool) u64 {
    var _it = it;
    var res = u64(0);
    while (_it.next()) |item| {
        if (predicate(item)) res += 1;
    }

    return res;
}

test "iterators.SliceIterator" {
    const data = "abacad";
    var it = SliceIterator(u8).init(data);

    var i = usize(0);
    while (it.next()) |item| : (i += 1) {
        testing.expectEqual(data[i], item);
    }

    testing.expectEqual(data.len, i);
}

test "iterators.SliceMutableIterator" {
    var data = "abacac";
    const res = "bcbdbd";
    var it = SliceMutableIterator(u8).init(data[0..]);

    while (it.next()) |item| {
        item.* += 1;
    }

    testing.expectEqualSlices(u8, data, res);
}

test "iterators.range" {
    const res = "abcd";
    var it = range(u8, 'a', 4, 1);

    var i = usize(0);
    while (it.next()) |item| : (i += 1) {
        testing.expectEqual(res[i], item);
    }

    testing.expectEqual(res.len, i);
}

test "iterators.repeat" {
    var it = repeat(u64, 3);

    var i = usize(0);
    while (it.next()) |item| : (i += 1) {
        testing.expectEqual(u64(3), item);
        if (i == 10) break;
    }
}

test "iterators.empty" {
    var it = empty(u8);
    var i = usize(0);
    while (it.next()) |item| : (i += 1) {
        testing.expect(false);
    }

    testing.expectEqual(usize(0), i);
}

test "iterators.aggregateAcc" {
    const data = "abacad";
    const countA = struct {
        fn f(acc: u64, char: u8) u64 {
            return acc + @boolToInt(char == 'a');
        }
    }.f;

    testing.expectEqual(u64(3), aggregateAcc(SliceIterator(u8).init(data), u64(0), countA).?);
}

test "iterators.all" {
    const data1 = "aaaa";
    const data2 = "abaa";
    const isA = struct {
        fn f(char: u8) bool {
            return char == 'a';
        }
    }.f;

    testing.expect(all(SliceIterator(u8).init(data1), isA));
    testing.expect(!all(SliceIterator(u8).init(data2), isA));
}

test "iterators.any" {
    const data1 = "bbbb";
    const data2 = "bbab";
    const isA = struct {
        fn f(char: u8) bool {
            return char == 'a';
        }
    }.f;

    testing.expect(!any(SliceIterator(u8).init(data1), isA));
    testing.expect(any(SliceIterator(u8).init(data2), isA));
}

test "iterators.countIf" {
    const data = "abab";
    const isA = struct {
        fn f(char: u8) bool {
            return char == 'a';
        }
    }.f;

    testing.expectEqual(usize(2), countIf(SliceIterator(u8).init(data), isA));
}

test "iterators.SliceIterator" {
    const data = "abc";

    var it = SliceIterator(u8).init(data);
    var i: usize = 0;
    while (it.next()) |item| : (i += 1) {
        testing.expectEqual(data[i], item);
    }

    testing.expectEqual(data.len, i);
}

test "iterators.append: TODO" {}

test "iterators.concat" {
    const data1 = "abc";
    const data2 = "defg";

    const it1 = SliceIterator(u8).init(data1);
    const it2 = SliceIterator(u8).init(data2);
    var concatted = it1.concat(it2);

    var i: usize = 0;
    while (concatted.next()) |item| : (i += 1) {
        if (i < data1.len)
            testing.expectEqual(data1[i], item)
        else
            testing.expectEqual(data2[i - data1.len], item);
    }

    testing.expectEqual(data1.len + data2.len, i);
}

test "iterators.except: TODO" {}

test "iterators.intersect: TODO" {}

test "iterators.prepend: TODO" {}

test "iterators.select" {
    const data = []f64{ 1.5, 2.5, 3.5 };
    const toI64 = struct {
        fn f(i: f64) i64 {
            return @floatToInt(i64, i);
        }
    }.f;

    var it = SliceIterator(f64).init(data).select(i64, toI64);

    var i: usize = 0;
    while (it.next()) |item| : (i += 1) {
        testing.expectEqual(@floatToInt(i64, data[i]), item);
    }

    testing.expectEqual(data.len, i);
}

test "iterators.skip" {
    const data = "abcd";
    const res = "cd";

    var it = SliceIterator(u8).init(data).skip(2);

    var i: usize = 0;
    while (it.next()) |item| : (i += 1) {
        testing.expectEqual(res[i], item);
    }

    testing.expectEqual(res.len, i);
}

test "iterators.skipWhile: TODO" {}

test "iterators.take" {
    const data = "abcd";
    const res = "ab";

    var it = SliceIterator(u8).init(data).take(2);

    var i: usize = 0;
    while (it.next()) |item| : (i += 1) {
        testing.expectEqual(res[i], item);
    }

    testing.expectEqual(res.len, i);
}

test "iterators.takeWhile: TODO" {}

test "iterators.where" {
    const data = "abc";
    const res = "ac";
    const isB = struct {
        fn f(i: u8) bool {
            return i != 'b';
        }
    }.f;

    var it = SliceIterator(u8).init(data).where(isB);

    var i: usize = 0;
    while (it.next()) |item| : (i += 1) {
        testing.expectEqual(res[i], item);
    }

    testing.expectEqual(res.len, i);
}

test "iterators.zip" {
    const data1 = "abc";
    const data2 = "defg";

    const it1 = SliceIterator(u8).init(data1);
    const it2 = SliceIterator(u8).init(data2);
    var zipped = it1.zip(it2);

    var i: usize = 0;
    while (zipped.next()) |item| : (i += 1) {
        testing.expectEqual(data1[i], item.first);
        testing.expectEqual(data2[i], item.second);
    }

    testing.expectEqual(data1.len, i);
}
