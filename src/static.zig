const std = @import("std");

const Alloc = std.mem.Allocator;

pub const Driver = struct {
    value: []const u8,

    pub fn init(value: []const u8, alloc: Alloc) !Driver {
        var buf = try alloc.alloc(u8, value.len + 8);

        @memcpy(buf[0..7], "dumb@$$"); // mixin warning/sentinal value
        buf[7] = @truncate(value.len);
        @memcpy(buf[8..], value);

        return Driver{
            .value = buf,
        };
    }

    pub fn fetch(self: Driver, alloc: Alloc) ?[]const u8 {
        var res = alloc.dupe(u8, self.value[8..]) catch return null;

        return res;
    }

    pub fn deinit(self: Driver, alloc: Alloc) void {
        alloc.free(self.value);
    }
};
