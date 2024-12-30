const std = @import("std");
const rl = @import("raylib");

const Assets = @import("assets.zig");
const Toolbox = @import("toolbox.zig").Toolbox;
const DebugInfo = @import("debug_info.zig").DebugInfo;
const stats = @import("stats.zig");
const EntityStats = @import("stats.zig").EntityStats;
const MapLevel = @import("map.zig").MapLevel;
const MapEditor = @import("map.zig").MapEditor;
const AttackLine = @import("attacks.zig").AttackLine;
const Attack = @import("attacks.zig").Attack;
const Projectile = @import("attacks.zig").Projectile;
const AttackKind = @import("attacks.zig").AttackKind;
const AttackUpgrade = @import("attacks.zig").AttackUpgrade;
const AttackUpgradeKinds = @import("attacks.zig").AttackUpgradeKinds;
const attack_info = @import("attacks.zig").attack_info;
const upgrade_paths = @import("attacks.zig").upgrade_paths;
const upgrade_info = @import("attacks.zig").upgrade_info;

pub const Facing = enum { left, right };
pub const Entity = struct {
    allocator: std.mem.Allocator,
    rect: rl.Rectangle,
    velocity: rl.Vector2 = rl.Vector2.init(0, 0),
    facing: Facing = .right,
    health: i32,
    stats: EntityStats,

    attack_line: ?AttackLine = null,
    projectiles: std.BoundedArray(Projectile, 20) = .{},

    pub fn init(allocator: std.mem.Allocator, spawn_point: rl.Vector2, entity_stats: EntityStats) Entity {
        return Entity{
            .allocator = allocator,
            .rect = rl.Rectangle.init(spawn_point.x, spawn_point.y, entity_stats.size.x, entity_stats.size.y),
            .stats = entity_stats,
            .health = entity_stats.max_health,
        };
    }

    pub fn isAlive(self: Entity) bool {
        return self.health > 0;
    }

    pub fn center(self: Entity) rl.Vector2 {
        return rl.Vector2.init(self.rect.x + self.rect.width / 2, self.rect.y + self.rect.height / 2);
    }

    pub fn addVelocity(self: *Entity, velocity: rl.Vector2) void {
        self.velocity = self.velocity.add(velocity).clamp(
            rl.Vector2.init(-self.stats.max_speed, -self.stats.max_speed),
            rl.Vector2.init(self.stats.max_speed, self.stats.max_speed),
        );
    }

    pub fn update(self: *Entity, state: *GameState) void {
        if (self.velocity.x > 0) {
            self.facing = .right;
        } else if (self.velocity.x < 0) {
            self.facing = .left;
        }
        self.applyMovement(state);
    }

    pub fn draw(self: *Entity, state: *GameState) void {
        const textureInfo = self.stats.texture;
        const texture = state.assets.getTexture(textureInfo.asset);
        texture.drawPro(textureInfo.sourceRect(self.facing), self.rect, rl.Vector2.zero(), 0, rl.Color.white);
    }

    pub fn drawHealthBar(self: *Entity) void {
        const Y_OFFSET = 8;
        const green_line_len = self.stats.size.x * @as(f32, @floatFromInt(self.health)) / @as(f32, @floatFromInt(self.stats.max_health));
        const red_line_len = self.stats.size.x - green_line_len;

        rl.drawLineEx(
            rl.Vector2.init(self.rect.x, self.rect.y - Y_OFFSET),
            rl.Vector2.init(self.rect.x + green_line_len, self.rect.y - Y_OFFSET),
            2,
            rl.Color.lime,
        );

        rl.drawLineEx(
            rl.Vector2.init(self.rect.x + green_line_len, self.rect.y - Y_OFFSET),
            rl.Vector2.init(self.rect.x + green_line_len + red_line_len, self.rect.y - Y_OFFSET),
            2,
            rl.Color.red,
        );
    }

    pub fn applyMovement(self: *Entity, state: *GameState) void {
        // check for collisions twice: once for X axis and once for Y axis
        // Dont apply velocity immediately - instead check for collisions after only applying velocity on one axis
        // e.g. apply X velocity, check for collisions - apply offset if colliding, apply final X position to rect
        var isXColliding = false;
        var isYColliding = false;
        for (state.map_level.tiles) |tile| {
            if (!tile.is_solid) {
                continue;
            }

            const newXRect = getNewXRect(self.rect, self.velocity);
            if (newXRect.checkCollision(tile.rect())) {
                const colliding_rect = newXRect.getCollision(tile.rect());

                isXColliding = true;
                self.rect.x = newXRect.x + if (tile.rect().x < self.rect.x) colliding_rect.width else -colliding_rect.width;
                self.velocity.x = 0;
            }

            const newYRect = getNewYRect(self.rect, self.velocity);
            if (newYRect.checkCollision(tile.rect())) {
                const colliding_rect = newYRect.getCollision(tile.rect());

                self.rect.y = newYRect.y + if (tile.rect().y < self.rect.y) colliding_rect.height else -colliding_rect.height;
                self.velocity.y = 0;
                isYColliding = true;
            }
        }

        if (!isXColliding) {
            self.rect.x += self.velocity.x * rl.getFrameTime();
        }

        if (!isYColliding) {
            self.rect.y += self.velocity.y * rl.getFrameTime();
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

    pub fn getNewXRect(rect: rl.Rectangle, velocity: rl.Vector2) rl.Rectangle {
        return rl.Rectangle.init(rect.x + velocity.x * rl.getFrameTime(), rect.y, rect.width, rect.height);
    }

    pub fn getNewYRect(rect: rl.Rectangle, velocity: rl.Vector2) rl.Rectangle {
        return rl.Rectangle.init(rect.x, rect.y + velocity.y * rl.getFrameTime(), rect.width, rect.height);
    }

    pub fn spawnProjectile(self: *Entity, radius: f32, velocity: rl.Vector2) void {
        self.projectiles.append(Projectile.init(self.allocator, self.center(), radius, velocity)) catch unreachable;
    }
};

pub const ExperienceOrb = struct {
    entity: Entity,
    experience: u8 = 0,
    used: bool = false,

    pub fn init(allocator: std.mem.Allocator, spawn_point: rl.Vector2) ExperienceOrb {
        return .{
            .entity = Entity.init(allocator, spawn_point, stats.experience_orb),
        };
    }

    pub fn rect(self: *ExperienceOrb) *rl.Rectangle {
        return &self.entity.rect;
    }

    pub fn velocity(self: *ExperienceOrb) *rl.Vector2 {
        return &self.entity.velocity;
    }

    pub fn center(self: ExperienceOrb) rl.Vector2 {
        return self.entity.center();
    }

    pub fn update(self: *ExperienceOrb, state: *GameState) void {
        const distance = state.player.center().distance(self.center());
        if (distance < stats.pickup_range) {
            const distanceRatio = 1 - distance / stats.pickup_range;
            const direction = rl.Vector2.init(state.player.rect().x - self.rect().x, state.player.rect().y - self.rect().y).normalize();
            self.entity.velocity = direction.scale(self.entity.stats.max_speed * distanceRatio);
        }

        if (!self.used and rl.checkCollisionRecs(self.rect().*, state.player.rect().*)) {
            state.player.gainExperience(1);
            self.used = true;
        }
        self.entity.update(state);
    }

    pub fn shouldDestroy(self: ExperienceOrb) bool {
        return self.used;
    }

    pub fn draw(self: *ExperienceOrb) void {
        rl.drawCircleGradient(@intFromFloat(self.rect().x), @intFromFloat(self.rect().y), self.entity.stats.size.x, rl.Color.sky_blue, rl.Color.lime);
    }
};

const Enemy = struct {
    allocator: std.mem.Allocator,
    entity: Entity,
    attack: Attack,
    upgrades: *std.EnumSet(AttackUpgrade),

    pub fn init(allocator: std.mem.Allocator, spawn_point: rl.Vector2, entity_stats: EntityStats) Enemy {
        const upgrades = allocator.create(std.EnumSet(AttackUpgrade)) catch unreachable;
        upgrades.* = std.EnumSet(AttackUpgrade).initEmpty();
        return .{
            .allocator = allocator,
            .entity = Entity.init(allocator, spawn_point, entity_stats),
            .attack = Attack.init(allocator, entity_stats.default_attack, upgrades),
            .upgrades = upgrades,
        };
    }

    pub fn deinit(self: Enemy) void {
        self.allocator.destroy(self.upgrades);
    }

    pub fn rect(self: *Enemy) *rl.Rectangle {
        return &self.entity.rect;
    }

    pub fn velocity(self: *Enemy) *rl.Vector2 {
        return &self.entity.velocity;
    }

    pub fn center(self: Enemy) rl.Vector2 {
        return self.entity.center();
    }

    pub fn isAlive(self: Enemy) bool {
        return self.entity.isAlive();
    }

    pub fn dealDamage(self: *Enemy, state: *GameState, source: *Entity, damage: i32) void {
        self.entity.health -= damage;

        const knockback_direction = rl.Vector2.init(self.rect().x - source.rect.x, self.rect().y - source.rect.y).normalize();
        self.velocity().* = self.velocity().add(knockback_direction.scale(stats.knockback_distance));

        if (!self.isAlive()) {
            state.spawnExperienceOrb(self);
        }
    }

    pub fn update(self: *Enemy, state: *GameState) void {
        self.entity.addVelocity(rl.Vector2.init(state.player.rect().x - self.rect().x, state.player.rect().y - self.rect().y).normalize().scale(self.entity.stats.acceleration));
        self.entity.update(state);

        self.attack.update(&self.entity, state);
        for (self.entity.projectiles.slice(), 0..) |*projectile, i| {
            projectile.update();
            if (projectile.shouldDestroy(state)) {
                var deleted_projectile = self.entity.projectiles.orderedRemove(i);
                deleted_projectile.deinit();
            }

            if (rl.checkCollisionCircleRec(projectile.position, projectile.radius, state.player.rect().*) and !projectile.isAlreadyDamaged(@ptrCast(&state.player))) {
                state.player.dealDamage(state, 1);
                projectile.markAsDamaged(@ptrCast(&state.player));
                projectile.destroy = true;
            }
        }
    }

    pub fn draw(self: *Enemy, state: *GameState) void {
        self.attack.draw(&self.entity);
        self.entity.draw(state);
        self.entity.drawHealthBar();
    }

    pub fn shouldDestroy(self: Enemy) bool {
        return self.entity.health <= 0;
    }
};

pub const Player = struct {
    allocator: std.mem.Allocator,
    entity: Entity,
    attacks: std.BoundedArray(Attack, std.meta.fields(AttackKind).len) = .{},
    upgrades: *std.EnumSet(AttackUpgrade),

    experience: u8 = 0,
    level: u8 = 1,
    death_time: f64 = 0,

    pub fn init(allocator: std.mem.Allocator, start_point: rl.Vector2) Player {
        const upgrades = allocator.create(std.EnumSet(AttackUpgrade)) catch unreachable;
        upgrades.* = std.EnumSet(AttackUpgrade).initEmpty();
        var self = Player{
            .allocator = allocator,
            .entity = Entity.init(allocator, start_point, stats.player),
            .upgrades = upgrades,
        };

        self.attacks.append(Attack.init(allocator, .word_of_radiance, self.upgrades)) catch unreachable;

        return self;
    }

    pub fn deinit(self: *Player) void {
        self.allocator.destroy(self.upgrades);
    }

    pub fn rect(self: *Player) *rl.Rectangle {
        return &self.entity.rect;
    }

    pub fn velocity(self: *Player) *rl.Vector2 {
        return &self.entity.velocity;
    }

    pub fn center(self: Player) rl.Vector2 {
        return self.entity.center();
    }

    pub fn gainExperience(self: *Player, amount: u8) void {
        self.experience += amount;

        if (self.experience >= stats.experience_for_next_level) {
            self.level += 1;
            self.experience = 0;
        }
    }

    pub fn addAttack(self: *Player, attack_kind: AttackKind) void {
        self.attacks.append(Attack.init(self.allocator, attack_kind, self.upgrades)) catch unreachable;
    }

    pub fn addUpgrade(self: *Player, upgrade_kind: AttackUpgradeKinds) void {
        const upgrade = upgrade_kind.getNextUpgrade(self.upgrades).?;
        self.upgrades.insert(upgrade);
    }

    pub fn update(self: *Player, state: *GameState) void {
        var velocityDelta = rl.Vector2.init(0, 0);
        if (self.isAlive()) {
            if (rl.isKeyDown(rl.KeyboardKey.key_w)) {
                velocityDelta.y = -self.entity.stats.acceleration;
            } else if (rl.isKeyDown(rl.KeyboardKey.key_s)) {
                velocityDelta.y = self.entity.stats.acceleration;
            } else {
                velocityDelta.y = -self.velocity().y;
            }

            if (rl.isKeyDown(rl.KeyboardKey.key_d)) {
                velocityDelta.x = self.entity.stats.acceleration;
            } else if (rl.isKeyDown(rl.KeyboardKey.key_a)) {
                velocityDelta.x = -self.entity.stats.acceleration;
            } else {
                velocityDelta.x = -self.velocity().x;
            }
        } else {
            velocityDelta.x = -self.velocity().x;
            velocityDelta.y = -self.velocity().y;
        }

        self.entity.addVelocity(velocityDelta);
        self.entity.update(state);

        for (self.attacks.slice()) |*attack| {
            attack.update(&self.entity, state);
        }

        if (self.entity.attack_line) |*attack_line| {
            attack_line.update(self.entity);

            for (state.enemies.items) |*enemy| {
                if (enemy.isAlive() and attack_line.checkCollision(enemy.entity.rect) and !attack_line.isAlreadyDamaged(@ptrCast(enemy))) {
                    enemy.dealDamage(state, &self.entity, 1);
                    attack_line.markAsDamaged(@ptrCast(enemy));
                }
            }
        }
        for (self.entity.projectiles.slice(), 0..) |*projectile, i| {
            projectile.update();
            if (projectile.shouldDestroy(state)) {
                var deleted_projectile = self.entity.projectiles.orderedRemove(i);
                deleted_projectile.deinit();
            }

            for (state.enemies.items) |*enemy| {
                if (enemy.isAlive() and projectile.checkCollision(enemy.entity.rect) and !projectile.isAlreadyDamaged(@ptrCast(enemy))) {
                    enemy.dealDamage(state, &self.entity, 1);
                    projectile.markAsDamaged(@ptrCast(enemy));
                    projectile.destroy = true;
                }
            }
        }
    }

    pub fn draw(self: *Player, state: *GameState) void {
        self.entity.draw(state);

        for (self.attacks.slice()) |*attack| {
            attack.draw(&self.entity);
        }

        for (self.entity.projectiles.slice()) |*projectile| {
            projectile.draw();
        }

        self.entity.drawHealthBar();

        if (!self.isAlive()) {
            const font_size = 100;
            const time_delta = std.math.clamp(rl.getTime() - self.death_time, 0, 3);
            const opacity = time_delta / 3;
            const screen_origin = rl.getScreenToWorld2D(rl.Vector2.zero(), state.cam);
            rl.drawRectangleV(
                screen_origin,
                rl.Vector2.init(@floatFromInt(rl.getScreenWidth()), @floatFromInt(rl.getScreenHeight())),
                rl.Color.black.fade(@floatCast(opacity)),
            );

            rl.drawText(
                "You Died",
                @as(i32, @intFromFloat(screen_origin.x)) + @divFloor(rl.getScreenWidth(), 2) - font_size * 2,
                @as(i32, @intFromFloat(screen_origin.y)) + @divFloor(rl.getScreenHeight(), 2),
                font_size,
                rl.Color.white.fade(@floatCast(opacity)),
            );
        }
    }

    pub fn isAlive(self: Player) bool {
        return self.entity.isAlive();
    }

    pub fn dealDamage(self: *Player, state: *GameState, damage: i32) void {
        if (self.isAlive()) {
            self.entity.health -= damage;
            rl.playSound(state.assets.getSound(.inc_damage));

            if (!self.isAlive()) {
                self.death_time = rl.getTime();
                rl.playSound(state.assets.getSound(.you_died));
            }
        }
    }
};

pub const Choice = union(enum) {
    weapon: AttackKind,
    upgrade: AttackUpgradeKinds,
};

const ALL_CHOICES = [_]Choice{
    .{ .weapon = .word_of_radiance },
    .{ .weapon = .sacred_flame },
    .{ .upgrade = .hammer_smash_repeats },
    .{ .upgrade = .hammer_smash_more_aoe },
    .{ .upgrade = .hammer_smash_less_cd },
    .{ .upgrade = .word_of_radiance_damage },
    .{ .upgrade = .word_of_radiance_faster },
    .{ .upgrade = .word_of_radiance_wider },
    .{ .upgrade = .sacred_flame_more_targets },
    .{ .upgrade = .sacred_flame_less_cd },
    .{ .upgrade = .sacred_flame_more_knockback },
};

pub const UpgradeSelectionMenu = struct {
    show: bool = false,
    available_choices: std.ArrayList(Choice),
    current_choices: [3]usize = undefined,
    current_choice: usize = 0,

    pub fn init() UpgradeSelectionMenu {
        var available_choices = std.ArrayList(Choice).init(std.heap.page_allocator);
        available_choices.appendSlice(&ALL_CHOICES) catch unreachable;
        return .{
            .available_choices = available_choices,
        };
    }

    pub fn showMenu(self: *UpgradeSelectionMenu, state: *GameState) void {
        self.show = true;
        self.current_choice = 0;
        self.resetChoices();
        rl.playSound(state.assets.getSound(.menu_open));
    }

    pub fn resetChoices(self: *UpgradeSelectionMenu) void {
        var prng = std.Random.DefaultPrng.init(@intFromFloat(rl.getTime()));
        var rolls = std.BoundedArray(usize, 3).init(0) catch unreachable;
        var roll_num: u8 = 0;
        while (roll_num < self.current_choices.len) {
            const roll = prng.random().uintLessThan(usize, self.available_choices.items.len);

            if (std.mem.indexOfScalar(usize, rolls.slice(), roll) != null) {
                continue;
            }

            rolls.append(roll) catch unreachable;
            roll_num += 1;
        }

        @memcpy(self.current_choices[0..], rolls.slice());
    }

    pub fn update(self: *UpgradeSelectionMenu, state: *GameState) void {
        if (rl.isKeyPressed(rl.KeyboardKey.key_enter)) {
            const choice_idx = self.current_choices[self.current_choice];
            const choice = self.available_choices.items[choice_idx];
            switch (choice) {
                .weapon => |weapon_kind| state.player.addAttack(weapon_kind),
                .upgrade => |upgrade_kind| state.player.addUpgrade(upgrade_kind),
            }
            rl.playSound(state.assets.getSound(.menu_choose));
            self.removeChoiceIfNeeded();
            self.show = false;
        }

        if (self.show) {
            if (rl.isKeyPressed(rl.KeyboardKey.key_w)) {
                if (self.current_choice == 0) {
                    self.current_choice = self.current_choices.len - 1;
                } else {
                    self.current_choice -= 1;
                }
            } else if (rl.isKeyPressed(rl.KeyboardKey.key_s)) {
                self.current_choice += 1;
                if (self.current_choice >= self.current_choices.len) {
                    self.current_choice = 0;
                }
            }
        }
    }

    pub fn removeChoiceIfNeeded(self: *UpgradeSelectionMenu) void {
        const choice_idx = self.current_choices[self.current_choice];
        const choice = self.available_choices.items[choice_idx];
        if (choice == .weapon) {
            _ = self.available_choices.orderedRemove(choice_idx);
        } else if (choice == .upgrade) {
            const is_upgrade_path_done = false;
            if (is_upgrade_path_done) {
                _ = self.available_choices.orderedRemove(choice_idx);
            }
        }
    }

    pub fn draw(self: UpgradeSelectionMenu, state: *GameState) void {
        const MENU_WIDTH = 500;
        const MENU_HEIGHT = 300;

        if (!self.show) {
            return;
        }

        const screen_pos = rl.Vector2.init(@floatFromInt(@divFloor(rl.getScreenWidth(), 2) - @divFloor(MENU_WIDTH, 2)), @floatFromInt(@divFloor(rl.getScreenHeight(), 2) - @divFloor(MENU_HEIGHT, 2)));
        var menu_pos = rl.getScreenToWorld2D(screen_pos, state.cam);

        rl.drawRectangleRec(rl.Rectangle.init(menu_pos.x, menu_pos.y, MENU_WIDTH, MENU_HEIGHT), rl.Color.white);
        rl.drawRectangleLinesEx(rl.Rectangle.init(menu_pos.x, menu_pos.y, MENU_WIDTH, MENU_HEIGHT), 2, rl.Color.black);

        // Offset for title
        menu_pos.x += 15;
        menu_pos.y += 15;

        rl.drawText("Choose an upgrade", @intFromFloat(menu_pos.x), @intFromFloat(menu_pos.y), 30, rl.Color.black);

        // Offset for items
        menu_pos.x += 25;
        menu_pos.y += 45;
        for (self.current_choices, 0..) |choice_idx, i| {
            const choice = self.available_choices.items[choice_idx];
            const choice_info = switch (choice) {
                .weapon => |weapon_kind| blk: {
                    break :blk .{ .title = attack_info.get(weapon_kind).name, .description = attack_info.get(weapon_kind).description };
                },
                .upgrade => |upgrade_kind| blk: {
                    const next_upgrade = upgrade_kind.getNextUpgrade(state.player.upgrades).?;
                    break :blk .{ .title = upgrade_info.get(next_upgrade).name, .description = upgrade_info.get(next_upgrade).description };
                },
            };

            menu_pos.y += 25;
            if (i > 0) {
                menu_pos.y += 25;
            }

            if (i == self.current_choice) {
                const cursor_rect = rl.Rectangle.init(menu_pos.x - 10, menu_pos.y - 10, MENU_WIDTH - 65, 60);
                rl.drawRectangleLinesEx(cursor_rect, 2, rl.Color.lime);
            }

            rl.drawText(choice_info.title, @intFromFloat(menu_pos.x), @intFromFloat(menu_pos.y), 20, rl.Color.black);

            menu_pos = rl.Vector2.init(menu_pos.x, menu_pos.y + 25);
            rl.drawText(choice_info.description, @intFromFloat(menu_pos.x), @intFromFloat(menu_pos.y), 14, rl.Color.black);
        }
    }
};

pub const GameState = struct {
    const Mode = enum { editor, play };

    allocator: std.mem.Allocator,
    assets: Assets,
    mode: Mode = .play,
    player: Player,
    enemies: std.ArrayList(Enemy),
    xp_orbs: std.ArrayList(ExperienceOrb),
    upgrade_selection_menu: UpgradeSelectionMenu,
    cam: rl.Camera2D,
    map_level: MapLevel,
    map_editor: MapEditor,
    debug_info: DebugInfo = .{},
    last_spawn_time: f64 = 0,

    pub fn init(allocator: std.mem.Allocator) GameState {
        const assets = Assets.init();
        const map_level = MapLevel.load(allocator) catch unreachable;
        const player = Player.init(allocator, map_level.player_spawn_point);

        return GameState{
            .allocator = allocator,
            .assets = assets,
            .player = player,
            .enemies = std.ArrayList(Enemy).init(allocator),
            .xp_orbs = std.ArrayList(ExperienceOrb).init(allocator),
            .upgrade_selection_menu = UpgradeSelectionMenu.init(),
            .cam = rl.Camera2D{
                .target = player.center(),
                .offset = getScreenCenter(),
                .rotation = 0,
                .zoom = 1,
            },
            .map_level = map_level,
            .map_editor = MapEditor.init(allocator, &map_level),
        };
    }

    pub fn initEntities(self: *GameState) void {
        for (self.enemies.items) |*enemy| {
            enemy.deinit();
        }
        self.enemies.clearAndFree();
        self.xp_orbs.clearAndFree();

        self.player.deinit();
        self.player = Player.init(self.allocator, self.map_level.player_spawn_point);
    }

    pub fn spawnExperienceOrb(self: *GameState, enemy: *Enemy) void {
        std.debug.print("spawnExperienceOrb\n", .{});
        self.xp_orbs.append(ExperienceOrb.init(self.allocator, enemy.center())) catch unreachable;
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
                self.initEntities();
            }
        }

        if (rl.isKeyPressed(rl.KeyboardKey.key_f3)) {
            self.upgrade_selection_menu.showMenu(self);
        }

        switch (self.mode) {
            .editor => self.updateEditorMode(),
            .play => self.updatePlayMode(),
        }
    }

    pub fn updatePlayMode(self: *GameState) void {
        self.upgrade_selection_menu.update(self);

        if (self.upgrade_selection_menu.show) {
            return;
        }

        var i = self.xp_orbs.items.len;
        while (i > 0) {
            i -|= 1;
            var orb = &self.xp_orbs.items[i];
            orb.update(self);
            if (orb.shouldDestroy()) {
                _ = self.xp_orbs.orderedRemove(i);
            }
        }

        i = self.enemies.items.len;
        while (i > 0) {
            i -|= 1;
            var enemy = &self.enemies.items[i];
            enemy.update(self);
            if (enemy.shouldDestroy()) {
                const deleted_enemy = self.enemies.orderedRemove(i);
                deleted_enemy.deinit();
            }
        }

        self.player.update(self);

        if (rl.getTime() - self.last_spawn_time > 1) {
            self.last_spawn_time = rl.getTime();
            self.enemies.append(Enemy.init(self.allocator, self.map_level.enemy_spawn_point, stats.bat)) catch unreachable;
        }

        if (!self.player.isAlive() and rl.isKeyPressed(rl.KeyboardKey.key_r)) {
            self.initEntities();
            rl.stopSound(self.assets.getSound(.you_died));
        }

        const minTarget = rl.Vector2.init(
            self.map_level.boundary.x + self.cam.offset.x,
            self.map_level.boundary.y + self.cam.offset.y,
        );
        const maxTarget = rl.Vector2.init(
            self.map_level.boundary.x - self.cam.offset.x + self.map_level.boundary.width,
            self.map_level.boundary.y - self.cam.offset.y + self.map_level.boundary.height,
        );

        self.cam.target = self.player.center().clamp(minTarget, maxTarget);
    }

    pub fn updateEditorMode(self: *GameState) void {
        self.map_editor.update(self);
        if (rl.isMouseButtonDown(rl.MouseButton.mouse_button_right)) {
            self.cam.target = rl.Vector2.add(self.cam.target, rl.getMouseDelta().scale(-1));

            var cursor = self.map_editor.toolbox;
            cursor.pos = cursor.pos.add(rl.getMouseDelta().scale(-1));
        }
    }

    pub fn draw(self: *GameState) void {
        rl.clearBackground(rl.Color.white);

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.beginMode2D(self.cam);
        defer rl.endMode2D();

        switch (self.mode) {
            .editor => self.drawEditorMode(),
            .play => self.drawPlayMode(),
        }

        self.debug_info.drawGrid();
        self.debug_info.draw(self);
    }

    pub fn drawPlayMode(self: *GameState) void {
        self.map_level.draw(self);
        for (self.enemies.items) |*enemy| {
            enemy.draw(self);
        }
        self.player.draw(self);
        for (self.xp_orbs.items) |*orb| {
            orb.draw();
        }

        self.upgrade_selection_menu.draw(self);
    }

    pub fn drawEditorMode(self: *GameState) void {
        self.map_editor.draw(self);
    }

    pub fn getScreenCenter() rl.Vector2 {
        return rl.Vector2.init(
            @floatFromInt(@divFloor(rl.getScreenWidth(), 2)),
            @floatFromInt(@divFloor(rl.getScreenHeight(), 2)),
        );
    }
};

pub fn main() anyerror!void {
    rl.initWindow(stats.screen_width, stats.screen_width, "Save the Druga");
    rl.initAudioDevice();
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
    rl.closeAudioDevice();
}
