const parser     = @import("parser.zig");
const functional = @import("functional.zig");
const comparer   = @import("comparer.zig");
const algorithm  = @import("algorithm/index.zig");

test "fun-with-zig" {
    _ = @import("parser.zig");
    _ = @import("functional.zig");
    _ = @import("comparer.zig");
    _ = @import("iterator.zig");
    _ = @import("namespaces/namespaces.zig");
    _ = @import("algorithm/index.zig");
}