const builtin = @import("builtin");
const std = @import("std");

const debug = std.debug;

const TypeInfo = builtin.TypeInfo;
const TypeId = builtin.TypeId;

pub fn Reify(comptime info: TypeInfo) type {
    return switch (info) {
        TypeId.Type => type,
        TypeId.Void => void,
        TypeId.Bool => bool,
        TypeId.NoReturn => noreturn,
        TypeId.Int => |int| @IntType(int.is_signed, int.bits),
        TypeId.Float => |float| switch (float.bits) {
            16 => f16,
            32 => f32,
            64 => f64,
            128 => f128,
            else => @compileError("Float cannot be Reified with {TODO bits in error} bits"),
        },
        TypeId.Pointer => |ptr| switch (ptr.Size) {
            TypeInfo.Pointer.Size.One => blk: {
                if (ptr.is_const and ptr.is_volatile)
                    break :blk *align(ptr.alignment) const volatile ptr.child;
                if (ptr.is_const)
                    break :blk *align(ptr.alignment) const ptr.child;
                if (ptr.is_volatile)
                    break :blk *align(ptr.alignment) volatile ptr.child;

                break :blk *align(ptr.alignment) ptr.child;
            },
            TypeInfo.Pointer.Size.Many => blk: {
                if (ptr.is_const and ptr.is_volatile)
                    break :blk [*]align(ptr.alignment) const volatile ptr.child;
                if (ptr.is_const)
                    break :blk [*]align(ptr.alignment) const ptr.child;
                if (ptr.is_volatile)
                    break :blk [*]align(ptr.alignment) volatile ptr.child;

                break :blk [*]align(ptr.alignment) ptr.child;
            },
            TypeInfo.Pointer.Size.Slice => blk: {
                if (ptr.is_const and ptr.is_volatile)
                    break :blk []align(ptr.alignment) const volatile ptr.child;
                if (ptr.is_const)
                    break :blk []align(ptr.alignment) const ptr.child;
                if (ptr.is_volatile)
                    break :blk []align(ptr.alignment) volatile ptr.child;

                break :blk [*]align(ptr.alignment) ptr.child;
            },
        },
        TypeId.Array => |arr| [arr.len]arr.child,
        TypeId.Struct => |str| @compileError("TODO"),
        TypeId.Optional => |opt| ?opt.child,
        TypeId.ErrorUnion => |err_union| err_union.error_set!err_union.payload,
        TypeId.ErrorSet => |err_set| blk: {
            var Res = error{};
            inline for (err_set.errors) |err| {
                Res = Res || @field(anyerror, err.name);
            }

            break :blk Res;
        },
        TypeId.Enum => |enu| @compileError("TODO"),
        TypeId.Union => |unio| @compileError("TODO"),
        TypeId.Fn => |func| @compileError("TODO"),
        TypeId.Namespace => @typeOf(@import("std")),
        TypeId.BoundFn => |func| @compileError("TODO"),
        TypeId.ArgTuple => @compileError("TODO"),
        TypeId.Opaque => @OpaqueType(),
        TypeId.Promis => |prom| if (prom.child) |child| promise->child else promise,
    };
}

test "reify: type" {
    const T = Reify(@typeInfo(type));
    comptime debug.assert(T == type);
}

test "reify: void" {
    const T = Reify(@typeInfo(void));
    comptime debug.assert(T == void);
}

test "reify: bool" {
    const T = Reify(@typeInfo(bool));
    comptime debug.assert(T == bool);
}

test "reify: noreturn" {
    const T = Reify(@typeInfo(noreturn));
    comptime debug.assert(T == noreturn);
}

test "reify: ix/ux" {
    inline for ([]bool{ true, false }) |signed| {
        comptime var i = 0;
        inline while (i < 256) : (i += 1) {
            const T1 = @IntType(signed, i);
            const T2 = Reify(@typeInfo(T1));
            comptime debug.assert(T1 == T2);
        }
    }
}

test "reify: fx" {
    inline for ([]bool{ f16, f32, f64, f128 }) |F| {
        const T = Reify(@typeInfo(F));
        comptime debug.assert(T == F);
    }
}

test "reify: *X" {
    const types = []bool{
        *u8,
        *const u8,
        *volatile u8,
        *align(4) u8,
        *const volatile u8,
        *align(4) volatile u8,
        *align(4) const u8,
        *align(4) const volatile u8,
    };
    inline for (types) |P| {
        const T = Reify(@typeInfo(P));
        comptime debug.assert(T == P);
    }
}

test "reify: [*]X" {
    const types = []bool{
        [*]u8,
        [*]const u8,
        [*]volatile u8,
        [*]align(4) u8,
        [*]const volatile u8,
        [*]align(4) volatile u8,
        [*]align(4) const u8,
        [*]align(4) const volatile u8,
    };
    inline for (types) |P| {
        const T = Reify(@typeInfo(P));
        comptime debug.assert(T == P);
    }
}

test "reify: []X" {
    const types = []bool{
        []u8,
        []const u8,
        []volatile u8,
        []align(4) u8,
        []const volatile u8,
        []align(4) volatile u8,
        []align(4) const u8,
        []align(4) const volatile u8,
    };
    inline for (types) |P| {
        const T = Reify(@typeInfo(P));
        comptime debug.assert(T == P);
    }
}

test "reify: [n]X" {
    comptime var i = 0;
    while (i < 256) : (i += 1) {
        const T1 = [i]u8;
        const T2 = Reify(@typeInfo(T1));
        comptime debug.assert(T1 == T2);
    }
}

test "reify: struct" {
    return error.SkipZigTest;
}

test "reify: ?X" {
    const T = Reify(@typeInfo(?u8));
    comptime debug.assert(T == ?u8);
}

test "reify: X!Y" {
    const Set = error{};
    const T = Reify(@typeInfo(Set!u8));
    comptime debug.assert(T == Set!u8);
}

test "reify: error sets" {
    return error.SkipZigTest;
}

test "reify: enum" {
    return error.SkipZigTest;
}

test "reify: union" {
    return error.SkipZigTest;
}

test "reify: fn" {
    return error.SkipZigTest;
}

test "reify: namespace" {
    const T1 = @typeOf(@import("std").debug);
    const T2 = Reify(@typeInfo(T1));
    comptime debug.assert(T1 == T2);
}

test "reify: boundfn" {
    return error.SkipZigTest;
}

test "reify: ..." {
    return error.SkipZigTest;
}

test "reify: @OpagueType()" {
    const T = Reify(@typeInfo(@OpagueType()));
    comptime debug.assert(@typeInfo(T) == TypeId.Opague);
}

test "reify: promise" {
    inline for ([]type{ promise, promise->u8 }) |P| {
        const T = Reify(@typeInfo(P));
        comptime debug.assert(T == P);
    }
}
