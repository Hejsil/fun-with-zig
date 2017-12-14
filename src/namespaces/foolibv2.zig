const debug = @import("std").debug;
const io = @import("std").io;

pub fn foo() {
    var stdout_file = io.getStdOut() %% unreachable;
    stdout_file.write("foo") %% unreachable;
}

pub fn bar() -> %void {
    var stdout_file = %return io.getStdOut();
    %return stdout_file.write("bar");
}