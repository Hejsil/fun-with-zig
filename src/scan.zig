const bench = @import("bench");
const builtin = @import("builtin");
const fun = @import("index.zig");
const std = @import("std");

const debug = std.debug;
const fmath = fun.math;
const heap = std.heap;
const io = std.io;
const math = std.math;
const mem = std.mem;
const testing = std.testing;

pub fn scan(ps: var, comptime fmt: []const u8, comptime Res: type) !Res {
    const PeekStream = @typeOf(ps.*);
    comptime debug.assert(PeekStream == FastStringPeekStream or
        PeekStream == io.PeekStream(1, @typeOf(ps.stream).Error));
    const State = enum {
        Start,
        OpenBrace,
        CloseBrace,
    };

    const fields = @typeInfo(Res).Struct.fields;
    comptime var start_index = 0;
    comptime var state = State.Start;
    comptime var next_arg = 0;

    var res: Res = undefined;
    inline for (fmt) |c, i| {
        switch (state) {
            State.Start => switch (c) {
                '{' => {
                    start_index = i + 1;
                    state = State.OpenBrace;
                },
                '}' => state = State.CloseBrace,
                else => try expect(ps, c),
            },
            State.OpenBrace => switch (c) {
                '{' => {
                    state = State.Start;
                    try expect(ps, c);
                },
                '}' => {
                    const field = fields[next_arg];
                    const inner_fmt = fmt[start_index..i];
                    @field(res, field.name) = try scanOne(ps, inner_fmt, field.field_type);
                    next_arg += 1;
                    state = State.Start;
                },
                else => {},
            },
            State.CloseBrace => switch (c) {
                '}' => {
                    state = State.Start;
                    try expect(ps, c);
                },
                else => @compileError("Single '}' encountered in format string"),
            },
        }
    }
    comptime {
        if (fields.len != next_arg) {
            @compileError("Unused arguments");
        }
        if (state != State.Start) {
            @compileError("Incomplete format string: " ++ fmt);
        }
    }

    return res;
}

fn expect(ps: var, char: u8) !void {
    const byte = try ps.stream.readByte();
    if (byte != char)
        return error.InvalidCharacter;
}

fn scanOne(ps: var, comptime fmt: []const u8, comptime T: type) !T {
    switch (@typeInfo(T)) {
        builtin.TypeId.Int => return try scanInt(ps, fmt, T),
        builtin.TypeId.Float => return try scanFloat(ps, fmt, T),
        builtin.TypeId.Bool => return try scanBool(ps, fmt),
        else => @compileError("Unable to format type '" ++ @typeName(T) ++ "'"),
    }
}

fn scanInt(ps: var, comptime fmt: []const u8, comptime Int: type) !Int {
    const base: u8 = if (fmt.len == 0)
        u8(10)
    else switch (fmt[0]) {
        'b' => u8(2),
        'd' => u8(10),
        'x' => u8(16),
        else => @compileError("Unknown format character: " ++ []u8{fmt[0]}),
    };

    const first = try ps.stream.readByte();
    return switch (first) {
        '+' => try scanIntRest(ps, null, Int, false, base),
        '-' => try scanIntRest(ps, null, Int, true, base),
        else => try scanIntRest(ps, first, Int, false, base),
    };
}

fn scanIntRest(ps: var, op_first: ?u8, comptime Int: type, negative: bool, base: u8) !Int {
    const first = op_first orelse try ps.stream.readByte();
    const first_d: isize = try charToDigit(first, base);
    const first_c = if (negative) -first_d else first_d;
    var res = try math.cast(Int, first_c);

    done: while (true) {
        const byte = ps.stream.readByte() catch |err| switch (err) {
            error.EndOfStream => break :done,
            else => return err,
        };

        const digit: isize = charToDigit(byte, base) catch {
            ps.putBackByte(byte);
            break :done;
        };
        const digit2 = if (negative) -digit else digit;

        res = try math.mul(Int, res, try math.cast(Int, base));
        res = try math.add(Int, res, try math.cast(Int, digit2));
    }

    return res;
}

pub fn charToDigit(c: u8, base: u8) (error{InvalidCharacter}!u8) {
    const value = switch (c) {
        '0'...'9' => c - '0',
        'A'...'Z' => c - 'A' + 10,
        'a'...'z' => c - 'a' + 10,
        else => return error.InvalidCharacter,
    };

    if (value >= base)
        return error.InvalidCharacter;

    return value;
}

fn scanFloat(ps: var, comptime fmt: []const u8, comptime Float: type) !Float {
    @compileError("TODO");
}

fn scanBool(ps: var, comptime fmt: []const u8) !bool {
    if (fmt.len != 0)
        @compileError("TODO");

    const byte = try ps.stream.readByte();
    const str = switch (byte) {
        't' => "true",
        'f' => "false",
        else => return error.InvalidCharacter,
    };

    for (str[1..]) |c|
        try expect(ps, c);

    return str[0] == 't';
}

fn testScanOk(comptime fmt: []const u8, str: []const u8, comptime T: type, res: T) !void {
    var mem_stream = io.SliceInStream.init(str);
    var ps = io.PeekStream(1, io.SliceInStream.Error).init(&mem_stream.stream);

    const result = try scan(&ps, fmt, struct {
        r: @typeOf(res),
    });
    switch (T) {
        []const u8, []u8 => testing.expectEqualSlices(u8, res, result.r),
        else => testing.expectEqual(res, result.r),
    }
}

fn testScanError(comptime fmt: []const u8, str: []const u8, comptime T: type, err: anyerror) void {
    var mem_stream = io.SliceInStream.init(str);
    var ps = io.PeekStream(1, io.SliceInStream.Error).init(&mem_stream.stream);

    testing.expectError(err, scan(&ps, fmt, struct {
        i: T,
    }));
}

test "scanInt" {
    try testScanOk("{}", "0", u1, 0);
    try testScanOk("{}", "1", u1, 1);
    //try testScanOk("{}", "0", i1, 0); TODO
    //try testScanOk("{}", "-1", i1, -1); TODO
    try testScanOk("{}", "0", i64, 0);
    try testScanOk("{}", "-0", i64, 0);
    try testScanOk("{}", "+0", i64, 0);
    try testScanOk("{}", "1", i64, 1);
    try testScanOk("{}", "-1", i64, -1);
    try testScanOk("{}", "+1", i64, 1);
    try testScanOk("{}", "99", i64, 99);
    try testScanOk("{}", "-99", i64, -99);
    try testScanOk("{}", "+99", i64, 99);
    try testScanOk("{b}", "10", i64, 0b10);
    try testScanOk("{d}", "10", i64, 10);
    try testScanOk("{x}", "10", i64, 0x10);
    try testScanOk("{}a", "0a", i64, 0);
    try testScanOk("{}a", "-0a", i64, 0);
    try testScanOk("{}a", "+0a", i64, 0);
    try testScanOk("{}a", "1a", i64, 1);
    try testScanOk("{}a", "-1a", i64, -1);
    try testScanOk("{}a", "+1a", i64, 1);
    try testScanOk("{}a", "99a", i64, 99);
    try testScanOk("{}a", "-99a", i64, -99);
    try testScanOk("{}a", "+99a", i64, 99);
    try testScanOk("a{}a", "a0a", i64, 0);
    try testScanOk("a{}a", "a-0a", i64, 0);
    try testScanOk("a{}a", "a+0a", i64, 0);
    try testScanOk("a{}a", "a1a", i64, 1);
    try testScanOk("a{}a", "a-1a", i64, -1);
    try testScanOk("a{}a", "a+1a", i64, 1);
    try testScanOk("a{}a", "a99a", i64, 99);
    try testScanOk("a{}a", "a-99a", i64, -99);
    try testScanOk("a{}a", "a+99a", i64, 99);

    testScanError("{}", "a", u8, error.InvalidCharacter);
    testScanError("{}", "256", u8, error.Overflow);
    testScanError("{}", "-a", i8, error.InvalidCharacter);
    testScanError("{}", "a", i8, error.InvalidCharacter);
    testScanError("{}", "128", i8, error.Overflow);
    testScanError("{}", "-129", i8, error.Overflow);
    testScanError(" {}", "1", i8, error.InvalidCharacter);
}

test "scanBool" {
    try testScanOk("{}", "true", bool, true);
    try testScanOk("{}", "false", bool, false);
    try testScanOk("a{}", "atrue", bool, true);
    try testScanOk("a{}", "afalse", bool, false);
    try testScanOk("a{}a", "atruea", bool, true);
    try testScanOk("a{}a", "afalsea", bool, false);

    testScanError("{}", "qrue", bool, error.InvalidCharacter);
    testScanError("{}", "qalse", bool, error.InvalidCharacter);
    testScanError("{}", "frue", bool, error.InvalidCharacter);
    testScanError("{}", "talse", bool, error.InvalidCharacter);
}

pub fn sscan(str: []const u8, comptime fmt: []const u8, comptime Res: type) !Res {
    var s = FastStringPeekStream.init(str);
    return try scan(&s, fmt, Res);
}

const FastStringPeekStream = struct {
    const Inner = struct {
        str: []const u8,
        i: usize,

        fn readByte(s: *Inner) !u8 {
            if (s.str.len <= s.i)
                return error.EndOfStream;

            defer s.i += 1;
            return s.str[s.i];
        }
    };

    stream: Inner,

    fn init(str: []const u8) FastStringPeekStream {
        return FastStringPeekStream{
            .stream = Inner{
                .str = str,
                .i = 0,
            },
        };
    }

    fn putBackByte(s: *FastStringPeekStream, c: u8) void {
        testing.expectEqual(s.stream.str[s.stream.i - 1], c);
        s.stream.i -= 1;
    }
};

fn sscanSlow(str: []const u8, comptime fmt: []const u8, comptime Res: type) !Res {
    var mem_stream = io.SliceInStream.init(str);
    var ps = io.PeekStream(1, io.SliceInStream.Error).init(&mem_stream.stream);
    return try scan(&ps, fmt, Res);
}

test "scan.sscan.benchmark.single" {
    try bench.benchmark(struct {
        const args = [][]const u8{
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

        fn scanSingle(str: []const u8) !u64 {
            const res = try sscanSlow(str, "{}={}", struct {
                a: u32,
                b: u32,
            });
            return u64(res.a) + res.b;
        }

        fn sscanSingle(str: []const u8) !u64 {
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
        const args = [][]const u8{
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

        const iterations = 100000;

        fn scanSwitch(str: []const u8) u128 {
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

        fn sscanSwitch(str: []const u8) u128 {
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
