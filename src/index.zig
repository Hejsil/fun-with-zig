pub const generic = @import("generic/index.zig");
pub const safe = @import("safe/index.zig");

test "" {
    _ = generic;
    _ = safe;
}
