const std = @import("std");

pub fn Channel(comptime T: type)  type {
    return struct {
        fifo: LinearFifoType,
        lock: std.Thread.Mutex,
        allocator: std.mem.Allocator,

        const Self = @This();
        const LinearFifoType =  std.fifo.LinearFifo([]const u8, .Dynamic);
        
        pub fn init(allocator: std.mem.Allocator) !*Self {
            const lf = try allocator.create(Self);
            lf.* = .{
                .fifo =  LinearFifoType.init(allocator),
                .lock = std.Thread.Mutex{},
                .allocator = allocator,
            };
            return lf;
        }

        pub fn deinit(self: *Self) void {
            self.fifo.deinit();
            self.allocator.destroy(self);
        }

        pub fn send(self: *Self, item: T) !void {
            self.lock.lock();
            defer self.lock.unlock();
            try self.fifo.writeItem(item);
        }

        pub fn recieve(self: *Self) ?T {
            self.lock.lock();
            defer self.lock.unlock();
            return self.fifo.readItem();
        }

    };
} 

