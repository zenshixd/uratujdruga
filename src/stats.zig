const std = @import("std");
const rl = @import("raylib");

const Facing = @import("main.zig").Facing;
const AttackKind = @import("attacks.zig").AttackKind;
const TextureKind = @import("assets.zig").TextureKind;

pub const screen_width = 800;
pub const screen_height = 600;
pub const tile_size = 32;
pub const sprite_size = 16;

pub const experience_for_next_level = 30;
pub const pickup_range = 500;
pub const projectile_speed = 200;
pub const knockback_distance = 300;

pub const EntityStats = struct {
    default_attack: AttackKind = .none,
    max_health: i32,
    max_speed: f32,
    acceleration: f32,
    size: rl.Vector2,
    resist_knockback: bool = false,
    texture: struct {
        asset: TextureKind,
        x: f32,
        y: f32,
        width: f32,
        height: f32,

        pub fn sourceRect(self: @This(), facing: Facing) rl.Rectangle {
            return rl.Rectangle.init(self.x, self.y, if (facing == .right) self.width else -self.width, self.height);
        }
    },
};

pub const player = EntityStats{
    .default_attack = .hammer_smash,
    .max_health = 50,
    .max_speed = 150,
    .acceleration = 50,
    .size = .{ .x = 32, .y = 48 },
    .texture = .{
        .asset = .ash,
        .x = 0,
        .y = 0,
        .width = 321,
        .height = 482,
    },
};

pub const bat = EntityStats{
    .max_health = 3,
    .max_speed = 110,
    .acceleration = 50,
    .size = .{ .x = 24, .y = 24 },
    .texture = .{
        .asset = .bat_monster,
        .x = 0,
        .y = 0,
        .width = 32,
        .height = 32,
    },
};

pub const boss = EntityStats{
    .default_attack = .spiral_ball_attack,
    .max_health = 40,
    .max_speed = 100,
    .acceleration = 100,
    .size = .{ .x = 32 * 4, .y = 48 * 4 },
    .resist_knockback = true,
    .texture = .{
        .asset = .mimic,
        .x = 0,
        .y = 0,
        .width = 32,
        .height = 48,
    },
};

pub const experience_orb = EntityStats{
    .max_health = 1,
    .max_speed = 300,
    .acceleration = 300,
    .size = .{ .x = 8, .y = 8 },
    .texture = .{
        .asset = .catacombs,
        .x = 0,
        .y = 0,
        .width = 8,
        .height = 8,
    },
};

pub const hammer = .{
    .size = .{ .x = 10, .y = 200 },
    .head_radius = 30,
    .start_angle = 220,
    .swing_angle = 100,
    .attack_cooldown = 1,
    .attack_duration = 0.4,
    .max_repeats = 1,
    .max_repeats2 = 2,
    .max_repeats3 = 3,
};

pub const word_of_radiance = .{
    .speed = 200,
    .angle = 30,
    .attack_cooldown = 3,
    .attack_duration = 1,
    .thickness = 10,
    .damage = 2,
};

pub const sacred_flame = .{
    .max_repeats = 5,
    .max_targets = 2,
    .attack_cooldown = 5,
    .attack_duration = 0.5,
};

pub const simple_ball_attack = .{
    .proj_count = 12,
    .attack_cooldown = 5,
};

pub const spiral_ball_attack = .{
    .attack_cooldown = 5,
    .frequency = 0.2,
    .duration = 2,
    .starting_angle = -30,
    .spiral_angle = 90,
};
