const std = @import("std");
const bench = @import("bench");
const fun = @import("fun-with-zig");

const mem = std.mem;

const StringSwitch = fun.match.StringSwitch;

// Alright, I though I was the smartest person alive making this StringSwitch.
// I was trying to make a nice abstraction, while having it be as fast or even
// faster than doing hash + mem.eql (which I've heard C# does for their switches).
// StringSwitch is indeed faster, but apparently, chaining mem.eql in ifs is the
// fastest... If we explore the assembly (https://godbolt.org/z/-07wYb), then we
// can see, that every method is being compiled into a lot of cmp + jmps (it looks
// like a state machine). It seems that the optimizer optimizes the code best when
// we use the naive approuch (which makes sense. They've probably spent a lot of
// time, optimizing this). I should learn more situations where the compiler can
// do transformations like these.
//
// ### Benchmarks ###
// ### debug
// Benchmark                          Mean(ns)
// -------------------------------------------
// switch_mem_eql.0                         30
// switch_mem_eql.1                         35
// switch_mem_eql.2                         40
// switch_mem_eql.3                         53
// switch_mem_eql.4                         72
// switch_mem_eql.5                        123
// switch_mem_eql.6                        202
// switch_mem_eql.7                        357
// switch_mem_eql.8                        672
// switch_mem_eql.9                       1365
// switch_mem_eql.10                      2762
// switch_mem_eql.11                       131
// switch_mem_eql.12                       212
// switch_mem_eql.13                       381
// switch_mem_eql.14                       758
// switch_mem_eql.15                      1402
// switch_mem_eql.16                      2728
// switch_mem_eql.17                      5181
// switch_mem_eql.18                     10158
// switch_StringSwitch.0                    30
// switch_StringSwitch.1                    35
// switch_StringSwitch.2                    42
// switch_StringSwitch.3                    55
// switch_StringSwitch.4                    81
// switch_StringSwitch.5                   137
// switch_StringSwitch.6                   246
// switch_StringSwitch.7                   460
// switch_StringSwitch.8                   853
// switch_StringSwitch.9                  1673
// switch_StringSwitch.10                 3268
// switch_StringSwitch.11                  171
// switch_StringSwitch.12                  283
// switch_StringSwitch.13                  484
// switch_StringSwitch.14                  893
// switch_StringSwitch.15                 1861
// switch_StringSwitch.16                 3309
// switch_StringSwitch.17                 6813
// switch_StringSwitch.18                13062
// switch_hash_mem_eql.0                    43
// switch_hash_mem_eql.1                    43
// switch_hash_mem_eql.2                    46
// switch_hash_mem_eql.3                    58
// switch_hash_mem_eql.4                    76
// switch_hash_mem_eql.5                   114
// switch_hash_mem_eql.6                   185
// switch_hash_mem_eql.7                   357
// switch_hash_mem_eql.8                   656
// switch_hash_mem_eql.9                  1267
// switch_hash_mem_eql.10                 2488
// switch_hash_mem_eql.11                  109
// switch_hash_mem_eql.12                  196
// switch_hash_mem_eql.13                  349
// switch_hash_mem_eql.14                  653
// switch_hash_mem_eql.15                 1261
// switch_hash_mem_eql.16                 2494
// switch_hash_mem_eql.17                 4942
// switch_hash_mem_eql.18                10529
// OK
//
// ### release-fast
// Benchmark                          Mean(ns)
// -------------------------------------------
// switch_mem_eql.0                         14
// switch_mem_eql.1                         14
// switch_mem_eql.2                         15
// switch_mem_eql.3                         15
// switch_mem_eql.4                         16
// switch_mem_eql.5                         17
// switch_mem_eql.6                         25
// switch_mem_eql.7                         39
// switch_mem_eql.8                         67
// switch_mem_eql.9                        124
// switch_mem_eql.10                       241
// switch_mem_eql.11                        17
// switch_mem_eql.12                        26
// switch_mem_eql.13                        41
// switch_mem_eql.14                        69
// switch_mem_eql.15                       124
// switch_mem_eql.16                       241
// switch_mem_eql.17                       465
// switch_mem_eql.18                       917
// switch_StringSwitch.0                    14
// switch_StringSwitch.1                    15
// switch_StringSwitch.2                    16
// switch_StringSwitch.3                    17
// switch_StringSwitch.4                    20
// switch_StringSwitch.5                    25
// switch_StringSwitch.6                    34
// switch_StringSwitch.7                    52
// switch_StringSwitch.8                    95
// switch_StringSwitch.9                   180
// switch_StringSwitch.10                  340
// switch_StringSwitch.11                   29
// switch_StringSwitch.12                   39
// switch_StringSwitch.13                   63
// switch_StringSwitch.14                  100
// switch_StringSwitch.15                  195
// switch_StringSwitch.16                  345
// switch_StringSwitch.17                  653
// switch_StringSwitch.18                 1250
// switch_hash_mem_eql.0                    15
// switch_hash_mem_eql.1                    16
// switch_hash_mem_eql.2                    16
// switch_hash_mem_eql.3                    19
// switch_hash_mem_eql.4                    25
// switch_hash_mem_eql.5                    39
// switch_hash_mem_eql.6                    67
// switch_hash_mem_eql.7                   124
// switch_hash_mem_eql.8                   235
// switch_hash_mem_eql.9                   459
// switch_hash_mem_eql.10                  908
// switch_hash_mem_eql.11                   39
// switch_hash_mem_eql.12                   67
// switch_hash_mem_eql.13                  123
// switch_hash_mem_eql.14                  237
// switch_hash_mem_eql.15                  458
// switch_hash_mem_eql.16                  910
// switch_hash_mem_eql.17                 1811
// switch_hash_mem_eql.18                 3596
// OK
//
// ### release-safe
// Benchmark                          Mean(ns)
// -------------------------------------------
// switch_mem_eql.0                         15
// switch_mem_eql.1                         15
// switch_mem_eql.2                         15
// switch_mem_eql.3                         15
// switch_mem_eql.4                         16
// switch_mem_eql.5                         18
// switch_mem_eql.6                         41
// switch_mem_eql.7                         50
// switch_mem_eql.8                         69
// switch_mem_eql.9                        125
// switch_mem_eql.10                       250
// switch_mem_eql.11                        18
// switch_mem_eql.12                        27
// switch_mem_eql.13                        42
// switch_mem_eql.14                        69
// switch_mem_eql.15                       125
// switch_mem_eql.16                       246
// switch_mem_eql.17                       493
// switch_mem_eql.18                       974
// switch_StringSwitch.0                    17
// switch_StringSwitch.1                    19
// switch_StringSwitch.2                    19
// switch_StringSwitch.3                    20
// switch_StringSwitch.4                    25
// switch_StringSwitch.5                    31
// switch_StringSwitch.6                    46
// switch_StringSwitch.7                    82
// switch_StringSwitch.8                   150
// switch_StringSwitch.9                   279
// switch_StringSwitch.10                  543
// switch_StringSwitch.11                   36
// switch_StringSwitch.12                   56
// switch_StringSwitch.13                   80
// switch_StringSwitch.14                  152
// switch_StringSwitch.15                  290
// switch_StringSwitch.16                  557
// switch_StringSwitch.17                 1052
// switch_StringSwitch.18                 2042
// switch_hash_mem_eql.0                    16
// switch_hash_mem_eql.1                    20
// switch_hash_mem_eql.2                    18
// switch_hash_mem_eql.3                    21
// switch_hash_mem_eql.4                    26
// switch_hash_mem_eql.5                    50
// switch_hash_mem_eql.6                    71
// switch_hash_mem_eql.7                   137
// switch_hash_mem_eql.8                   261
// switch_hash_mem_eql.9                   504
// switch_hash_mem_eql.10                 1021
// switch_hash_mem_eql.11                   44
// switch_hash_mem_eql.12                   73
// switch_hash_mem_eql.13                  134
// switch_hash_mem_eql.14                  254
// switch_hash_mem_eql.15                  494
// switch_hash_mem_eql.16                  946
// switch_hash_mem_eql.17                 1899
// switch_hash_mem_eql.18                 3783
// OK
//
// ### release-small
// Benchmark                          Mean(ns)
// -------------------------------------------
// switch_mem_eql.0                         14
// switch_mem_eql.1                         14
// switch_mem_eql.2                         14
// switch_mem_eql.3                         17
// switch_mem_eql.4                         19
// switch_mem_eql.5                         25
// switch_mem_eql.6                         39
// switch_mem_eql.7                         60
// switch_mem_eql.8                        102
// switch_mem_eql.9                        242
// switch_mem_eql.10                       465
// switch_mem_eql.11                        26
// switch_mem_eql.12                        39
// switch_mem_eql.13                        61
// switch_mem_eql.14                       102
// switch_mem_eql.15                       242
// switch_mem_eql.16                       354
// switch_mem_eql.17                       912
// switch_mem_eql.18                      1845
// switch_StringSwitch.0                    15
// switch_StringSwitch.1                    15
// switch_StringSwitch.2                    16
// switch_StringSwitch.3                    18
// switch_StringSwitch.4                    21
// switch_StringSwitch.5                    30
// switch_StringSwitch.6                    45
// switch_StringSwitch.7                    75
// switch_StringSwitch.8                   141
// switch_StringSwitch.9                   269
// switch_StringSwitch.10                  491
// switch_StringSwitch.11                   34
// switch_StringSwitch.12                   50
// switch_StringSwitch.13                   80
// switch_StringSwitch.14                  143
// switch_StringSwitch.15                  264
// switch_StringSwitch.16                  495
// switch_StringSwitch.17                  951
// switch_StringSwitch.18                 1854
// switch_hash_mem_eql.0                    14
// switch_hash_mem_eql.1                    15
// switch_hash_mem_eql.2                    17
// switch_hash_mem_eql.3                    18
// switch_hash_mem_eql.4                    25
// switch_hash_mem_eql.5                    39
// switch_hash_mem_eql.6                    67
// switch_hash_mem_eql.7                   124
// switch_hash_mem_eql.8                   234
// switch_hash_mem_eql.9                   460
// switch_hash_mem_eql.10                  906
// switch_hash_mem_eql.11                   39
// switch_hash_mem_eql.12                   68
// switch_hash_mem_eql.13                  123
// switch_hash_mem_eql.14                  234
// switch_hash_mem_eql.15                  460
// switch_hash_mem_eql.16                  905
// switch_hash_mem_eql.17                 1809
// switch_hash_mem_eql.18                 3594
// OK
test "match.StringSwitch.benchmark" {
    try bench.benchmark(struct {
        const args = [][]const u8{
            "A" ** 1,
            "A" ** 2,
            "A" ** 4,
            "A" ** 8,
            "A" ** 16,
            "A" ** 32,
            "A" ** 64,
            "A" ** 128,
            "A" ** 256,
            "A" ** 512,
            "A" ** 1024,
            "abcd" ** 8,
            "abcd" ** 16,
            "abcd" ** 32,
            "abcd" ** 64,
            "abcd" ** 128,
            "abcd" ** 256,
            "abcd" ** 512,
            "abcd" ** 1024,
        };

        fn switch_StringSwitch(str: []const u8) usize {
            @setEvalBranchQuota(100000);
            const sw = StringSwitch(args);
            switch (sw.match(str)) {
                sw.case("A" ** 1) => return 21,
                sw.case("A" ** 2) => return 15,
                sw.case("A" ** 4) => return 31,
                sw.case("A" ** 8) => return 111,
                sw.case("A" ** 16) => return 400,
                sw.case("A" ** 32) => return 2,
                sw.case("A" ** 64) => return 100000,
                sw.case("A" ** 128) => return 12345,
                sw.case("A" ** 256) => return 1,
                sw.case("A" ** 512) => return 35,
                sw.case("A" ** 1024) => return 99999999,
                sw.case("abcd" ** 8) => return 4,
                sw.case("abcd" ** 16) => return 1512,
                sw.case("abcd" ** 32) => return 152222,
                sw.case("abcd" ** 64) => return 42566,
                sw.case("abcd" ** 128) => return 66477,
                sw.case("abcd" ** 256) => return 345377,
                sw.case("abcd" ** 512) => return 745745,
                sw.case("abcd" ** 1024) => return 3444,
                else => return 2241255,
            }
        }

        fn switch_hash_mem_eql(str: []const u8) usize {
            @setEvalBranchQuota(100000);
            const hash = mem.hash_slice_u8;
            const eql = mem.eql_slice_u8;
            switch (hash(str)) {
                hash("A" ** 1) => {
                    if (!eql("A", str)) return 2241255;
                    return 21;
                },
                hash("A" ** 2) => {
                    if (!eql("A", str)) return 2241255;
                    return 15;
                },
                hash("A" ** 4) => {
                    if (!eql("A", str)) return 2241255;
                    return 31;
                },
                hash("A" ** 8) => {
                    if (!eql("A", str)) return 2241255;
                    return 111;
                },
                hash("A" ** 16) => {
                    if (!eql("A", str)) return 2241255;
                    return 400;
                },
                hash("A" ** 32) => {
                    if (!eql("A", str)) return 2241255;
                    return 2;
                },
                hash("A" ** 64) => {
                    if (!eql("A", str)) return 2241255;
                    return 100000;
                },
                hash("A" ** 128) => {
                    if (!eql("A", str)) return 2241255;
                    return 12345;
                },
                hash("A" ** 256) => {
                    if (!eql("A", str)) return 2241255;
                    return 1;
                },
                hash("A" ** 512) => {
                    if (!eql("A", str)) return 2241255;
                    return 35;
                },
                hash("A" ** 1024) => {
                    if (!eql("A", str)) return 2241255;
                    return 99999999;
                },
                hash("abcd" ** 8) => {
                    if (!eql("abcd", str)) return 2241255;
                    return 4;
                },
                hash("abcd" ** 16) => {
                    if (!eql("abcd", str)) return 2241255;
                    return 1512;
                },
                hash("abcd" ** 32) => {
                    if (!eql("abcd", str)) return 2241255;
                    return 152222;
                },
                hash("abcd" ** 64) => {
                    if (!eql("abcd", str)) return 2241255;
                    return 42566;
                },
                hash("abcd" ** 128) => {
                    if (!eql("abcd", str)) return 2241255;
                    return 66477;
                },
                hash("abcd" ** 256) => {
                    if (!eql("abcd", str)) return 2241255;
                    return 345377;
                },
                hash("abcd" ** 512) => {
                    if (!eql("abcd", str)) return 2241255;
                    return 745745;
                },
                hash("abcd" ** 1024) => {
                    if (!eql("abcd", str)) return 2241255;
                    return 3444;
                },
                else => return 2241255,
            }
        }

        fn switch_mem_eql(str: []const u8) usize {
            if (mem.eql(u8, "A" ** 1, str)) {
                return 21;
            } else if (mem.eql(u8, "A" ** 2, str)) {
                return 15;
            } else if (mem.eql(u8, "A" ** 4, str)) {
                return 31;
            } else if (mem.eql(u8, "A" ** 8, str)) {
                return 111;
            } else if (mem.eql(u8, "A" ** 16, str)) {
                return 400;
            } else if (mem.eql(u8, "A" ** 32, str)) {
                return 2;
            } else if (mem.eql(u8, "A" ** 64, str)) {
                return 100000;
            } else if (mem.eql(u8, "A" ** 128, str)) {
                return 12345;
            } else if (mem.eql(u8, "A" ** 256, str)) {
                return 1;
            } else if (mem.eql(u8, "A" ** 512, str)) {
                return 35;
            } else if (mem.eql(u8, "A" ** 1024, str)) {
                return 99999999;
            } else if (mem.eql(u8, "abcd" ** 8, str)) {
                return 4;
            } else if (mem.eql(u8, "abcd" ** 16, str)) {
                return 1512;
            } else if (mem.eql(u8, "abcd" ** 32, str)) {
                return 152222;
            } else if (mem.eql(u8, "abcd" ** 64, str)) {
                return 42566;
            } else if (mem.eql(u8, "abcd" ** 128, str)) {
                return 66477;
            } else if (mem.eql(u8, "abcd" ** 256, str)) {
                return 345377;
            } else if (mem.eql(u8, "abcd" ** 512, str)) {
                return 745745;
            } else if (mem.eql(u8, "abcd" ** 1024, str)) {
                return 3444;
            } else {
                return 2241255;
            }
        }
    });
}
