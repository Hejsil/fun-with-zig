const std = @import("std");
const debug = std.debug;
const mem = std.mem;
const assert = debug.assert;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;

pub const Position = struct {
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

pub const Input = struct {
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

pub fn CleanUp(comptime T: type) -> type {
    return fn(&const T, &Allocator);
}

pub fn Converter(comptime T: type, comptime K: type) -> type {
    return fn(&const T, &Allocator, CleanUp(T)) -> %K;
}

pub fn defaultCleanUp(comptime T: type) -> CleanUp(T) {
    return struct {
        fn cleanUp(value: &const T, allocator: &Allocator) { }
    }.cleanUp;
}

/// A parser that, given an input string, will return ::T on success.
pub fn Parser(comptime T: type) -> type {
    return ParserWithCleanup(T, comptime defaultCleanUp(T));
}

error ParserError;
error EOS;

/// A parser that, given an input string, will return ::T on success.
/// This version can have a custom clean up function.
pub fn ParserWithCleanup(comptime T: type, comptime clean: CleanUp(T)) -> type {
    return struct {
        const Self = this;
        const Returns = T;
        const cleanUp = clean;

        parse: fn (&Allocator, &Input) -> %T,

        pub fn init(parse: fn (&Allocator, &Input) -> %T) -> Self {
            return Self { .parse = parse };
        }

        /// Type casts ::T -> ::K.
        pub fn as(comptime self: &const Self, comptime K: type) -> Parser(K) {
            const Func = struct {
                fn parse(allocator: &Allocator, in: &Input) -> %K {
                    const res = %return self.parse(allocator, in);
                    return K(res);
                }
            };

            return Parser(K).init(Func.parse);
        }

        fn convertFunc(comptime self: &const Self, comptime K: type, comptime converter: Converter(T, K))
            -> fn(&Allocator, &Input) -> %K {
            return struct {
                fn parse(allocator: &Allocator, in: &Input) -> %K {
                    const prev = in.pos;
                    const res = %return self.parse(allocator, in);
                    return converter(res, allocator, cleanUp) %% |err| {
                        in.pos = prev;
                        cleanUp(res, allocator);
                        return err;
                    };
                }
            }.parse;
        }

        /// Converts ::T -> ::K using the provided ::converter.
        /// ::converter is responsible for calling cleanup on ::T on failure or
        /// if ::K doesn't take ownership of ::T.
        pub fn convert(comptime self: &const Self, comptime K: type, comptime converter: Converter(T, K)) -> Parser(K) {
            return Parser(K).init(self.convertFunc(K, converter));
        }

        /// Converts ::T -> ::K using the provided ::converter. ::convertWithCleanUp
        /// allowes the user to specify a ::newCleanUp function for ::K, so that
        /// furture parsers know how to clean up ::K on failure.
        /// ::converter is responsible for calling cleanup on ::T on failure or
        /// if ::K doesn't take ownership of ::T.
        pub fn convertWithCleanUp(comptime self: &const Self, comptime K: type, comptime converter: Converter(T, K), 
            comptime newCleanUp: CleanUp(K)) -> ParserWithCleanup(K, newCleanUp) {
            return ParserWithCleanup(K, newCleanUp).init(self.convertFunc(K, converter));
        }

        /// Parse with ::self. If that succeeds, return, otherwise parse using
        /// ::parser.
        pub fn _or(comptime self: &const Self, comptime parser: Self) -> Self {
            const Func = struct {
                fn parse(allocator: &Allocator, in: &Input) -> %T {
                    const prev = in.pos;

                    return self.parse(allocator, in) %% {
                        in.pos = prev;
                        return parser.parse(allocator, in);
                    };
                }
            };

            return Self.init(Func.parse);
        }

        
        fn sliceCleanUp(values: &const []T, allocator: &Allocator) {
            if (@sizeOf(T) > 0) {
                if (values.len > 0) {
            for (*values) |value| {
                cleanUp(value, allocator);
            }

            allocator.destroy(*values);
        }
        }
        }

        /// Parse ::self, then ::parser and return the result of both.
        pub fn then(comptime self: &const Self, comptime parser: Self) -> ParserWithCleanup([]T, sliceCleanUp) {
            const Func = struct {
                fn parse(allocator: &Allocator, in: &Input) -> %[]T {
                    const prev = in.pos;
                    %defer in.pos = prev;

                    const res1 = %return self.parse(allocator, in);
                    %defer cleanUp(res1, allocator);

                    const res2 = %return parser.parse(allocator, in);
                    %defer cleanUp(res2, allocator);

                    if (@sizeOf(T) > 0) {
                    const result = %return allocator.alloc(T, 2);
                    result[0] = res1;
                    result[1] = res2;
                        return result;
                    } else {
                        return []T{};
                    }

                }
            };

            return ParserWithCleanup([]T, sliceCleanUp).init(Func.parse);
        }

        /// Parse ::self ::count times.
        pub fn repeat(comptime self: &const Self, comptime count: u64) -> ParserWithCleanup([]T, sliceCleanUp) {
            const Func = struct {
                fn parse(allocator: &Allocator, in: &Input) -> %[]T {
                    const prev = in.pos;
                    if (@sizeOf(T) > 0) {
                    var results = %return allocator.alloc(T, count);

                    for (results) |_, i| {
                        results[i] = self.parse(allocator, in) %% |err| {
                                in.pos = prev;
                                sliceCleanUp(results[0..i], allocator);
                            return err;
                        };
                    }

                    return results;
                    } else {
                        %defer in.pos = prev;
                        var i : usize = 0;
                        while (i < count) : (i += 1) {
                            _ = %return self.parse(allocator, in);
                }

                        return []T{};
                    }
                }
            };

            return ParserWithCleanup([]T, sliceCleanUp).init(Func.parse);
        }

        /// Parse ::self until it failed.
        pub fn many(comptime self: &const Self) -> ParserWithCleanup([]T, sliceCleanUp) {
            const Func = struct {
                fn parse(allocator: &Allocator, in: &Input) -> %[]T {
                    if (@sizeOf(T) > 0) {
                        const prev = in.pos;
                    var results = ArrayList(T).init(allocator);

                    while (self.parse(allocator, in)) |value| {
                        results.append(value) %% |err| {
                                in.pos = prev;
                                sliceCleanUp(results.toOwnedSlice(), allocator);
                            return err;
                        };
                    } else |err| { }

                    return results.toOwnedSlice();
                    } else {
                        while (self.parse(allocator, in)) |value| {
                        } else |err| { }

                        return []T{};
                    }
                }
            };

            return ParserWithCleanup([]T, sliceCleanUp).init(Func.parse);
        }

        /// Parse ::self once and then until it failed.
        pub fn atLeastOnce(comptime self: &const Self) -> ParserWithCleanup([]T, sliceCleanUp) {
            const Func = struct {
                fn parse(allocator: &Allocator, in: &Input) -> %[]T {
                    if (@sizeOf(T) > 0) {
                        const prev = in.pos;
                        var results = ArrayList(T).init(allocator);

                        %defer {
                            in.pos = prev;
                            sliceCleanUp(results.toOwnedSlice(), allocator);
                        }

                        %return results.append(%return self.parse(allocator, in));

                        while (self.parse(allocator, in)) |value| {
                            %return results.append(value);
                        } else |err| { }

                        return results.toOwnedSlice();
                    } else {
                        while (self.parse(allocator, in)) |value| {
                        } else |err| { }

                        return []T{};
                    }
                }
            };

            return ParserWithCleanup([]T, sliceCleanUp).init(Func.parse);
        }

        pub fn discard(comptime self: &const Self) -> Parser(void) {
            const Func = struct {
                fn parse(allocator: &Allocator, in: &Input) -> %void {
                    cleanUp(%return self.parse(allocator, in), allocator);
                }
            };

            return Parser(void).init(Func.parse);
        }

        pub fn voidBefore(comptime self: &const Self, comptime before: Parser(void)) -> Self {
            const Func = struct {
                fn parse(allocator: &Allocator, in: &Input) -> %T {
                    const prev = in.pos;
                    %defer in.pos = prev;

                    _ = %return before.parse(allocator, in);
                    const result = %return self.parse(allocator, in);
                    return result;
                }
            };

            return Self.init(Func.parse);
        }

        pub fn voidAfter(comptime self: &const Self, comptime before: Parser(void)) -> Self {
            const Func = struct {
                fn parse(allocator: &Allocator, in: &Input) -> %T {
                    const prev = in.pos;
                    %defer in.pos = prev;

                    const result = %return self.parse(allocator, in);
                    %defer cleanUp(result, allocator);

                    _ = %return before.parse(allocator, in);
                    return result;
                }
    };

            return Self.init(Func.parse);
        }

        pub fn voidSurround(comptime self: &const Self, comptime left: Parser(void), comptime right: Parser(void)) -> Self {
            return self.voidBefore(left).voidAfter(right);
        }

        pub fn trim(comptime self: &const Self) -> Self {
            const trimmer = comptime whitespace.discard().many().discard();
            return self.voidSurround(trimmer, trimmer);
}
    };
}

/// A parser that matches any character.
pub fn any() -> Parser(u8) {
    const Func = struct {
        fn parse(allocator: &Allocator, in: &Input) -> %u8 {
            return in.eat() ?? error.EOS;
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

/// A parser that matches end of string.
pub fn end() -> Parser(void) {
    const Func = struct {
        fn parse(allocator: &Allocator, in: &Input) -> %void {
            const prev = in.pos;
            _ = in.eat() ?? return;

            in.pos = prev;
            return error.ParserError;
        }
    };

    return Parser(void).init(Func.parse);
}

/// A parser that matches a specific character.
pub fn char(comptime chr: u8) -> Parser(u8) {
    const Func = struct {
        fn parse(allocator: &Allocator, in: &Input) -> %u8 {
            const prev = in.pos;
            %defer in.pos = prev;

            const result = in.eat() ?? return error.EOS;

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

/// A parser that matches a characters where ::from <= c and c <= ::to.
pub fn range(comptime from: u8, comptime to: u8) -> Parser(u8) {
    comptime assert(from <= to);
    const Func = struct {
        fn parse(allocator: &Allocator, in: &Input) -> %u8 {
            const prev = in.pos;
            %defer in.pos = prev;

            const result = in.eat() ?? return error.EOS;
                           
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

/// A parser that matches a digit.
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

/// A parser that matches a lower case character.
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

/// A parser that matches a upper case character.
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

/// A parser that matches an alphabetical character.
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

/// A parser that matches a whitespace.
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

/// A parser that matches a string.
pub fn string(comptime str: []const u8) -> Parser([]const u8) {
    const Func = struct {
        fn parse(allocator: &Allocator, in: &Input) -> %[]const u8 {
            const prev = in.pos;
            %defer in.pos = prev;

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

pub fn ref(comptime T: type, comptime cleanUp: CleanUp(T), comptime refFunc: fn () -> &const ParserWithCleanup(T, cleanUp)) 
    -> ParserWithCleanup(T, cleanUp) {
    const Func = struct {
        fn parse(allocator: &Allocator, in: &Input) -> %T {
            return refFunc().parse(allocator, in);
        }
    };

    return ParserWithCleanup(T, cleanUp).init(Func.parse);
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

test "parser.Parser.then" {
    const ab_parser = comptime char('a').then(char('b'));
    const cd_parser = comptime char('c').then(char('d'));
    const parser = comptime ab_parser.then(cd_parser);

    var input = Input.init("abcd");
    const res = parser.parse(debug.global_allocator, &input) %% unreachable;
    assert(mem.eql(u8, res[0], "ab"));
    assert(mem.eql(u8, res[1], "cd"));
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

test "parser.Parser.many" {
    const asParser = comptime char('a').many();

    var input = Input.init("aaaaa");
    const res = asParser.parse(debug.global_allocator, &input) %% unreachable;
    assert(mem.eql(u8, res, "aaaaa"));
    assert(input.pos.index == 5);
}

test "parser.Parser.atLeastOnce" {
    const asParser = comptime char('a').atLeastOnce();

    {
        var input = Input.init("aaaaa");
        const res = asParser.parse(debug.global_allocator, &input) %% unreachable;
        assert(mem.eql(u8, res, "aaaaa"));
        assert(input.pos.index == 5);
    }

    {
        var input = Input.init("");
        if (asParser.parse(debug.global_allocator, &input)) |res| {
            assert(false);
        } else |err| { }
    }
}

test "parser.Parser.trim" {
    const aParser = comptime char('a').trim();

    var input = Input.init("   a       ");
    const res = aParser.parse(debug.global_allocator, &input) %% unreachable;
    assert(res == 'a');
    assert(input.pos.index == 11);
}