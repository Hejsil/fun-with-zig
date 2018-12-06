const bench = @import("bench");
const builtin = @import("builtin");
const generic = @import("generic/index.zig");
const std = @import("std");

const compare = generic.compare;
const debug = std.debug;
const mem = std.mem;

const TypeId = builtin.TypeId;
const TypeInfo = builtin.TypeInfo;

// A type for searching binary data for instances of ::T. It also allows ignoring of certain
// fields and nested fields.
pub fn Searcher(comptime T: type, comptime ignored_fields: []const []const []const u8) type {
    return struct {
        data: []const u8,

        pub fn init(data: []const u8) @This() {
            return @This(){ .data = data };
        }

        pub fn find(searcher: @This(), item: T) ?*const T {
            const slice = searcher.findSlice([]T{item}) orelse return null;
            return &slice[0];
        }

        pub fn findSlice(searcher: @This(), items: []const T) ?[]const T {
            return searcher.findSlice3(items, []T{});
        }

        pub fn findSlice2(searcher: @This(), start: T, end: T) ?[]const T {
            return searcher.findSlice3([]T{start}, []T{end}) orelse return null;
        }

        pub fn findSlice3(searcher: @This(), start: []const T, end: []const T) ?[]const T {
            const found_start = searcher.findSliceHelper(0, 1, start) orelse return null;
            const start_offset = @ptrToInt(found_start.ptr);
            const next_offset = (start_offset - @ptrToInt(searcher.data.ptr)) + start.len * @sizeOf(T);

            const found_end = searcher.findSliceHelper(next_offset, @sizeOf(T), end) orelse return null;
            const end_offset = @ptrToInt(found_end.ptr) + found_end.len * @sizeOf(T);
            const len = @divExact(end_offset - start_offset, @sizeOf(T));

            return found_start.ptr[0..len];
        }

        fn findSliceHelper(searcher: @This(), offset: usize, skip: usize, items: []const T) ?[]const T {
            const bytes = items.len * @sizeOf(T);
            if (searcher.data.len < bytes)
                return null;

            var i: usize = offset;
            const end = searcher.data.len - bytes;
            next: while (i <= end) : (i += skip) {
                const data_slice = searcher.data[i .. i + bytes];
                const data_items = @bytesToSlice(T, data_slice);
                for (items) |item_a, j| {
                    const item_b = data_items[j];
                    if (!matches(T, ignored_fields, item_a, item_b))
                        continue :next;
                }

                return data_items;
            }

            return null;
        }
    };
}

fn matches(comptime T: type, comptime ignored_fields: []const []const []const u8, a: T, b: T) bool {
    const info = @typeInfo(T);
    switch (info) {
        TypeId.Pointer => |ptr| switch (ptr.size) {
            TypeInfo.Pointer.Size.Slice => {
                return a.ptr == b.ptr and a.len == b.len;
            },
            else => return a == b,
        },
        TypeId.Array => {
            if (a.len != b.len)
                return false;

            for (a) |_, i| {
                if (!matches(T.Child, ignored_fields, a[i], b[i]))
                    return false;
            }

            return true;
        },
        TypeId.Optional => |optional| {
            const a_value = a orelse {
                return if (b) |_| false else true;
            };
            const b_value = b orelse return false;

            return matches(optional.child, ignored_fields, a_value, b_value);
        },
        TypeId.ErrorUnion => |err_union| {
            const a_value = a catch |a_err| {
                if (b) |_| {
                    return false;
                } else |b_err| {
                    return matches(err_union.error_set, ignored_fields, a_err, b_err);
                }
            };
            const b_value = b catch return false;

            return matches(err_union.payload, ignored_fields, a_value, b_value);
        },
        TypeId.Struct => |struct_info| {
            const next_ignored = comptime blk: {
                var res: []const []const []const u8 = [][]const []const u8{};
                for (ignored_fields) |fields| {
                    if (fields.len > 1)
                        res = res ++ fields[1..];
                }

                break :blk res;
            };

            ignore: inline for (struct_info.fields) |field| {
                inline for (ignored_fields) |fields| {
                    if (comptime fields.len == 1 and mem.eql(u8, fields[0], field.name))
                        continue :ignore;
                }

                if (!matches(field.field_type, next_ignored, @field(a, field.name), @field(b, field.name)))
                    return false;
            }

            return true;
        },
        else => return a == b,
    }
}

test "searcher.Searcher.find" {
    const S = packed struct {
        a: u16,
        b: u32,
    };
    const s_array = []S{
        S{ .a = 0, .b = 1 },
        S{ .a = 2, .b = 3 },
    };
    const s_byte_array = @sliceToBytes(s_array[0..]);
    const s_searcher1 = Searcher(S, [][]const []const u8{
        [][]const u8{"a"},
        [][]const u8{"hack"}, // TODO: https://github.com/ziglang/zig/issues/1608
    }).init(s_byte_array);
    const s_searcher2 = Searcher(S, [][]const []const u8{[][]const u8{"b"}}).init(s_byte_array);

    const search_for = S{ .a = 0, .b = 3 };
    debug.assert(s_searcher1.find(search_for).? == &s_array[1]);
    debug.assert(s_searcher2.find(search_for).? == &s_array[0]);
}

test "searcher.Searcher.findSlice" {
    const S = packed struct {
        a: u16,
        b: u32,
    };
    const s_array = []S{
        S{ .a = 4, .b = 1 },
        S{ .a = 0, .b = 3 },
        S{ .a = 4, .b = 1 },
    };
    const s_byte_array = @sliceToBytes(s_array[0..]);
    const s_searcher1 = Searcher(S, [][]const []const u8{
        [][]const u8{"a"},
        [][]const u8{"hack"}, // TODO: https://github.com/ziglang/zig/issues/1608
    }).init(s_byte_array);
    const s_searcher2 = Searcher(S, [][]const []const u8{[][]const u8{"b"}}).init(s_byte_array);

    const search_for = []S{
        S{ .a = 4, .b = 3 },
        S{ .a = 0, .b = 1 },
    };
    debug.assert(compare.equal([]const S, s_searcher1.findSlice(search_for).?, s_array[1..3]));
    debug.assert(compare.equal([]const S, s_searcher2.findSlice(search_for).?, s_array[0..2]));
}

test "searcher.Searcher.findSlice2" {
    const S = packed struct {
        a: u16,
        b: u32,
    };
    const s_array = []S{
        S{ .a = 4, .b = 1 },
        S{ .a = 0, .b = 3 },
        S{ .a = 4, .b = 1 },
        S{ .a = 0, .b = 3 },
    };
    const s_byte_array = @sliceToBytes(s_array[0..]);
    const s_searcher1 = Searcher(S, [][]const []const u8{
        [][]const u8{"a"},
        [][]const u8{"hack"}, // TODO: https://github.com/ziglang/zig/issues/1608
    }).init(s_byte_array);
    const s_searcher2 = Searcher(S, [][]const []const u8{[][]const u8{"b"}}).init(s_byte_array);

    const a = S{ .a = 4, .b = 3 };
    const b = S{ .a = 4, .b = 3 };
    debug.assert(compare.equal([]const S, s_searcher1.findSlice2(a, b).?, s_array[1..4]));
    debug.assert(compare.equal([]const S, s_searcher2.findSlice2(a, b).?, s_array[0..3]));
}

test "searcher.Searcher.findSlice3" {
    const S = packed struct {
        a: u16,
        b: u32,
    };
    const s_array = []S{
        S{ .a = 4, .b = 1 },
        S{ .a = 0, .b = 3 },
        S{ .a = 4, .b = 1 },
        S{ .a = 0, .b = 3 },
        S{ .a = 4, .b = 1 },
        S{ .a = 0, .b = 3 },
    };
    const s_byte_array = @sliceToBytes(s_array[0..]);
    const s_searcher1 = Searcher(S, [][]const []const u8{
        [][]const u8{"a"},
        [][]const u8{"hack"}, // TODO: https://github.com/ziglang/zig/issues/1608
    }).init(s_byte_array);
    const s_searcher2 = Searcher(S, [][]const []const u8{[][]const u8{"b"}}).init(s_byte_array);

    const a = []S{
        S{ .a = 4, .b = 3 },
        S{ .a = 0, .b = 1 },
    };
    const b = []S{
        S{ .a = 0, .b = 1 },
        S{ .a = 4, .b = 3 },
    };
    debug.assert(compare.equal([]const S, s_searcher1.findSlice3(a, b).?, s_array[1..6]));
    debug.assert(compare.equal([]const S, s_searcher2.findSlice3(a, b).?, s_array[0..5]));
}

test "searcher.Searcher.benchmark" {
    try bench.benchmark(struct {
        const A = packed struct {
            a: u8,
            b: u8,
            c: u16,
            d: u32,
            e: u64,
        };

        const fill = []A{A{
            .a = 1,
            .b = 2,
            .c = 3,
            .d = 4,
            .e = 5,
        }};

        const find = []A{A{
            .a = 5,
            .b = 5,
            .c = 5,
            .d = 5,
            .e = 5,
        }};

        const args = [][]const A{
            (fill ** 256) ++ find,
            find ++ (fill ** 256),
            (fill ** 128) ++ find ++ (fill ** 128),
        };

        fn @"Searcher (Skip 0)"(a: []const A) *const A {
            const s = Searcher(A, [][]const []const u8{}).init(@sliceToBytes(a));
            return s.find(find[0]).?;
        }

        fn @"Searcher (Skip 1)"(a: []const A) *const A {
            const s = Searcher(A, [][]const []const u8{[][]const u8{"a"}}).init(@sliceToBytes(a));
            return s.find(find[0]).?;
        }

        fn @"Searcher (Skip 2)"(a: []const A) *const A {
            const s = Searcher(A, [][]const []const u8{
                [][]const u8{"a"},
                [][]const u8{"b"},
            }).init(@sliceToBytes(a));
            return s.find(find[0]).?;
        }

        fn @"Searcher (Skip 3)"(a: []const A) *const A {
            const s = Searcher(A, [][]const []const u8{
                [][]const u8{"a"},
                [][]const u8{"b"},
                [][]const u8{"c"},
            }).init(@sliceToBytes(a));
            return s.find(find[0]).?;
        }

        fn @"Searcher (Skip 4)"(a: []const A) *const A {
            const s = Searcher(A, [][]const []const u8{
                [][]const u8{"a"},
                [][]const u8{"b"},
                [][]const u8{"c"},
                [][]const u8{"d"},
            }).init(@sliceToBytes(a));
            return s.find(find[0]).?;
        }

        fn @"Searcher (Skip 5)"(a: []const A) *const A {
            const s = Searcher(A, [][]const []const u8{
                [][]const u8{"a"},
                [][]const u8{"b"},
                [][]const u8{"c"},
                [][]const u8{"d"},
                [][]const u8{"e"},
            }).init(@sliceToBytes(a));
            return s.find(find[0]).?;
        }

        fn @"mem.indexOf"(a: []const A) *const A {
            const i = mem.indexOf(u8, @sliceToBytes(a), @sliceToBytes(find[0..])).?;
            return &a[i / @sizeOf(A)];
        }
    });
}
