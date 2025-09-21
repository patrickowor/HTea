const std = @import("std");
const Htea = @import("HTea");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try Htea.main(allocator);
}