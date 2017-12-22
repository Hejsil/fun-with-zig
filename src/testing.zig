const debug = @import("std").debug;
const assert = debug.assert;

pub fn TestCase(comptime TIn: type, comptime TOut) -> type {
    return struct {
        const Self = this;

        in: TIn,
        out: TOut,

        pub fn init(in: &const TIn, out: &const TOut) -> Self {
            return Self {
                .in = in,
                .out = out
            };
        }

        pub fn run(self: &const Self, func: fn(&const TIn) -> TOut, eql: fn(&const TOut, &const TOut) -> bool) {
            assert(eql(func(&self.in), &self.out));   
        }
    };
}