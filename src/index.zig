const parser     = @import("parser.zig");
const functional = @import("functional.zig");
const comparer   = @import("comparer.zig");
const algorithm  = @import("algorithm/index.zig");

test "fun-with-zig" {
    _ = @import("parser.zig");
    _ = @import("parser.examples.zig");
    _ = @import("functional.zig");
    _ = @import("comparer.zig");
    _ = @import("iterator.zig");
    _ = @import("overloading.zig");
    _ = @import("namespaces/index.zig");
    _ = @import("algorithm/index.zig");
}
