const Namespace = @typeOf(@import("std"));

const modules = []Namespace.{
    @import("a.zig"),
    @import("b.zig"),
};

// An interesting use case for namespace arrays are for a module like system.
// Let's say that we want users to be able to provide features for our app,
// and that alot of new features is just implementing functions of some signatures
// and call it in main code.
// With namespace arrays, a contributor can just implement their new functionality,
// in a file, and then import the file into the namespace array, and our inline
// loop will automaticly generate the code for calling the right functions in
// that namespace!
// NOTE: This is not a plugin system. The program have to be recompiled with
//       the new module, for the feature to be present.
test "namespaces.namespace_array.Example: \"Module\" system" {
    inline for (modules) |mod| {
        mod.print();
    }
}
