const debug = @import("std").debug;
const assert = debug.assert;

pub fn Iterator(comptime T: type) type {
    return struct {
        const Self = this;

        nextFn: fn(&Self) ?T,

        pub fn init(nextFn: fn(&Self) ?T) Self {
            return Self { .nextFn = nextFn };
        }

        pub fn next(iter: &Self) ?T {
            return iter.nextFn(iter);
        }
    };
}

pub fn SliceIter(comptime T: type) type {
    return struct {
        const Self = this;

        iter: Iterator(&const T),
        slice: []const T,
        index: usize,

        pub fn init(slice: []const T) Self {
            return Self {
                .iter = Iterator(&const T).init(internalNext),
                .slice = slice,
                .index = 0
            };
        }

        pub fn next(iter: &Self) ?&const T {
            return iter.iter.next();
        }

        fn internalNext(iter: &Iterator(&const T)) ?&const T {
            var sliceIter = @fieldParentPtr(SliceIter(T), "iter", iter);

            if (sliceIter.index < sliceIter.slice.len) {
                const result = &sliceIter.slice[sliceIter.index];
                sliceIter.index += 1;
                return result;
            } else {
                return null;
            }
        }
    };
}

test "iterator.SliceIter" {
    const data = []i64 { 1, 2, 3, 2, 1, 5, 7};

    var iter = SliceIter(i64).init(data);
    var i : usize = 0;
    while (iter.next()) |item| : (i += 1) {
        assert(*item == data[i]);
    }

    assert(i == data.len);
}
