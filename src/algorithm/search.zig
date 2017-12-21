pub fn all(comptime T: type, data: []const T, predicate: fn(&const T) -> bool) -> bool {    
    for (data) |*item| {
        if (!predicate(item)) return false;
    }

    return true;
}

pub fn allWithContext(comptime TData: type, comptime TContext: type, 
    data: []const TData, context: &const TContext,
    predicate: fn(&const TData, &const TContext) -> bool) -> bool {
    for (data) |*item| {
        if (!predicate(item, context)) return false;
    }

    return true;
}

pub fn any(comptime T: type, data: []const T, predicate: fn(&const T) -> bool) -> bool {    
    for (data) |*item| {
        if (predicate(item)) return true;
    }

    return false;
}

pub fn anyWithContext(comptime TData: type, comptime TContext: type, 
    data: []const TData, context: &const TContext,
    predicate: fn(&const TData, &const TContext) -> bool) -> bool {
    for (data) |*item| {
        if (predicate(item, context)) return true;
    }

    return false;
}