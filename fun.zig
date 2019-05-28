pub const @"struct" = @import("src/struct.zig");
pub const @"union" = @import("src/union.zig");
pub const ascii = @import("src/ascii.zig");
pub const bits = @import("src/bits.zig");
pub const generic = @import("src/generic.zig");
pub const loop = @import("src/loop.zig");
pub const match = @import("src/match.zig");
pub const math = @import("src/math.zig");
pub const parser = @import("src/parser.zig");
pub const platform = @import("src/platform.zig");
pub const scan = @import("src/scan.zig");
pub const searcher = @import("src/searcher.zig");

test "fun-with-zig" {
    _ = @import("fun/comptime_dynamic_typing.zig");
    _ = @import("fun/functional.zig");
    _ = @import("fun/handle.zig");
    _ = @import("fun/interface.zig");
    _ = @import("fun/iterators.zig");
    _ = @import("fun/overloading.zig");
    //_ = @import("fun/reify.zig");

    _ = @"struct";
    _ = @"union";
    _ = ascii;
    _ = bits;
    _ = generic;
    _ = loop;
    _ = match;
    _ = math;
    _ = parser;
    _ = platform;
    _ = scan;
    _ = searcher;
}
