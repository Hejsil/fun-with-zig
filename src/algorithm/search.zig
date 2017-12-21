const Iterator = @import("../iterator.zig").Iterator;

pub fn all(comptime T: type, iter: &Iterator(&const T), predicate: fn(&const T) -> bool) -> bool {  
    while (iter.next()) |item| {
        if (!predicate(item)) return false;
    }

    return true;
}

pub fn allC(comptime TData: type, comptime TContext: type, 
    iter: &Iterator(&const TData), context: &const TContext,
    predicate: fn(&const TData, &const TContext) -> bool) -> bool {
    while (iter.next()) |item| {
        if (!predicate(item, context)) return false;
    }

    return true;
}

pub fn any(comptime T: type, iter: &Iterator(&const T), predicate: fn(&const T) -> bool) -> bool {    
    while (iter.next()) |item| {
        if (predicate(item)) return true;
    }

    return false;
}

pub fn anyC(comptime TData: type, comptime TContext: type, 
    iter: &Iterator(&const TData), context: &const TContext,
    predicate: fn(&const TData, &const TContext) -> bool) -> bool {
    while (iter.next()) |item| {
        if (predicate(item, context)) return true;
    }

    return false;
}