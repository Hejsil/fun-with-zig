const std = @import("std");
const testing = std.testing;

const Opaque = @OpaqueType();

pub const Dynamic = struct {
    v: *const Opaque,
    Type: type,

    pub fn init(comptime Type: type, v: *const Type) Dynamic {
        return Dynamic{
            .v = @ptrCast(*const Opaque, v),
            .Type = Type,
        };
    }

    // TODO: Change to pass-by-value
    pub fn value(comptime dyn: *const Dynamic) dyn.Type {
        return @ptrCast(*const dyn.Type, dyn.v).*;
    }

    // TODO: Change to pass-by-value
    pub fn field(comptime dyn: *const Dynamic, comptime field_name: []const u8) (@typeOf(@field(dyn.Type{}, field_name))) {
        return @field(dyn.value(), field_name);
    }

    // TODO: Change to pass-by-value
    pub fn call(comptime dyn: *const Dynamic, args: ...) dyn.Type.ReturnType {
        return switch (args.len) {
            0 => dyn.value()(),
            1 => dyn.value()(args[0]),
            2 => dyn.value()(args[0], args[1]),
            3 => dyn.value()(args[0], args[1], args[2]),
            4 => dyn.value()(args[0], args[1], args[2], args[3]),
            5 => dyn.value()(args[0], args[1], args[2], args[3], args[4]),
            6 => dyn.value()(args[0], args[1], args[2], args[3], args[4], args[5]),
            7 => dyn.value()(args[0], args[1], args[2], args[3], args[4], args[5], args[6]),
            8 => dyn.value()(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7]),
            9 => dyn.value()(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8]),
            else => comptime unreachable,
        };
    }
};

test "Dynamic.value" {
    comptime {
        const dyn_int = Dynamic.init(u8, &u8(0));
        const dyn_float = Dynamic.init(f32, &f32(1.0));
        const dyn_string = Dynamic.init([]const u8, &([]const u8)("Hello World!"));

        // They are all the same static type, just like in dynamic typed languages
        testing.expectEqual(@typeOf(dyn_int), @typeOf(dyn_float));
        testing.expectEqual(@typeOf(dyn_int), @typeOf(dyn_string));
        testing.expectEqual(@typeOf(dyn_float), @typeOf(dyn_string));

        // Their values, are not the same dynamic type though.
        testing.expect(@typeOf(dyn_int.value()) != @typeOf(dyn_float.value()));
        testing.expect(@typeOf(dyn_int.value()) != @typeOf(dyn_string.value()));
        testing.expect(@typeOf(dyn_float.value()) != @typeOf(dyn_string.value()));

        testing.expectEqual(dyn_int.value(), 0);
        testing.expectEqual(dyn_float.value(), 1.0);
        testing.expectEqualSlices(u8, "Hello World!", dyn_string.value());
    }
}
