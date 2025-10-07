const std = @import("std");
const net = std.net;


const Chan = @import("../shared/channel.zig").Channel;
const Channel = Chan([]const u8);


pub fn getLinesChannel(alloc: std.mem.Allocator, reader_ptr: *std.Io.Reader) !*Channel {
    const channel = try Channel.init(alloc);

    const thread = try std.Thread.spawn(.{}, struct {
        fn task(allocator: std.mem.Allocator, reader: *std.Io.Reader, ch: *Channel ) !void {
            var str = std.ArrayList(u8){};
            defer str.deinit(allocator);
            while (true) {
                var buffer: [8]u8 = undefined;
                const n = reader.*.readSliceShort(buffer[0..]) catch |err| {
                    std.debug.print("error: {any}\n", .{err});
                    break;
                };
                if (n < 1) {
                    break;
                }
                if (std.mem.indexOf(u8, buffer[0..n], "\n")) |i| {
                    if (n > i) {
                        try str.appendSlice(allocator, buffer[0..i]);

                        const strSlice: []const u8 = try str.toOwnedSlice(allocator);
                        try ch.send(strSlice);

                        if( (i + 1) < n ){
                            try str.appendSlice(allocator, buffer[(i + 1)..n]);
                        }                   
                    }

                } else {
                    try str.appendSlice(allocator, buffer[0..n]);
                }
            }
            const strSlice: []const u8 = try str.toOwnedSlice(allocator);
            try ch.send(strSlice);
        }
    }.task, .{alloc, reader_ptr, channel});
    defer thread.join();

    return channel;
}

pub fn main(allocator: std.mem.Allocator) !void {

    const host: []const u8 = "0.0.0.0";
    var address = try net.Address.parseIp(host, 42069);
    var server = try address.listen(.{});
    defer server.deinit();
    std.debug.print("Server started at: {f}}\n", .{server.listen_address});


    while (true) {
        var conn = try server.accept();
        defer conn.stream.close();

        var reader_buffer: [1024]u8 = undefined;
        var reader = conn.stream.reader(&reader_buffer); //.reader().any();
        var channel = try getLinesChannel(allocator, &reader.interface_state);
        defer channel.deinit();

        while  (channel.recieve()) |v|{
            std.debug.print("\nGot line: {s}\n", .{v});
            allocator.free(v);
        }  

       
    }
    std.debug.print("Channel closed\n", .{});       
}



test "tcpListener test" {
    // const allocator = std.testing.allocator;

    try std.testing.expectEqual("Test Active", "Test Active");
}