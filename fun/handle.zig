const std = @import("std");
const debug = std.debug;

pub fn OpaqueHandle(comptime T: type, comptime hack_around_comptime_cache: type) type {
    return packed struct.{
        // We could store this variable as a @IntType(false, @sizeOf(T) * 8)
        // but we lose the exact size in bits this way. If we had @sizeOfBits,
        // this would work better.
        ____________: T,

        pub fn init(v: T) @This() {
            return @This().{.____________ = v};
        }

        pub fn cast(self: @This()) T {
            return self.____________;
        }
    };
}


test "OpaqueHandle" {
    const A = OpaqueHandle(u64, @OpaqueType());
    const B = OpaqueHandle(u64, @OpaqueType());
    debug.assert(A != B);
    const a = A.init(10);
    const b = B.init(10);
    debug.assert(a.cast() == b.cast());
}
