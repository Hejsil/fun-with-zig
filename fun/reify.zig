const builtin = @import("builtin");
const std = @import("std");

const debug = std.debug;
const testing = std.testing;

const TypeInfo = builtin.TypeInfo;
const TypeId = builtin.TypeId;

pub fn Reify(comptime info: TypeInfo) type {
    return switch (info) {
        .Type => type,
        .Void => void,
        .Bool => bool,
        .Null => null,
        .Undefined => @typeOf(undefined),
        .NoReturn => noreturn,
        .ComptimeInt => comptime_int,
        .ComptimeFloat => comptime_float,
        .Int => |int| @IntType(int.is_signed, int.bits),
        .Float => |float| switch (float.bits) {
            16 => f16,
            32 => f32,
            64 => f64,
            128 => f128,
            else => @compileError("Float cannot be Reified with {TODO bits in error} bits"),
        },
        .Pointer => |ptr| switch (ptr.size) {
            .One => blk: {
                if (ptr.is_const and ptr.is_volatile)
                    break :blk *align(ptr.alignment) const volatile ptr.child;
                if (ptr.is_const)
                    break :blk *align(ptr.alignment) const ptr.child;
                if (ptr.is_volatile)
                    break :blk *align(ptr.alignment) volatile ptr.child;

                break :blk *align(ptr.alignment) ptr.child;
            },
            .Many => blk: {
                if (ptr.is_const and ptr.is_volatile)
                    break :blk [*]align(ptr.alignment) const volatile ptr.child;
                if (ptr.is_const)
                    break :blk [*]align(ptr.alignment) const ptr.child;
                if (ptr.is_volatile)
                    break :blk [*]align(ptr.alignment) volatile ptr.child;

                break :blk [*]align(ptr.alignment) ptr.child;
            },
            .Slice => blk: {
                if (ptr.is_const and ptr.is_volatile)
                    break :blk []align(ptr.alignment) const volatile ptr.child;
                if (ptr.is_const)
                    break :blk []align(ptr.alignment) const ptr.child;
                if (ptr.is_volatile)
                    break :blk []align(ptr.alignment) volatile ptr.child;

                break :blk []align(ptr.alignment) ptr.child;
            },
            .C => blk: {
                if (ptr.is_const and ptr.is_volatile)
                    break :blk [*c]align(ptr.alignment) const volatile ptr.child;
                if (ptr.is_const)
                    break :blk [*c]align(ptr.alignment) const ptr.child;
                if (ptr.is_volatile)
                    break :blk [*c]align(ptr.alignment) volatile ptr.child;

                break :blk [*c]align(ptr.alignment) ptr.child;
            },
        },
        .Array => |arr| [arr.len]arr.child,
        .Struct => |str| @compileError("TODO"),
        .Optional => |opt| ?opt.child,
        .ErrorUnion => |err_union| err_union.error_set!err_union.payload,
        .ErrorSet => |err_set| blk: {
            var Res = error{};
            inline for (err_set.errors) |err| {
                Res = Res || @field(anyerror, err.name);
            }

            break :blk Res;
        },
        .Opaque => @OpaqueType(),
        .AnyFrame => anyframe,
        .Enum => |enu| @compileError("TODO"),
        .Union => |unio| @compileError("TODO"),
        .Fn => |func| @compileError("TODO"),
        .BoundFn => |func| @compileError("TODO"),
        .ArgTuple => @compileError("TODO"),
        .Frame => @compileError("TODO"),
        .Vector => @compileError("TODO"),
    };
}

test "reify: type" {
    const T = Reify(@typeInfo(type));
    comptime testing.expectEqual(T, type);
}

test "reify: void" {
    const T = Reify(@typeInfo(void));
    comptime testing.expectEqual(T, void);
}

test "reify: bool" {
    const T = Reify(@typeInfo(bool));
    comptime testing.expectEqual(T, bool);
}

test "reify: noreturn" {
    const T = Reify(@typeInfo(noreturn));
    comptime testing.expectEqual(T, noreturn);
}

test "reify: ix/ux" {
    @setEvalBranchQuota(10000);
    inline for ([]bool{ true, false }) |signed| {
        comptime var i = 0;
        inline while (i < 256) : (i += 1) {
            const T1 = @IntType(signed, i);
            const T2 = Reify(@typeInfo(T1));
            comptime testing.expectEqual(T1, T2);
        }
    }
}

test "reify: fx" {
    inline for ([]type{ f16, f32, f64, f128 }) |F| {
        const T = Reify(@typeInfo(F));
        comptime testing.expectEqual(T, F);
    }
}

test "reify: *X" {
    const types = []type{
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
        comptime testing.expectEqual(T, P);
    }
}

test "reify: [*]X" {
    const types = []type{
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
        comptime testing.expectEqual(T, P);
    }
}

test "reify: []X" {
    const types = []type{
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
        comptime testing.expectEqual(T, P);
    }
}

test "reify: [n]X" {
    @setEvalBranchQuota(10000);
    comptime var i = 0;
    inline while (i < 256) : (i += 1) {
        const T1 = [i]u8;
        const T2 = Reify(@typeInfo(T1));
        comptime testing.expectEqual(T1, T2);
    }
}

test "reify: struct" {
    return error.SkipZigTest;
}

test "reify: ?X" {
    const T = Reify(@typeInfo(?u8));
    comptime testing.expectEqual(T, ?u8);
}

test "reify: X!Y" {
    const Set = error{};
    const T = Reify(@typeInfo(Set!u8));
    comptime testing.expectEqual(T, Set!u8);
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

test "reify: boundfn" {
    return error.SkipZigTest;
}

test "reify: ..." {
    return error.SkipZigTest;
}

test "reify: @OpaqueType()" {
    const T = Reify(@typeInfo(@OpaqueType()));
    comptime testing.expectEqual(TypeId(@typeInfo(T)), .Opaque);
}

test "reify: anyframe" {
    const T = Reify(@typeInfo(anyframe));
    comptime testing.expectEqual(T, anyframe);
}

test "reify: @Frame" {
    return error.SkipZigTest;
}
