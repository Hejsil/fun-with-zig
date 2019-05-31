const std = @import("std");
const builtin = @import("builtin");
const debug = std.debug;
const mem = std.mem;
const testing = std.testing;

pub const Self = @OpaqueType();

pub fn Interface(comptime T: type) type {
    const info = @typeInfo(T).Struct;
    const VTable = struct {
        funcs: [info.decls.len]fn () void,

        fn init(comptime Funcs: type, comptime State: type) @This() {
            var res: @This() = undefined;

            inline for (info.decls) |def, i| {
                const DefType = @field(T, def.name);
                comptime debug.assert(@typeOf(DefType) == type);

                const func_info = @typeInfo(DefType).Fn;
                comptime debug.assert(func_info.args[0].arg_type.? == *Self);

                const Type = FnType(State, func_info.args[1..], func_info.return_type.?);
                const func: Type = @field(Funcs, def.name);
                res.funcs[i] = @ptrCast(fn () void, func);
            }

            return res;
        }

        fn dispatch(vtable: @This(), comptime fn_name: []const u8, self: *Self, args: ...) @field(T, fn_name).ReturnType {
            inline for (info.decls) |decl, i| {
                if (comptime !mem.eql(u8, decl.name, fn_name))
                    continue;

                const func = @ptrCast(@field(T, decl.name), vtable.funcs[i]);
                return switch (args.len) {
                    0 => func(self),
                    1 => func(self, args[0]),
                    2 => func(self, args[0], args[1]),
                    3 => func(self, args[0], args[1], args[2]),
                    else => comptime unreachable,
                };
            }

            comptime unreachable;
        }

        fn FnType(comptime State: type, comptime args: []const builtin.TypeInfo.FnArg, comptime Return: type) type {
            return switch (args.len) {
                0 => fn (*State) Return,
                1 => fn (*State, args[0].arg_type.?) Return,
                2 => fn (*State, args[0].arg_type.?, args[1].arg_type.?) Return,
                3 => fn (*State, args[0].arg_type.?, args[1].arg_type.?, args[2].arg_type.?) Return,
                else => comptime unreachable,
            };
        }
    };

    return struct {
        state: *Self,
        vtable: *const VTable,

        pub fn init(comptime State: type, state: *State) @This() {
            return initWithFuncs(State, state, State);
        }

        pub fn initWithFuncs(comptime State: type, state: *State, comptime Funcs: type) @This() {
            return @This(){
                .state = @ptrCast(*Self, state),
                .vtable = &comptime VTable.init(Funcs, State),
            };
        }

        fn call(self: @This(), comptime fn_name: []const u8, args: ...) @field(T, fn_name).ReturnType {
            return self.vtable.dispatch(fn_name, self.state, args);
        }
    };
}

const Sb = struct {
    b: u8,

    fn a(self: *Sb, v: u8) u8 {
        return self.b + v;
    }
};

const Sq = struct {
    q: u8,

    fn a(self: *Sq, v: u8) u8 {
        return self.q * v;
    }
};

const IA = Interface(struct {
    const a = fn (*Self, u8) u8;
});

test "interface" {
    var sb = Sb{ .b = 3 };
    var sq = Sq{ .q = 3 };
    const ib = IA.init(Sb, &sb);
    const iq = IA.init(Sq, &sq);
    testing.expectEqual(u8(5), ib.call("a", u8(2)));
    testing.expectEqual(u8(6), iq.call("a", u8(2)));
}
