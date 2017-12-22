const debug = @import("std").debug;
const assert = debug.assert;
const equal = @import("comparer.zig").equal;

pub fn TestCase(comptime TIn: type, comptime TOut: type) -> type {
    return struct {
        const Self = this;

        in: TIn,
        out: TOut,

        pub fn init(in: &const TIn, out: &const TOut) -> Self {
            return Self {
                .in = *in,
                .out = *out
            };
        }

        pub fn runDefaultEql(self: &const Self, func: fn(&const TIn) -> TOut) {
            self.run(func, equal(TOut));
        }

        pub fn run(self: &const Self, func: fn(&const TIn) -> TOut, eql: fn(&const TOut, &const TOut) -> bool) {
            assert(eql(func(&self.in), &self.out));
        }
    };
}