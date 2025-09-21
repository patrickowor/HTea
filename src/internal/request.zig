const std = @import("std");
const Str = @import("../shared/string.zig").String;
const Allocator = std.mem.Allocator;


const RequestState = enum {
    INIT,//: [] u8 = "init",
    DONE//: [] u8 = "done"
};

pub const RequestError  = error {
    MALFORMED_REQUEST_LINE,
} || Str.Error;

const  RequestLine = struct {
    allocator: Allocator,
    method: []const u8,
    request_target: []const u8,
    http_version: []const u8,

    const Self = @This();

    pub fn init(allocator:Allocator, parts: [][]const u8) !*Self {
        const request_line = try allocator.create(RequestLine);
        var String = Str.init(allocator) catch {
            return RequestError.OUT_OF_MEMORY_ERROR;
        };
        defer String.deinit();

        var version = String.trim(parts[2][0..], "HTTP/");
        



        request_line.* = Self {
            .allocator = allocator,
            .method = try allocator.dupe(u8, parts[0][0..]),
            .request_target = try allocator.dupe(u8, parts[1][0..]),
            .http_version = try allocator.dupe(u8, version[0..]),

        };

        return request_line;
    }
    pub fn deinit(self: *RequestLine) void {
        self.allocator.free(self.http_version);
        self.allocator.free(self.method);
        self.allocator.free(self.request_target);
        self.allocator.destroy(self);
    }
};


pub const Request = struct {
    allocator: Allocator,
    request_line : *RequestLine,
    state: RequestState = RequestState.INIT,

    pub fn init(alloc: Allocator, rl: *RequestLine) !*Request {
        const request = try alloc.create(Request);

        request.* = Request{
            .allocator = alloc,
            .request_line = rl,
        };
        return request;
    }

    pub fn deinit(self: *Request) void {
        self.request_line.deinit();
        self.allocator.destroy(self);
    }

    pub fn parse(buffer: []const u8) !usize {
        _ = buffer;
    }
};

pub fn parseRequestLine(allocator: Allocator, line: []u8) RequestError!*RequestLine {
    var String = Str.init(allocator) catch {
        return RequestError.OUT_OF_MEMORY_ERROR;
    };
    defer String.deinit();

    const parts = try String.splitAlloc(line," ");
    defer allocator.free(parts);

    if (parts.len != 3 ) {
        return RequestError.MALFORMED_REQUEST_LINE;
    }

    const request_line = RequestLine.init(allocator, parts) catch {
        return RequestError.MALFORMED_REQUEST_LINE;
    };
    
    return request_line;
}

pub fn requestFromReader(allocator: Allocator, reader: *std.io.AnyReader) RequestError!*Request {
    const max_size : usize = 1024; 
    var String = Str.init(allocator) catch {
        return RequestError.OUT_OF_MEMORY_ERROR;
    };
    defer String.deinit();

    var buffer =  std.ArrayList(u8).initCapacity(allocator, max_size) catch {
        return RequestError.OUT_OF_MEMORY_ERROR;
    };
    var bufferLen: usize = 0;
    defer buffer.deinit();
    buffer.expandToCapacity();
    buffer.items.len = max_size;
    @memset(buffer.items, undefined);
    // buffer.ensureTotalCapacity(max_size) catch {
    //     return RequestError.OUT_OF_MEMORY_ERROR;
    // };

    while (true) {
        const n = reader.read(buffer.items[bufferLen..max_size]) catch {
            return RequestError.OUT_OF_MEMORY_ERROR;
        };

        if (n < 0) {
            break;
        }

        bufferLen += n;
        const readN = try Request.parse(buffer.items[0..bufferLen]);


        // copy all the remaining unparsed items back to start of the buffer
        // find the defrence and clear all the values at the remaining 
        // part of the buffer  
        @memcpy(buffer.items[0..max_size], buffer.items[readN..bufferLen]);
        bufferLen -= readN;
        @memset(buffer.items[bufferLen..max_size], undefined);
        
    }




    // var buffer = std.ArrayList(u8).init(allocator);
    // defer buffer.deinit();

    // reader.readAllArrayList(&buffer, max_size) catch |err|{
    //     std.debug.print("error: {}", .{err});
    //     return RequestError.OUT_OF_MEMORY_ERROR;
    // };


    var sep: []const u8  = "\r\n";
    if (!String.contains(buffer.items[0..buffer.items.len],"\r\n")) {
        sep = "\r";
    }
    var parts =  String.splitAlloc(buffer.items[0..buffer.items.len], sep) catch |err|{
        std.debug.print("error: {}", .{err});
        return RequestError.OUT_OF_MEMORY_ERROR;
    };
    defer allocator.free(parts);


    const reqline_str = allocator.dupe(u8, parts[0][0..]) catch {
        return RequestError.OUT_OF_MEMORY_ERROR;
    };
    defer allocator.free(reqline_str);

    const request_line =  parseRequestLine(allocator, reqline_str) catch |err|{
        std.debug.print("error: {}", .{err});
        return RequestError.MALFORMED_REQUEST_LINE;
    };


    return Request.init(allocator, request_line) catch {
        return RequestError.MALFORMED_REQUEST_LINE;
    };
}
