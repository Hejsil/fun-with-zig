const builtin = @import("builtin");
const std = @import("std");

const debug = std.debug;
const io = std.io;
const math = std.math;

pub fn scan(ps: var, comptime fmt: []const u8, comptime Res: type) !Res {
    comptime debug.assert(@typeOf(ps.*) == io.PeekStream(1, @typeOf(ps.stream).Error));
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
                '{' => state = State.OpenBrace,
                '}' => state = State.CloseBrace,
                else => {
                    try expect(ps, c);
                },
            },
            State.OpenBrace => switch (c) {
                '{' => {
                    state = State.Start;
                    try expect(ps, c);
                },
                '}' => {
                    @field(res, fields[next_arg].name) = try scanOne(ps, fields[next_arg].field_type);
                    next_arg += 1;
                    state = State.Start;
                },
                else => @compileError("TODO"),
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

fn scanOne(ps: var, comptime T: type) !T {
    switch (@typeInfo(T)) {
        builtin.TypeId.Int => return try scanInt(ps, T),
        builtin.TypeId.Float => return try scanFloat(ps, T),
        builtin.TypeId.Bool => return try scanBool(ps),
        else => @compileError("Unable to format type '" ++ @typeName(T) ++ "'"),
    }
}

fn scanInt(ps: var, comptime Int: type) !Int {
    if (!Int.is_signed)
        return scanIntRest(ps, null, Int);

    const first = try ps.stream.readByte();
    return switch (first) {
        '+' => try scanIntRest(ps, null, Int),
        '-' => math.negate(try scanIntRest(ps, null, Int)),
        else => try scanIntRest(ps, first, Int),
    };
}

fn scanIntRest(ps: var, op_first: ?u8, comptime Int: type) !Int {
    const radix: u8 = 10;
    const first = op_first orelse try ps.stream.readByte();
    var res: Int = try math.cast(Int, try charToDigit(first, radix));

    while (true) {
        const byte = ps.stream.readByte() catch |err| switch (err) {
            error.EndOfStream => return res,
            else => return err,
        };

        const digit = charToDigit(byte, radix) catch {
            ps.putBackByte(byte);
            return res;
        };

        res = try math.mul(Int, res, try math.cast(Int, radix));
        res = try math.add(Int, res, try math.cast(Int, digit));
    }
}

fn scanFloat(ps: var, comptime Float: type) !Float {
    @compileError("TODO");
}

fn scanBool(ps: var) !bool {
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

pub fn charToDigit(c: u8, radix: u8) (error{InvalidCharacter}!u8) {
    const value = switch (c) {
        '0'...'9' => c - '0',
        'A'...'Z' => c - 'A' + 10,
        'a'...'z' => c - 'a' + 10,
        else => return error.InvalidCharacter,
    };

    if (value >= radix)
        return error.InvalidCharacter;

    return value;
}

test "scan.NoArgs" {
    const string = "abcd";
    inline for (string) |_, i| {
        var mem_stream = io.SliceInStream.init(string);
        var ps = io.PeekStream(1, io.SliceInStream.Error).init(&mem_stream.stream);

        _ = try scan(&ps, string[0 .. i + 1], struct {});
    }
}

fn testScanOk(comptime fmt: []const u8, str: []const u8, comptime T: type, res: T) !void {
    var mem_stream = io.SliceInStream.init(str);
    var ps = io.PeekStream(1, io.SliceInStream.Error).init(&mem_stream.stream);

    const result = try scan(&ps, fmt, struct {
        r: @typeOf(res),
    });
    debug.assert(result.r == res);
}

fn testScanError(comptime fmt: []const u8, str: []const u8, comptime T: type, err: anyerror) void {
    var mem_stream = io.SliceInStream.init(str);
    var ps = io.PeekStream(1, io.SliceInStream.Error).init(&mem_stream.stream);

    debug.assertError(scan(&ps, fmt, struct {
        i: T,
    }), err);
}

test "scanInt" {
    try testScanOk("{}", "0", i64, 0);
    try testScanOk("{}", "-0", i64, 0);
    try testScanOk("{}", "+0", i64, 0);
    try testScanOk("{}", "1", i64, 1);
    try testScanOk("{}", "-1", i64, -1);
    try testScanOk("{}", "+1", i64, 1);
    try testScanOk("{}", "99", i64, 99);
    try testScanOk("{}", "-99", i64, -99);
    try testScanOk("{}", "+99", i64, 99);
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

    testScanError("{}", "-0", u8, error.InvalidCharacter);
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
