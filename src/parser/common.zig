const string = @import("string.zig");

const std = @import("std");
const @"struct" = @import("../struct.zig");
const @"union" = @import("../union.zig");

const StructField = @"struct".Field;
const Struct = @"struct".Struct;
const UnionField = @"union".Field;
const Union = @"union".Union;

const debug = std.debug;
const mem = std.mem;
const testing = std.testing;

pub fn ParseResult(comptime Input: type, comptime Result: type) type {
    return struct {
        input: Input,
        result: Result,
    };
}

fn Func(comptime Result: type) type {
    return @TypeOf(struct {
        fn func(input: var) ?ParseResult(@TypeOf(input), Result) {
            unreachable;
        }
    }.func);
}

pub fn eatIf(comptime Token: type, comptime predicate: fn (Token) bool) type {
    return struct {
        pub const Result = Token;

        pub fn parse(input: var) ?ParseResult(@TypeOf(input), Result) {
            const curr = input.curr() orelse return null;
            if (!predicate(curr))
                return null;

            return ParseResult(@TypeOf(input), Result){
                .input = input.next(),
                .result = curr,
            };
        }
    };
}

pub fn end() type {
    return struct {
        pub const Result = void;

        pub fn parse(input: var) ?ParseResult(@TypeOf(input), Result) {
            if (input.curr() == null) {
                return ParseResult(@TypeOf(input), void){
                    .input = input,
                    .result = {},
                };
            }

            return null;
        }
    };
}

pub fn sequence(comptime parsers: []const type) type {
    return struct {
        pub const Result = SeqParserResult(parsers);

        pub fn parse(input: var) ?ParseResult(@TypeOf(input), Result) {
            var res: Result = undefined;
            var next = input;

            inline for (@TypeOf(res).fields) |field, i| {
                const r = parsers[i].parse(next) orelse return null;
                next = r.input;
                res.ptr(i).* = r.result;
            }

            return ParseResult(@TypeOf(input), Result){
                .input = next,
                .result = res,
            };
        }
    };
}

fn SeqParserResult(comptime parsers: []const type) type {
    var results: [parsers.len]StructField(usize) = undefined;
    for (parsers) |Par, i|
        results[i] = StructField(usize).init(i, Par.Result);

    return Struct(usize, results);
}

pub fn options(comptime parsers: []const type) type {
    return struct {
        pub const Result = OptParserResult(parsers);

        pub fn parse(input: var) ?ParseResult(@TypeOf(input), Result) {
            inline for (parsers) |Par| {
                if (Par.parse(input)) |res| {
                    return ParseResult(@TypeOf(input), Result){
                        .input = res.input,
                        .result = res.result,
                    };
                }
            }

            return null;
        }
    };
}

fn OptParserResult(comptime parsers: []const type) type {
    debug.assert(parsers.len != 0);
    const Res = parsers[0].Result;
    for (parsers[1..]) |Par| {
        //@compileLog(Par.Result, Res);
        debug.assert(Par.Result == Res);
    }

    return Res;
}

pub fn then(
    comptime Parser: type,
    comptime Res: type,
    comptime func: fn (Parser.Result) Res,
) type {
    return struct {
        pub const Result = Res;

        pub fn parse(input: var) ?ParseResult(@TypeOf(input), Result) {
            const parsed = Parser.parse(input) orelse return null;
            const res = func(parsed.result);
            return ParseResult(@TypeOf(input), Result){
                .input = parsed.input,
                .result = res,
            };
        }
    };
}

pub fn toVoid(comptime T: type) fn (T) void {
    return struct {
        fn toVoid(arg: T) void {}
    }.toVoid;
}

pub const nothing = struct {
    pub const Result = void;

    pub fn parse(input: var) ?ParseResult(@TypeOf(input), Result) {
        return ParseResult(@TypeOf(input), Result){
            .input = input,
            .result = {},
        };
    }
};

fn refFunc() type {
    unreachable;
}

pub fn ref(comptime Res: type, comptime f: @TypeOf(refFunc)) type {
    return struct {
        pub const Result = Res;

        pub fn parse(input: var) ?ParseResult(@TypeOf(input), Result) {
            return f().parse(input);
        }
    };
}

fn isPred(comptime c: u8) fn (u8) bool {
    return struct {
        fn predicate(char: u8) bool {
            return char == c;
        }
    }.predicate;
}

fn testSuccess(comptime P: type, str: []const u8, result: var) void {
    const res = P.parse(string.Input.init(str)) orelse unreachable;
    comptime testing.expectEqual(@sizeOf(P.Result), @sizeOf(@TypeOf(result)));
    if (@sizeOf(P.Result) != 0)
        testing.expectEqualSlices(u8, &mem.toBytes(result), &mem.toBytes(res.result));
}

fn testFail(comptime P: type, str: []const u8) void {
    if (P.parse(string.Input.init(str))) |res| {
        testing.expect(res.input.str.len != 0);
    }
}

test "parser.eatIf" {
    const P = eatIf(u8, comptime isPred('a'));

    testSuccess(P, "a", @as(u8, 'a'));
    testFail(P, "b");
}

test "parser.end" {
    const P = end();

    testSuccess(P, "", {});
    testFail(P, "b");
}

test "parser.sequence" {
    const A = eatIf(u8, comptime isPred('a'));
    const B = eatIf(u8, comptime isPred('b'));
    const C = eatIf(u8, comptime isPred('c'));
    const P = sequence([_]type{ A, B, C });

    testSuccess(P, "abc", "abc");
    testFail(P, "cba");
}

test "parser.options" {
    const A = eatIf(u8, comptime isPred('a'));
    const B = eatIf(u8, comptime isPred('b'));
    const C = eatIf(u8, comptime isPred('c'));
    const P = options(&[_]type{ A, B, C });

    testSuccess(P, "a", @as(u8, 'a'));
    testSuccess(P, "b", @as(u8, 'b'));
    testSuccess(P, "c", @as(u8, 'c'));
    testFail(P, "d");
}

test "parser.options" {
    const A = eatIf(u8, comptime isPred('a'));
    const B = eatIf(u8, comptime isPred('b'));
    const C = eatIf(u8, comptime isPred('c'));
    const P = options(&[_]type{ A, B, C });

    testSuccess(P, "a", @as(u8, 'a'));
    testSuccess(P, "b", @as(u8, 'b'));
    testSuccess(P, "c", @as(u8, 'c'));
    testFail(P, "d");
}

test "parser.then" {
    const A = eatIf(u8, comptime isPred('a'));
    const B = eatIf(u8, comptime isPred('b'));
    const S = sequence(&[_]type{ A, B });
    const P = options(&[_]type{
        then(S, void, comptime toVoid(S.Result)),
        then(A, void, comptime toVoid(A.Result)),
    });

    testSuccess(P, "a", {});
    testSuccess(P, "ab", {});
    testFail(P, "ba");
}

test "parser.nothing" {
    testSuccess(nothing, "a", {});
    testSuccess(nothing, "aaa", {});
    testSuccess(nothing, "qqq", {});
    testSuccess(nothing, "", {});
    testSuccess(nothing, "2", {});
    testSuccess(nothing, "10", {});
}
