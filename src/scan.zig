const builtin = @import("builtin");
const std = @import("std");

const debug = std.debug;
const heap = std.heap;
const io = std.io;
const math = std.math;
const mem = std.mem;

pub fn scan(allocator: *mem.Allocator, ps: var, comptime fmt: []const u8, comptime Res: type) !Res {
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
    if (@sizeOf(Res) != 0)
        mem.set(u8, mem.asBytes(&res), 0);

    errdefer {
        skip: inline for (fields) |f| switch (@typeInfo(f.field_type)) {
            builtin.TypeId.Pointer => |ptr| {
                if (ptr.size != builtin.TypeInfo.Pointer.Size.Slice)
                    continue :skip;

                allocator.free(@field(res, f.name));
            },
            else => {},
        };
    }

    inline for (fmt) |c, i| {
        switch (state) {
            State.Start => switch (c) {
                '{' => {
                    start_index = i + 1;
                    state = State.OpenBrace;
                },
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
                    const field = fields[next_arg];
                    const inner_fmt = fmt[start_index..i];
                    @field(res, field.name) = try scanOne(allocator, ps, inner_fmt, field.field_type);
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

fn scanOne(allocator: *mem.Allocator, ps: var, comptime fmt: []const u8, comptime T: type) !T {
    switch (@typeInfo(T)) {
        builtin.TypeId.Int => return try scanInt(ps, fmt, T),
        builtin.TypeId.Float => return try scanFloat(ps, fmt, T),
        builtin.TypeId.Bool => return try scanBool(ps, fmt),
        builtin.TypeId.Pointer => |ptr| {
            err: {
                if (ptr.size != builtin.TypeInfo.Pointer.Size.Slice)
                    break :err;
                if (ptr.child != u8)
                    break :err;

                return try scanString(allocator, ps, fmt);
            }

            @compileError("Unable to format type '" ++ @typeName(T) ++ "'");
        },
        else => @compileError("Unable to format type '" ++ @typeName(T) ++ "'"),
    }
}

fn scanInt(ps: var, comptime fmt: []const u8, comptime Int: type) !Int {
    const base: u8 = if (fmt.len == 0)
        u8(10)
    else switch(fmt[0]) {
        'b' => u8(2),
        'd' => u8(10),
        'x' => u8(16),
        else => @compileError("Unknown format character: " ++ []u8{fmt[0]}),
    };

    if (!Int.is_signed)
        return scanIntRest(ps, null, Int, base);

    const first = try ps.stream.readByte();
    return switch (first) {
        '+' => try scanIntRest(ps, null, Int, base),
        '-' => math.negate(try scanIntRest(ps, null, Int, base)),
        else => try scanIntRest(ps, first, Int, base),
    };
}

fn scanIntRest(ps: var, op_first: ?u8, comptime Int: type, base: u8) !Int {
    const first = op_first orelse try ps.stream.readByte();
    var res: Int = try math.cast(Int, try charToDigit(first, base));

    while (true) {
        const byte = ps.stream.readByte() catch |err| switch (err) {
            error.EndOfStream => return res,
            else => return err,
        };

        const digit = charToDigit(byte, base) catch {
            ps.putBackByte(byte);
            return res;
        };

        res = try math.mul(Int, res, try math.cast(Int, base));
        res = try math.add(Int, res, try math.cast(Int, digit));
    }
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

fn scanString(allocator: *mem.Allocator, ps: var, comptime fmt: []const u8) ![]u8 {
    const valid_chars = comptime blk: {
        const State = union(enum) {
            Begin,
            Char: u8,
            Escape,
            Range: u8,
        };

        var state: State = State.Begin;
        var res = []bool{false} ** (math.maxInt(u8) + 1);
        for (fmt) |c| switch (state) {
            State.Begin => switch (c) {
                '\\' => state = State.Escape,
                '-' => @compileError("TODO: Error"),
                else => state = State{.Char = c},
            },
            State.Char => |last| switch (c) {
                '\\' => {
                    res[last] = true;
                    state = State.Escape;
                },
                '-' => state = State{.Range = last},
                else => {
                    res[last] = true;
                    state = State{.Char = c};
                },
            },
            State.Escape => |last| switch (c) {
                '\\', '-' => state = State{.Char = c},
                else => @compileError("TODO: Error"),
            },
            State.Range => |first| switch (c) {
                '-' => @compileError("TODO: Error"),
                else => {
                    if (c < first)
                        @compileError("TODO: Error");

                    var i = first;
                    while (i < c) : (i += 1)
                        res[i] = true;

                    state = State.Begin;
                },
            },
        };

        switch (state) {
            State.Begin => {},
            State.Char => |last| res[last] = true,
            State.Escape => @compileError("TODO: Error"),
            State.Range => @compileError("TODO: Error"),
        }

        break :blk res;
    };

    return try scanValidChars(allocator, ps, valid_chars);
}

fn scanValidChars(allocator: *mem.Allocator, ps: var, valid: [math.maxInt(u8) + 1]bool) ![]u8 {
    var buf = try std.Buffer.initSize(allocator, 0);
    errdefer buf.deinit();

    while (true) {
        const byte = ps.stream.readByte() catch |err| switch (err) {
            error.EndOfStream => return buf.toOwnedSlice(),
            else => return err,
        };

        if (!valid[byte]) {
            ps.putBackByte(byte);
            return buf.toOwnedSlice();
        }

        try buf.appendByte(byte);
    }
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

test "scan.NoArgs" {
    var buf: [2 * 1024]u8 = undefined;
    var fix_buf_alloc = heap.FixedBufferAllocator.init(buf[0..]);
    const allocator = &fix_buf_alloc.allocator;

    const string = "abcd";
    inline for (string) |_, i| {
        var mem_stream = io.SliceInStream.init(string);
        var ps = io.PeekStream(1, io.SliceInStream.Error).init(&mem_stream.stream);

        _ = try scan(allocator, &ps, string[0 .. i + 1], struct {});
    }
}

fn testScanOk(comptime fmt: []const u8, str: []const u8, comptime T: type, res: T) !void {
    var buf: [2 * 1024]u8 = undefined;
    var fix_buf_alloc = heap.FixedBufferAllocator.init(buf[0..]);
    const allocator = &fix_buf_alloc.allocator;

    var mem_stream = io.SliceInStream.init(str);
    var ps = io.PeekStream(1, io.SliceInStream.Error).init(&mem_stream.stream);

    const result = try scan(allocator, &ps, fmt, struct {
        r: @typeOf(res),
    });
    switch (T) {
        []const u8, []u8 => debug.assert(mem.eql(u8, result.r, res)),
        else => debug.assert(result.r == res),
    }
}

fn testScanError(comptime fmt: []const u8, str: []const u8, comptime T: type, err: anyerror) void {
    var buf: [2 * 1024]u8 = undefined;
    var fix_buf_alloc = heap.FixedBufferAllocator.init(buf[0..]);
    const allocator = &fix_buf_alloc.allocator;

    var mem_stream = io.SliceInStream.init(str);
    var ps = io.PeekStream(1, io.SliceInStream.Error).init(&mem_stream.stream);

    debug.assertError(scan(allocator, &ps, fmt, struct {
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

test "scanString" {
    try testScanOk("{a}", "", []const u8, "");
    try testScanOk("{a}", "a", []const u8, "a");
    try testScanOk("{a}", "aa", []const u8, "aa");
    try testScanOk("{a-z}", "abcd", []const u8, "abcd");
    try testScanOk("a{a-z}", "abcd", []const u8, "bcd");
    try testScanOk("a{a-z}Z", "abcdZ", []const u8, "bcd");
    //try testScanOk("a{\\\\}c", "a-c", []const u8, "-");

    testScanError("a{}b", "acb", bool, error.InvalidCharacter);
}
