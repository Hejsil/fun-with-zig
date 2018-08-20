pub const ascii = @import("ascii.zig");
pub const generic = @import("generic/index.zig");
pub const loop = @import("loop/index.zig");
pub const math = @import("math/index.zig");

test "" {
    _ = ascii;
    _ = generic;
    _ = loop;
    _ = math;
}
