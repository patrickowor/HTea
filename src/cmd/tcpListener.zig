const std = @import("std");
const net = std.net;


const Chan = @import("../shared/channel.zig").Channel;
const Channel = Chan([]const u8);


pub fn getLinesChannel(alloc: std.mem.Allocator, reader_ptr: *std.io.AnyReader) !*Channel {
    const channel = try Channel.init(alloc);

    const thread = try std.Thread.spawn(.{}, struct {
        fn task(allocator: std.mem.Allocator, reader: *std.io.AnyReader, ch: *Channel ) !void {
            var str = std.ArrayList(u8).init(allocator);
            defer str.deinit();

            while (true) {
                var buffer: [8]u8 = undefined;
                const n = reader.*.read(buffer[0..]) catch |err| {
                    std.debug.print("error: {any}", .{err});
                    break;
                };
                if (n < 1) {
                    break;
                }
                if (std.mem.indexOf(u8, buffer[0..n], "\n")) |i| {
                    if (n > i) {
                        try str.appendSlice(buffer[0..i]);

                        const strSlice: []const u8 = try str.toOwnedSlice();
                        try ch.send(strSlice);

                        if( (i + 1) < n ){
                            try str.appendSlice(buffer[(i + 1)..n]);
                        }                   
                    }

                } else {
                    try str.appendSlice(buffer[0..n]);
                }
            }
            const strSlice: []const u8 = try str.toOwnedSlice();
            try ch.send(strSlice);
        }
    }.task, .{alloc, reader_ptr, channel});
    defer thread.join();

    return channel;
}

pub fn main(allocator: std.mem.Allocator) !void {

    var address = try net.Address.parseIp("0.0.0.0", 42069);
    var server = try address.listen(.{});
    defer server.deinit();
    std.debug.print("Server started at: {any}\n", .{server.listen_address});


    while (true) {
        var conn = try server.accept();
        defer conn.stream.close();

        var reader = conn.stream.reader().any();
        var channel = try getLinesChannel(allocator, &reader);
        defer channel.deinit();

        while  (channel.recieve()) |v|{
            std.debug.print("Got line: {s}\n", .{v});
            allocator.free(v);
        }  
       
    }
    std.debug.print("Channel closed\n", .{});       
}