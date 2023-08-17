const std = @import("std");
const gpgmez = @import("gpgmez");
const gpg_mod = @import("gpg.zig");

pub const Cred = union(enum) {
    token: []const u8,
    basic: struct {
        username: []const u8,
        password: []const u8,
    },

    fn init(content: []const u8, alloc: std.mem.Allocator) !Cred {
        if (std.mem.indexOf(u8, content, ":")) |pos| {
            var username = try alloc.alloc(u8, pos);
            errdefer alloc.free(username);

            var password = try alloc.alloc(u8, content.len - (pos + 1));

            @memcpy(username, content[0..pos]);
            @memcpy(password, content[pos + 1 .. content.len]);
            return Cred{
                .basic = .{
                    .username = username,
                    .password = password,
                },
            };
        } else {
            var buf = try alloc.alloc(u8, content.len);
            @memcpy(buf, content);
            return Cred{ .token = buf };
        }
    }

    fn deinit(self: Cred, alloc: std.mem.Allocator) void {
        switch (self) {
            .token => |t| alloc.free(t),
            .basic => |b| {
                alloc.free(b.username);
                alloc.free(b.password);
            },
        }
    }
};

const Driver = union(enum) {
    gpg: gpg_mod.Driver,

    fn fetch(self: *Driver, alloc: std.mem.Allocator) ?Cred {
        switch (self.*) {
            .gpg => |g| {
                const res = g.fetch(alloc) orelse return null;
                defer alloc.free(res);

                return Cred.init(res, alloc) catch return null;
            },
        }

        return null;
    }

    fn deinit(self: *Driver, alloc: std.mem.Allocator) void {
        switch (self.*) {
            .gpg => |g| g.deinit(alloc),
        }
    }
};

pub const Credentials = struct {
    drivers: std.ArrayList(Driver),
    alloc: std.mem.Allocator,

    pub fn init(alloc: std.mem.Allocator) Credentials {
        const drivers = std.ArrayList(Driver).init(alloc);
        return Credentials{
            .alloc = alloc,
            .drivers = drivers,
        };
    }

    pub fn deinit(self: *Credentials) void {
        for (self.drivers.items) |*driver| {
            driver.deinit(self.alloc);
        }

        self.drivers.deinit();
    }

    pub fn gpg(self: *Credentials, path: []const u8) !void {
        gpgmez.init();

        var ctx = try self.alloc.create(gpgmez.Context);
        ctx.* = try gpgmez.Context.init();

        var buf = try self.alloc.alloc(u8, path.len + 1);
        @memcpy(buf[0..path.len], path);
        buf[path.len] = 0;

        try self.drivers.append(Driver{
            .gpg = gpg_mod.Driver{
                .ctx = ctx,
                .path = @ptrCast(buf),
            },
        });
    }

    pub fn fetch(self: *Credentials) ?Cred {
        for (self.drivers.items) |*driver|
            if (driver.fetch(self.alloc)) |cred|
                return cred;

        return null;
    }

    pub fn free(self: *Credentials, cred: Cred) void {
        cred.deinit(self.alloc);
    }
};

test "testing gpg key" {
    const Err = error{failed};
    var fetcher = Credentials.init(std.testing.allocator);
    defer fetcher.deinit();

    try fetcher.gpg("deps/gpgmez/msg.gpg");

    var cred = fetcher.fetch() orelse return Err.failed;
    defer fetcher.free(cred);

    try std.testing.expectEqualSlices(u8, "hello world\n", cred.token);
}
