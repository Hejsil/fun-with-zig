pub const @"struct" = @import("struct.zig");
pub const @"union" = @import("union.zig");
pub const ascii = @import("ascii.zig");
pub const bits = @import("bits.zig");
pub const generic = @import("generic/index.zig");
pub const loop = @import("loop.zig");
pub const match = @import("match.zig");
pub const math = @import("math/index.zig");
pub const platform = @import("platform.zig");
pub const scan = @import("scan.zig");
pub const searcher = @import("searcher.zig");

test "" {
    _ = @"struct";
    _ = @"union";
    _ = ascii;
    _ = bits;
    _ = generic;
    _ = loop;
    _ = match;
    _ = math;
    _ = platform;
    _ = scan;
    _ = searcher;
}
