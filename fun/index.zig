const parser = @import("parser.zig");
const functional = @import("functional.zig");
const comparer = @import("comparer.zig");
const algorithm = @import("algorithm/index.zig");

test "fun-with-zig" {
    _ = @import("namespaces/index.zig");
    _ = @import("comptime_dynamic_typing.zig");
    _ = @import("functional.zig");
    _ = @import("interface.zig");
    _ = @import("iterators.zig");
    _ = @import("overloading.zig");
//    _ = @import("reify.zig");
}
