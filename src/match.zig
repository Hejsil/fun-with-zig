const std = @import("std");

const debug = std.debug;
const mem = std.mem;
const rand = std.rand;
const sort = std.sort;

pub fn StringSwitch(comptime strings: []const []const u8) type {
    var sorted: [strings.len][]const u8 = undefined;
    mem.copy([]const u8, sorted[0..], strings);
    sort.sort([]const u8, sorted[0..], struct {
        fn lessThan(a: []const u8, b: []const u8) bool {
            return mem.lessThan(u8, a, b);
        }
    }.lessThan);
    for (sorted[1..]) |_, i|
        debug.assert(!mem.eql(u8, strings[i], strings[i + 1]));


    return struct {
        pub fn match(str: []const u8) usize {
            var curr: usize = 0;
            next: for (sorted) |s, i| {
                while (curr < s.len) : (curr += 1) {
                    const a = str[curr];
                    const b = s[curr];
                    if (a != b)
                        continue :next;
                }

                if (s.len == str.len)
                    return i;
            }

            return sorted.len;
        }

        pub fn case(comptime str: []const u8) usize {
            const i = match(str);
            debug.assert(i < sorted.len);
            return i;
        }
    };
}

test "switch.StringSwitch" {
    @setEvalBranchQuota(1000000);
    const strings = comptime blk: {
        var res: [100][]const u8 = undefined;
        var r = rand.DefaultPrng.init(0);

        for (res) |_, i| {
            var s: [(i + 2) * 2]u8 = undefined;
            r.random.bytes(s[0..]);
            res[i] = s;
        }

        break :blk res;
    };

    const sw = comptime StringSwitch(strings);

    inline for (strings) |str| switch (sw.match(str)) {
        sw.case(str) => {},
        else => unreachable,
    };
}
