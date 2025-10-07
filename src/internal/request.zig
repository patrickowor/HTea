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

    pub fn init(alloc: Allocator) !*Request {
        const request = try alloc.create(Request);
        const rl = try alloc.create(RequestLine);

        request.* = Request{
            .allocator = alloc,
            .request_line = rl,
        };
        return request;
    }

    pub fn deinit(self: *Request) void {
        if (self.state != RequestState.INIT){
            self.request_line.deinit();
        } else {
            // because request allocates memory for request line before a request line is created 
            // in a situation we cannot sucessfully parse a request line then no request line
            //is then created hence the request line cannot destroy itself because an instance of it doesnt exist yet
            self.allocator.destroy(self.request_line);
        }
        self.allocator.destroy(self);
    }

    pub fn parse(self: *Request, buffer: []u8) !usize {
        switch (self.state) {
            RequestState.INIT => {
                const n = try parseRequestLine(self.allocator, buffer, self.request_line);
                if (n != 0){
                    self.state = RequestState.DONE;
                }
                return n;
            },
            RequestState.DONE => {
                return 0;
            }
        }
    }

    pub fn done(self: *Request) bool {
        return self.state == RequestState.DONE;
    }
};


pub fn parseRequestLine(allocator: Allocator, buffer: []u8, rl: *RequestLine ) RequestError!usize {
    var String = Str.init(allocator) catch {
        return RequestError.OUT_OF_MEMORY_ERROR;
    };
    defer String.deinit();

    const sep: []const u8  = "\r\n";
    const n = std.mem.indexOf(u8, buffer, sep);
    if (n == null) return 0;

    var buffer_lines =  String.splitAlloc(buffer[0..buffer.len], sep) catch |err|{
        std.debug.print("error: {}", .{err});
        return RequestError.OUT_OF_MEMORY_ERROR;
    };
    // NOTE: freeing this could be a problem
    defer allocator.free(buffer_lines);

    const reqline_str = allocator.dupe(u8, buffer_lines[0][0..]) catch {
        return RequestError.OUT_OF_MEMORY_ERROR;
    };
    defer allocator.free(reqline_str);

    const parts = try String.splitAlloc(reqline_str," ");
    defer allocator.free(parts);

    if (parts.len != 3 ) {
        return RequestError.MALFORMED_REQUEST_LINE;
    }


    var version = String.trim(parts[2][0..], "HTTP/");
    rl.* = RequestLine{
        .allocator = allocator,
        .method = allocator.dupe(u8, parts[0][0..]) catch { return RequestError.OUT_OF_MEMORY_ERROR; },
        .request_target =  allocator.dupe(u8, parts[1][0..]) catch { return RequestError.OUT_OF_MEMORY_ERROR; },
        .http_version =  allocator.dupe(u8, version[0..]) catch { return RequestError.OUT_OF_MEMORY_ERROR; },    
    };    
    return n.?;
}

pub fn requestFromReader(allocator: Allocator, reader: *std.Io.Reader) RequestError!*Request {
    const request = Request.init(allocator) catch {
        return RequestError.OUT_OF_MEMORY_ERROR;
    };
    errdefer request.deinit();
    // errdefer allocator.destroy(request.request_line);

    const max_size : usize = 1024; 
    var String = Str.init(allocator) catch {
        return RequestError.OUT_OF_MEMORY_ERROR;
    };
    defer String.deinit();


    var bufferLen: usize = 0;
    var buffer =  allocator.alloc(u8, 1024) catch {
        return RequestError.OUT_OF_MEMORY_ERROR;
    };
    defer allocator.free(buffer);
    @memset(buffer, undefined);

    while (!request.done()) {
        const n = reader.*.readSliceShort(buffer[bufferLen..max_size]) catch {
            return RequestError.OUT_OF_MEMORY_ERROR;
        };

        if (n <= 0) {
            break;
        }

        bufferLen += n;
        const readN = try request.parse(buffer[0..bufferLen]);
        // copy all the remaining unparsed items back to start of the buffer
        // find the defrence and clear all the values at the remaining 
        // part of the buffer 

        std.mem.copyForwards(u8, buffer[0..max_size], buffer[readN..bufferLen]);
        bufferLen -= readN;
        @memset(buffer[bufferLen..max_size], undefined);
    }

    return request;
}
