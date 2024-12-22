const std = @import("std");
const rl = @import("raylib");
const Toolbox = @import("toolbox.zig").Toolbox;

const SCREEN_WIDTH = 800;
const SCREEN_HEIGHT = 600;
pub const TILE_SIZE = 32;
pub const SPRITE_SIZE = 16;

pub const Tileset = enum {
    buildings,
    hive,
    interior,
    rocks,
    tiles,
    tree_assets,

    pub fn getTexture(tileset: Tileset) rl.Texture2D {
        const filename = switch (tileset) {
            .buildings => "assets/sprites/buildings.png",
            .hive => "assets/sprites/hive.png",
            .interior => "assets/sprites/interior.png",
            .rocks => "assets/sprites/rocks.png",
            .tiles => "assets/sprites/tiles.png",
            .tree_assets => "assets/sprites/tree_assets.png",
        };
        return rl.loadTexture(filename);
    }

    pub fn sourceRect(offset: rl.Vector2) rl.Rectangle {
        return rl.Rectangle.init(offset.x, offset.y, SPRITE_SIZE, SPRITE_SIZE);
    }
};

const DebugInfo = struct {
    enabled: bool = false,
    line_num: i32 = 0,
    coordsBuffer: [256]u8 = undefined,

    pub fn draw(self: *DebugInfo, state: *GameState) void {
        if (self.enabled) {
            const cam = state.cam;
            const player = state.player;
            const map_editor = state.map_editor;

            self.line_num = 0;
            self.drawText("cam x: {d:.2} y: {d:.2}", .{ cam.target.x, cam.target.y });
            self.drawText("player x: {d:.2} y: {d:.2}", .{ player.rect.x, player.rect.y });
            self.drawText("player velocity x: {d:.2} y: {d:.2}", .{ player.velocity.x, player.velocity.y });
            self.drawText("cursor x: {d:.2} y: {d:.2}", .{ rl.getMousePosition().x, rl.getMousePosition().y });
            self.drawText("boundary x: {d:.2} y: {d:.2}, width: {d:.2}, height: {d:.2}", .{ map_editor.boundary.x, map_editor.boundary.y, map_editor.boundary.width, map_editor.boundary.height });
            self.drawText("selected point: {s}", .{@tagName(map_editor.toolbox.selected_point)});
        }
    }

    pub fn drawGrid(self: *DebugInfo) void {
        if (self.enabled) {
            const LINES = 100;

            var i: i32 = -LINES;
            while (i < LINES) : (i += 1) {
                rl.drawLineEx(rl.Vector2.init(@floatFromInt(i * TILE_SIZE), -9000), rl.Vector2.init(@floatFromInt(i * TILE_SIZE), 9000), 1, rl.Color.light_gray);
                rl.drawLineEx(rl.Vector2.init(-9000, @floatFromInt(i * TILE_SIZE)), rl.Vector2.init(9000, @floatFromInt(i * TILE_SIZE)), 1, rl.Color.light_gray);
            }
        }
    }

    fn drawText(self: *DebugInfo, comptime fmt: []const u8, args: anytype) void {
        const text = std.fmt.bufPrintZ(&self.coordsBuffer, fmt, args) catch unreachable;
        rl.drawText(text, 5, 5 + self.line_num * 20, 16, rl.Color.red);
        self.line_num += 1;
    }
};

pub const PLAYER_SPEED = 200;
pub const DECELERATION = 0.9;
pub const GRAVITY = 800;
pub const JUMP_SPEED = 500;
pub const PLAYER_SIZE_X = 30;
pub const PLAYER_SIZE_Y = 50;

pub const Player = struct {
    rect: rl.Rectangle,
    velocity: rl.Vector2 = rl.Vector2.init(0, 0),
    colliding_rects: std.ArrayList(rl.Rectangle),
    on_ground: bool = false,

    pub fn init(allocator: std.mem.Allocator, start_point: rl.Vector2) Player {
        return Player{
            .rect = rl.Rectangle.init(start_point.x, start_point.y, PLAYER_SIZE_X, PLAYER_SIZE_Y),
            .colliding_rects = std.ArrayList(rl.Rectangle).init(allocator),
        };
    }

    pub fn update(self: *Player, state: *GameState) void {
        self.velocity.y += GRAVITY * rl.getFrameTime();

        if (rl.isKeyDown(rl.KeyboardKey.key_space) and self.on_ground) {
            self.velocity.y = -JUMP_SPEED;
        }

        if (rl.isKeyDown(rl.KeyboardKey.key_d)) {
            self.velocity.x = PLAYER_SPEED;
        } else if (rl.isKeyDown(rl.KeyboardKey.key_a)) {
            self.velocity.x = -PLAYER_SPEED;
        } else {
            self.velocity.x = self.velocity.x * DECELERATION * rl.getFrameTime();
        }

        // check for collisions twice: once for X axis and once for Y axis
        // Dont apply velocity immediately - instead check for collisions after only applying velocity on one axis
        // e.g. apply X velocity, check for collisions - apply offset if colliding, apply final X position to rect
        var isXColliding = false;
        var isYColliding = false;
        self.on_ground = false;
        for (state.map_level.tiles) |tile| {
            if (!tile.is_solid) {
                continue;
            }

            const newXRect = rl.Rectangle.init(self.getNewXPos(), self.rect.y, self.rect.width, self.rect.height);
            if (newXRect.checkCollision(tile.rect())) {
                const colliding_rect = newXRect.getCollision(tile.rect());

                isXColliding = true;
                self.rect.x = newXRect.x + if (tile.rect().x < self.rect.x) colliding_rect.width else -colliding_rect.width;
                self.velocity.x = 0;
            }

            const newYRect = rl.Rectangle.init(self.rect.x, self.getNewYPos(), self.rect.width, self.rect.height);
            if (newYRect.checkCollision(tile.rect())) {
                const colliding_rect = newYRect.getCollision(tile.rect());

                self.rect.y = newYRect.y + if (tile.rect().y < self.rect.y) colliding_rect.height else -colliding_rect.height;
                self.velocity.y = 0;
                isYColliding = true;

                if (tile.rect().y > self.rect.y) {
                    self.on_ground = true;
                }
            }
        }

        if (!isXColliding) {
            self.rect.x = self.getNewXPos();
        }

        if (!isYColliding) {
            self.rect.y = self.getNewYPos();
        }

        if (self.rect.x < state.map_level.boundary.x) {
            self.rect.x = state.map_level.boundary.x;
        } else if (self.rect.x > state.map_level.boundary.x + state.map_level.boundary.width) {
            self.rect.x = state.map_level.boundary.x + state.map_level.boundary.width;
        }

        if (self.rect.y < state.map_level.boundary.y) {
            self.rect.y = state.map_level.boundary.y;
        } else if (self.rect.y > state.map_level.boundary.y + state.map_level.boundary.height) {
            self.rect.y = state.map_level.boundary.y + state.map_level.boundary.height;
        }
    }

    pub fn getNewXPos(self: Player) f32 {
        return self.rect.x + self.velocity.x * rl.getFrameTime();
    }

    pub fn getNewYPos(self: Player) f32 {
        return self.rect.y + self.velocity.y * rl.getFrameTime();
    }

    pub fn draw(self: *Player) void {
        rl.drawRectangleRec(self.rect, rl.Color.green);
    }

    pub fn getCenter(self: Player) rl.Vector2 {
        return rl.Vector2.init(self.rect.x + self.rect.width / 2, self.rect.y + self.rect.height / 2);
    }
};

pub const Tile = struct {
    position: rl.Vector2,
    tileset: Tileset = .tiles,
    offset: rl.Vector2 = rl.Vector2.init(0, 0),
    is_solid: bool = true,

    pub fn rect(self: Tile) rl.Rectangle {
        return rl.Rectangle.init(
            self.position.x * TILE_SIZE,
            self.position.y * TILE_SIZE,
            TILE_SIZE,
            TILE_SIZE,
        );
    }

    pub fn draw(self: Tile, state: *GameState) void {
        if (state.sprite_tiles.get(self.tileset)) |texture| {
            texture.drawPro(Tileset.sourceRect(self.offset), self.rect(), rl.Vector2.zero(), 0, rl.Color.white);
        }
    }

    pub fn toTilePos(pos: rl.Vector2) rl.Vector2 {
        const x = @divFloor(pos.x, TILE_SIZE);
        const y = @divFloor(pos.y, TILE_SIZE);

        return rl.Vector2.init(x, y);
    }
};

pub const MapEditor = struct {
    toolbox: Toolbox,
    tiles: std.ArrayList(Tile),
    start_point: rl.Vector2,
    boundary: rl.Rectangle,

    pub fn init(allocator: std.mem.Allocator, map_level: *const MapLevel) MapEditor {
        var tiles = std.ArrayList(Tile).init(allocator);
        tiles.appendSlice(map_level.tiles) catch unreachable;

        return MapEditor{
            .tiles = tiles,
            .start_point = map_level.start_point,
            .boundary = map_level.boundary,
            .toolbox = Toolbox.init(allocator),
        };
    }

    pub fn update(self: *MapEditor, state: *GameState) void {
        self.toolbox.update(state);
    }

    pub fn draw(self: *MapEditor, state: *GameState) void {
        for (self.tiles.items) |tile| {
            tile.draw(state);
            if (tile.is_solid) {
                rl.drawRectangleRec(tile.rect(), rl.Color.red.fade(0.3));
            }
        }

        rl.drawCircleV(self.start_point.addValue(TILE_SIZE / 2), 10, rl.Color.lime);
        rl.drawRectangleLinesEx(self.boundary, 3, rl.Color.blue);
        self.toolbox.draw(state);
    }

    pub fn save(self: *MapEditor) !void {
        const file = try std.fs.cwd().createFile("map.json", .{});
        defer file.close();

        const writer = file.writer();

        try std.json.stringify(MapLevel{
            .start_point = self.start_point,
            .tiles = self.tiles.items,
            .boundary = self.boundary,
        }, .{ .whitespace = .indent_2 }, writer);
    }
};

const MapLevel = struct {
    tiles: []const Tile = &[_]Tile{
        Tile{ .position = rl.Vector2.init(0, 3) },
        Tile{ .position = rl.Vector2.init(1, 3) },
        Tile{ .position = rl.Vector2.init(2, 3) },
        Tile{ .position = rl.Vector2.init(3, 3) },
    },
    start_point: rl.Vector2 = rl.Vector2.init(0, 0),
    boundary: rl.Rectangle = rl.Rectangle.init(0, 0, 1000, 1000),

    pub fn load(allocator: std.mem.Allocator) !MapLevel {
        const file = std.fs.cwd().openFile("map.json", .{}) catch |err| switch (err) {
            error.FileNotFound => {
                std.debug.print("File map.json not found\n", .{});
                return MapLevel{};
            },
            else => |e| return e,
        };
        defer file.close();

        const file_reader = file.reader();
        var json_reader = std.json.reader(allocator, file_reader);

        const parsedMapLevel = std.json.parseFromTokenSource(MapLevel, allocator, &json_reader, .{}) catch |err| {
            std.debug.print("Error parsing map.json: {s}\n", .{@errorName(err)});
            return MapLevel{};
        };

        return parsedMapLevel.value;
    }

    pub fn draw(self: *MapLevel, state: *GameState) void {
        for (self.tiles) |tile| {
            tile.draw(state);
        }
    }
};

pub const GameState = struct {
    const Mode = enum { editor, play };

    allocator: std.mem.Allocator,
    mode: Mode = .play,
    player: Player,
    cam: rl.Camera2D,
    map_level: MapLevel,
    map_editor: MapEditor,
    debug_info: DebugInfo = .{},
    sprite_tiles: std.EnumMap(Tileset, rl.Texture2D),

    pub fn init(allocator: std.mem.Allocator) GameState {
        const map_level = MapLevel.load(allocator) catch unreachable;
        const player = Player.init(allocator, map_level.start_point);
        var sprite_tiles = std.EnumMap(Tileset, rl.Texture2D){};

        inline for (std.meta.fields(Tileset)) |kind| {
            sprite_tiles.put(@enumFromInt(kind.value), Tileset.getTexture(@enumFromInt(kind.value)));
        }

        return GameState{
            .allocator = allocator,
            .player = player,
            .cam = rl.Camera2D{
                .target = player.getCenter(),
                .offset = getScreenCenter(),
                .rotation = 0,
                .zoom = 1,
            },
            .sprite_tiles = sprite_tiles,
            .map_level = map_level,
            .map_editor = MapEditor.init(allocator, &map_level),
        };
    }

    pub fn tick(self: *GameState) void {
        if (rl.isKeyPressed(rl.KeyboardKey.key_f1)) {
            self.debug_info.enabled = !self.debug_info.enabled;
        }

        if (rl.isKeyPressed(rl.KeyboardKey.key_f2)) {
            self.mode = if (self.mode == .editor) .play else .editor;
            if (self.mode == .play) {
                self.map_editor.save() catch unreachable;

                self.map_level.tiles = self.allocator.dupe(Tile, self.map_editor.tiles.items) catch unreachable;
                self.map_level.start_point = self.map_editor.start_point;
                self.map_level.boundary = self.map_editor.boundary;

                self.player = Player.init(self.allocator, self.map_level.start_point);
                self.player.rect.x = self.map_level.start_point.x;
                self.player.rect.y = self.map_level.start_point.y;
            }
        }

        if (self.mode == .editor) {
            self.map_editor.update(self);
        } else {
            self.player.update(self);
        }

        if (self.mode == .play) {
            const minTarget = rl.Vector2.init(
                self.map_level.boundary.x + self.cam.offset.x,
                self.map_level.boundary.y + self.cam.offset.y,
            );
            const maxTarget = rl.Vector2.init(
                self.map_level.boundary.x - self.cam.offset.x + self.map_level.boundary.width,
                self.map_level.boundary.y - self.cam.offset.y + self.map_level.boundary.height,
            );

            self.cam.target = self.player.getCenter().clamp(minTarget, maxTarget);
        } else {
            if (rl.isMouseButtonDown(rl.MouseButton.mouse_button_right)) {
                self.cam.target = rl.Vector2.add(self.cam.target, rl.getMouseDelta().scale(-1));

                var cursor = self.map_editor.toolbox;
                cursor.pos = cursor.pos.add(rl.getMouseDelta().scale(-1));
            }
        }
    }

    pub fn draw(self: *GameState) void {
        rl.clearBackground(rl.Color.white);

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.beginMode2D(self.cam);
        defer rl.endMode2D();

        if (self.mode == .editor) {
            self.map_editor.draw(self);
        } else {
            self.map_level.draw(self);
            self.player.draw();
        }

        self.debug_info.drawGrid();
        self.debug_info.draw(self);
    }

    pub fn getScreenCenter() rl.Vector2 {
        return rl.Vector2.init(
            @floatFromInt(@divFloor(rl.getScreenWidth(), 2)),
            @floatFromInt(@divFloor(rl.getScreenHeight(), 2)),
        );
    }
};

pub fn main() anyerror!void {
    rl.initWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Save the Druga");
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.toggleBorderlessWindowed();
    rl.disableCursor();

    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second

    var state = GameState.init(std.heap.page_allocator);

    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        // Update
        state.tick();

        // Draw
        state.draw();
    }

    try state.map_editor.save();
}
