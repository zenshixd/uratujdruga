const std = @import("std");
const rl = @import("raylib");
const Tile = @import("main.zig").Tile;
const Tileset = @import("main.zig").Tileset;
const MapEditor = @import("main.zig").MapEditor;
const GameState = @import("main.zig").GameState;
const TILE_SIZE = @import("main.zig").TILE_SIZE;
const SPRITE_SIZE = @import("main.zig").SPRITE_SIZE;

pub const Toolbox = struct {
    const Kind = enum {
        pointer,
        erase,
        paint,
        make_solid,
        start_point,
        move_boundary,

        pub fn getIcon(kind: Kind) rl.Texture2D {
            const filename = switch (kind) {
                .pointer => "assets/icons/pointer_scifi_a.png",
                .erase => "assets/icons/drawing_eraser.png",
                .paint => "assets/icons/drawing_brush.png",
                .make_solid => "assets/icons/tool_wand.png",
                .start_point => "assets/icons/gauntlet_point.png",
                .move_boundary => "assets/icons/resize_d_cross.png",
            };
            return rl.loadTexture(filename);
        }

        pub fn next(self: Kind) Kind {
            const fields = std.meta.fields(Kind);
            if (@intFromEnum(self) == fields.len - 1) {
                return @enumFromInt(0);
            }

            return @enumFromInt(@intFromEnum(self) + 1);
        }

        pub fn prev(self: Kind) Kind {
            const fields = std.meta.fields(Kind);
            if (@intFromEnum(self) == 0) {
                return @enumFromInt(fields.len - 1);
            }

            return @enumFromInt(@intFromEnum(self) - 1);
        }
    };

    kind: Kind,
    icon: rl.Texture2D,
    pos: rl.Vector2,
    active_tileset: Tileset = .tiles,
    active_tile: rl.Vector2 = rl.Vector2.init(0, 0),
    display_tileset: bool = true,
    selection: std.AutoHashMap(usize, void),
    selected_point: enum { none, ne, nw, se, sw } = .none,

    pub fn init(allocator: std.mem.Allocator) Toolbox {
        return Toolbox{
            .kind = .pointer,
            .icon = Kind.pointer.getIcon(),
            .selection = std.AutoHashMap(usize, void).init(allocator),
            .pos = rl.Vector2.init(
                @floatFromInt(@divFloor(rl.getScreenWidth(), 2)),
                @floatFromInt(@divFloor(rl.getScreenHeight(), 2)),
            ),
        };
    }

    pub fn load(self: *Toolbox, kind: Kind) void {
        self.kind = kind;
        self.icon = kind.getIcon();
    }

    pub fn update(self: *Toolbox, state: *GameState) void {
        if (rl.isKeyPressed(rl.KeyboardKey.key_one)) {
            self.load(self.kind.prev());
        }

        if (rl.isKeyPressed(rl.KeyboardKey.key_two)) {
            self.load(self.kind.next());
        }

        self.pos = rl.getMousePosition();

        switch (self.kind) {
            .pointer => self.updateSelectTool(state),
            .erase => self.updateEraseTool(state),
            .paint => self.updatePaintTool(state),
            .make_solid => self.updateMakeSolidTool(state),
            .start_point => self.updateStartPointTool(state),
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
            const mouse_pos = rl.getMousePosition().add(rl.Vector2.init(TILE_SIZE / 2, TILE_SIZE / 2));
            const tileVec = Tile.toTilePos(mouse_pos);

            if (findTileIdx(map_editor, tileVec)) |tile_idx| {
                map_editor.tiles.items[tile_idx].tileset = self.active_tileset;
                map_editor.tiles.items[tile_idx].offset = self.active_tile;
            } else {
                std.debug.print("paint tile\n", .{});
                map_editor.tiles.append(Tile{ .position = tileVec, .offset = self.active_tile }) catch unreachable;
            }
        }

        if (rl.isKeyPressed(rl.KeyboardKey.key_three)) {
            self.display_tileset = !self.display_tileset;
        }

        if (rl.isKeyPressed(rl.KeyboardKey.key_w)) {
            if (self.active_tile.y > 0) {
                self.active_tile.y -= SPRITE_SIZE;
            } else {
                self.active_tile.y = 0;
            }
        }

        if (rl.isKeyPressed(rl.KeyboardKey.key_s)) {
            const tileset = state.sprite_tiles.get(self.active_tileset).?;
            const tilesetHeight: f32 = @floatFromInt(tileset.height - SPRITE_SIZE);
            if (self.active_tile.y < tilesetHeight) {
                self.active_tile.y += SPRITE_SIZE;
            } else {
                self.active_tile.y = tilesetHeight;
            }
        }

        if (rl.isKeyPressed(rl.KeyboardKey.key_d)) {
            const tileset = state.sprite_tiles.get(self.active_tileset).?;
            const tilesetWidth: f32 = @floatFromInt(tileset.width - SPRITE_SIZE);
            if (self.active_tile.x < tilesetWidth) {
                self.active_tile.x += SPRITE_SIZE;
            } else {
                self.active_tile.x = tilesetWidth;
            }
        }

        if (rl.isKeyPressed(rl.KeyboardKey.key_a)) {
            if (self.active_tile.x > 0) {
                self.active_tile.x -= SPRITE_SIZE;
            } else {
                self.active_tile.x = 0;
            }
        }
    }

    pub fn updateStartPointTool(_: *Toolbox, state: *GameState) void {
        if (rl.isMouseButtonPressed(rl.MouseButton.mouse_button_left)) {
            const mouse_pos = rl.getMousePosition();
            const tileVec = Tile.toTilePos(mouse_pos);
            state.map_editor.start_point = rl.Vector2.init(tileVec.x * TILE_SIZE, tileVec.y * TILE_SIZE);
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
            self.selected_point = if (mouse_pos.distance(rl.Vector2.init(boundary.x, boundary.y)) < TILE_SIZE * 2)
                .ne
            else if (mouse_pos.distance(rl.Vector2.init(boundary.x + boundary.width, boundary.y)) < TILE_SIZE * 2)
                .nw
            else if (mouse_pos.distance(rl.Vector2.init(boundary.x, boundary.y + boundary.height)) < TILE_SIZE * 2)
                .se
            else if (mouse_pos.distance(rl.Vector2.init(boundary.x + boundary.width, boundary.y + boundary.height)) < TILE_SIZE * 2)
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
            if (state.sprite_tiles.get(self.active_tileset)) |texture| {
                const tilesetPosition = rl.getScreenToWorld2D(rl.Vector2.zero(), state.cam);
                texture.drawV(tilesetPosition, rl.Color.white);
                rl.drawRectangleLinesEx(
                    rl.Rectangle.init(
                        tilesetPosition.x + self.active_tile.x,
                        tilesetPosition.y + self.active_tile.y,
                        SPRITE_SIZE,
                        SPRITE_SIZE,
                    ),
                    1,
                    rl.Color.red,
                );
            }
        }

        if (self.kind == .paint) {
            if (state.sprite_tiles.get(self.active_tileset)) |texture| {
                const cursorRect = rl.Rectangle.init(self.pos.x, self.pos.y, TILE_SIZE, TILE_SIZE);
                texture.drawPro(Tileset.sourceRect(self.active_tile), cursorRect, rl.Vector2.zero(), 0, rl.Color.white);
            }
        } else {
            rl.drawTextureV(self.icon, self.pos, rl.Color.white);
        }
    }

    pub fn nextTile(self: *Toolbox, state: *GameState) void {
        const tileset = state.sprite_tiles.get(self.active_tileset) orelse return;
        const tilesetWidth: f32 = @floatFromInt(tileset.width);
        const tilesetHeight: f32 = @floatFromInt(tileset.height);

        if (self.active_tile.x >= tilesetWidth and self.active_tile.y >= tilesetHeight - SPRITE_SIZE) {
            self.active_tile.x = 0;
            self.active_tile.y = 0;
        } else if (self.active_tile.x >= tilesetWidth) {
            self.active_tile.x = 0;
            self.active_tile.y += SPRITE_SIZE;
        } else {
            self.active_tile.x += SPRITE_SIZE;
        }

        std.debug.print("active_tile: {d}, {d}\n", .{ self.active_tile.x, self.active_tile.y });
    }

    pub fn prevTile(self: *Toolbox, state: *GameState) void {
        const tileset = state.sprite_tiles.get(self.active_tileset) orelse return;
        const tilesetWidth: f32 = @floatFromInt(tileset.width);
        const tilesetHeight: f32 = @floatFromInt(tileset.height);

        if (self.active_tile.y <= 0 and self.active_tile.x <= 0) {
            self.active_tile.x = tilesetWidth;
            self.active_tile.y = tilesetHeight - SPRITE_SIZE;
        } else if (self.active_tile.x <= 0) {
            self.active_tile.x = tilesetWidth;
            self.active_tile.y -= SPRITE_SIZE;
        } else {
            self.active_tile.x -= SPRITE_SIZE;
        }

        std.debug.print("active_tile: {d}, {d}\n", .{ self.active_tile.x, self.active_tile.y });
    }
};
