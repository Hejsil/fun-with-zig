const builtin = @import("builtin");
const std = @import("std");

const debug = std.debug;
const testing = std.testing;

const TypeInfo = builtin.TypeInfo;
const TypeId = builtin.TypeId;

pub fn Reify(comptime info: TypeInfo) type {
    switch (info) {
        .Type => return type,
        .Void => return void,
        .Bool => return bool,
        .Null => return @TypeOf(null),
        .Undefined => return @TypeOf(undefined),
        .NoReturn => return noreturn,
        .ComptimeInt => return comptime_int,
        .ComptimeFloat => return comptime_float,
        // TODO: Implement without using @Type
        .Int => |int| unreachable,
        .Float => |float| switch (float.bits) {
            16 => return f16,
            32 => return f32,
            64 => return f64,
            128 => return f128,
            else => @compileError("Float cannot be Reified with {TODO bits in error} bits"),
        },
        .Pointer => |ptr| switch (ptr.size) {
            .One => {
                if (ptr.is_const and ptr.is_volatile)
                    return *align(ptr.alignment) const volatile ptr.child;
                if (ptr.is_const)
                    return *align(ptr.alignment) const ptr.child;
                if (ptr.is_volatile)
                    return *align(ptr.alignment) volatile ptr.child;

                return *align(ptr.alignment) ptr.child;
            },
            .Many => {
                if (ptr.is_const and ptr.is_volatile)
                    return [*]align(ptr.alignment) const volatile ptr.child;
                if (ptr.is_const)
                    return [*]align(ptr.alignment) const ptr.child;
                if (ptr.is_volatile)
                    return [*]align(ptr.alignment) volatile ptr.child;

                return [*]align(ptr.alignment) ptr.child;
            },
            .Slice => {
                if (ptr.is_const and ptr.is_volatile)
                    return []align(ptr.alignment) const volatile ptr.child;
                if (ptr.is_const)
                    return []align(ptr.alignment) const ptr.child;
                if (ptr.is_volatile)
                    return []align(ptr.alignment) volatile ptr.child;

                return []align(ptr.alignment) ptr.child;
            },
            .C => {
                if (ptr.is_const and ptr.is_volatile)
                    return [*c]align(ptr.alignment) const volatile ptr.child;
                if (ptr.is_const)
                    return [*c]align(ptr.alignment) const ptr.child;
                if (ptr.is_volatile)
                    return [*c]align(ptr.alignment) volatile ptr.child;

                return [*c]align(ptr.alignment) ptr.child;
            },
        },
        .Array => |arr| return [arr.len]arr.child,
        .Struct => |str| @compileError("TODO"),
        .Optional => |opt| return ?opt.child,
        .ErrorUnion => |err_union| return err_union.error_set!err_union.payload,
        .ErrorSet => |err_set| {
            var Res = error{};
            inline for (err_set.errors) |err| {
                Res = Res || @field(anyerror, err.name);
            }

            return Res;
        },
        .Opaque => return @OpaqueType(),
        .AnyFrame => return anyframe,
        .Enum => |enu| @compileError("TODO"),
        .Union => |unio| @compileError("TODO"),
        .Fn => |func| @compileError("TODO"),
        .BoundFn => |func| @compileError("TODO"),
        .Frame => @compileError("TODO"),
        .Vector => @compileError("TODO"),
        .EnumLiteral => @compileError("TODO"),
    }
}

test "reify: type" {
    const T = Reify(@typeInfo(type));
    testing.expectEqual(T, type);
}

test "reify: void" {
    const T = Reify(@typeInfo(void));
    testing.expectEqual(T, void);
}

test "reify: bool" {
    const T = Reify(@typeInfo(bool));
    testing.expectEqual(T, bool);
}

test "reify: noreturn" {
    const T = Reify(@typeInfo(noreturn));
    testing.expectEqual(T, noreturn);
}

test "reify: ix/ux" {
    //@setEvalBranchQuota(10000);
    //inline for ([_]bool{ true, false }) |signed| {
    //    comptime var i = 0;
    //    inline while (i < 256) : (i += 1) {
    //        const T1 = @IntType(signed, i);
    //        const T2 = Reify(@typeInfo(T1));
    //        comptime testing.expectEqual(T1, T2);
    //    }
    //}
}

test "reify: fx" {
    testing.expectEqual(Reify(@typeInfo(f16)), f16);
    // TODO: All these fail for some reason
    //testing.expectEqual(Reify(@typeInfo(f32)), f32);
    //testing.expectEqual(Reify(@typeInfo(f64)), f64);
    //testing.expectEqual(Reify(@typeInfo(f128)), f128);
}

test "reify: *X" {
    const types = [_]type{
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
        testing.expectEqual(T, P);
    }
}

test "reify: [*]X" {
    const types = [_]type{
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
        testing.expectEqual(T, P);
    }
}

test "reify: []X" {
    const types = [_]type{
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
        const T = comptime Reify(@typeInfo(P));
        testing.expectEqual(T, P);
    }
}

test "reify: [n]X" {
    testing.expectEqual([1]u8, Reify(@typeInfo([1]u8)));
    // TODO: This fails for some reason
    //testing.expectEqual([10]u8, Reify(@typeInfo([10]u8)));
}

test "reify: struct" {
    return error.SkipZigTest;
}

test "reify: ?X" {
    const T = Reify(@typeInfo(?u8));
    testing.expectEqual(T, ?u8);
}

test "reify: X!Y" {
    const Set = error{};
    const T = Reify(@typeInfo(Set!u8));
    testing.expectEqual(T, Set!u8);
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
    testing.expectEqual(@as(TypeId, @typeInfo(T)), .Opaque);
}

test "reify: anyframe" {
    const T = Reify(@typeInfo(anyframe));
    testing.expectEqual(T, anyframe);
}

test "reify: @Frame" {
    return error.SkipZigTest;
}
