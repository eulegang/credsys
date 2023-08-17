const std = @import("std");
const gpgmez = @import("gpgmez");

pub const Driver = struct {
    ctx: *gpgmez.Context,
    path: [*:0]const u8,

    pub fn fetch(self: Driver, alloc: std.mem.Allocator) ?[]const u8 {
        var secret = gpgmez.Data.file(self.path) catch return null;
        defer secret.deinit();

        var out = gpgmez.Data.init() catch return null;
        defer out.deinit();

        self.ctx.decrypt(&secret, &out) catch return null;
        out.reset();

        var buf: [4096]u8 = undefined;
        const len = out.read(&buf);
        if (len == -1) return null;

        var cred = alloc.alloc(u8, @intCast(len)) catch return null;
        @memcpy(cred, buf[0..@intCast(len)]);

        return cred;
    }

    pub fn deinit(self: Driver, alloc: std.mem.Allocator) void {
        self.ctx.deinit();
        alloc.destroy(self.ctx);

        const len = std.mem.len(self.path);
        var slice: []const u8 = self.path[0 .. len + 1];

        alloc.free(slice);
    }
};
