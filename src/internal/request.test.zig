const std = @import("std");
const testing = std.testing;

const RequestLib = @import("request.zig");
const Request = RequestLib.Request;
const RequestError = RequestLib.RequestError;

test "read succesful get request from reader" {
    const allocator = testing.allocator;
    var reader = std.Io.Reader.fixed("GET / HTTP/1.1\r\nHost: localhost:42069\r\nUser-Agent: curl/7.81.0\r\nAccept: */*\r\n\r\n");

    var request = try RequestLib.requestFromReader(allocator,&reader);
    defer request.deinit();
    
    try testing.expectEqualStrings("GET", request.request_line.method);
    try testing.expectEqualStrings("/", request.request_line.request_target);
    try testing.expectEqualStrings("1.1", request.request_line.http_version);
}


test "read succesful get request with path from reader" {
    const allocator = testing.allocator;
    var reader = std.Io.Reader.fixed("GET /coffee HTTP/1.1\r\nHost: localhost:42069\r\nUser-Agent: curl/7.81.0\r\nAccept: */*\r\n\r\n");

    var request = try RequestLib.requestFromReader(allocator,&reader);
    defer request.deinit();

    try testing.expectEqualStrings("GET", request.request_line.method);
    try testing.expectEqualStrings("/coffee", request.request_line.request_target);
    try testing.expectEqualStrings("1.1", request.request_line.http_version);
}

test "read failing get request from reader" {

    const allocator = testing.allocator;
    var reader = std.Io.Reader.fixed("/coffee HTTP/1.1\r\nHost: localhost:42069\r\nUser-Agent: curl/7.81.0\r\nAccept: */*\r\n\r\n");

    try testing.expectError(RequestError.MALFORMED_REQUEST_LINE, RequestLib.requestFromReader(allocator,&reader));
}