const std = @import("std");

const debug = std.debug;
const mem = std.mem;
const sort = std.sort;

pub const StringSwitch = struct {
    strings: []const []const u8,

    pub fn init(comptime strings: []const []const u8) StringSwitch {
        return StringSwitch{
            .strings = comptime blk: {
                var res: [strings.len][]const u8 = undefined;
                mem.copy([]const u8, res[0..], strings);
                sort.sort([]const u8, res[0..], lessThan);
                break :blk res;
            },
        };
    }

    pub fn match(comptime sw: StringSwitch, str: []const u8) usize {
        var curr: usize = 0;
        next: for (sw.strings) |s, i| {
            while (curr < s.len) : (curr += 1) {
                const a = str[curr];
                const b = s[curr];
                if (a != b)
                    continue :next;
            }

            if (s.len == str.len)
                return i;
        }

        return sw.strings.len;
    }

    pub fn case(comptime sw: StringSwitch, comptime str: []const u8) usize {
        const i = sw.match(str);
        debug.assert(i < sw.strings.len);
        return i;
    }

    fn lessThan(a: []const u8, b: []const u8) bool {
        return mem.lessThan(u8, a, b);
    }
};

test "switch.StringSwitch" {
    const sw = comptime StringSwitch.init([][]const u8{
        "Summer",
        "Winter",
        "Fall",
        "Spring",
    });

    inline for ([][]const u8{
        "Winter",
        "Spring",
        "Fall",
        "Summer",
    }) |str| switch (sw.match(str)) {
        sw.case(str) => {},
        else => unreachable,
    };
}
