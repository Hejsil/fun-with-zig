const equal = @import("comparer.zig").equal;

error TestFailed;

pub fn TestCase(comptime TIn: type, comptime TOut: type) type {
    return struct {
        const Self = this;

        in: TIn,
        out: TOut,

        pub fn init(in: &const TIn, out: &const TOut) Self {
            return Self {
                .in = *in,
                .out = *out
            };
        }

        pub fn runDefaultEql(self: &const Self, func: fn(&const TIn) %TOut) %void {
            return self.run(func, equal(TOut));
        }

        pub fn run(self: &const Self, func: fn(&const TIn) %TOut, eql: fn(&const TOut, &const TOut) bool) %void {
            if (!eql(try func(&self.in), &self.out)) {
                return error.TestFailed;
            }
        }
    };
}