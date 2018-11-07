pub const generic = @import("generic/index.zig");
pub const math = @import("math/index.zig");
pub const parser = @import("parser/index.zig");

pub const ascii = @import("ascii.zig");
pub const loop = @import("loop.zig");
pub const @"struct" = @import("struct.zig");
pub const @"union" = @import("union.zig");

test "" {
    _ = generic;
    _ = math;
    _ = parser;

    _ = ascii;
    _ = loop;
    _ = @"struct";
    _ = @"union";
}
