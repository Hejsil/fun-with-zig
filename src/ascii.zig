const std = @import("std");
const debug = std.debug;
const math = std.math;
const mem = std.mem;
const testing = std.testing;

pub fn isAlphanumeric(c: u7) bool {
    return isAlpha(c) or isDigit(c);
}

test "ascii.isAlphanumeric" {
    testing.expect(!isAlphanumeric('.'));
    testing.expect(isAlphanumeric('a'));
    testing.expect(isAlphanumeric('z'));
    testing.expect(isAlphanumeric('A'));
    testing.expect(isAlphanumeric('Z'));
    testing.expect(isAlphanumeric('0'));
    testing.expect(isAlphanumeric('9'));
    testing.expect(!isAlphanumeric(' '));
    testing.expect(!isAlphanumeric('\t'));
    testing.expect(!isAlphanumeric('\x00'));
    testing.expect(!isAlphanumeric('\x1f'));
    testing.expect(!isAlphanumeric('\x7f'));
}

pub fn isAlpha(c: u7) bool {
    return ('A' <= c and c <= 'Z') or
        ('a' <= c and c <= 'z');
}

test "ascii.isAlpha" {
    testing.expect(!isAlpha('.'));
    testing.expect(isAlpha('a'));
    testing.expect(isAlpha('z'));
    testing.expect(isAlpha('A'));
    testing.expect(isAlpha('Z'));
    testing.expect(!isAlpha('0'));
    testing.expect(!isAlpha('9'));
    testing.expect(!isAlpha(' '));
    testing.expect(!isAlpha('\t'));
    testing.expect(!isAlpha('\x00'));
    testing.expect(!isAlpha('\x1f'));
    testing.expect(!isAlpha('\x7f'));
}

pub fn isAscii(str: []const u8) bool {
    for (str) |c|
        _ = math.cast(u7, c) catch return false;

    return true;
}

test "ascii.isAscii" {
    testing.expect(isAscii("\x00abc\x7f"));
    testing.expect(!isAscii("\x80"));
    testing.expect(!isAscii("\xFF"));
}

pub fn asAsciiConst(str: []const u8) ![]const u7 {
    if (!isAscii(str))
        return error.IsNotAsciiString;

    return @bytesToSlice(u7, str);
}

test "ascii.asAsciiConst" {
    var str = "abc";
    var invalid_str = "\xFF";
    testing.expectEqualSlices(u7, @bytesToSlice(u7, str), try asAsciiConst(str[0..]));
    testing.expectError(error.IsNotAsciiString, if (asAsciiConst(invalid_str[0..])) invalid_str else |err| err);
}

pub fn asAscii(str: []u8) ![]u7 {
    if (!isAscii(str))
        return error.IsNotAsciiString;

    return @bytesToSlice(u7, str);
}

test "ascii.asAscii" {
    var str = "abc";
    var invalid_str = "\xFF";
    testing.expectEqualSlices(u7, @bytesToSlice(u7, str), try asAscii(str[0..]));
    testing.expectError(error.IsNotAsciiString, if (asAscii(invalid_str[0..])) invalid_str else |err| err);
}

pub fn isControl(c: u7) bool {
    return ('\x00' <= c and c <= '\x1f') or c == '\x7f';
}

test "ascii.isControl" {
    testing.expect(!isControl('.'));
    testing.expect(!isControl('a'));
    testing.expect(!isControl('z'));
    testing.expect(!isControl('A'));
    testing.expect(!isControl('Z'));
    testing.expect(!isControl('0'));
    testing.expect(!isControl('9'));
    testing.expect(!isControl(' '));
    testing.expect(isControl('\t'));
    testing.expect(isControl('\x00'));
    testing.expect(isControl('\x1f'));
    testing.expect(isControl('\x7f'));
}

pub fn isDigit(c: u7) bool {
    return '0' <= c and c <= '9';
}

test "ascii.isDigit" {
    testing.expect(!isDigit('.'));
    testing.expect(!isDigit('a'));
    testing.expect(!isDigit('z'));
    testing.expect(!isDigit('A'));
    testing.expect(!isDigit('Z'));
    testing.expect(isDigit('0'));
    testing.expect(isDigit('9'));
    testing.expect(!isDigit(' '));
    testing.expect(!isDigit('\t'));
    testing.expect(!isDigit('\x00'));
    testing.expect(!isDigit('\x1f'));
    testing.expect(!isDigit('\x7f'));
}

pub fn isGraph(c: u7) bool {
    return '!' <= c and c <= '~';
}

test "ascii.isGraph" {
    testing.expect(isGraph('.'));
    testing.expect(isGraph('a'));
    testing.expect(isGraph('z'));
    testing.expect(isGraph('A'));
    testing.expect(isGraph('Z'));
    testing.expect(isGraph('0'));
    testing.expect(isGraph('9'));
    testing.expect(!isGraph(' '));
    testing.expect(!isGraph('\t'));
    testing.expect(!isGraph('\x00'));
    testing.expect(!isGraph('\x1f'));
    testing.expect(!isGraph('\x7f'));
}

pub fn isLower(c: u7) bool {
    return 'a' <= c and c <= 'z';
}

test "ascii.isLower" {
    testing.expect(!isLower('.'));
    testing.expect(isLower('a'));
    testing.expect(isLower('z'));
    testing.expect(!isLower('A'));
    testing.expect(!isLower('Z'));
    testing.expect(!isLower('0'));
    testing.expect(!isLower('9'));
    testing.expect(!isLower(' '));
    testing.expect(!isLower('\t'));
    testing.expect(!isLower('\x00'));
    testing.expect(!isLower('\x1f'));
    testing.expect(!isLower('\x7f'));
}

pub fn isPrintable(c: u7) bool {
    return !isControl(c);
}

test "ascii.isPrintable" {
    testing.expect(isPrintable('-'));
    testing.expect(isPrintable('a'));
    testing.expect(isPrintable('z'));
    testing.expect(isPrintable('A'));
    testing.expect(isPrintable('Z'));
    testing.expect(isPrintable('0'));
    testing.expect(isPrintable('9'));
    testing.expect(isPrintable(' '));
    testing.expect(!isPrintable('\t'));
    testing.expect(!isPrintable('\x00'));
    testing.expect(!isPrintable('\x1f'));
    testing.expect(!isPrintable('\x7f'));
}

pub fn isPunctuation(c: u7) bool {
    return isGraph(c) and !isAlphanumeric(c);
}

test "ascii.isPunctuation" {
    testing.expect(isPunctuation('.'));
    testing.expect(!isPunctuation('a'));
    testing.expect(!isPunctuation('z'));
    testing.expect(!isPunctuation('A'));
    testing.expect(!isPunctuation('Z'));
    testing.expect(!isPunctuation('0'));
    testing.expect(!isPunctuation('9'));
    testing.expect(!isPunctuation(' '));
    testing.expect(!isPunctuation('\t'));
    testing.expect(!isPunctuation('\x00'));
    testing.expect(!isPunctuation('\x1f'));
    testing.expect(!isPunctuation('\x7f'));
}

pub fn isSpace(c: u7) bool {
    return c == ' ' or ('\t' <= c and c <= '\r');
}

test "ascii.isSpace" {
    testing.expect(!isSpace('.'));
    testing.expect(!isSpace('a'));
    testing.expect(!isSpace('z'));
    testing.expect(!isSpace('A'));
    testing.expect(!isSpace('Z'));
    testing.expect(!isSpace('0'));
    testing.expect(!isSpace('9'));
    testing.expect(isSpace(' '));
    testing.expect(isSpace('\t'));
    testing.expect(!isSpace('\x00'));
    testing.expect(!isSpace('\x1f'));
    testing.expect(!isSpace('\x7f'));
}

pub fn isUpper(c: u7) bool {
    return 'A' <= c and c <= 'Z';
}

test "ascii.isUpper" {
    testing.expect(!isUpper('.'));
    testing.expect(!isUpper('a'));
    testing.expect(!isUpper('z'));
    testing.expect(isUpper('A'));
    testing.expect(isUpper('Z'));
    testing.expect(!isUpper('0'));
    testing.expect(!isUpper('9'));
    testing.expect(!isUpper(' '));
    testing.expect(!isUpper('\t'));
    testing.expect(!isUpper('\x00'));
    testing.expect(!isUpper('\x1f'));
    testing.expect(!isUpper('\x7f'));
}

pub fn isHex(c: u7) bool {
    return isDigit(c) or
        ('a' <= c and c <= 'f') or
        ('A' <= c and c <= 'F');
}

test "ascii.isHex" {
    testing.expect(!isHex('.'));
    testing.expect(isHex('a'));
    testing.expect(!isHex('z'));
    testing.expect(isHex('A'));
    testing.expect(!isHex('Z'));
    testing.expect(isHex('0'));
    testing.expect(isHex('9'));
    testing.expect(!isHex(' '));
    testing.expect(!isHex('\t'));
    testing.expect(!isHex('\x00'));
    testing.expect(!isHex('\x1f'));
    testing.expect(!isHex('\x7f'));
}
