const std = @import("std");
const rl = @import("raylib");

pub const Assets = struct {
    bonk_sound: rl.Sound = undefined,

    pub fn init(self: *Assets) void {
        self.bonk_sound = rl.loadSound("assets/bonk.wav");
    }
};
