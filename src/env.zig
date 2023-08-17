const std = @import("std");

const Alloc = std.mem.Allocator;

pub const Driver = struct {
    key: []const u8,

    pub fn init(key: []const u8, alloc: Alloc) !Driver {
        var buf = try alloc.dupe(u8, key);

        return Driver{
            .key = buf,
        };
    }

    pub fn fetch(self: Driver, alloc: Alloc) ?[]const u8 {
        var env = std.process.getEnvMap(alloc) catch return null;
        defer env.deinit();

        if (env.get(self.key)) |val| {
            var buf = alloc.alloc(u8, val.len) catch return null;

            @memcpy(buf, val);
            return buf;
        } else {
            return null;
        }
    }

    pub fn deinit(self: Driver, alloc: Alloc) void {
        alloc.free(self.key);
    }
};
