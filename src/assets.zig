const std = @import("std");
const rl = @import("raylib");

const Assets = @This();

pub const SoundKind = enum {
    inc_damage,
    bonk,
    you_died,
    menu_open,
    menu_choose,
};

pub const TextureKind = enum {
    buildings,
    hive,
    interior,
    rocks,
    tiles,
    tree_assets,
    catacombs,
    catacombs_decor,

    hammur,
    ash,
    monsters1,
    bat_monster,
    mimic,

    pointer,
    erase,
    paint,
    make_solid,
    spawn_point,
    move_boundary,
};

soundAssets: std.EnumMap(SoundKind, rl.Sound),
textureAssets: std.EnumMap(TextureKind, rl.Texture2D),

pub fn init() Assets {
    var self = Assets{
        .soundAssets = std.EnumMap(SoundKind, rl.Sound).init(.{}),
        .textureAssets = std.EnumMap(TextureKind, rl.Texture2D).init(.{}),
    };

    self.soundAssets.put(.inc_damage, rl.loadSound("assets/inc_damage_taken.wav"));
    self.soundAssets.put(.bonk, rl.loadSound("assets/bonk.wav"));
    self.soundAssets.put(.you_died, rl.loadSound("assets/you_died.wav"));
    self.soundAssets.put(.menu_open, rl.loadSound("assets/menu_open.wav"));
    self.soundAssets.put(.menu_choose, rl.loadSound("assets/menu_choose.wav"));

    self.textureAssets.put(.buildings, rl.loadTexture("assets/sprites/buildings.png"));
    self.textureAssets.put(.hive, rl.loadTexture("assets/sprites/hive.png"));
    self.textureAssets.put(.interior, rl.loadTexture("assets/sprites/interior.png"));
    self.textureAssets.put(.rocks, rl.loadTexture("assets/sprites/rocks.png"));
    self.textureAssets.put(.tiles, rl.loadTexture("assets/sprites/tiles.png"));
    self.textureAssets.put(.tree_assets, rl.loadTexture("assets/sprites/tree_assets.png"));
    self.textureAssets.put(.catacombs, rl.loadTexture("assets/catacombs/mainlevbuild.png"));
    self.textureAssets.put(.catacombs_decor, rl.loadTexture("assets/catacombs/decorative.png"));

    self.textureAssets.put(.hammur, rl.loadTexture("assets/hammur2.png"));
    self.textureAssets.put(.ash, rl.loadTexture("assets/sprites/ash_sprite_3.png"));
    self.textureAssets.put(.bat_monster, rl.loadTexture("assets/sprites/bat.png"));
    self.textureAssets.put(.mimic, rl.loadTexture("assets/sprites/mimic.png"));

    self.textureAssets.put(.pointer, rl.loadTexture("assets/icons/pointer_scifi_a.png"));
    self.textureAssets.put(.erase, rl.loadTexture("assets/icons/drawing_eraser.png"));
    self.textureAssets.put(.paint, rl.loadTexture("assets/icons/drawing_brush.png"));
    self.textureAssets.put(.make_solid, rl.loadTexture("assets/icons/tool_wand.png"));
    self.textureAssets.put(.spawn_point, rl.loadTexture("assets/icons/gauntlet_point.png"));
    self.textureAssets.put(.move_boundary, rl.loadTexture("assets/icons/resize_d_cross.png"));

    return self;
}

pub fn getSound(self: Assets, kind: SoundKind) rl.Sound {
    return self.soundAssets.get(kind).?;
}

pub fn getTexture(self: Assets, kind: TextureKind) rl.Texture2D {
    return self.textureAssets.get(kind).?;
}
