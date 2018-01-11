const debug = @import("std").debug;
const io = @import("std").io;

pub fn foo() {
    var stdout_file = io.getStdOut() catch unreachable;
    stdout_file.write("foo") catch unreachable;
}

pub fn bar() -> %void {
    var stdout_file = try io.getStdOut();
    try stdout_file.write("bar");
}