pub const string = @import("parser/string.zig");
pub const json = @import("parser/json.zig");
pub usingnamespace @import("parser/common.zig");

test "parser" {
    _ = string;
    _ = json;
}
