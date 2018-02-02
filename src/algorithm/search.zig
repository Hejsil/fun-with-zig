const Iterator = @import("../iterator.zig").Iterator;

pub fn all(comptime T: type, iter: &Iterator(&const T), predicate: fn(&const T) bool) bool {
    while (iter.next()) |item| {
        if (!predicate(item)) return false;
    }

    return true;
}

pub fn allC(comptime TData: type, comptime TContext: type,
    iter: &Iterator(&const TData), context: &const TContext,
    predicate: fn(&const TData, &const TContext) bool) bool {
    while (iter.next()) |item| {
        if (!predicate(item, context)) return false;
    }

    return true;
}

pub fn any(comptime T: type, iter: &Iterator(&const T), predicate: fn(&const T) bool) bool {
    while (iter.next()) |item| {
        if (predicate(item)) return true;
    }

    return false;
}

pub fn anyC(comptime TData: type, comptime TContext: type,
    iter: &Iterator(&const TData), context: &const TContext,
    predicate: fn(&const TData, &const TContext) bool) bool {
    while (iter.next()) |item| {
        if (predicate(item, context)) return true;
    }

    return false;
}

pub fn first(comptime T: type, iter: &Iterator(&const T), predicate: fn(&const T) bool) ?T {
    while (iter.next()) |item| {
        if (predicate(item)) return *item;
    }

    return null;
}

pub fn firstC(comptime TData: type, comptime TContext: type,
    iter: &Iterator(&const TData), context: &const TContext,
    predicate: fn(&const TData, &const TContext) bool) ?TData {
    while (iter.next()) |item| {
        if (predicate(item, context)) return *item;
    }

    return null;
}

pub fn count(comptime T: type, iter: &Iterator(&const T), predicate: fn(&const T) bool) usize {
    var res : usize = 0;
    while (iter.next()) |item| {
        if (predicate(item)) i += 1;
    }

    return res;
}

pub fn countC(comptime TData: type, comptime TContext: type,
    iter: &Iterator(&const TData), context: &const TContext,
    predicate: fn(&const TData, &const TContext) bool) usize {
    var res : usize = 0;
    while (iter.next()) |item| {
        if (predicate(item, context)) i += 1;
    }

    return res;
}