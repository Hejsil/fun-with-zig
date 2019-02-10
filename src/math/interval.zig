const std = @import("std");
const builtin = @import("builtin");

const math = std.math;
const mem = std.mem;
const debug = std.debug;
const testing = std.testing;

const min = @import("index.zig").min;
const max = @import("index.zig").max;

pub fn Interval(comptime T: type) type {
    const info = @typeInfo(T);
    debug.assert(info == builtin.TypeId.Int or
        info == builtin.TypeId.Float or
        info == builtin.TypeId.ComptimeInt or
        info == builtin.TypeId.ComptimeFloat);

    return struct {
        const Self = @This();

        min: T,
        max: T,

        pub fn fromSlice(nums: []const T) Self {
            return Self{
                .min = mem.min(T, nums),
                .max = mem.max(T, nums),
            };
        }

        pub fn add(a: Self, b: Self) Self {
            return Self{
                .min = a.min + b.min,
                .max = a.max + b.max,
            };
        }

        pub fn sub(a: Self, b: Self) Self {
            return Self{
                .min = a.min - b.max,
                .max = a.max - b.min,
            };
        }

        pub fn mul(a: Self, b: Self) Self {
            return fromSlice([]T{
                a.min * b.min,
                a.min * b.max,
                a.max * b.min,
                a.max * b.max,
            });
        }

        pub fn div(a: Self, b: Self) Self {
            debug.assert(b.min != 0 and b.max != 0);
            return fromSlice([]T{
                a.min / b.min,
                a.min / b.max,
                a.max / b.min,
                a.max / b.max,
            });
        }

        pub fn mod(a: Self, b: Self) Self {
            debug.assert(b.min != 0 and b.max != 0);
            return fromSlice([]T{
                a.min % b.min,
                a.min % b.max,
                a.max % b.min,
                a.max % b.max,
            });
        }

        pub fn shiftLeft(a: Self, b: Self) Self {
            return fromSlice([]T{
                a.min << b.min,
                a.min << b.max,
                a.max << b.min,
                a.max << b.max,
            });
        }

        pub fn shiftRight(a: Self, b: Self) Self {
            return fromSlice([]T{
                a.min >> b.min,
                a.min >> b.max,
                a.max >> b.min,
                a.max >> b.max,
            });
        }
    };
}
