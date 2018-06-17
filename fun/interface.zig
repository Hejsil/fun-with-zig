const std = @import("std");
const builtin = @import("builtin");
const debug = std.debug;
const mem = std.mem;
const assert = debug.assert;

pub const Opaque = @OpaqueType();

pub fn Interface(comptime T: type) type {
    const info = @typeInfo(T).Struct;
    const VTable = struct {
        const Self = this;

        funcs: [info.defs.len]fn () void,

        fn init(comptime Funcs: type, comptime State: type) Self {
            var res: Self = undefined;

            inline for (info.defs) |def, i| {
                const DefType = @field(T, def.name);
                comptime assert(@typeOf(DefType) == type);

                const func_info = @typeInfo(DefType).Fn;
                comptime assert(func_info.args[0].arg_type == *Opaque);

                const Type = FnType(State, func_info.args[1..], func_info.return_type);
                const func: Type = @field(Funcs, def.name);
                res.funcs[i] = @ptrCast(fn () void, func);
            }

            return res;
        }

        fn dispatch(vtable: Self, comptime fn_name: []const u8, self: *Opaque, args: ...) @field(T, fn_name).ReturnType {
            inline for (info.defs) |def, i| {
                if (comptime !mem.eql(u8, def.name, fn_name))
                    continue;

                const func = @ptrCast(@field(T, def.name), vtable.funcs[i]);
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
                1 => fn (*State, args[0].arg_type) Return,
                2 => fn (*State, args[0].arg_type, args[1].arg_type) Return,
                3 => fn (*State, args[0].arg_type, args[1].arg_type, args[2].arg_type) Return,
                else => comptime unreachable,
            };
        }
    };

    return struct {
        const Self = this;

        state: *Opaque,
        vtable: *const VTable,

        pub fn init(comptime State: type, state: *State) Self {
            return initWithFuncs(State, state, State);
        }

        pub fn initWithFuncs(comptime State: type, state: *State, comptime Funcs: type) Self {
            return Self{
                .state = @ptrCast(*Opaque, state),
                .vtable = &comptime VTable.init(Funcs, State),
            };
        }

        fn call(self: Self, comptime fn_name: []const u8, args: ...) @field(T, fn_name).ReturnType {
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
    const a = fn (*Opaque, u8) u8;
});

test "" {
    var sb = Sb{ .b = 3 };
    var sq = Sq{ .q = 3 };
    const ib = IA.init(Sb, &sb);
    const iq = IA.init(Sq, &sq);
    assert(ib.call("a", u8(2)) == 5);
    assert(iq.call("a", u8(2)) == 6);
}
