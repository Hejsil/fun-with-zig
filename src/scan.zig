const builtin = @import("builtin");
const std = @import("std");

const debug = std.debug;
const io = std.io;
const math = std.math;

pub fn scan(ps: var, comptime fmt: []const u8, args: ...) !void {
    comptime debug.assert(@typeOf(ps.*) == io.PeekStream(1, @typeOf(ps.stream).Error));
    const State = enum {
        Start,
        OpenBrace,
        CloseBrace,
    };

    comptime var start_index = 0;
    comptime var state = State.Start;
    comptime var next_arg = 0;

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
                    args[next_arg].* = try scanOne(ps, @typeOf(args[next_arg].*));
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
        if (args.len != next_arg) {
            @compileError("Unused arguments");
        }
        if (state != State.Start) {
            @compileError("Incomplete format string: " ++ fmt);
        }
    }
}

fn expect(ps: var, char: u8) !void {
    const byte = try ps.stream.readByte();
    if (byte != char)
        return error.InvalidCharacter;
}

fn scanOne(ps: var, comptime T: type) !T {
    switch (@typeInfo(T)) {
        builtin.TypeId.Int => return try scanInt(ps, T),
        builtin.TypeId.Float => @compileError("TODO"),
        builtin.TypeId.Bool => @compileError("TODO"),
        builtin.TypeId.Optional => @compileError("TODO"),
        builtin.TypeId.Enum => @compileError("TODO"),
        builtin.TypeId.Pointer => |ptr_info| switch (ptr_info.size) {
            builtin.TypeInfo.Pointer.Size.Slice => @compileError("TODO"),
            else => @compileError("Unable to format type '" ++ @typeName(T) ++ "'"),
        },
        builtin.TypeId.Array => |info| @compileError("TODO"),
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

pub fn charToDigit(c: u8, radix: u8) (error{InvalidCharacter}!u8) {
    const value = switch (c) {
        '0'...'9' => c - '0',
        'A'...'Z' => c - 'A' + 10,
        'a'...'z' => c - 'a' + 10,
        else => return error.InvalidCharacter,
    };

    if (value >= radix) return error.InvalidCharacter;

    return value;
}


test "scan.NoArgs" {
    const string = "abcd";
    inline for (string) |_, i| {
        var mem_stream = io.SliceInStream.init(string);
        var ps = io.PeekStream(1, io.SliceInStream.Error).init(&mem_stream.stream);

        try scan(&ps, string[0..i+1]);
    }
}

fn testScanIntOk(comptime fmt: []const u8, str: []const u8, res: i64) !void {
    var mem_stream = io.SliceInStream.init(str);
    var ps = io.PeekStream(1, io.SliceInStream.Error).init(&mem_stream.stream);

    var result: i64 = undefined;
    try scan(&ps, fmt, &result);
    debug.assert(result == res);
}

fn testScanIntError(comptime fmt: []const u8, str: []const u8, comptime Int: type, err: anyerror) void {
    var mem_stream = io.SliceInStream.init(str);
    var ps = io.PeekStream(1, io.SliceInStream.Error).init(&mem_stream.stream);

    var result: Int = undefined;
    debug.assertError(scan(&ps, fmt, &result), err);
}

test "scan.Int" {
    try testScanIntOk("{}", "0", 0);
    try testScanIntOk("{}", "-0", 0);
    try testScanIntOk("{}", "+0", 0);
    try testScanIntOk("{}", "1", 1);
    try testScanIntOk("{}", "-1", -1);
    try testScanIntOk("{}", "+1", 1);
    try testScanIntOk("{}", "99", 99);
    try testScanIntOk("{}", "-99", -99);
    try testScanIntOk("{}", "+99", 99);
    try testScanIntOk("{}a", "0a", 0);
    try testScanIntOk("{}a", "-0a", 0);
    try testScanIntOk("{}a", "+0a", 0);
    try testScanIntOk("{}a", "1a", 1);
    try testScanIntOk("{}a", "-1a", -1);
    try testScanIntOk("{}a", "+1a", 1);
    try testScanIntOk("{}a", "99a", 99);
    try testScanIntOk("{}a", "-99a", -99);
    try testScanIntOk("{}a", "+99a", 99);
    try testScanIntOk("a{}a", "a0a", 0);
    try testScanIntOk("a{}a", "a-0a", 0);
    try testScanIntOk("a{}a", "a+0a", 0);
    try testScanIntOk("a{}a", "a1a", 1);
    try testScanIntOk("a{}a", "a-1a", -1);
    try testScanIntOk("a{}a", "a+1a", 1);
    try testScanIntOk("a{}a", "a99a", 99);
    try testScanIntOk("a{}a", "a-99a", -99);
    try testScanIntOk("a{}a", "a+99a", 99);


    testScanIntError("{}", "-0", u8, error.InvalidCharacter);
    testScanIntError("{}", "a", u8, error.InvalidCharacter);
    testScanIntError("{}", "256", u8, error.Overflow);
    testScanIntError("{}", "-a", i8, error.InvalidCharacter);
    testScanIntError("{}", "a", i8, error.InvalidCharacter);
    testScanIntError("{}", "128", i8, error.Overflow);
    testScanIntError("{}", "-129", i8, error.Overflow);
}
