const std = @import("std");
const HteateaP = @import("HteateaP");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try HteateaP.main(allocator);
}