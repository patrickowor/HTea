const std = @import("std");

pub fn Channel(comptime T: type)  type {
    return struct {
        fifo: LinearFifoType,
        lock: std.Thread.Mutex,
        allocator: std.mem.Allocator,

        const Self = @This();
        const LinearFifoType =  std.ArrayList([]const u8);//std.fifo.LinearFifo([]const u8, .Dynamic);
        
        pub fn init(allocator: std.mem.Allocator) !*Self {
            const lf = try allocator.create(Self);
            lf.* = .{
                .fifo =  LinearFifoType{},
                .lock = std.Thread.Mutex{},
                .allocator = allocator,
            };
            return lf;
        }

        pub fn deinit(self: *Self) void {
            self.fifo.deinit(self.allocator);
            self.allocator.destroy(self);
        }

        pub fn send(self: *Self, item: T) !void {
            self.lock.lock();
            defer self.lock.unlock();
            try self.fifo.append(self.allocator, item);
        }

        pub fn recieve(self: *Self) ?T {
            self.lock.lock();
            defer self.lock.unlock();
            
            return if (self.fifo.items.len > 0)  self.fifo.orderedRemove(0) else null ;
        }

    };
} 

