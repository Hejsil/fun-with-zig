// Namespaces, like types, are meta types, that you can work with at comptime.
// We can get the namespace type, and now the fun begins
const Namespace = @typeOf(@import("std"));

// We can now define function that take namespaces at comptime.
fn namespaceHelloWorld(comptime N: Namespace) -> %void {
    var stdout_file = %return N.getStdOut();
    %return stdout_file.write("Hello, world!\n");
}

// And we can now use this function as we would any other.
test "namespaceHelloWorld" {
    _ = namespaceHelloWorld(@import("std").io);

    // Ofc, if we pase a namespace that doesn't have the right public
    // identifiers, then the program won't compile:
    // src/namespaces/namespaces.zig:7:32: error: no member named 'getStdOut' in '/usr/local/lib/zig/std/index.zig'
    //     var stdout_file = %return N.getStdOut();
    //                                ^
    // src/namespaces/namespaces.zig:17:28: note: called from here
    //     _ = namespaceHelloWorld(@import("std"));
}

// I don't quite know how this is useful, yet, but we can do a few fun things.
// We could write functions that takes a library as input, and then we can use
// diffrent versions in different places :)
test "foolib" {
    const foolibv1 = @import("foolibv1.zig");
    const foolibv2 = @import("foolibv2.zig");

    // So between versions, we are able to choose implementation.
    // For signatures that didn't change, we can use the old version,
    // or the new one no problem:
    useFoo(foolibv1);
    useFoo(foolibv2);

    // If a signature changes, then we can just keep using the old version
    // until we actually fix our code.
    useBar(foolibv1);
    // useBar(foolibv2); // error: expression value is ignored


    // _ = useNewBar(foolibv1);
    _ = useNewBar(foolibv2);
}

fn useFoo(comptime FooLib: Namespace) {
    FooLib.foo();
}

fn useBar(comptime FooLib: Namespace) {
    FooLib.bar();
}

fn useNewBar(comptime FooLib: Namespace) -> %void {
    %return FooLib.bar();
}