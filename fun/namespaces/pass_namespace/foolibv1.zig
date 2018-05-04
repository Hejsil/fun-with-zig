const debug = @import("std").debug;

pub fn foo() void {
    debug.warn("foo");
}

pub fn bar() void {
    debug.warn("bar");
}
