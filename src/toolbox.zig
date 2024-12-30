const std = @import("std");
const rl = @import("raylib");

const Assets = @import("assets.zig");
const Tile = @import("map.zig").Tile;
const Tileset = @import("map.zig").Tileset;
const MapEditor = @import("map.zig").MapEditor;
const GameState = @import("main.zig").GameState;
const stats = @import("stats.zig");

pub const Toolbox = struct {
    const Kind = enum {
        pointer,
        erase,
        paint,
        make_solid,
        start_point,
        enemy_point,
        move_boundary,
    };

    kind: Kind,
    pos: rl.Vector2,
    active_tileset: Tileset = .catacombs,
    active_tile: rl.Vector2 = rl.Vector2.init(0, 0),
    display_tileset: bool = true,
    selection: std.AutoHashMap(usize, void),
    selected_point: enum { none, ne, nw, se, sw } = .none,

    pub fn init(allocator: std.mem.Allocator) Toolbox {
        return Toolbox{
            .kind = .pointer,
            .selection = std.AutoHashMap(usize, void).init(allocator),
            .pos = rl.Vector2.init(
                @floatFromInt(@divFloor(rl.getScreenWidth(), 2)),
                @floatFromInt(@divFloor(rl.getScreenHeight(), 2)),
            ),
        };
    }

    pub fn update(self: *Toolbox, state: *GameState) void {
        if (rl.isKeyPressed(rl.KeyboardKey.key_one)) {
            self.kind = prevEnumValue(Kind, self.kind);
        }

        if (rl.isKeyPressed(rl.KeyboardKey.key_two)) {
            self.kind = nextEnumValue(Kind, self.kind);
        }

        self.pos = rl.getMousePosition();

        switch (self.kind) {
            .pointer => self.updateSelectTool(state),
            .erase => self.updateEraseTool(state),
            .paint => self.updatePaintTool(state),
            .make_solid => self.updateMakeSolidTool(state),
            .start_point => self.updateSpawnPointTool(&state.map_editor.player_spawn_point),
            .enemy_point => self.updateSpawnPointTool(&state.map_editor.enemy_spawn_point),
            .move_boundary => self.updateMoveBoundaryTool(state),
        }
    }

    pub fn updateSelectTool(self: *Toolbox, state: *GameState) void {
        if (rl.isMouseButtonDown(rl.MouseButton.mouse_button_left)) {
            const mouse_pos = rl.getMousePosition();
            const tileVec = Tile.toTilePos(mouse_pos);

            if (findTileIdx(&state.map_editor, tileVec)) |tile_idx| {
                self.selection.put(tile_idx, {}) catch unreachable;
            }
        }
    }
    pub fn updateEraseTool(_: *Toolbox, state: *GameState) void {
        if (rl.isMouseButtonDown(rl.MouseButton.mouse_button_left)) {
            const mouse_pos = rl.getMousePosition();
            const tileVec = Tile.toTilePos(mouse_pos);

            if (findTileIdx(&state.map_editor, tileVec)) |tile_idx| {
                _ = state.map_editor.tiles.orderedRemove(tile_idx);
            }
        }
    }
    pub fn updatePaintTool(self: *Toolbox, state: *GameState) void {
        var map_editor = &state.map_editor;
        if (rl.isMouseButtonDown(rl.MouseButton.mouse_button_left)) {
            const mouse_pos = rl.getMousePosition().add(rl.Vector2.init(stats.tile_size / 2, stats.tile_size / 2));
            const tileVec = Tile.toTilePos(mouse_pos);

            if (findTileIdx(map_editor, tileVec)) |tile_idx| {
                map_editor.tiles.items[tile_idx].tileset = self.active_tileset;
                map_editor.tiles.items[tile_idx].offset = self.active_tile;
            } else {
                map_editor.tiles.append(Tile{ .position = tileVec, .offset = self.active_tile }) catch unreachable;
            }
        }

        if (rl.isKeyPressed(rl.KeyboardKey.key_three)) {
            self.display_tileset = !self.display_tileset;
        }

        if (rl.isKeyPressed(rl.KeyboardKey.key_q)) {
            self.active_tileset = prevEnumValue(Tileset, self.active_tileset);
        }

        if (rl.isKeyPressed(rl.KeyboardKey.key_e)) {
            self.active_tileset = nextEnumValue(Tileset, self.active_tileset);
        }

        if (rl.isKeyPressed(rl.KeyboardKey.key_a)) {
            self.active_tile.x -= stats.sprite_size;
        }

        if (rl.isKeyPressed(rl.KeyboardKey.key_d)) {
            self.active_tile.x += stats.sprite_size;
        }

        if (rl.isKeyPressed(rl.KeyboardKey.key_w)) {
            self.active_tile.y -= stats.sprite_size;
        }

        if (rl.isKeyPressed(rl.KeyboardKey.key_s)) {
            self.active_tile.y += stats.sprite_size;
        }

        const texture = self.active_tileset.getTexture(state.assets);
        const tilesetWidth: f32 = @floatFromInt(texture.width - stats.sprite_size);
        const tilesetHeight: f32 = @floatFromInt(texture.height - stats.sprite_size);
        self.active_tile.x = wrapValue(self.active_tile.x, 0, tilesetWidth);
        self.active_tile.y = wrapValue(self.active_tile.y, 0, tilesetHeight);
    }

    pub fn updateSpawnPointTool(_: *Toolbox, out_point: *rl.Vector2) void {
        if (rl.isMouseButtonPressed(rl.MouseButton.mouse_button_left)) {
            const mouse_pos = rl.getMousePosition();
            const tileVec = Tile.toTilePos(mouse_pos);
            out_point.* = rl.Vector2.init(tileVec.x * stats.tile_size, tileVec.y * stats.tile_size);
        }
    }

    pub fn updateMakeSolidTool(_: *Toolbox, state: *GameState) void {
        if (rl.isMouseButtonDown(rl.MouseButton.mouse_button_left)) {
            const mouse_pos = rl.getMousePosition();
            const tileVec = Tile.toTilePos(mouse_pos);

            if (findTileIdx(&state.map_editor, tileVec)) |tile_idx| {
                state.map_editor.tiles.items[tile_idx].is_solid = !rl.isKeyDown(rl.KeyboardKey.key_left_shift);
            }
        }
    }

    pub fn updateMoveBoundaryTool(self: *Toolbox, state: *GameState) void {
        var boundary = &state.map_editor.boundary;
        if (rl.isMouseButtonPressed(rl.MouseButton.mouse_button_left)) {
            if (self.selected_point != .none) {
                self.selected_point = .none;
                return;
            }

            const mouse_pos = rl.getMousePosition();
            self.selected_point = if (mouse_pos.distance(rl.Vector2.init(boundary.x, boundary.y)) < stats.tile_size * 2)
                .ne
            else if (mouse_pos.distance(rl.Vector2.init(boundary.x + boundary.width, boundary.y)) < stats.tile_size * 2)
                .nw
            else if (mouse_pos.distance(rl.Vector2.init(boundary.x, boundary.y + boundary.height)) < stats.tile_size * 2)
                .se
            else if (mouse_pos.distance(rl.Vector2.init(boundary.x + boundary.width, boundary.y + boundary.height)) < stats.tile_size * 2)
                .sw
            else
                .none;
        }

        if (self.selected_point != .none) {
            const mouse_delta = rl.getMouseDelta();
            switch (self.selected_point) {
                .ne => {
                    boundary.x += mouse_delta.x;
                    boundary.y += mouse_delta.y;
                    boundary.width -= mouse_delta.x;
                    boundary.height -= mouse_delta.y;
                },
                .nw => {
                    boundary.y += mouse_delta.y;
                    boundary.width += mouse_delta.x;
                    boundary.height -= mouse_delta.y;
                },
                .se => {
                    boundary.x += mouse_delta.x;
                    boundary.width -= mouse_delta.x;
                    boundary.height += mouse_delta.y;
                },
                .sw => {
                    boundary.width += mouse_delta.x;
                    boundary.height += mouse_delta.y;
                },
                else => unreachable,
            }
        }
    }

    pub fn findTileIdx(map_editor: *MapEditor, pos: rl.Vector2) ?usize {
        for (map_editor.tiles.items, 0..) |tile, idx| {
            if (tile.position.equals(pos) == 1) {
                return idx;
            }
        }

        return null;
    }

    pub fn draw(self: *Toolbox, state: *GameState) void {
        if (self.display_tileset) {
            const texture = self.active_tileset.getTexture(state.assets);
            const tilesetPosition = rl.getScreenToWorld2D(rl.Vector2.zero(), state.cam);
            texture.drawV(tilesetPosition, rl.Color.white);

            rl.drawRectangleLinesEx(
                rl.Rectangle.init(
                    tilesetPosition.x + self.active_tile.x,
                    tilesetPosition.y + self.active_tile.y,
                    stats.sprite_size,
                    stats.sprite_size,
                ),
                1,
                rl.Color.red,
            );
        }

        if (self.kind == .paint) {
            const texture = self.active_tileset.getTexture(state.assets);
            const cursorRect = rl.Rectangle.init(self.pos.x, self.pos.y, stats.tile_size, stats.tile_size);
            texture.drawPro(Tileset.sourceRect(self.active_tile), cursorRect, rl.Vector2.zero(), 0, rl.Color.white);
            rl.drawRectangleLinesEx(cursorRect, 1, rl.Color.red);
        } else {
            const textureColor = switch (self.kind) {
                .start_point => rl.Color.lime,
                .enemy_point => rl.Color.red,
                else => rl.Color.white,
            };
            rl.drawTextureV(self.getCursorIcon(state.assets), self.pos, textureColor);
        }
    }

    pub fn getCursorIcon(self: Toolbox, assets: Assets) rl.Texture2D {
        return switch (self.kind) {
            .pointer => assets.getTexture(.pointer),
            .erase => assets.getTexture(.erase),
            .paint => assets.getTexture(.paint),
            .make_solid => assets.getTexture(.make_solid),
            .start_point, .enemy_point => assets.getTexture(.spawn_point),
            .move_boundary => assets.getTexture(.move_boundary),
        };
    }

    pub fn nextTile(self: *Toolbox, state: *GameState) void {
        const tileset = state.sprite_tiles.get(self.active_tileset) orelse return;
        const tilesetWidth: f32 = @floatFromInt(tileset.width);
        const tilesetHeight: f32 = @floatFromInt(tileset.height);

        if (self.active_tile.x >= tilesetWidth and self.active_tile.y >= tilesetHeight - stats.sprite_size) {
            self.active_tile.x = 0;
            self.active_tile.y = 0;
        } else if (self.active_tile.x >= tilesetWidth) {
            self.active_tile.x = 0;
            self.active_tile.y += stats.sprite_size;
        } else {
            self.active_tile.x += stats.sprite_size;
        }
    }

    pub fn prevTile(self: *Toolbox, state: *GameState) void {
        const tileset = state.sprite_tiles.get(self.active_tileset) orelse return;
        const tilesetWidth: f32 = @floatFromInt(tileset.width);
        const tilesetHeight: f32 = @floatFromInt(tileset.height);

        if (self.active_tile.y <= 0 and self.active_tile.x <= 0) {
            self.active_tile.x = tilesetWidth;
            self.active_tile.y = tilesetHeight - stats.sprite_size;
        } else if (self.active_tile.x <= 0) {
            self.active_tile.x = tilesetWidth;
            self.active_tile.y -= stats.sprite_size;
        } else {
            self.active_tile.x -= stats.sprite_size;
        }
    }
};

pub fn wrapValue(value: anytype, min: anytype, max: anytype) @TypeOf(value) {
    if (value < min) {
        return max;
    } else if (value > max) {
        return min;
    }

    return value;
}

pub fn prevEnumValue(comptime T: type, value: T) T {
    const fields = std.meta.fields(T);
    if (@intFromEnum(value) == 0) {
        return @enumFromInt(fields.len - 1);
    }

    return @enumFromInt(@intFromEnum(value) - 1);
}

pub fn nextEnumValue(comptime T: type, value: T) T {
    const fields = std.meta.fields(T);
    if (@intFromEnum(value) == fields.len - 1) {
        return @enumFromInt(0);
    }

    return @enumFromInt(@intFromEnum(value) + 1);
}
