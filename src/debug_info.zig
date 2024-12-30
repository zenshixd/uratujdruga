const std = @import("std");
const rl = @import("raylib");

const GameState = @import("main.zig").GameState;
const stats = @import("stats.zig");

pub const DebugInfo = struct {
    enabled: bool = false,
    line_num: i32 = 0,
    coordsBuffer: [256]u8 = undefined,

    pub fn draw(self: *DebugInfo, state: *GameState) void {
        if (self.enabled) {
            const cam = state.cam;
            var player = state.player;
            const map_editor = state.map_editor;

            self.line_num = 0;
            self.drawText(state, "cam x: {d:.2} y: {d:.2}", .{ cam.target.x, cam.target.y });
            self.drawText(state, "player x: {d:.2} y: {d:.2}", .{ player.rect().x, player.rect().y });
            self.drawText(state, "player velocity x: {d:.2} y: {d:.2}", .{ player.velocity().x, player.velocity().y });
            self.drawText(state, "cursor x: {d:.2} y: {d:.2}", .{ rl.getMousePosition().x, rl.getMousePosition().y });
            self.drawText(state, "boundary x: {d:.2} y: {d:.2}, width: {d:.2}, height: {d:.2}", .{ map_editor.boundary.x, map_editor.boundary.y, map_editor.boundary.width, map_editor.boundary.height });
            self.drawText(state, "selected point: {s}", .{@tagName(map_editor.toolbox.selected_point)});
        }
    }

    pub fn drawGrid(self: *DebugInfo) void {
        if (self.enabled) {
            const LINES = 100;

            var i: i32 = -LINES;
            while (i < LINES) : (i += 1) {
                rl.drawLineEx(rl.Vector2.init(@floatFromInt(i * stats.tile_size), -9000), rl.Vector2.init(@floatFromInt(i * stats.tile_size), 9000), 1, rl.Color.light_gray);
                rl.drawLineEx(rl.Vector2.init(-9000, @floatFromInt(i * stats.tile_size)), rl.Vector2.init(9000, @floatFromInt(i * stats.tile_size)), 1, rl.Color.light_gray);
            }
        }
    }

    fn drawText(self: *DebugInfo, state: *GameState, comptime fmt: []const u8, args: anytype) void {
        const text = std.fmt.bufPrintZ(&self.coordsBuffer, fmt, args) catch unreachable;
        const world_pos = rl.getScreenToWorld2D(rl.Vector2.init(5, @floatFromInt(5 + self.line_num * 20)), state.cam);
        rl.drawText(text, @intFromFloat(world_pos.x), @intFromFloat(world_pos.y), 16, rl.Color.red);
        self.line_num += 1;
    }
};
