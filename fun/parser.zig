const std = @import("std");
const tuple = @import("fun/struct.zig");
const debug = std.debug;

pub const Tuple = tuple.Tuple;
pub const Unit = tuple.Unit;

fn Func(comptime TResult: type) type {
    return @typeOf(struct.{
        fn func(input: var) ?TResult {
            return undefined;
        }
    }.func);
}

pub fn Parser(comptime TResult: type, comptime parseFn: Func(TResult)) type {
    return struct.{
        pub const Result = TResult;

        pub fn parse(input: var) ?Result {
            const state = input.state();
            if (parseFn(input)) |result|
                return result;

            input.reset(state);
            return null;
        }
    };
}

pub fn eat(comptime Token: type, comptime kind: var) type {
    return Parser(Token, struct.{
        fn func(input: var) ?Token {
            return input.eat(kind);
        }
    }.func);
}

pub fn sequence(comptime parsers: []const type) type {
    const Res = SeqParserResult(parsers);
    return Parser(Res, struct.{
        fn func(input: var) ?Res {
            var res: Res = undefined;

            comptime var i = 0;
            inline while (i < @typeOf(res).len) : (i += 1) {
                const v = parsers[i].parse(input) orelse return null;
                res.set(i, v);
            }

            return res;
        }
    }.func);
}

fn SeqParserResult(comptime parsers: []const type) type {
    var results: [parsers.len]type = undefined;
    for (parsers) |Par, i|
        results[i] = Par.Result;

    return Tuple(results);
}

pub fn options(comptime parsers: []const type) type {
    const Res = SeqParserResult(parsers);
    return Parser(Res, struct.{
        fn func(input: var) ?Res {
            var res: Res = undefined;

            comptime var i = 0;
            inline while (i < @typeOf(res).len) : (i += 1) {
                const v = parsers[i].parse(input) orelse return null;
                res.set(i, v);
            }

            return res;
        }
    }.func);
}

pub const StringInput = struct.{
    str: []const u8,

    pub fn init(str: []const u8) StringInput {
        return StringInput.{
            .str = str,
            .i = 0,
        };
    }

    pub fn eat(input: *StringInput, kind: u8) ?u8 {
        if ()
        defer input.i += 1;
        return input.str[input.i];
    }
};

test "parser.eat" {
    const parser = eat(u8, 'a');

    var input = StringInput.init("a");
    const res = parser.parse(&input) orelse unreachable;

    debug.assert(res == 'a');
    debug.assert(input.str.len == input.i);
}

test "parser.sequence" {
    const a = eat(u8, 'a');
    const b = eat(u8, 'b');
    const c = eat(u8, 'c');
    const parser = sequence([]type.{a, b, c});

    var input = StringInput.init("abc");
    const res = parser.parse(&input) orelse unreachable;

    debug.assert(res.at(0) == 'a');
    debug.assert(res.at(1) == 'b');
    debug.assert(res.at(2) == 'c');
    debug.assert(input.str.len == input.i);
}
