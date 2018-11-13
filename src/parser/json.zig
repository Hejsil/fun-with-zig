const std = @import("std");
use @import("parser.zig");
use @import("string.zig");

const debug = std.debug;
const math = std.math;
const mem = std.mem;
const fmt = std.fmt;

fn valueRef() type {
    return value;
}

const value = options([]type{
    object,
    array,
    jstring,
    number,
    string("true"),
    string("false"),
    string("null"),
});

const object = options([]type{
    sequence([]type{ char('{'), members, char('}') }),
    sequence([]type{ char('{'), ws, char('}') }),
});

const members = options([]type{
    sequence([]type{ member, char(','), members }),
    member,
});

const member = sequence([]type{ ws, string, ws, char(':'), element });

const array = options([]type{
    sequence([]type{ char('['), elements, char(']') }),
    sequence([]type{ char('['), ws, char(']') }),
});

const elements = options([]type{
    sequence([]type{ element, char(','), elements }),
    element,
});

const element = sequence([]type{ ws, ref(void, valueRef), ws });

const jstring = sequence([]type{ char('"'), characters, char('"') });

const characters = options([]type{
    sequence([]type{ character, characters }),
    character,
});

// TODO: Unicode
const character = options([]type{
    range(' ', '!'),
    range('#', '['),
    range(']', '~'),
    sequence([]type{ char('\\'), escape }),
});

const escape = options([]type{
    char('"'),
    char('\\'),
    char('/'),
    char('b'),
    char('n'),
    char('r'),
    char('t'),
    sequence([]type{ char('u'), hex, hex, hex, hex }),
});

const hex = options([]type{
    digit,
    range('A', 'F'),
    range('a', 'f'),
});

const number = sequence([]type{ int, frac, exp });

const int = options([]type{
    sequence([]type{ char('-'), onenine, digits }),
    sequence([]type{ char('-'), digit }),
    sequence([]type{ onenine, digits }),
    sequence([]type{digit}),
});

const digits = options([]type{
    sequence([]type{ digit, digits }),
    digit,
});

const digit = options([]type{
    char('0'),
    onenine,
});

const onenine = range('1', '9');

const frac = options([]type{
    sequence([]type{ char('.'), digits }),
    string(""),
});

const exp = options([]type{
    sequence([]type{ char('E'), sign, digits }),
    sequence([]type{ char('e'), sign, digits }),
    string(""),
});

const sign = options([]type{
    char('+'),
    char('-'),
    string(""),
});

fn wsRef() type {
    return ws;
}

const ws = options([]type{
    sequence([]type{ char(0x09), ref(u8, wsRef) }),
    sequence([]type{ char(0x0a), ref(u8, wsRef) }),
    sequence([]type{ char(0x0d), ref(u8, wsRef) }),
    sequence([]type{ char(0x20), ref(u8, wsRef) }),
    string(""),
});

//test "parser.json" {
//    _ = element.parse(Input.init("{}")) orelse unreachable;
//}
