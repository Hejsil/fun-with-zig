const assert = @import("std").debug.assert;

pub fn all(slice: var, rest: ...) bool {
    return switch (rest.len) {
        1 => allNoContext(slice, rest[0]),
        2 => allWithContext(slice, rest[0], rest[1]),
        else => unreachable,
    };
}

fn allNoContext(slice: var, predicate: fn(&const @typeOf(slice[0])) bool) bool {
    for (slice) |item| {
        if (!predicate(item)) return false;
    }

    return true;
}


pub fn allWithContext(slice: var, context: var, predicate: fn(&const @typeOf(slice[0]), @typeOf(context)) bool) bool {
    for (slice) |item| {
        if (!predicate(item, context)) return false;
    }

    return true;
}


test "overloading.all" {
    assert(all("aaaa"[0..], struct { fn l(c: &const u8) bool { return c.* == 'a'; } }.l));
    assert(all("aaaa"[0..], u8('a'), struct { fn l(c: &const u8, c2: u8) bool { return c.* == c2; } }.l));
}
