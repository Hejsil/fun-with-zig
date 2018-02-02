const TypeId = @import("builtin").TypeId;

/// Determin if ::T can be passed by value.
pub fn canPassByValue(comptime T: type) bool {
    if (@sizeOf(T) == 0) return true;

    switch (@typeId(T)) {
        TypeId.Struct,
        TypeId.Union,
        TypeId.Array       => return false,
        TypeId.ErrorUnion,
        TypeId.Nullable    => return canPassByValue(T.Child),
        else               => return true
    }
}

/// Modify ::T, so it can be passed to a function.
pub fn Pass(comptime T: type) type {
    if (canPassByValue(T)) {
        return T;
    } else {
        return &const T;
    }
}

/// Get the value of ::T. Only useful in generic function that use ::Pass
pub fn getValue(comptime T: type, value: Pass(T)) T {
    if (canPassByValue(T)) {
        return value;
    } else {
        return *value;
    }
}