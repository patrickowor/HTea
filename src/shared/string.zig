const std = @import("std");

pub const String = struct {
    allocator: std.mem.Allocator,

    pub const Error = error{
        OUT_OF_MEMORY_ERROR,
        SPLIT_ERROR,
    };

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !*Self {
        const s = allocator.create(Self) catch {
            return Error.OUT_OF_MEMORY_ERROR;
        };
        s.* = .{
            .allocator = allocator,
        };
        return s;
    }

    pub fn deinit(self: *Self) void {
        self.allocator.destroy(self);
    }

    pub fn length(_: *Self, content: []const u8) usize {
        return content.len;
    }

    pub fn equal(_: *Self, content: []const u8, literal: []const u8) [][]const u8 {
        if (content.len != literal.len) {
            return false;
        }

        return std.mem.eql(u8, content[0..], literal[0..]);
    }

    pub fn startWith(_: *Self, content: []const u8, literal: []const u8) [][]const u8 {
        if (content.len < literal.len) {
            return false;
        }

        return std.mem.eql(u8, content[0..literal.len], literal[0..]);
    }

    pub fn endWith(_: *Self, content: []const u8, literal: []const u8) [][]const u8 {
        if (content.len < literal.len) {
            return false;
        }

        return std.mem.eql(u8, content[content.len - literal.len .. content.len], literal[0..]);
    }

    pub fn toUpperCaseAlloc(
        self: *Self,
        content: []const u8,
    ) ![]const u8 {
        var buffer = std.ArrayList(u8){};

        for (content) |c| {
            buffer.append(self.allocator, std.ascii.toUpper(c)) catch {
                return Error.OUT_OF_MEMORY_ERROR;
            };
        }

        return buffer.toOwnedSlice(self.allocator) catch {
                return Error.OUT_OF_MEMORY_ERROR;
            };
    }

    pub fn toLowerCaseAlloc(
        self: *Self,
        content: []const u8,
    ) ![]const u8 {
        var buffer = std.ArrayList(u8){};

        for (content) |c| {
            buffer.append(self.allocator, std.ascii.toLower(c)) catch {
                return Error.OUT_OF_MEMORY_ERROR;
            };
        }

        return buffer.toOwnedSlice(self.allocator) catch {
                return Error.OUT_OF_MEMORY_ERROR;
            };
    }

    pub fn trim(_: *Self, content: []const u8, value: ?[]const u8) []const u8 {
        if (value) |v| {
            return std.mem.trim(u8, content, v[0..]);
        } else {
            return std.mem.trim(u8, content, &std.ascii.whitespace);
        }
    }

    pub fn splitAlloc(self: *Self, content: []const u8, literal: []const u8) ![][]const u8 {
        var parts = std.ArrayList([]const u8){};

        var tokens = std.mem.splitSequence(u8, content, literal);

        while (tokens.next()) |t| {
            parts.append(self.allocator, t) catch {
                return Error.OUT_OF_MEMORY_ERROR;
            };
        }

        return parts.toOwnedSlice(self.allocator) catch {
                return Error.OUT_OF_MEMORY_ERROR;
            };
    }

    pub fn indexOf(_: *Self, content: []const u8, literal: []const u8) bool {
        return std.mem.indexOf(u8, content, literal);
    }

    pub fn contains(_: *Self, content: []const u8, literal: []const u8) bool {
        if (std.mem.indexOf(u8, content, literal)) |_| {
            return true;
        } else {
            return false;
        }
    }

    pub fn replaceAlloc(self: *Self, content: []const u8, literal: []const u8, replacement: []const u8) ![]const u8 {
        const size = std.mem.replacementSize(u8, content[0..], literal, replacement);
        var buffer = self.allocator.alloc(u8, size) catch {
            return Error.OUT_OF_MEMORY_ERROR;
        };
        _ = std.mem.replace(u8, content, literal, replacement, buffer[0..]);
        return buffer;
    }
};

test "get string length" {
    const allocator = std.testing.allocator;
    const Str = try String.init(allocator);
    defer Str.deinit();

    try std.testing.expectEqual(Str.length("Hello World"), 11);
}

test "to uppercase string" {
    const allocator = std.testing.allocator;
    const Str = try String.init(allocator);
    defer Str.deinit();

    const expected =  try Str.toUpperCaseAlloc("hello world");
    defer allocator.free(expected);

    try std.testing.expectEqualStrings(expected, "HELLO WORLD");
}

test "to lower string" {
    const allocator = std.testing.allocator;
    const Str = try String.init(allocator);
    defer Str.deinit();

    const expected =  try Str.toLowerCaseAlloc("HELLO WORLD");
    defer allocator.free(expected);

    try std.testing.expectEqualStrings(expected,  "hello world");
}

test "test split string" {
    const allocator = std.testing.allocator;
    const Str = try String.init(allocator);
    defer Str.deinit();

    const expected =  try Str.splitAlloc("HELLO WORLD", " ");
    defer allocator.free(expected);

    try std.testing.expectEqualStrings(expected[0], "HELLO");
    try std.testing.expectEqualStrings(expected[1], "WORLD");
}

test "contains value"{
    const allocator = std.testing.allocator;
    const Str = try String.init(allocator);
    defer Str.deinit();

    const expected =  Str.contains("HELLO WORLD\r\n", "\r\n");

    try std.testing.expect(expected);
}

test "trim string" {
    const allocator = std.testing.allocator;
    const Str = try String.init(allocator);
    defer Str.deinit();

    const expected =  Str.trim("HELLO WORLD\r\n", "\r\n");

    try std.testing.expectEqualStrings(expected, "HELLO WORLD");

    const expected2 =  Str.trim(" HELLO WORLD ", null);

    try std.testing.expectEqualStrings(expected2, "HELLO WORLD");
}

test "replace value in string" {
    const allocator = std.testing.allocator;
    const Str = try String.init(allocator);
    defer Str.deinit();

    const expected =  try Str.replaceAlloc("HELLO WORLD\r\n", "WORLD", "MAKER");
    defer allocator.free(expected);

    try std.testing.expectEqualStrings("HELLO MAKER\r\n", expected);
}