const std = @import("std");
const parser = @import("parser.zig");

const debug = std.debug;
const math = std.math;
const mem = std.mem;
const fmt = std.fmt;

const ParseResult = parser.ParseResult;

pub const Input = struct.{
    str: []const u8,

    pub fn init(str: []const u8) Input {
        return Input.{
            .str = str,
        };
    }

    pub fn curr(input: Input) ?u8 {
        if (input.str.len != 0)
            return input.str[0];

        return null;
    }

    pub fn next(input: Input) Input {
        return Input.{
            .str = if (input.str.len != 0) input.str[1..] else input.str,
        };
    }
};

pub fn char(comptime c1: u8) type {
    return parser.eatIf(u8, struct.{
        fn predicate(c2: u8) bool {
            return c1 == c2;
        }
    }.predicate);
}

pub fn range(comptime a: u8, comptime b: u8) type {
    return parser.eatIf(u8, struct.{
        fn predicate(c: u8) bool {
            return a <= c and c <= b;
        }
    }.predicate);
}

pub fn uint(comptime Int: type, comptime base: u8) type {
    return struct.{
        pub const Result = Int;

        pub fn parse(input: var) ?ParseResult(@typeOf(input), Result) {
            const first = input.curr() orelse return null;
            const first_digit = fmt.charToDigit(first, base) catch return null;
            var res = math.cast(Result, first_digit) catch return null;

            var next = input.next();
            while (next.curr()) |curr| : (next = next.next()) {
                const digit = fmt.charToDigit(curr, base) catch break;
                res = math.mul(Result, res, base) catch return null;
                res = math.add(Result, res, digit) catch return null;
            }

            return ParseResult(@typeOf(input), Result).{
                .input = next,
                .result = res,
            };
        }
    };
}

pub fn string(comptime s: []const u8) type {
    return struct.{
        pub const Result = []const u8;

        pub fn parse(input: var) ?ParseResult(@typeOf(input), Result) {
            var next = input;
            for (s) |c| {
                const curr = next.curr() orelse return null;
                if (c != curr)
                    return null;

                next = next.next();
            }

            return ParseResult(@typeOf(input), Result).{
                .input = next,
                .result = s,
            };
        }
    };
}

fn testSuccess(comptime P: type, str: []const u8, result: var) void {
    const res = P.parse(Input.init(str)) orelse unreachable;
    debug.assert(res.input.str.len == 0);
    comptime debug.assert(@sizeOf(P.Result) == @sizeOf(@typeOf(result)));
    if (@sizeOf(P.Result) != 0)
        debug.assert(mem.eql(u8, mem.toBytes(res.result), mem.toBytes(result)));
}

fn testFail(comptime P: type, str: []const u8) void {
    if (P.parse(Input.init(str))) |res| {
        debug.assert(res.input.str.len != 0);
    }
}

test "parser.string.char" {
    const P = char('a');

    comptime var i = 0;
    inline while (i < 'a') : (i += 1)
        testFail(P, []u8.{i});
    inline while (i <= 'a') : (i += 1)
        testSuccess(P, []u8.{i}, u8(i));
    inline while (i <= math.maxInt(u8)) : (i += 1)
        testFail(P, []u8.{i});
}

test "parser.string.range" {
    const P = range('a', 'z');

    comptime var i = 0;
    inline while (i < 'a') : (i += 1)
        testFail(P, []u8.{i});
    inline while (i <= 'z') : (i += 1)
        testSuccess(P, []u8.{i}, u8(i));
    inline while (i <= math.maxInt(u8)) : (i += 1)
        testFail(P, []u8.{i});
}

test "parser.string.uint" {
    for ([][]const u8.{
        "0000", "1111", "7777", "9999",
        "aaaa", "AAAA", "ffff", "FFFF",
        "zzzz", "ZZZZ", "0123", "4567",
        "89AB", "CDEF", "GHIJ", "KLMN",
        "OPQR", "STUV", "WYZa", "bcde",
        "fghi", "jklm", "nopq", "rstu",
        "bwyz",
    }) |str| {
        comptime var base = 1;
        inline while (base <= 36) : (base += 1) {
            const P = uint(u64, base);
            if (fmt.parseUnsigned(u64, str, base)) |res| {
                testSuccess(P, str, res);
            } else |err| {
                testFail(P, str);
            }
        }
    }
}

test "parser.string.string" {
    const s: []const u8 = "1234";
    const P = string(s);

    testSuccess(P, s, s);
    testFail(P, "1235");
}
