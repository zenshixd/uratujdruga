const std = @import("std");
const rl = @import("raylib");
const Assets = @import("assets.zig").Assets;
const Toolbox = @import("toolbox.zig").Toolbox;

const SCREEN_WIDTH = 800;
const SCREEN_HEIGHT = 600;
pub const TILE_SIZE = 32;
pub const SPRITE_SIZE = 16;
pub const PLAYER_SPEED = 200;
pub const ENEMY_SPEED = 50;
pub const DECELERATION = 0.85;
pub const GRAVITY = 800;
pub const JUMP_SPEED = 500;

pub const PLAYER_SIZE_X = 30;
pub const PLAYER_SIZE_Y = 50;
pub const HAMMER_SIZE_X = 10;
pub const HAMMER_SIZE_Y = 200;
pub const HAMMER_HEAD_RADIUS = 30;
pub const HAMMER_START_ANGLE = 220;
pub const HAMMER_SWING_ANGLE = 100;
pub const ATTACK_DURATION = 0.4;
pub const DAMAGE_COOLDOWN = 1;
pub const KNOCKBACK_DISTANCE = 300;

const Facing = enum { left, right };

var assets: Assets = .{};

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

const Movable = struct {
    pub fn applyMovement(rect: *rl.Rectangle, velocity: *rl.Vector2, state: *GameState) void {
        // check for collisions twice: once for X axis and once for Y axis
        // Dont apply velocity immediately - instead check for collisions after only applying velocity on one axis
        // e.g. apply X velocity, check for collisions - apply offset if colliding, apply final X position to rect
        var isXColliding = false;
        var isYColliding = false;
        for (state.map_level.tiles) |tile| {
            if (!tile.is_solid) {
                continue;
            }

            const newXRect = getNewXRect(rect.*, velocity.*);
            if (newXRect.checkCollision(tile.rect())) {
                const colliding_rect = newXRect.getCollision(tile.rect());

                isXColliding = true;
                rect.x = newXRect.x + if (tile.rect().x < rect.x) colliding_rect.width else -colliding_rect.width;
                velocity.x = 0;
            }

            const newYRect = getNewYRect(rect.*, velocity.*);
            if (newYRect.checkCollision(tile.rect())) {
                const colliding_rect = newYRect.getCollision(tile.rect());

                rect.y = newYRect.y + if (tile.rect().y < rect.y) colliding_rect.height else -colliding_rect.height;
                velocity.y = 0;
                isYColliding = true;
            }
        }

        if (!isXColliding) {
            rect.x += velocity.x * rl.getFrameTime();
        }

        if (!isYColliding) {
            rect.y += velocity.y * rl.getFrameTime();
        }

        if (rect.x < state.map_level.boundary.x) {
            rect.x = state.map_level.boundary.x;
        } else if (rect.x > state.map_level.boundary.x + state.map_level.boundary.width) {
            rect.x = state.map_level.boundary.x + state.map_level.boundary.width;
        }

        if (rect.y < state.map_level.boundary.y) {
            rect.y = state.map_level.boundary.y;
        } else if (rect.y > state.map_level.boundary.y + state.map_level.boundary.height) {
            rect.y = state.map_level.boundary.y + state.map_level.boundary.height;
        }
    }

    pub fn getNewXRect(rect: rl.Rectangle, velocity: rl.Vector2) rl.Rectangle {
        return rl.Rectangle.init(rect.x + velocity.x * rl.getFrameTime(), rect.y, rect.width, rect.height);
    }

    pub fn getNewYRect(rect: rl.Rectangle, velocity: rl.Vector2) rl.Rectangle {
        return rl.Rectangle.init(rect.x, rect.y + velocity.y * rl.getFrameTime(), rect.width, rect.height);
    }
};

const Projectile = struct {
    position: rl.Vector2,
    radius: f32,
    velocity: rl.Vector2,

    pub fn update(self: *Projectile) void {
        self.position.x += self.velocity.x * rl.getFrameTime();
        self.position.y += self.velocity.y * rl.getFrameTime();
    }

    pub fn shouldDestroy(self: Projectile, state: *GameState) bool {
        const boundary = state.map_level.boundary;
        return self.position.x < boundary.x or self.position.x > boundary.x + boundary.width or self.position.y < boundary.y or self.position.y > boundary.y + boundary.height;
    }

    pub fn draw(self: *Projectile) void {
        rl.drawCircleGradient(@intFromFloat(self.position.x), @intFromFloat(self.position.y), self.radius, rl.Color.white, rl.Color.red);
    }
};

const Enemy = struct {
    rect: rl.Rectangle,
    velocity: rl.Vector2 = rl.Vector2.init(0, 0),
    facing: Facing = .right,
    health: f32 = 10,
    simple_ball_attack_time: f64 = -1,
    spiral_ball_next_attack_time: f64 = SPIRAL_BALL_ATTACK_COOLDOWN,
    spiral_ball_attack_end_time: f64 = 0,
    prev_spiral_ball_time: f64 = 0,
    last_damage_time: f64 = -DAMAGE_COOLDOWN,
    projectiles: std.BoundedArray(Projectile, 100) = .{},

    const PROJECTILE_SPEED = 100;
    const DAMAGE_TAKEN_BLINK_FREQUENCY = 0.05;

    const SIMPLE_BALL_ATTACK_PROJ_COUNT = 12;
    const SIMPLE_BALL_ATTACK_COOLDOWN = 5;

    const SPIRAL_BALL_ATTACK_COOLDOWN = 5;
    const SPIRAL_BALL_FREQUENCY = 0.2;
    const SPIRAL_BALL_DURATION = SPIRAL_BALL_FREQUENCY * 10;

    pub fn init(spawn_point: rl.Vector2) Enemy {
        return .{
            .rect = rl.Rectangle.init(spawn_point.x, spawn_point.y, PLAYER_SIZE_X, PLAYER_SIZE_Y),
        };
    }

    pub fn isTakingDamageOnCooldown(self: Enemy) bool {
        return rl.getTime() - self.last_damage_time < DAMAGE_COOLDOWN;
    }

    pub fn dealDamage(self: *Enemy, source: *Player, damage: f32) void {
        if (self.isTakingDamageOnCooldown()) {
            // dealing damage has 1s cooldown
            return;
        }

        self.health -= damage;
        self.last_damage_time = rl.getTime();
        const knockback_direction = rl.Vector2.init(self.rect.x - source.rect.x, self.rect.y - source.rect.y).normalize();
        self.velocity = self.velocity.add(knockback_direction.scale(KNOCKBACK_DISTANCE));
        rl.playSound(assets.bonk_sound);
    }

    pub fn update(self: *Enemy, state: *GameState) void {
        if (self.facing == .left) {
            self.velocity.x = -ENEMY_SPEED;
        } else {
            self.velocity.x = ENEMY_SPEED;
        }
        self.velocity.y += GRAVITY * rl.getFrameTime();

        Movable.applyMovement(&self.rect, &self.velocity, state);
        for (self.projectiles.slice(), 0..) |*projectile, i| {
            projectile.update();
            if (projectile.shouldDestroy(state)) {
                std.debug.print("destroying projectile\n", .{});
                _ = self.projectiles.orderedRemove(i);
            }
        }

        const distToLeftEdge = self.rect.x - state.map_level.boundary.x;
        const distToRightEdge = state.map_level.boundary.x + state.map_level.boundary.width - self.rect.x;
        if (distToLeftEdge < 10) {
            self.facing = .right;
        } else if (distToRightEdge < 10) {
            self.facing = .left;
        }

        const time = rl.getTime();
        if (time - self.simple_ball_attack_time > SIMPLE_BALL_ATTACK_COOLDOWN) {
            std.debug.print("simple ball\n", .{});
            self.simple_ball_attack_time = rl.getTime();
            self.simpleBallAttack();
        }

        if (time > self.spiral_ball_next_attack_time) {
            self.spiral_ball_attack_end_time = time + SPIRAL_BALL_DURATION;
            self.spiral_ball_next_attack_time = time + SPIRAL_BALL_ATTACK_COOLDOWN;
        }

        if (time < self.spiral_ball_attack_end_time) {
            std.debug.print("spiral ball\n", .{});
            self.spiralBallAttack(&state.player);
        }
    }

    pub fn simpleBallAttack(self: *Enemy) void {
        for (0..SIMPLE_BALL_ATTACK_PROJ_COUNT) |i| {
            const angle = std.math.degreesToRadians(@as(f32, @floatFromInt(360 * i / SIMPLE_BALL_ATTACK_PROJ_COUNT)));
            const velocity = rl.Vector2.init(1, 0).rotate(angle).scale(PROJECTILE_SPEED);
            std.debug.print("velocity: {d:.2}, {d:.2}\n", .{ velocity.x, velocity.y });
            self.projectiles.append(.{
                .position = rl.Vector2.init(self.rect.x + self.rect.width / 2, self.rect.y + self.rect.height / 2),
                .radius = 10,
                .velocity = velocity,
            }) catch std.debug.print("Failed to append projectile\n", .{});
        }
    }

    pub fn spiralBallAttack(self: *Enemy, target: *Player) void {
        const prev_ball_time_delta = rl.getTime() - self.prev_spiral_ball_time;
        if (prev_ball_time_delta > SPIRAL_BALL_FREQUENCY) {
            const attack_time_until_done = self.spiral_ball_attack_end_time - rl.getTime();
            const angle = std.math.degreesToRadians(45 + -90 * attack_time_until_done / SPIRAL_BALL_DURATION);
            self.prev_spiral_ball_time = rl.getTime();
            self.projectiles.append(.{
                .position = rl.Vector2.init(self.rect.x + self.rect.width / 2, self.rect.y + self.rect.height / 2),
                .radius = 10,
                .velocity = rl.Vector2.init(target.rect.x - self.rect.x, target.rect.y - self.rect.y).normalize().rotate(@floatCast(angle)).scale(PROJECTILE_SPEED),
            }) catch std.debug.print("Failed to append projectile\n", .{});
        }
    }

    pub fn draw(self: *Enemy) void {
        var color = rl.Color.red.fade(self.health / 10);
        if (self.isTakingDamageOnCooldown()) {
            color = color.fade(self.health / 10 * self.damageTakenFade());
        }
        rl.drawRectangleRec(self.rect, color);

        for (self.projectiles.slice()) |*projectile| {
            projectile.draw();
        }
    }

    pub fn damageTakenFade(self: *Enemy) f32 {
        const time_delta = rl.getTime() - self.last_damage_time;
        const rem = @mod(time_delta, DAMAGE_TAKEN_BLINK_FREQUENCY * 2);

        if (rem < DAMAGE_TAKEN_BLINK_FREQUENCY) {
            return 0.0;
        } else {
            return 1.0;
        }
    }
};

const Hammer = struct {
    rect: rl.Rectangle = rl.Rectangle.init(0, 0, HAMMER_SIZE_X, HAMMER_SIZE_Y),
    facing: Facing = .right,
    rotation: f32 = 0,
    attack_time: f64 = 0,

    pub fn checkCollision(self: Hammer, rect: rl.Rectangle) bool {
        return rl.checkCollisionCircleRec(self.headPoint(), HAMMER_HEAD_RADIUS, rect);
    }

    pub fn headPoint(self: Hammer) rl.Vector2 {
        return rl.Vector2.init(self.rect.x, self.rect.y).add(rl.Vector2.init(0, HAMMER_SIZE_Y).rotate(std.math.degreesToRadians(self.rotation)));
    }

    pub fn update(self: *Hammer, state: *GameState) void {
        const player = &state.player;
        self.rect.x = player.rect.x;
        self.rect.y = player.rect.y + PLAYER_SIZE_Y / 3;
        self.facing = player.facing;

        if (self.facing == .left) {
            self.rect.x += PLAYER_SIZE_X - HAMMER_SIZE_X / 2;
        } else {
            self.rect.x += HAMMER_SIZE_X / 2;
        }

        const attackDelta = rl.getTime() - self.attack_time;
        self.rotation = @floatCast(HAMMER_START_ANGLE + HAMMER_SWING_ANGLE * attackDelta / ATTACK_DURATION);

        if (self.facing == .left) {
            self.rotation *= -1;
        }

        if (attackDelta > ATTACK_DURATION) {
            self.attack_time = 0;
        }

        if (self.attack_time > 0 and self.checkCollision(state.enemy.rect)) {
            state.enemy.dealDamage(&state.player, 1);
        }
    }

    pub fn draw(self: *Hammer) void {
        if (self.attack_time > 0) {
            // Handle
            rl.drawRectanglePro(self.rect, rl.Vector2.init(HAMMER_SIZE_X / 2, 0), self.rotation, rl.Color.red);
            // Head
            rl.drawCircleV(self.headPoint(), HAMMER_HEAD_RADIUS, rl.Color.red);
        }
    }
};

pub const Player = struct {
    rect: rl.Rectangle,
    facing: Facing = .right,
    hammer: Hammer = .{},
    jump_time: f64 = -1,
    velocity: rl.Vector2 = rl.Vector2.init(0, 0),

    pub fn init(start_point: rl.Vector2) Player {
        return Player{
            .rect = rl.Rectangle.init(start_point.x, start_point.y, PLAYER_SIZE_X, PLAYER_SIZE_Y),
        };
    }

    pub fn update(self: *Player, state: *GameState) void {
        const jump_time_delta = rl.getTime() - self.jump_time;
        if (rl.isKeyUp(rl.KeyboardKey.key_space) and jump_time_delta < 0.1) {
            self.velocity.y *= 0.6;
        }

        if (rl.isKeyDown(rl.KeyboardKey.key_space) and self.velocity.y == 0) {
            self.jump_time = rl.getTime();
            self.velocity.y = -JUMP_SPEED;
        }

        self.velocity.y += GRAVITY * rl.getFrameTime();
        if (rl.isKeyDown(rl.KeyboardKey.key_d)) {
            self.velocity.x = PLAYER_SPEED;
            self.facing = .right;
        } else if (rl.isKeyDown(rl.KeyboardKey.key_a)) {
            self.velocity.x = -PLAYER_SPEED;
            self.facing = .left;
        } else {
            self.velocity.x *= DECELERATION;
        }

        if (rl.isKeyPressed(rl.KeyboardKey.key_r)) {
            self.hammer.attack_time = rl.getTime();
        }
        Movable.applyMovement(&self.rect, &self.velocity, state);
        self.hammer.update(state);
    }

    pub fn draw(self: *Player) void {
        rl.drawRectangleRec(self.rect, rl.Color.green);
        if (self.facing == .right) {
            rl.drawCircleV(rl.Vector2.init(self.rect.x + PLAYER_SIZE_X, self.rect.y + 5), 5, rl.Color.dark_purple);
        } else {
            rl.drawCircleV(rl.Vector2.init(self.rect.x, self.rect.y + 5), 5, rl.Color.dark_purple);
        }
        self.hammer.draw();
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
    player_spawn_point: rl.Vector2,
    enemy_spawn_point: rl.Vector2,
    boundary: rl.Rectangle,

    pub fn init(allocator: std.mem.Allocator, map_level: *const MapLevel) MapEditor {
        var tiles = std.ArrayList(Tile).init(allocator);
        tiles.appendSlice(map_level.tiles) catch unreachable;

        return MapEditor{
            .tiles = tiles,
            .player_spawn_point = map_level.player_spawn_point,
            .enemy_spawn_point = map_level.enemy_spawn_point,
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

        rl.drawCircleV(self.player_spawn_point.addValue(TILE_SIZE / 2), 10, rl.Color.lime);
        rl.drawCircleV(self.enemy_spawn_point.addValue(TILE_SIZE / 2), 10, rl.Color.red.brightness(-0.2));
        rl.drawRectangleLinesEx(self.boundary, 3, rl.Color.blue);
        self.toolbox.draw(state);
    }

    pub fn toMapLevel(self: *MapEditor) MapLevel {
        return MapLevel{
            .tiles = self.tiles.items,
            .boundary = self.boundary,
            .player_spawn_point = self.player_spawn_point,
            .enemy_spawn_point = self.enemy_spawn_point,
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
            .enemy_spawn_point = self.enemy_spawn_point,
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
    player_spawn_point: rl.Vector2 = rl.Vector2.init(0, 0),
    enemy_spawn_point: rl.Vector2 = rl.Vector2.init(0, 0),
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
    enemy: Enemy,
    cam: rl.Camera2D,
    map_level: MapLevel,
    map_editor: MapEditor,
    debug_info: DebugInfo = .{},
    sprite_tiles: std.EnumMap(Tileset, rl.Texture2D),

    pub fn init(allocator: std.mem.Allocator) GameState {
        const map_level = MapLevel.load(allocator) catch unreachable;
        const player = Player.init(map_level.player_spawn_point);
        var sprite_tiles = std.EnumMap(Tileset, rl.Texture2D){};

        inline for (std.meta.fields(Tileset)) |kind| {
            sprite_tiles.put(@enumFromInt(kind.value), Tileset.getTexture(@enumFromInt(kind.value)));
        }

        return GameState{
            .allocator = allocator,
            .player = player,
            .enemy = Enemy.init(map_level.enemy_spawn_point),
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

    pub fn spawnEntities(self: *GameState) void {
        self.player = Player.init(self.map_level.player_spawn_point);
        self.enemy = Enemy.init(self.map_level.enemy_spawn_point);
    }

    pub fn tick(self: *GameState) void {
        if (rl.isKeyPressed(rl.KeyboardKey.key_f1)) {
            self.debug_info.enabled = !self.debug_info.enabled;
        }

        if (rl.isKeyPressed(rl.KeyboardKey.key_f2)) {
            self.mode = if (self.mode == .editor) .play else .editor;
            if (self.mode == .play) {
                self.map_editor.save() catch unreachable;
                self.map_level = self.map_editor.toMapLevel();
                self.spawnEntities();
            }
        }

        if (self.mode == .editor) {
            self.map_editor.update(self);
        } else {
            self.player.update(self);
            self.enemy.update(self);
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
            self.enemy.draw();
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
    rl.initAudioDevice();
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.toggleBorderlessWindowed();
    rl.disableCursor();

    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second

    assets.init();
    var state = GameState.init(std.heap.page_allocator);

    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        // Update
        state.tick();

        // Draw
        state.draw();
    }

    try state.map_editor.save();
    rl.closeAudioDevice();
}
