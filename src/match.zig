const std = @import("std");

const debug = std.debug;
const mem = std.mem;
const rand = std.rand;
const sort = std.sort;

pub fn StringSwitch(comptime strings: []const []const u8) type {
    for (strings[1..]) |_, i| {
        if (mem.lessThan(u8, strings[i], strings[i + 1]))
            continue;

        @compileError("Input not sorted (assert(\"" ++ strings[i] ++ "\" < \"" ++ strings[i + 1] ++ "\"))");
    }

    return struct {
        pub fn match(str: []const u8) usize {
            var curr: usize = 0;
            next: for (strings) |s, i| {
                while (curr < s.len) : (curr += 1) {
                    const a = str[curr];
                    const b = s[curr];
                    if (a != b)
                        continue :next;
                }

                if (s.len == str.len)
                    return i;
            }

            return strings.len;
        }

        pub fn case(comptime str: []const u8) usize {
            const i = match(str);
            debug.assert(i < strings.len);
            return i;
        }
    };
}

test "match.StringSwitch" {
    @setEvalBranchQuota(1000000);
    const strings = [_][]const u8{
        "A",
        "AA",
        "AAA",
        "AAAA",
        "AAAAA",
        "AAAAAA",
        "AAAAAAA",
        "AAAAAAAA",
    };
    const sw = comptime StringSwitch(strings);

    inline for (strings) |str|
        switch (sw.match(str)) {
        sw.case(str) => {},
        else => unreachable,
    };
}
