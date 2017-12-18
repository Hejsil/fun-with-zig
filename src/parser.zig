const debug = @import("std").debug;
const mem = @import("std").mem;
const Allocator = mem.Allocator;
const assert = debug.assert;

const Position = struct {
    const Self = this;

    index: u64,
    line: u64,
    column: u64,

    pub fn init(index: u64, line: u64, column: u64) -> Self {
        return Self {
            .index  = index,
            .line   = line,
            .column = column
        };
    }
};

const Input = struct {
    const Self = this;

    pos: Position,
    str: []const u8,

    pub fn init(str: []const u8) -> Self {
        return Self {
            .str = str,
            .pos = Position.init(0, 1, 1)
        };
    }

    pub fn peek(self: &const Self) -> ?u8 {
        return self.peekOffset(0);
    }

    pub fn peekOffset(self: &const Self, offset: u64) -> ?u8 {
        const index = self.pos.index + offset;
        return if (index < self.str.len) self.str[index] else null;
    }

    pub fn eat(self: &Self) -> ?u8 {
        if (self.str.len <= self.pos.index) return null;

        const result = self.str[self.pos.index];

        if (result == '\n') {
            self.pos.line += 1;
            self.pos.column = 0;
        }

        self.pos.index += 1;
        self.pos.column += 1;
        return result;
    }

    pub fn eatMany(self: &Self, count: u64) -> []const u8 {
        const start = self.pos.index;
        var i: usize = 0;
        while (i < count) : (i += 1) {
            _ = self.eat() ?? return self.str[start..self.pos.index];
        }

        return self.str[start..self.pos.index];
    }
};

error ParserError;

pub fn Parser(comptime T: type) -> type {
    return struct {
        const Self = this;

        parse: fn (&Allocator, &Input) -> %T,

        pub fn init(parse: fn (&Allocator, &Input) -> %T) -> Self {
            return Self { .parse = parse };
        }

        pub fn as(comptime self: &const Self, comptime K: type) -> Parser(K) {
            const Func = struct {
                fn parse(allocator: &Allocator, in: &Input) -> %K {
                    const res = %return self.parse(allocator, in);
                    return K(res);
                }
            };

            return Parser(K).init(Func.parse);
        }

        pub fn convert(comptime self: &const Self, comptime K: type, comptime converter: fn(&const T) -> %K) -> Parser(K) {
            const Func = struct {
                fn parse(allocator: &Allocator, in: &Input) -> %K {
                    const res = %return self.parse(allocator, in);
                    return converter(res);
                }
            };

            return Parser(K).init(Func.parse);
        }

        pub fn _or(comptime self: &const Self, comptime parser: Parser(T)) -> Parser(T) {
            const Func = struct {
                fn parse(allocator: &Allocator, in: &Input) -> %T {
                    const prev = in.pos;

                    return self.parse(allocator, in) %% {
                        in.pos = prev;
                        parser.parse(allocator, in)
                    };
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
                fn parse(allocator: &Allocator, in: &Input) -> %[2]T {
                    const res1 = %return self.parse(allocator, in);
                    // TODO: Figure out, how we deallocate res1, in case parser.parse failes. 
                    const res2 = %return parser.parse(allocator, in);
                    return [2]T{ res1, res2 };
                }
            };

            return Parser([2]T).init(Func.parse);
        }

        /// TODO: Same as _and
        pub fn repeat(comptime self: &const Self, comptime count: u64) -> Parser([count]T) {
            const Func = struct {
                fn parse(allocator: &Allocator, in: &Input) -> %[count]T {
                    var results : [count]T = undefined;

                    for (results) |_, i| {
                        // TODO: Figure out, how we deallocate results, in case self.parse failes.
                        results[i] = %return self.parse(allocator, in);
                    }

                    return results;
                }
            };

            return Parser([count]T).init(Func.parse);
        }
    };
}

pub fn any() -> Parser(u8) {
    const Func = struct {
        fn parse(allocator: &Allocator, in: &Input) -> %u8 {
            return in.eat() ?? error.ParserError;
        }
    };

    return Parser(u8).init(Func.parse);
}

test "parser.any" {
    const parser = comptime any();
    var input = Input.init("abc");
    const res1 = parser.parse(debug.global_allocator, &input) %% unreachable;
    const res2 = parser.parse(debug.global_allocator, &input) %% unreachable;
    const res3 = parser.parse(debug.global_allocator, &input) %% unreachable;
    assert(res1 == 'a');
    assert(res2 == 'b');
    assert(res3 == 'c');
    assert(input.pos.index == 3);
}

pub fn char(comptime chr: u8) -> Parser(u8) {
    const Func = struct {
        fn parse(allocator: &Allocator, in: &Input) -> %u8 {
            const result = in.eat() ?? return error.ParserError;

            if (result != chr) return error.ParserError;
            return result;
        }
    };

    return Parser(u8).init(Func.parse);
}

test "parser.char" {
    const a_parser = comptime char('a');
    const b_parser = comptime char('b');
    const c_parser = comptime char('c');
    var input = Input.init("abc");
    const res1 = a_parser.parse(debug.global_allocator, &input) %% unreachable;
    const res2 = b_parser.parse(debug.global_allocator, &input) %% unreachable;
    const res3 = c_parser.parse(debug.global_allocator, &input) %% unreachable;
    assert(res1 == 'a');
    assert(res2 == 'b');
    assert(res3 == 'c');
    assert(input.pos.index == 3);
}

pub fn range(comptime from: u8, comptime to: u8) -> Parser(u8) {
    comptime assert(from <= to);
    const Func = struct {
        fn parse(allocator: &Allocator, in: &Input) -> %u8 {
            const result = in.eat() ?? return error.ParserError;
                           
            if (result < from or to < result) return error.ParserError;
            return result;
        }
    };

    return Parser(u8).init(Func.parse);
}

test "parser.range" {
    const parser = comptime range('a', 'c');
    var input = Input.init("abc");
    const res1 = parser.parse(debug.global_allocator, &input) %% unreachable;
    const res2 = parser.parse(debug.global_allocator, &input) %% unreachable;
    const res3 = parser.parse(debug.global_allocator, &input) %% unreachable;
    assert(res1 == 'a');
    assert(res2 == 'b');
    assert(res3 == 'c');
    assert(input.pos.index == 3);
}

pub const digit = comptime range('0', '9');

test "parser.digit" {
    var input = Input.init("123");
    const res1 = digit.parse(debug.global_allocator, &input) %% unreachable;
    const res2 = digit.parse(debug.global_allocator, &input) %% unreachable;
    const res3 = digit.parse(debug.global_allocator, &input) %% unreachable;
    assert(res1 == '1');
    assert(res2 == '2');
    assert(res3 == '3');
    assert(input.pos.index == 3);
}

pub const lower = comptime range('a', 'z');

test "parser.lower" {
    var input = Input.init("abc");
    const res1 = lower.parse(debug.global_allocator, &input) %% unreachable;
    const res2 = lower.parse(debug.global_allocator, &input) %% unreachable;
    const res3 = lower.parse(debug.global_allocator, &input) %% unreachable;
    assert(res1 == 'a');
    assert(res2 == 'b');
    assert(res3 == 'c');
    assert(input.pos.index == 3);
}

pub const upper = comptime range('A', 'Z');

test "parser.upper" {
    var input = Input.init("ABC");
    const res1 = upper.parse(debug.global_allocator, &input) %% unreachable;
    const res2 = upper.parse(debug.global_allocator, &input) %% unreachable;
    const res3 = upper.parse(debug.global_allocator, &input) %% unreachable;
    assert(res1 == 'A');
    assert(res2 == 'B');
    assert(res3 == 'C');
    assert(input.pos.index == 3);
}

pub const alpha = comptime lower._or(upper);

test "parser.alpha" {
    var input = Input.init("abC");
    const res1 = alpha.parse(debug.global_allocator, &input) %% unreachable;
    const res2 = alpha.parse(debug.global_allocator, &input) %% unreachable;
    const res3 = alpha.parse(debug.global_allocator, &input) %% unreachable;
    assert(res1 == 'a');
    assert(res2 == 'b');
    assert(res3 == 'C');
    assert(input.pos.index == 3);
}

pub const whitespace = comptime 
    range('\t', '\r')    // \t,\n,\v,\f,\r
        ._or(char(' ')); // space

test "parser.whitespace" {
    var input = Input.init(" \t\n");
    const res1 = whitespace.parse(debug.global_allocator, &input) %% unreachable;
    const res2 = whitespace.parse(debug.global_allocator, &input) %% unreachable;
    const res3 = whitespace.parse(debug.global_allocator, &input) %% unreachable;
    assert(res1 == ' ');
    assert(res2 == '\t');
    assert(res3 == '\n');
    assert(input.pos.index == 3);
}

pub fn string(comptime str: []const u8) -> Parser([]const u8) {
    const Func = struct {
        fn parse(allocator: &Allocator, in: &Input) -> %[]const u8 {
            const result = in.eatMany(str.len);
            if (!mem.eql(u8, result, str)) return error.ParserError;
            return result;
        }
    };

    return Parser([]const u8).init(Func.parse);
}

test "parser.string" {
    var input = Input.init("abcd");
    const ab_parser = comptime string("ab");
    const cd_parser = comptime string("cd");
    const res1 = ab_parser.parse(debug.global_allocator, &input) %% unreachable;
    const res2 = cd_parser.parse(debug.global_allocator, &input) %% unreachable;
    assert(mem.eql(u8, res1, "ab"));
    assert(mem.eql(u8, res2, "cd"));
    assert(input.pos.index == 4);
}

test "parser.Parser.as" {
    var input = Input.init("abc");
    const parser = comptime any().as(f32);
    const res1 = parser.parse(debug.global_allocator, &input) %% unreachable;
    const res2 = parser.parse(debug.global_allocator, &input) %% unreachable;
    const res3 = parser.parse(debug.global_allocator, &input) %% unreachable;
    assert(res1 == f32('a'));
    assert(res2 == f32('b'));
    assert(res3 == f32('c'));
    assert(input.pos.index == 3);
}

test "parser.Parser.convert" {
    // TODO: Write test
}

test "parser.Parser._or" {
    const parser = comptime char('a')
        ._or(char('b'))
        ._or(char('c'));

    var input = Input.init("abc");
    const res1 = parser.parse(debug.global_allocator, &input) %% unreachable;
    const res2 = parser.parse(debug.global_allocator, &input) %% unreachable;
    const res3 = parser.parse(debug.global_allocator, &input) %% unreachable;
    assert(res1 == 'a');
    assert(res2 == 'b');
    assert(res3 == 'c');
    assert(input.pos.index == 3);
} 

fn toFoarString(str: &const [2][2]u8) -> %[4]u8 {
    return *@ptrCast(&const [4]u8, str);
}

test "parser.Parser._and" {
    const ab_parser = comptime char('a')._and(char('b'));
    const cd_parser = comptime char('c')._and(char('d'));
    const parser = comptime ab_parser._and(cd_parser).convert([4]u8, toFoarString);

    var input = Input.init("abcd");
    const res = parser.parse(debug.global_allocator, &input) %% unreachable;
    assert(mem.eql(u8, res, "abcd"));
    assert(input.pos.index == 4);
}

test "parser.Parser.repeat" {
    const a_parser = comptime char('a').repeat(3);
    const b_parser = comptime char('b').repeat(3);
    const c_parser = comptime char('c').repeat(3);

    var input = Input.init("aaabbbccc");
    const res1 = a_parser.parse(debug.global_allocator, &input) %% unreachable;
    const res2 = b_parser.parse(debug.global_allocator, &input) %% unreachable;
    const res3 = c_parser.parse(debug.global_allocator, &input) %% unreachable;
    assert(mem.eql(u8, res1, "aaa"));
    assert(mem.eql(u8, res2, "bbb"));
    assert(mem.eql(u8, res3, "ccc"));
    assert(input.pos.index == 9);
}


test "parser.Example: Expression Parser" {

}