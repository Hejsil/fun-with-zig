const std = @import("std");
const debug = std.debug;
const math = std.math;
const mem = std.mem;

pub fn isAlphanumeric(c: u7) bool {
    return isAlpha(c) or isDigit(c);
}

test "ascii.isAlphanumeric" {
    debug.assert(!isAlphanumeric('.'));
    debug.assert(isAlphanumeric('a'));
    debug.assert(isAlphanumeric('z'));
    debug.assert(isAlphanumeric('A'));
    debug.assert(isAlphanumeric('Z'));
    debug.assert(isAlphanumeric('0'));
    debug.assert(isAlphanumeric('9'));
    debug.assert(!isAlphanumeric(' '));
    debug.assert(!isAlphanumeric('\t'));
    debug.assert(!isAlphanumeric('\x00'));
    debug.assert(!isAlphanumeric('\x1f'));
    debug.assert(!isAlphanumeric('\x7f'));
}

pub fn isAlpha(c: u7) bool {
    return ('A' <= c and c <= 'Z') or
        ('a' <= c and c <= 'z');
}

test "ascii.isAlpha" {
    debug.assert(!isAlpha('.'));
    debug.assert(isAlpha('a'));
    debug.assert(isAlpha('z'));
    debug.assert(isAlpha('A'));
    debug.assert(isAlpha('Z'));
    debug.assert(!isAlpha('0'));
    debug.assert(!isAlpha('9'));
    debug.assert(!isAlpha(' '));
    debug.assert(!isAlpha('\t'));
    debug.assert(!isAlpha('\x00'));
    debug.assert(!isAlpha('\x1f'));
    debug.assert(!isAlpha('\x7f'));
}

pub fn isAscii(str: []const u8) bool {
    for (str) |c|
        _ = math.cast(u7, c) catch return false;

    return true;
}

test "ascii.isAscii" {
    debug.assert(isAscii("\x00abc\x7f"));
    debug.assert(!isAscii("\x80"));
    debug.assert(!isAscii("\xFF"));
}

pub fn asAsciiConst(str: []const u8) ![]const u7 {
    if (!isAscii(str))
        return error.IsNotAsciiString;

    return @bytesToSlice(u7, str);
}

test "ascii.asAsciiConst" {
    debug.assert(mem.eql(u7, try asAsciiConst("abc"), @bytesToSlice(u7, "abc")));
    debug.assertError(asAsciiConst("\xFF"), error.IsNotAsciiString);
}

pub fn asAscii(str: []u8) ![]u7 {
    if (!isAscii(str))
        return error.IsNotAsciiString;

    return @bytesToSlice(u7, str);
}

test "ascii.asAscii" {
    var str = "abc";
    var invalid_str = "\xFF";
    debug.assert(mem.eql(u7, try asAscii(str[0..]), @bytesToSlice(u7, str)));
    debug.assertError(asAscii(invalid_str[0..]), error.IsNotAsciiString);
}

pub fn isControl(c: u7) bool {
    return ('\x00' <= c and c <= '\x1f') or c == '\x7f';
}

test "ascii.isControl" {
    debug.assert(!isControl('.'));
    debug.assert(!isControl('a'));
    debug.assert(!isControl('z'));
    debug.assert(!isControl('A'));
    debug.assert(!isControl('Z'));
    debug.assert(!isControl('0'));
    debug.assert(!isControl('9'));
    debug.assert(!isControl(' '));
    debug.assert(isControl('\t'));
    debug.assert(isControl('\x00'));
    debug.assert(isControl('\x1f'));
    debug.assert(isControl('\x7f'));
}

pub fn isDigit(c: u7) bool {
    return '0' <= c and c <= '9';
}

test "ascii.isDigit" {
    debug.assert(!isDigit('.'));
    debug.assert(!isDigit('a'));
    debug.assert(!isDigit('z'));
    debug.assert(!isDigit('A'));
    debug.assert(!isDigit('Z'));
    debug.assert(isDigit('0'));
    debug.assert(isDigit('9'));
    debug.assert(!isDigit(' '));
    debug.assert(!isDigit('\t'));
    debug.assert(!isDigit('\x00'));
    debug.assert(!isDigit('\x1f'));
    debug.assert(!isDigit('\x7f'));
}

pub fn isGraph(c: u7) bool {
    return '!' <= c and c <= '~';
}

test "ascii.isGraph" {
    debug.assert(isGraph('.'));
    debug.assert(isGraph('a'));
    debug.assert(isGraph('z'));
    debug.assert(isGraph('A'));
    debug.assert(isGraph('Z'));
    debug.assert(isGraph('0'));
    debug.assert(isGraph('9'));
    debug.assert(!isGraph(' '));
    debug.assert(!isGraph('\t'));
    debug.assert(!isGraph('\x00'));
    debug.assert(!isGraph('\x1f'));
    debug.assert(!isGraph('\x7f'));
}

pub fn isLower(c: u7) bool {
    return 'a' <= c and c <= 'z';
}

test "ascii.isLower" {
    debug.assert(!isLower('.'));
    debug.assert(isLower('a'));
    debug.assert(isLower('z'));
    debug.assert(!isLower('A'));
    debug.assert(!isLower('Z'));
    debug.assert(!isLower('0'));
    debug.assert(!isLower('9'));
    debug.assert(!isLower(' '));
    debug.assert(!isLower('\t'));
    debug.assert(!isLower('\x00'));
    debug.assert(!isLower('\x1f'));
    debug.assert(!isLower('\x7f'));
}

pub fn isPrintable(c: u7) bool {
    return !isControl(c);
}

test "ascii.isPrintable" {
    debug.assert(isPrintable('-'));
    debug.assert(isPrintable('a'));
    debug.assert(isPrintable('z'));
    debug.assert(isPrintable('A'));
    debug.assert(isPrintable('Z'));
    debug.assert(isPrintable('0'));
    debug.assert(isPrintable('9'));
    debug.assert(isPrintable(' '));
    debug.assert(!isPrintable('\t'));
    debug.assert(!isPrintable('\x00'));
    debug.assert(!isPrintable('\x1f'));
    debug.assert(!isPrintable('\x7f'));
}

pub fn isPunctuation(c: u7) bool {
    return isGraph(c) and !isAlphanumeric(c);
}

test "ascii.isPunctuation" {
    debug.assert(isPunctuation('.'));
    debug.assert(!isPunctuation('a'));
    debug.assert(!isPunctuation('z'));
    debug.assert(!isPunctuation('A'));
    debug.assert(!isPunctuation('Z'));
    debug.assert(!isPunctuation('0'));
    debug.assert(!isPunctuation('9'));
    debug.assert(!isPunctuation(' '));
    debug.assert(!isPunctuation('\t'));
    debug.assert(!isPunctuation('\x00'));
    debug.assert(!isPunctuation('\x1f'));
    debug.assert(!isPunctuation('\x7f'));
}

pub fn isSpace(c: u7) bool {
    return c == ' ' or ('\t' <= c and c <= '\r');
}

test "ascii.isSpace" {
    debug.assert(!isSpace('.'));
    debug.assert(!isSpace('a'));
    debug.assert(!isSpace('z'));
    debug.assert(!isSpace('A'));
    debug.assert(!isSpace('Z'));
    debug.assert(!isSpace('0'));
    debug.assert(!isSpace('9'));
    debug.assert(isSpace(' '));
    debug.assert(isSpace('\t'));
    debug.assert(!isSpace('\x00'));
    debug.assert(!isSpace('\x1f'));
    debug.assert(!isSpace('\x7f'));
}

pub fn isUpper(c: u7) bool {
    return 'A' <= c and c <= 'Z';
}

test "ascii.isUpper" {
    debug.assert(!isUpper('.'));
    debug.assert(!isUpper('a'));
    debug.assert(!isUpper('z'));
    debug.assert(isUpper('A'));
    debug.assert(isUpper('Z'));
    debug.assert(!isUpper('0'));
    debug.assert(!isUpper('9'));
    debug.assert(!isUpper(' '));
    debug.assert(!isUpper('\t'));
    debug.assert(!isUpper('\x00'));
    debug.assert(!isUpper('\x1f'));
    debug.assert(!isUpper('\x7f'));
}

pub fn isHex(c: u7) bool {
    return isDigit(c) or
        ('a' <= c and c <= 'f') or
        ('A' <= c and c <= 'F');
}

test "ascii.isHex" {
    debug.assert(!isHex('.'));
    debug.assert(isHex('a'));
    debug.assert(!isHex('z'));
    debug.assert(isHex('A'));
    debug.assert(!isHex('Z'));
    debug.assert(isHex('0'));
    debug.assert(isHex('9'));
    debug.assert(!isHex(' '));
    debug.assert(!isHex('\t'));
    debug.assert(!isHex('\x00'));
    debug.assert(!isHex('\x1f'));
    debug.assert(!isHex('\x7f'));
}
