const std = @import("std");
const bench = @import("bench");
const fun = @import("fun-with-zig");

const mem = std.mem;

const Searcher = fun.searcher.Searcher;

test "searcher.Searcher.benchmark" {
    try bench.benchmark(struct {
        const A = packed struct {
            a: u8,
            b: u8,
            c: u16,
            d: u32,
            e: u64,
        };

        const fill = [_]A{A{
            .a = 1,
            .b = 2,
            .c = 3,
            .d = 4,
            .e = 5,
        }};

        const find = [_]A{A{
            .a = 5,
            .b = 5,
            .c = 5,
            .d = 5,
            .e = 5,
        }};

        pub const args = [_][]const A{
            (fill ** 256) ++ find,
            find ++ (fill ** 256),
            (fill ** 128) ++ find ++ (fill ** 128),
        };

        pub fn @"Searcher (Skip 0)"(a: []const A) *const A {
            const s = Searcher(A, [_][]const []const u8{}).init(@sliceToBytes(a));
            return s.find(find[0]).?;
        }

        pub fn @"Searcher (Skip 1)"(a: []const A) *const A {
            const s = Searcher(A, [_][]const []const u8{[_][]const u8{"a"}}).init(@sliceToBytes(a));
            return s.find(find[0]).?;
        }

        pub fn @"Searcher (Skip 2)"(a: []const A) *const A {
            const s = Searcher(A, [_][]const []const u8{
                [_][]const u8{"a"},
                [_][]const u8{"b"},
            }).init(@sliceToBytes(a));
            return s.find(find[0]).?;
        }

        pub fn @"Searcher (Skip 3)"(a: []const A) *const A {
            const s = Searcher(A, [_][]const []const u8{
                [_][]const u8{"a"},
                [_][]const u8{"b"},
                [_][]const u8{"c"},
            }).init(@sliceToBytes(a));
            return s.find(find[0]).?;
        }

        pub fn @"Searcher (Skip 4)"(a: []const A) *const A {
            const s = Searcher(A, [_][]const []const u8{
                [_][]const u8{"a"},
                [_][]const u8{"b"},
                [_][]const u8{"c"},
                [_][]const u8{"d"},
            }).init(@sliceToBytes(a));
            return s.find(find[0]).?;
        }

        pub fn @"Searcher (Skip 5)"(a: []const A) *const A {
            const s = Searcher(A, [_][]const []const u8{
                [_][]const u8{"a"},
                [_][]const u8{"b"},
                [_][]const u8{"c"},
                [_][]const u8{"d"},
                [_][]const u8{"e"},
            }).init(@sliceToBytes(a));
            return s.find(find[0]).?;
        }

        pub fn @"mem.indexOf"(a: []const A) *const A {
            const i = mem.indexOf(u8, @sliceToBytes(a), @sliceToBytes(find[0..])).?;
            return &a[i / @sizeOf(A)];
        }
    });
}
