const std = @import("std");
const rl = @import("raylib");
const stats = @import("stats.zig");

const GameState = @import("main.zig").GameState;
const Entity = @import("main.zig").Entity;

pub const AttackKind = enum {
    none,
    hammer_smash,
    word_of_radiance,
    sacred_flame,
    triple_ball_attack,
    circle_ball_attack,
    spiral_ball_attack,
};

pub const AttackInfo = struct {
    name: [:0]const u8,
    description: [:0]const u8,
};

pub const AttackUpgradeKinds = enum {
    hammer_smash_repeats,
    hammer_smash_more_aoe,
    hammer_smash_less_cd,

    word_of_radiance_damage,
    word_of_radiance_faster,
    word_of_radiance_wider,

    sacred_flame_more_targets,
    sacred_flame_less_cd,
    sacred_flame_more_knockback,

    pub fn getNextUpgrade(self: AttackUpgradeKinds, completed_upgrades: *std.EnumSet(AttackUpgrade)) ?AttackUpgrade {
        const upgrade_path = upgrade_paths.get(self);
        for (upgrade_path) |upgrade| {
            if (!completed_upgrades.contains(upgrade)) {
                return upgrade;
            }
        }

        return null;
    }
};

pub const AttackUpgrade = enum {
    hammer_smash_repeats1,
    hammer_smash_repeats2,
    hammer_smash_more_aoe1,
    hammer_smash_more_aoe2,
    hammer_smash_less_cd1,
    hammer_smash_less_cd2,

    word_of_radiance_damage1,
    word_of_radiance_damage2,
    word_of_radiance_faster1,
    word_of_radiance_faster2,
    word_of_radiance_wider1,
    word_of_radiance_wider2,

    sacred_flame_more_targets1,
    sacred_flame_more_targets2,
    sacred_flame_less_cd1,
    sacred_flame_less_cd2,
    sacred_flame_more_knockback1,
    sacred_flame_more_knockback2,
};

pub const AttackUpgradeInfo = struct {
    name: [:0]const u8,
    description: [:0]const u8,
};

pub const attack_upgrades: std.EnumArray(AttackKind, [3]AttackUpgradeKinds) = std.EnumArray(AttackKind, [3]AttackUpgradeKinds).init(.{
    .hammer_smash = .{ .hammer_repeats, .hammer_more_aoe, .hammer_less_cd },
    .word_of_radiance = .{ .word_of_radiance_damage, .word_of_radiance_faster, .word_of_radiance_wider },
    .sacred_flame = .{ .sacred_flame_more_targets1, .sacred_flame_less_cd1, .sacred_flame_more_knockback1 },
});

pub const upgrade_paths: std.EnumArray(AttackUpgradeKinds, [2]AttackUpgrade) = std.EnumArray(AttackUpgradeKinds, [2]AttackUpgrade).init(.{
    .hammer_smash_repeats = .{ .hammer_smash_repeats1, .hammer_smash_repeats2 },
    .hammer_smash_more_aoe = .{ .hammer_smash_more_aoe1, .hammer_smash_more_aoe2 },
    .hammer_smash_less_cd = .{ .hammer_smash_less_cd1, .hammer_smash_less_cd2 },
    .word_of_radiance_damage = .{ .word_of_radiance_damage1, .word_of_radiance_damage2 },
    .word_of_radiance_faster = .{ .word_of_radiance_faster1, .word_of_radiance_faster2 },
    .word_of_radiance_wider = .{ .word_of_radiance_wider1, .word_of_radiance_wider2 },
    .sacred_flame_more_targets = .{ .sacred_flame_more_targets1, .sacred_flame_more_targets2 },
    .sacred_flame_less_cd = .{ .sacred_flame_less_cd1, .sacred_flame_less_cd2 },
    .sacred_flame_more_knockback = .{ .sacred_flame_more_knockback1, .sacred_flame_more_knockback2 },
});

pub const attack_info: std.EnumArray(AttackKind, AttackInfo) = std.EnumArray(AttackKind, AttackInfo).init(.{
    .none = .{
        .name = "None",
        .description = "No attack",
    },
    .hammer_smash = .{
        .name = "Hammer Smash",
        .description = "I myyyyk z młotka",
    },
    .word_of_radiance = .{
        .name = "Word of Radiance",
        .description = "Napierdalasz przeciwników świętym słowem (bo słowa też bolą)",
    },
    .sacred_flame = .{
        .name = "Sacred Flame",
        .description = "Jezus świeci światłem tak długo aż umrą",
    },
    .triple_ball_attack = .{
        .name = "Triple Ball Attack",
        .description = "Triple Ball Attack",
    },
    .circle_ball_attack = .{
        .name = "Circle Ball Attack",
        .description = "Circle Ball Attack",
    },
    .spiral_ball_attack = .{
        .name = "Spiral Ball Attack",
        .description = "Spiral Ball Attack",
    },
});

pub const upgrade_info: std.EnumArray(AttackUpgrade, AttackUpgradeInfo) = std.EnumArray(AttackUpgrade, AttackUpgradeInfo).init(.{
    .hammer_smash_repeats1 = .{
        .name = "Hammer Smash Repeats 1",
        .description = "Po co uderzać młotkiem raz jak można dwa razy?",
    },
    .hammer_smash_repeats2 = .{
        .name = "Hammer Smash Repeats 2",
        .description = "A co z trzecim uderzeniem?",
    },
    .hammer_smash_more_aoe1 = .{
        .name = "Hammer Smash More AOE 1",
        .description = "Hammer Smash Attack now does more AOE",
    },
    .hammer_smash_more_aoe2 = .{
        .name = "Hammer Smash More AOE 2",
        .description = "Hammer Smash Attack now does more AOE",
    },
    .hammer_smash_less_cd1 = .{
        .name = "Hammer Smash Less CD 1",
        .description = "Hammer Smash Attack cooldown is now 20% less",
    },
    .hammer_smash_less_cd2 = .{
        .name = "Hammer Smash Less CD 2",
        .description = "Hammer Smash Attack cooldown is now 40% less",
    },
    .word_of_radiance_damage1 = .{
        .name = "Word of Radiance Damage 1",
        .description = "Word of Radiance Attack now deals more damage",
    },
    .word_of_radiance_damage2 = .{
        .name = "Word of Radiance Damage 2",
        .description = "Word of Radiance Attack now deals more damage",
    },
    .word_of_radiance_faster1 = .{
        .name = "Word of Radiance Faster 1",
        .description = "Word of Radiance Attack now does more damage per second",
    },
    .word_of_radiance_faster2 = .{
        .name = "Word of Radiance Faster 2",
        .description = "Word of Radiance Attack now does more damage per second",
    },
    .word_of_radiance_wider1 = .{
        .name = "Word of Radiance Wider 1",
        .description = "Word of Radiance Attack now does more AOE",
    },
    .word_of_radiance_wider2 = .{
        .name = "Word of Radiance Wider 2",
        .description = "Word of Radiance Attack now does more AOE",
    },
    .sacred_flame_more_targets1 = .{
        .name = "Sacred Flame More Targets 1",
        .description = "Sacred Flame Attack now does more targets",
    },
    .sacred_flame_more_targets2 = .{
        .name = "Sacred Flame More Targets 2",
        .description = "Sacred Flame Attack now does more targets",
    },
    .sacred_flame_less_cd1 = .{
        .name = "Sacred Flame Less CD 1",
        .description = "Sacred Flame Attack cooldown is now 20% less",
    },
    .sacred_flame_less_cd2 = .{
        .name = "Sacred Flame Less CD 2",
        .description = "Sacred Flame Attack cooldown is now 40% less",
    },
    .sacred_flame_more_knockback1 = .{
        .name = "Sacred Flame More Knockback 1",
        .description = "Sacred Flame Attack now does more knockback",
    },
    .sacred_flame_more_knockback2 = .{
        .name = "Sacred Flame More Knockback 2",
        .description = "Sacred Flame Attack now does more knockback",
    },
});

pub const AttackLine = struct {
    start: rl.Vector2,
    rotation: f32,
    length: f32,
    already_damaged: std.AutoArrayHashMap(*void, void),

    pub fn init(allocator: std.mem.Allocator, start: rl.Vector2, rotation: f32, length: f32) AttackLine {
        return AttackLine{
            .start = start,
            .rotation = rotation,
            .length = length,
            .already_damaged = std.AutoArrayHashMap(*void, void).init(allocator),
        };
    }

    pub fn deinit(self: *AttackLine) void {
        self.already_damaged.deinit();
    }

    pub fn endPos(self: AttackLine) rl.Vector2 {
        return self.start.add(rl.Vector2.init(0, self.length).rotate(std.math.degreesToRadians(self.rotation)));
    }

    pub fn checkCollision(self: AttackLine, rect: rl.Rectangle) bool {
        var cp: rl.Vector2 = undefined;

        const top_left = rl.Vector2.init(rect.x, rect.y);
        const top_right = rl.Vector2.init(rect.x + rect.width, rect.y);
        const bottom_left = rl.Vector2.init(rect.x, rect.y + rect.height);
        const bottom_right = rl.Vector2.init(rect.x + rect.width, rect.y + rect.height);

        return rl.checkCollisionLines(self.start, self.endPos(), top_left, top_right, &cp) or
            rl.checkCollisionLines(self.start, self.endPos(), top_right, bottom_right, &cp) or
            rl.checkCollisionLines(self.start, self.endPos(), bottom_right, bottom_left, &cp) or
            rl.checkCollisionLines(self.start, self.endPos(), bottom_left, top_left, &cp);
    }

    pub fn isAlreadyDamaged(self: AttackLine, other: *void) bool {
        return self.already_damaged.get(other) != null;
    }

    pub fn markAsDamaged(self: *AttackLine, other: *void) void {
        self.already_damaged.put(other, {}) catch unreachable;
    }

    pub fn resetMarks(self: *AttackLine) void {
        self.already_damaged.clearAndFree();
    }

    pub fn update(self: *AttackLine, owner: Entity) void {
        self.start = owner.center();
    }

    pub fn draw(self: *AttackLine) void {
        rl.drawLineEx(self.start, self.endPos(), 2, rl.Color.black);
    }
};

pub const Projectile = struct {
    position: rl.Vector2,
    radius: f32,
    velocity: rl.Vector2,
    already_damaged: std.AutoArrayHashMap(*void, void),
    destroy: bool = false,

    pub fn init(allocator: std.mem.Allocator, position: rl.Vector2, radius: f32, velocity: rl.Vector2) Projectile {
        return Projectile{
            .position = position,
            .radius = radius,
            .velocity = velocity,
            .already_damaged = std.AutoArrayHashMap(*void, void).init(allocator),
        };
    }

    pub fn deinit(self: *Projectile) void {
        self.already_damaged.deinit();
    }

    pub fn checkCollision(self: Projectile, rect: rl.Rectangle) bool {
        return rl.checkCollisionCircleRec(self.position, self.radius, rect);
    }

    pub fn update(self: *Projectile) void {
        self.position.x += self.velocity.x * rl.getFrameTime();
        self.position.y += self.velocity.y * rl.getFrameTime();
    }

    pub fn shouldDestroy(self: Projectile, state: *GameState) bool {
        const boundary = state.map_level.boundary;
        return self.destroy or self.position.x < boundary.x or self.position.x > boundary.x + boundary.width or self.position.y < boundary.y or self.position.y > boundary.y + boundary.height;
    }

    pub fn isAlreadyDamaged(self: Projectile, other: *void) bool {
        return self.already_damaged.get(other) != null;
    }

    pub fn markAsDamaged(self: *Projectile, other: *void) void {
        self.already_damaged.put(other, {}) catch unreachable;
    }

    pub fn resetMarks(self: *Projectile) void {
        self.already_damaged.clearAndFree();
    }

    pub fn draw(self: *Projectile) void {
        rl.drawCircleGradient(@intFromFloat(self.position.x), @intFromFloat(self.position.y), self.radius, rl.Color.white, rl.Color.red);
    }
};

pub const WaveAttack = struct {
    pub const SEGMENTS = 10;

    owner: *Entity,
    origin: rl.Vector2,
    direction: rl.Vector2,
    speed: f32,
    position: rl.Vector2,
    start_angle: f32,
    end_angle: f32,
    thickness: f32,

    already_damaged: std.AutoArrayHashMap(*void, void),

    pub fn init(
        allocator: std.mem.Allocator,
        owner: *Entity,
        direction: rl.Vector2,
        speed: f32,
        start_angle: f32,
        end_angle: f32,
        thickness: f32,
    ) WaveAttack {
        return WaveAttack{
            .owner = owner,
            .origin = owner.center(),
            .direction = direction,
            .speed = speed,
            .position = owner.center(),
            .start_angle = start_angle,
            .end_angle = end_angle,
            .thickness = thickness,
            .already_damaged = std.AutoArrayHashMap(*void, void).init(allocator),
        };
    }

    pub fn deinit(self: *WaveAttack) void {
        self.already_damaged.deinit();
    }

    pub fn update(self: *WaveAttack) void {
        self.position.x += self.direction.x * rl.getFrameTime() * self.speed;
        self.position.y += self.direction.y * rl.getFrameTime() * self.speed;
    }

    pub fn attackEnemies(self: *WaveAttack, state: *GameState, damage: i32) void {
        for (state.enemies.items) |*enemy| {
            if (enemy.isAlive() and self.checkCollision(enemy.rect().*) and !self.isAlreadyDamaged(@ptrCast(enemy))) {
                enemy.dealDamage(state, self.owner, damage);
                self.markAsDamaged(@ptrCast(enemy));
            }
        }
    }

    pub fn draw(self: *WaveAttack) void {
        const radius = self.position.distance(self.origin);
        rl.drawRing(self.origin, radius, radius + self.thickness, self.start_angle, self.end_angle, SEGMENTS, rl.Color.yellow);

        //const points = self.genRingPoints();
        //for (0..points.len - 1) |i| {
        //    const point = points[i];
        //    const next_point = points[i + 1];
        //    rl.drawLineEx(point, next_point, 2, rl.Color.red);
        //}
        //rl.drawLineEx(points[points.len - 1], points[0], 2, rl.Color.red);
    }

    const POINTS_NUM = SEGMENTS * 2 + 2;
    pub fn genRingPoints(self: WaveAttack) [POINTS_NUM]rl.Vector2 {
        var points: [POINTS_NUM]rl.Vector2 = undefined;
        const step_length = (self.end_angle - self.start_angle) / SEGMENTS;

        const radius = self.position.distance(self.origin);
        const direction = self.position.subtract(self.origin).normalize();
        var angle: f32 = 0;
        for (0..POINTS_NUM / 2) |i| {
            const angle_rad = std.math.degreesToRadians(angle);
            points[i] = self.origin.add(direction.rotate(angle_rad).scale(radius));

            angle += step_length;
        }

        const thickness_offset = direction.scale(self.thickness);
        for (POINTS_NUM / 2..POINTS_NUM) |i| {
            points[i] = points[POINTS_NUM - i - 1].add(thickness_offset);
        }

        return points;
    }

    pub fn checkCollision(self: WaveAttack, rect: rl.Rectangle) bool {
        const points = self.genRingPoints();
        return rl.checkCollisionPointPoly(rl.Vector2.init(rect.x, rect.y), &points) or
            rl.checkCollisionPointPoly(rl.Vector2.init(rect.x + rect.width, rect.y), &points) or
            rl.checkCollisionPointPoly(rl.Vector2.init(rect.x, rect.y + rect.height), &points) or
            rl.checkCollisionPointPoly(rl.Vector2.init(rect.x + rect.width, rect.y + rect.height), &points);
    }

    pub fn isAlreadyDamaged(self: WaveAttack, other: *void) bool {
        return self.already_damaged.get(other) != null;
    }

    pub fn markAsDamaged(self: *WaveAttack, other: *void) void {
        self.already_damaged.put(other, {}) catch unreachable;
    }

    pub fn resetMarks(self: *WaveAttack) void {
        self.already_damaged.clearAndFree();
    }
};
pub const Attack = struct {
    allocator: std.mem.Allocator,
    kind: AttackKind,
    upgrades: *std.EnumSet(AttackUpgrade),
    cooldown_timer: f64 = 0,
    duration_timer: f64 = 0,
    next_attack_time: f64 = 0,
    repeat_count: u8 = 0,

    wave: ?WaveAttack = null,

    pub fn init(allocator: std.mem.Allocator, kind: AttackKind, upgrades: *std.EnumSet(AttackUpgrade)) Attack {
        return Attack{
            .allocator = allocator,
            .kind = kind,
            .upgrades = upgrades,
        };
    }

    pub fn duration(self: Attack) f64 {
        return switch (self.kind) {
            .none => 0,
            .hammer_smash => stats.hammer.attack_duration,
            .sacred_flame => stats.sacred_flame.attack_duration,
            .word_of_radiance => stats.word_of_radiance.attack_duration,
            .triple_ball_attack,
            .circle_ball_attack,
            => 0,
            .spiral_ball_attack => stats.spiral_ball_attack.duration,
        };
    }

    pub fn cooldown(self: Attack) f64 {
        return switch (self.kind) {
            .none => 0,
            .hammer_smash => stats.hammer.attack_cooldown,
            .sacred_flame => stats.sacred_flame.attack_cooldown,
            .word_of_radiance => stats.word_of_radiance.attack_cooldown,
            .triple_ball_attack,
            .circle_ball_attack,
            => stats.simple_ball_attack.attack_cooldown,
            .spiral_ball_attack => stats.spiral_ball_attack.attack_cooldown,
        };
    }

    pub fn maxRepeats(self: Attack) u8 {
        return switch (self.kind) {
            .none => 0,
            .hammer_smash => self.hammerAttackMaxRepeats(),
            .sacred_flame => stats.sacred_flame.max_repeats,
            .word_of_radiance,
            .triple_ball_attack,
            .circle_ball_attack,
            .spiral_ball_attack,
            => 1,
        };
    }

    pub fn update(self: *Attack, owner: *Entity, state: *GameState) void {
        if (self.kind == .none) {
            return;
        }

        self.cooldown_timer += rl.getFrameTime();
        if (self.duration_timer > 0) {
            self.duration_timer -= rl.getFrameTime();
            self.attackTick(owner, state);
        }

        if (self.cooldown_timer > self.cooldown()) {
            self.cooldown_timer -= self.cooldown() + self.duration();
            self.duration_timer = self.duration();
            self.repeat_count = 1;
            self.activate(owner);
        }
    }

    pub fn draw(self: *Attack, owner: *Entity) void {
        switch (self.kind) {
            .none => {},
            .hammer_smash => {
                var attack_line = owner.attack_line orelse return;
                if (self.duration_timer > 0) {
                    attack_line.draw();
                }
            },
            .word_of_radiance => {
                if (self.wave) |*wave| {
                    wave.draw();
                }
            },
            .sacred_flame => {},
            .triple_ball_attack,
            .circle_ball_attack,
            .spiral_ball_attack,
            => {
                for (owner.projectiles.slice()) |*projectile| {
                    projectile.draw();
                }
            },
        }
    }

    pub fn activate(self: *Attack, owner: *Entity) void {
        switch (self.kind) {
            .none => unreachable,
            .hammer_smash => self.hammerAttackActivate(owner),
            .word_of_radiance => self.wordOfRadianceActivate(owner),
            .sacred_flame => self.sacredFlameActivate(owner),
            .triple_ball_attack => self.tripleBallAttack(owner),
            .circle_ball_attack => self.simpleBallAttack(owner),
            .spiral_ball_attack => {},
        }
    }

    pub fn attackTick(self: *Attack, owner: *Entity, state: *GameState) void {
        switch (self.kind) {
            .none => unreachable,
            .hammer_smash => self.hammerAttackTick(owner),
            .word_of_radiance => self.wordOfRadianceTick(state),
            .sacred_flame => self.sacredFlameTick(state),
            .triple_ball_attack,
            .circle_ball_attack,
            => {},
            .spiral_ball_attack => self.spiralBallAttackTick(owner),
        }
    }

    pub fn hammerAttackActivate(self: *Attack, owner: *Entity) void {
        owner.attack_line = AttackLine.init(self.allocator, owner.center(), stats.hammer.start_angle, stats.hammer.size.y);
        self.hammerAttackTick(owner);
    }

    pub fn hammerAttackMaxRepeats(self: Attack) u8 {
        if (self.upgrades.contains(.hammer_smash_repeats2)) {
            return stats.hammer.max_repeats3;
        } else if (self.upgrades.contains(.hammer_smash_repeats1)) {
            return stats.hammer.max_repeats2;
        } else {
            return stats.hammer.max_repeats;
        }
    }

    pub fn hammerAttackTick(self: *Attack, owner: *Entity) void {
        var attack_line = &(owner.attack_line orelse return);
        if (self.duration_timer <= 0) {
            if (self.repeat_count < self.maxRepeats()) {
                self.repeat_count += 1;
                attack_line.resetMarks();
                self.duration_timer = self.duration();
            } else {
                attack_line.deinit();
                owner.attack_line = null;
            }

            return;
        }

        attack_line.start.x = owner.center().x;
        attack_line.start.y = owner.center().y;

        const attackDelta = stats.hammer.attack_duration - self.duration_timer;
        attack_line.rotation = @floatCast(stats.hammer.start_angle + stats.hammer.swing_angle * attackDelta / stats.hammer.attack_duration);

        if (@mod(self.repeat_count, 2) == 0) {
            attack_line.rotation *= -1;
        }
    }

    pub fn wordOfRadianceActivate(self: *Attack, owner: *Entity) void {
        var prng = std.Random.DefaultPrng.init(@intFromFloat(rl.getTime()));
        const start_angle: f32 = @floatFromInt(prng.random().uintLessThan(u32, 360));
        self.wave = WaveAttack.init(
            self.allocator,
            owner,
            rl.Vector2.init(1, 0).rotate(std.math.degreesToRadians(start_angle)),
            self.wordOfRadianceSpeed(),
            start_angle,
            start_angle + self.wordOfRadianceAngle(),
            stats.word_of_radiance.thickness,
        );
    }

    pub fn wordOfRadianceAngle(self: Attack) f32 {
        if (self.upgrades.contains(.word_of_radiance_wider2)) {
            return stats.word_of_radiance.angle * 2;
        } else if (self.upgrades.contains(.word_of_radiance_wider1)) {
            return stats.word_of_radiance.angle * 1.5;
        } else {
            return stats.word_of_radiance.angle;
        }
    }

    pub fn wordOfRadianceSpeed(self: Attack) f32 {
        if (self.upgrades.contains(.word_of_radiance_faster2)) {
            return stats.word_of_radiance.speed * 2;
        } else if (self.upgrades.contains(.word_of_radiance_faster1)) {
            return stats.word_of_radiance.speed * 1.5;
        } else {
            return stats.word_of_radiance.speed;
        }
    }

    pub fn wordOfRadianceDamage(self: Attack) i32 {
        if (self.upgrades.contains(.word_of_radiance_damage2)) {
            return stats.word_of_radiance.damage * 3;
        } else if (self.upgrades.contains(.word_of_radiance_damage1)) {
            return stats.word_of_radiance.damage * 2;
        } else {
            return stats.word_of_radiance.damage;
        }
    }

    pub fn wordOfRadianceTick(self: *Attack, state: *GameState) void {
        if (self.wave) |*wave| {
            wave.update();
            wave.attackEnemies(state, self.wordOfRadianceDamage());
            if (self.duration_timer <= 0) {
                wave.deinit();
                self.wave = null;
            }
        }
    }

    pub fn sacredFlameActivate(_: *Attack, _: *Entity) void {}

    pub fn sacredFlameTick(_: *Attack, _: *GameState) void {}

    pub fn tripleBallAttack(_: *Attack, owner: *Entity) void {
        const ANGLES = [_]f32{ -30, 0, 30 };
        for (ANGLES) |angle| {
            const velocity = rl.Vector2.init(-1, 0).rotate(std.math.degreesToRadians(angle)).scale(stats.projectile_speed);
            owner.spawnProjectile(10, velocity);
        }
    }

    pub fn simpleBallAttack(_: *Attack, owner: *Entity) void {
        for (0..stats.simple_ball_attack.proj_count) |i| {
            const angle = std.math.degreesToRadians(@as(f32, @floatFromInt(360 * i / stats.simple_ball_attack.proj_count)));
            const velocity = rl.Vector2.init(1, 0).rotate(angle).scale(stats.projectile_speed);
            owner.spawnProjectile(10, velocity);
        }
    }

    pub fn spiralBallAttackTick(self: *Attack, owner: *Entity) void {
        self.next_attack_time += rl.getFrameTime();
        if (self.next_attack_time > stats.spiral_ball_attack.frequency) {
            self.next_attack_time -= stats.spiral_ball_attack.frequency;
            const ratio = self.duration_timer / stats.spiral_ball_attack.duration;
            const angle = std.math.degreesToRadians(stats.spiral_ball_attack.starting_angle + stats.spiral_ball_attack.spiral_angle * ratio);
            owner.spawnProjectile(10, rl.Vector2.zero().rotate(@floatCast(angle)).scale(stats.projectile_speed));
        }
    }
};
