const std = @import("std");
const debug = std.debug;

pub const Dynamic = struct {
    v: &const void,
    Type: type,

    fn TakePtr(comptime T: type) type { return &T; }

    pub fn init(comptime Type: type, v: &const Type) Dynamic {
        return Dynamic {
            .v = @ptrCast(&const void, v),
            .Type = Type,
        };
    }

    pub fn value(comptime dyn: Dynamic) dyn.Type {
        return @ptrCast(TakePtr(dyn.Type), @alignCast(@alignOf(dyn.Type), dyn.v));
    }

    pub fn field(comptime dyn: Dynamic, comptime field_name: []const u8) (@typeOf(@field(dyn.Type{}, field_name))) {
        return @field(dyn.value(), field_name);
    }

    pub fn call(comptime dyn: Dynamic, args: ...) dyn.Type.ReturnType {
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
        const dyn_int = Dynamic.init(u8, 0);
        const dyn_float = Dynamic.init(f32, 1.0);
        const dyn_string = Dynamic.init([]const u8, "Hello World!");

        // They are all the same static type, just like in dynamic typed languages
        debug.assert(@typeOf(dyn_int)   == @typeOf(dyn_float));
        debug.assert(@typeOf(dyn_int)   == @typeOf(dyn_string));
        debug.assert(@typeOf(dyn_float) == @typeOf(dyn_string));

        // zig: /home/hejsil/Documents/zig/src/analyze.cpp:449: TypeTableEntry* get_pointer_to_type_extra(CodeGen*, TypeTableEntry*, bool, bool, uint32_t, uint32_t, uint32_t):Assertion `byte_alignment == 0' failed.
        // Their values, are not the same dynamic type though.
        //debug.assert(@typeOf(dyn_int.value())   != @typeOf(dyn_float.value()));
        //debug.assert(@typeOf(dyn_int.value())   != @typeOf(dyn_string.value()));
        //debug.assert(@typeOf(dyn_float.value()) != @typeOf(dyn_string.value()));

        //debug.assert(dyn_int.value() == 0);
        //debug.assert(dyn_float.value() == 1.0);
        //debug.assert(std.mem.eql(u8, dyn_string.value(), "Hello World!"));
    }
}
