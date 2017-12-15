const debug = @import("std").debug;
const assert = debug.assert;
const mem = @import("std").mem;

/// The result returned by a parser
pub fn Result(comptime T: type) -> type {
    return struct {
        const Self = this;

        result: T,
        rest: []const u8,

        pub fn init(result: &const T, rest: []const u8) -> Self {
            return Self {
                .result = *result,
                .rest = rest
            };
        }
    };
}

error ParserError;

pub fn Parser(comptime T: type) -> type {
    return struct {
        const Self = this;

        parse: fn ([]const u8) -> %Result(T),

        pub fn init(parse: fn ([]const u8) -> %Result(T)) -> Self {
            return Self { .parse = parse };
        }

        pub fn as(comptime self: &const Self, comptime K: type) -> Parser(K) {
            const Func = struct {
                fn parse(in: []const u8) -> %Result(K) {
                    const res = %return self.parse(in);
                    return Result(K).init(K(res.result), res.rest);
                }
            };

            return Parser(K).init(Func.parse);
        }

        pub fn convert(comptime self: &const Self, comptime K: type, comptime converter: fn(&const T) -> %K) -> Parser(K) {
            const Func = struct {
                fn parse(in: []const u8) -> %Result(K) {
                    const res = %return self.parse(in);
                    return Result(K).init(%return converter(res.result), res.rest);
                }
            };

            return Parser(K).init(Func.parse);
        }

        pub fn _or(comptime self: &const Self, comptime parser: Parser(T)) -> Parser(T) {
            const Func = struct {
                fn parse(in: []const u8) -> %Result(T) {
                    return self.parse(in) %% parser.parse(in);
                }
            };

            return Parser(T).init(Func.parse);
        }

        /// TODO: Figure out if there are performance benifits to returning a slice of the input string
        ///       if the result is u8 or []const u8. The compiler might be able to optimize it away.
        ///       It is however, sometimes a little anoying that if you combine mutible _ands, then
        ///       you get arrays of arrays. See test "Parser._and".
        pub fn _and(comptime self: &const Self, comptime parser: Parser(T)) -> Parser([2]T) {
            const Func = struct {
                fn parse(in: []const u8) -> %Result([2]T) {
                    const res1 = %return self.parse(in);
                    const res2 = %return parser.parse(res1.rest);
                    return Result([2]T).init([2]T{ res1.result, res2.result }, res2.rest);
                }
            };

            return Parser([2]T).init(Func.parse);
        }

        /// TODO: Same as _and
        pub fn repeat(comptime self: &const Self, comptime count: u64) -> Parser([count]T) {
            const Func = struct {
                fn parse(in: []const u8) -> %Result([count]T) {
                    var results : [count]T = undefined;
                    var rest = in;

                    for (results) |_, i| {
                        const res = %return self.parse(rest);
                        rest = res.rest;
                        results[i] = res.result;
                    }

                    return Result([count]T).init(results, rest);
                }
            };

            return Parser([count]T).init(Func.parse);
        }
    };
}

pub fn any() -> Parser(u8) {
    const Func = struct {
        fn parse(in: []const u8) -> %Result(u8) {
            const result = if (in.len > 0) in[0] 
                           else return error.ParserError;
            return Result(u8).init(result, in[1..]);
        }
    };

    return Parser(u8).init(Func.parse);
}

test "parser.any" {
    const input = "abc";
    const parser = comptime any();
    const res1 = parser.parse(input) %% unreachable;
    const res2 = parser.parse(res1.rest) %% unreachable;
    const res3 = parser.parse(res2.rest) %% unreachable;
    assert(res1.result == 'a');
    assert(res2.result == 'b');
    assert(res3.result == 'c');
    assert(res3.rest.len == 0);
}

pub fn char(comptime chr: u8) -> Parser(u8) {
    const Func = struct {
        fn parse(in: []const u8) -> %Result(u8) {
            const result = if (in.len > 0) in[0] 
                           else return error.ParserError;

            if (result != chr) return error.ParserError;
            return Result(u8).init(result, in[1..]);
        }
    };

    return Parser(u8).init(Func.parse);
}

test "parser.char" {
    const input = "abc";
    const a_parser = comptime char('a');
    const b_parser = comptime char('b');
    const c_parser = comptime char('c');
    const res1 = a_parser.parse(input) %% unreachable;
    const res2 = b_parser.parse(res1.rest) %% unreachable;
    const res3 = c_parser.parse(res2.rest) %% unreachable;
    assert(res1.result == 'a');
    assert(res2.result == 'b');
    assert(res3.result == 'c');
    assert(res3.rest.len == 0);
}

pub fn range(comptime from: u8, comptime to: u8) -> Parser(u8) {
    comptime assert(from <= to);
    const Func = struct {
        fn parse(in: []const u8) -> %Result(u8) {
            const result = if (in.len > 0) in[0] else 
                           return error.ParserError;
                           
            if (result < from or to < result) return error.ParserError;
            return Result(u8).init(result, in[1..]);
        }
    };

    return Parser(u8).init(Func.parse);
}

test "parser.range" {
    const input = "abc";
    const parser = comptime range('a', 'c');
    const res1 = parser.parse(input) %% unreachable;
    const res2 = parser.parse(res1.rest) %% unreachable;
    const res3 = parser.parse(res2.rest) %% unreachable;
    assert(res1.result == 'a');
    assert(res2.result == 'b');
    assert(res3.result == 'c');
    assert(res3.rest.len == 0);
}

pub const digit = comptime range('0', '9');

test "parser.digit" {
    const input = "123";
    const res1 = digit.parse(input) %% unreachable;
    const res2 = digit.parse(res1.rest) %% unreachable;
    const res3 = digit.parse(res2.rest) %% unreachable;
    assert(res1.result == '1');
    assert(res2.result == '2');
    assert(res3.result == '3');
    assert(res3.rest.len == 0);
}

pub const lower = comptime range('a', 'z');

test "parser.lower" {
    const input = "abc";
    const res1 = lower.parse(input) %% unreachable;
    const res2 = lower.parse(res1.rest) %% unreachable;
    const res3 = lower.parse(res2.rest) %% unreachable;
    assert(res1.result == 'a');
    assert(res2.result == 'b');
    assert(res3.result == 'c');
    assert(res3.rest.len == 0);
}

pub const upper = comptime range('A', 'Z');

test "parser.upper" {
    const input = "ABC";
    const res1 = upper.parse(input) %% unreachable;
    const res2 = upper.parse(res1.rest) %% unreachable;
    const res3 = upper.parse(res2.rest) %% unreachable;
    assert(res1.result == 'A');
    assert(res2.result == 'B');
    assert(res3.result == 'C');
    assert(res3.rest.len == 0);
}

pub const alpha = comptime lower._or(upper);

test "parser.alpha" {
    const input = "abC";
    const res1 = alpha.parse(input) %% unreachable;
    const res2 = alpha.parse(res1.rest) %% unreachable;
    const res3 = alpha.parse(res2.rest) %% unreachable;
    assert(res1.result == 'a');
    assert(res2.result == 'b');
    assert(res3.result == 'C');
    assert(res3.rest.len == 0);
}

pub const whitespace = comptime 
    range('\t', '\r')    // \t,\n,\v,\f,\r
        ._or(char(' ')); // space

test "parser.whitespace" {
    const input = " \t\n";
    const res1 = whitespace.parse(input) %% unreachable;
    const res2 = whitespace.parse(res1.rest) %% unreachable;
    const res3 = whitespace.parse(res2.rest) %% unreachable;
    assert(res1.result == ' ');
    assert(res2.result == '\t');
    assert(res3.result == '\n');
    assert(res3.rest.len == 0);
}

pub fn string(comptime str: []const u8) -> Parser([]const u8) {
    const Func = struct {
        fn parse(in: []const u8) -> %Result([]const u8) {
            const result = if (str.len <= in.len) in[0..str.len] 
                           else return error.ParserError;

            if (!mem.eql(u8, result, str)) return error.ParserError;
            return Result([]const u8).init(result, in[str.len..]);
        }
    };

    return Parser([]const u8).init(Func.parse);
}

test "parser.string" {
    const input = "abcd";
    const ab_parser = comptime string("ab");
    const cd_parser = comptime string("cd");
    const res1 = ab_parser.parse(input) %% unreachable;
    const res2 = cd_parser.parse(res1.rest) %% unreachable;
    assert(mem.eql(u8, res1.result, "ab"));
    assert(mem.eql(u8, res2.result, "cd"));
    assert(res2.rest.len == 0);
}

test "parser.Parser.as" {
    const input = "abc";
    const parser = comptime any().as(f32);
    const res1 = parser.parse(input) %% unreachable;
    const res2 = parser.parse(res1.rest) %% unreachable;
    const res3 = parser.parse(res2.rest) %% unreachable;
    assert(res1.result == f32('a'));
    assert(res2.result == f32('b'));
    assert(res3.result == f32('c'));
    assert(res3.rest.len == 0);
}

test "parser.Parser.convert" {
    // TODO: Write test
}

test "parser.Parser._or" {
    const input = "abc";
    const parser = comptime char('a')
        ._or(char('b'))
        ._or(char('c'));

    const res1 = parser.parse(input) %% unreachable;
    const res2 = parser.parse(res1.rest) %% unreachable;
    const res3 = parser.parse(res2.rest) %% unreachable;
    assert(res1.result == 'a');
    assert(res2.result == 'b');
    assert(res3.result == 'c');
    assert(res3.rest.len == 0);
} 

test "parser.Parser._and" {
    const toFourString = struct {
        fn func(str: &const [2][2]u8) -> %[4]u8 {
            return *@ptrCast(&const [4]u8, str);
        }
    }.func;
    const input = "abcd";
    const ab_parser = comptime char('a')._and(char('b'));
    const cd_parser = comptime char('c')._and(char('d'));
    const parser = comptime ab_parser._and(cd_parser).convert([4]u8, toFourString);

    const res = parser.parse(input) %% unreachable;
    assert(mem.eql(u8, res.result, "abcd"));
    assert(res.rest.len == 0);
}

test "parser.Parser.repeat" {
    const input = "aaabbbccc";
    const a_parser = comptime char('a').repeat(3);
    const b_parser = comptime char('b').repeat(3);
    const c_parser = comptime char('c').repeat(3);

    const res1 = a_parser.parse(input) %% unreachable;
    const res2 = b_parser.parse(res1.rest) %% unreachable;
    const res3 = c_parser.parse(res2.rest) %% unreachable;
    assert(mem.eql(u8, res1.result, "aaa"));
    assert(mem.eql(u8, res2.result, "bbb"));
    assert(mem.eql(u8, res3.result, "ccc"));
    assert(res3.rest.len == 0);
}


test "Example: Expression Parser" {

}