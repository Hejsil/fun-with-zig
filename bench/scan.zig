const std = @import("std");
const bench = @import("bench");
const fun = @import("fun-with-zig");

const io = std.io;

const scan = fun.scan.scan;
const sscan = fun.scan.sscan;

fn sscanSlow(str: []const u8, comptime fmt: []const u8, comptime Res: type) !Res {
    var mem_stream = io.SliceInStream.init(str);
    var ps = io.PeekStream(1, io.SliceInStream.Error).init(&mem_stream.stream);
    return try scan(&ps, fmt, Res);
}

test "scan.sscan.benchmark.single" {
    try bench.benchmark(struct {
        pub const args = [][]const u8{
            "0=0",
            "10=10",
            "210=210",
            "3210=3210",
            "43210=43210",
            "543210=543210",
            "6543210=6543210",
            "76543210=76543210",
            "876543210=876543210",
        };

        pub fn scanSingle(str: []const u8) !u64 {
            const res = try sscanSlow(str, "{}={}", struct {
                a: u32,
                b: u32,
            });
            return u64(res.a) + res.b;
        }

        pub fn sscanSingle(str: []const u8) !u64 {
            const res = try sscan(str, "{}={}", struct {
                a: u32,
                b: u32,
            });
            return u64(res.a) + res.b;
        }
    });
}

test "scan.sscan.benchmark.switch" {
    try bench.benchmark(struct {
        pub const args = [][]const u8{
            "foo=0",
            "foo.bar=0",
            "foo.bar.baz=0",
            "foo[0].bar[0].baz[0]=0",
            "baz=0",
            "baz.bar=0",
            "baz.bar.foo=0",
            "baz[0].bar[0].foo[0]=0",
            "foo=9223372036854775807",
            "foo.bar=9223372036854775807",
            "foo.bar.baz=9223372036854775807",
            "foo[9223372036854775807].bar[9223372036854775807].baz[9223372036854775807]=9223372036854775807",
            "baz=9223372036854775807",
            "baz.bar=9223372036854775807",
            "baz.bar.foo=9223372036854775807",
            "baz[9223372036854775807].bar[9223372036854775807].foo[9223372036854775807]=9223372036854775807",
        };

        pub const iterations = 100000;

        pub fn scanSwitch(str: []const u8) u128 {
            if (sscanSlow(str, "foo={}", struct {
                a: u64,
            })) |v| {
                return v.a;
            } else |_| if (sscanSlow(str, "foo.bar={}", struct {
                a: u64,
            })) |v| {
                return v.a;
            } else |_| if (sscanSlow(str, "foo.bar.baz={}", struct {
                a: u64,
            })) |v| {
                return v.a;
            } else |_| if (sscanSlow(str, "foo[{}].bar[{}].baz[{}]={}", struct {
                a: u64,
                b: u64,
                c: u64,
                d: u64,
            })) |v| {
                return u128(v.a) + v.b + v.c + v.d;
            } else |_| if (sscanSlow(str, "baz={}", struct {
                a: u64,
            })) |v| {
                return v.a;
            } else |_| if (sscanSlow(str, "baz.bar={}", struct {
                a: u64,
            })) |v| {
                return v.a;
            } else |_| if (sscanSlow(str, "baz.bar.foo={}", struct {
                a: u64,
            })) |v| {
                return v.a;
            } else |_| if (sscanSlow(str, "baz[{}].bar[{}].foo[{}]={}", struct {
                a: u64,
                b: u64,
                c: u64,
                d: u64,
            })) |v| {
                return u128(v.a) + v.b + v.c + v.d;
            } else |_| {
                unreachable;
            }
        }

        pub fn sscanSwitch(str: []const u8) u128 {
            if (sscan(str, "foo={}", struct {
                a: u64,
            })) |v| {
                return v.a;
            } else |_| if (sscan(str, "foo.bar={}", struct {
                a: u64,
            })) |v| {
                return v.a;
            } else |_| if (sscan(str, "foo.bar.baz={}", struct {
                a: u64,
            })) |v| {
                return v.a;
            } else |_| if (sscan(str, "foo[{}].bar[{}].baz[{}]={}", struct {
                a: u64,
                b: u64,
                c: u64,
                d: u64,
            })) |v| {
                return u128(v.a) + v.b + v.c + v.d;
            } else |_| if (sscan(str, "baz={}", struct {
                a: u64,
            })) |v| {
                return v.a;
            } else |_| if (sscan(str, "baz.bar={}", struct {
                a: u64,
            })) |v| {
                return v.a;
            } else |_| if (sscan(str, "baz.bar.foo={}", struct {
                a: u64,
            })) |v| {
                return v.a;
            } else |_| if (sscan(str, "baz[{}].bar[{}].foo[{}]={}", struct {
                a: u64,
                b: u64,
                c: u64,
                d: u64,
            })) |v| {
                return u128(v.a) + v.b + v.c + v.d;
            } else |_| {
                unreachable;
            }
        }
    });
}
