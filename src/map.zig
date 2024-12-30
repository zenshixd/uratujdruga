const std = @import("std");
const rl = @import("raylib");

const Toolbox = @import("toolbox.zig").Toolbox;
const GameState = @import("main.zig").GameState;
const stats = @import("stats.zig");
const Assets = @import("assets.zig");

pub const Tileset = enum {
    buildings,
    hive,
    interior,
    rocks,
    tiles,
    tree_assets,
    catacombs,
    catacombs_decor,

    pub fn getTexture(tileset: Tileset, assets: Assets) rl.Texture2D {
        return switch (tileset) {
            .buildings => assets.getTexture(.buildings),
            .hive => assets.getTexture(.hive),
            .interior => assets.getTexture(.interior),
            .rocks => assets.getTexture(.rocks),
            .tiles => assets.getTexture(.tiles),
            .tree_assets => assets.getTexture(.tree_assets),
            .catacombs => assets.getTexture(.catacombs),
            .catacombs_decor => assets.getTexture(.catacombs_decor),
        };
    }

    pub fn sourceRect(offset: rl.Vector2) rl.Rectangle {
        return rl.Rectangle.init(offset.x, offset.y, stats.sprite_size, stats.sprite_size);
    }
};

pub const Tile = struct {
    position: rl.Vector2,
    tileset: Tileset = .catacombs,
    offset: rl.Vector2 = rl.Vector2.init(0, 0),
    is_solid: bool = true,
    layer: u8 = 0,

    pub fn rect(self: Tile) rl.Rectangle {
        return rl.Rectangle.init(
            self.position.x * stats.tile_size,
            self.position.y * stats.tile_size,
            stats.tile_size,
            stats.tile_size,
        );
    }

    pub fn draw(self: Tile, state: *GameState) void {
        self.drawExtra(state, 1);
    }

    pub fn drawExtra(self: Tile, state: *GameState, opacity: f32) void {
        const texture = self.tileset.getTexture(state.assets);
        texture.drawPro(Tileset.sourceRect(self.offset), self.rect(), rl.Vector2.zero(), 0, rl.Color.white.fade(opacity));
    }

    pub fn toTilePos(pos: rl.Vector2) rl.Vector2 {
        const x = @divFloor(pos.x, stats.tile_size);
        const y = @divFloor(pos.y, stats.tile_size);

        return rl.Vector2.init(x, y);
    }
};

pub const MapEditor = struct {
    toolbox: Toolbox,
    tiles: std.ArrayList(Tile),
    player_spawn_point: rl.Vector2,
    druga_spawn_point: rl.Vector2,
    boundary: rl.Rectangle,

    pub fn init(allocator: std.mem.Allocator, map_level: *const MapLevel) MapEditor {
        var tiles = std.ArrayList(Tile).init(allocator);
        tiles.appendSlice(map_level.tiles) catch unreachable;

        return MapEditor{
            .tiles = tiles,
            .player_spawn_point = map_level.player_spawn_point,
            .druga_spawn_point = map_level.druga_spawn_point,
            .boundary = map_level.boundary,
            .toolbox = Toolbox.init(allocator),
        };
    }

    pub fn update(self: *MapEditor, state: *GameState) void {
        self.toolbox.update(state);
    }

    pub fn draw(self: *MapEditor, state: *GameState) void {
        const display_layer = self.toolbox.display_layer;
        for (self.tiles.items) |tile| {
            //if (tile.layer > display_layer) {
            //    continue;
            //}

            const opacity: f32 = if (tile.layer == display_layer) 1 else 0.5;
            tile.drawExtra(state, opacity);
            if (tile.is_solid) {
                rl.drawRectangleRec(tile.rect(), rl.Color.red.fade(0.3));
            }
        }

        rl.drawCircleV(self.player_spawn_point.addValue(stats.tile_size / 2), 10, rl.Color.lime);
        rl.drawRectangleLinesEx(self.boundary, 3, rl.Color.blue);
        self.toolbox.draw(state);
    }

    pub fn toMapLevel(self: *MapEditor) MapLevel {
        return MapLevel{
            .tiles = self.tiles.items,
            .boundary = self.boundary,
            .player_spawn_point = self.player_spawn_point,
        };
    }

    pub fn save(self: *MapEditor) !void {
        const file = try std.fs.cwd().createFile("map.json", .{});
        defer file.close();

        const writer = file.writer();

        try std.json.stringify(MapLevel{
            .tiles = self.tiles.items,
            .boundary = self.boundary,
            .player_spawn_point = self.player_spawn_point,
        }, .{ .whitespace = .indent_2 }, writer);
    }
};

pub const MapLevel = struct {
    tiles: []const Tile = &[_]Tile{
        Tile{ .position = rl.Vector2.init(0, 3) },
        Tile{ .position = rl.Vector2.init(1, 3) },
        Tile{ .position = rl.Vector2.init(2, 3) },
        Tile{ .position = rl.Vector2.init(3, 3) },
    },
    player_spawn_point: rl.Vector2 = rl.Vector2.init(0, 0),
    druga_spawn_point: rl.Vector2 = rl.Vector2.init(0, 0),
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

    pub fn draw(self: *MapLevel, state: *GameState, layer: u8) void {
        for (self.tiles) |tile| {
            if (tile.layer == layer) {
                tile.draw(state);
            }
        }
    }
};
