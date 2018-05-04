const std = @import("std");
const debug = std.debug;

// TODO: When we have @reify and @reflect, we can just have an Interface type, that takes a comptime
//       vtable, and generates all the code below
pub fn Iterator(comptime T: type) type {
    const VTable = struct {
        const Self = this;

        next: fn([]u8) ?T,

        fn init(comptime It: type) Self {
            return Self {
                .next = struct {
                    fn next(d: &u8) ?T {
                        return It.next(@ptrCast(&T, d));
                    }
                }.next
            };
        }
    };

    return struct {
        const Self = this;

        data: &u8,
        vtable: &const VTable,

        pub fn init(data: var) Self {
            const Type = @typeOf(*data);
            return Self {
                .data = @ptrCast(&u8, data),
                .vtable = &comptime VTable.init(Type),
            };
        }

        fn next(it: &const Self) ?T {
            return it.vtable.next(it.data);
        }
    };
}

pub fn Once(comptime T: type) type {
    return struct {
        const Self = this;

        value: ?T,

        pub fn next(it: &Self) ?T {
            defer it.value = null;
            const res = it.value;
            return res;
        }
    };
}

pub fn Repeat(comptime T: type) type {
    return struct {
        const Self = this;

        value: T,

        pub fn next(it: &Self) ?T {
            return it.value;
        }
    };
}

pub fn takeIt(it: &const Iterator(u8)) ?u8 {
    return it.next();
}

test "iterator" {
    var once = Once(u8) { .value = 2 };
    var repeat = Repeat(u8) { .value = 4 };
    const once_it = Iterator(u8).init(&once);
    const repeat_it = Iterator(u8).init(&repeat);

    @breakpoint();
    debug.assert(??takeIt(once_it) == 2);
    debug.assert(  takeIt(once_it) == null);
    debug.assert(??takeIt(repeat_it) == 2);
    debug.assert(??takeIt(repeat_it) == 2);
}
