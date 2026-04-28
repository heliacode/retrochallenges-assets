-- Mega Man 2 — Metal Man, Quick Boomerang Only (Infinite Ammo)
-- Same boss room as boss-metalman. Quick Boomerang does 1 damage to
-- Metal Man — boss has 28 HP, so this needs 28 successful hits. Ammo
-- is refilled every frame so you can spam without worrying about it;
-- the challenge is purely about aim, timing, and not getting hit.
--
-- Loadout: full HP (28), Quick Boomerang equipped, on_frame keeps
-- weapon locked + ammo full. Die once and the run is over.

local hud       = require("RcHud")
local challenge = require("RcChallenge")

local read_u8  = memory.read_u8  or memory.readbyte
local write_u8 = memory.write_u8 or memory.writebyte

-- ---------------------------------------------------------------------------
-- Memory map (US NES Mega Man 2)
-- See nes/megaman2/RAM.md for the full reference.
-- ---------------------------------------------------------------------------
local PLAYER_HP        = 0x06C0
local BOSS_HP          = 0x06C1
local LIVES            = 0x00A8
local CURRENT_WEAPON   = 0x00A9
local UNLOCKED_WEAPONS = 0x009A
local AMMO_QUICK       = 0x00A0
local DIFFICULTY       = 0x00CB
local GAME_MODE        = 0x00AA   -- bit 2 = "pause entities" — see RAM.md

-- Freeze trick: write 0x04 to game_mode to set bit 2 — entity_update_dispatch
-- short-circuits, so AI / physics / projectiles / animations all halt while
-- the renderer keeps drawing our banner. 0x00 resumes.
local function freeze_game()
    write_u8(GAME_MODE, 0x04)
    joypad.set({}, 1)
end

local function release_game()
    write_u8(GAME_MODE, 0x00)
end

-- Sprite palette 0 (player + own projectiles share it). The pause-
-- menu weapon-switch handler runs `weapon_palette_copy` (bank0F
-- $D2ED) which writes these three bytes from a per-weapon table.
-- Skipping that routine leaves Mega Man + the boomerang sprite
-- rendered against buster colors — boomerang tile pixels don't
-- shape correctly, looking like a "Y". We mirror the routine.
local PAL_SPRITE_1     = 0x0367   -- color 1 (outline)
local PAL_SPRITE_2     = 0x0368   -- color 2 (highlight)
local PAL_SPRITE_3     = 0x0369   -- color 3 (body)
-- Quick Boomerang (ID 5) palette per weapon_palette_data[5*4+1..3]
-- in bank0F:2785 of the ca65 disassembly.
local QUICK_PAL_1 = 0x0F   -- black
local QUICK_PAL_2 = 0x34   -- peach
local QUICK_PAL_3 = 0x25   -- pink

local MAX_HP                  = 0x1C   -- 28
local WEAPON_QUICK_BOOMERANG  = 0x05
local NORMAL_DIFFICULTY       = 0x00

-- ---------------------------------------------------------------------------
-- Per-attempt state (lives baseline for the death detector).
-- ---------------------------------------------------------------------------
local prev_lives = 0

-- ---------------------------------------------------------------------------
-- Run the challenge
-- ---------------------------------------------------------------------------
challenge.run{
    savestate           = "savestates/metalman-quick-only.state",
    expected_rom_hashes = { "2290D8D839A303219E9327EA1451C5EEA430F53D" },  -- Mega Man 2 (USA, iNES file SHA1)

    freeze_game  = freeze_game,
    release_game = release_game,

    setup = function(state)
        write_u8(PLAYER_HP,        MAX_HP)
        write_u8(UNLOCKED_WEAPONS, 0xFF)               -- all weapons unlocked so engine accepts the write
        write_u8(AMMO_QUICK,       MAX_HP)             -- start with max ammo (28)
        write_u8(CURRENT_WEAPON,   WEAPON_QUICK_BOOMERANG)
        write_u8(PAL_SPRITE_1,     QUICK_PAL_1)
        write_u8(PAL_SPRITE_2,     QUICK_PAL_2)
        write_u8(PAL_SPRITE_3,     QUICK_PAL_3)
        write_u8(DIFFICULTY,       NORMAL_DIFFICULTY)
        emu.frameadvance()
        prev_lives = read_u8(LIVES)
    end,

    -- Lock the weapon, refill the ammo, and force the sprite palette
    -- back to Quick Boomerang's pink-on-peach every frame. The engine
    -- writes palette_sprite when entities take damage / on transitions
    -- so we re-pin every tick to be safe.
    on_frame = function(state)
        write_u8(CURRENT_WEAPON, WEAPON_QUICK_BOOMERANG)
        write_u8(AMMO_QUICK,     MAX_HP)
        write_u8(PAL_SPRITE_1,   QUICK_PAL_1)
        write_u8(PAL_SPRITE_2,   QUICK_PAL_2)
        write_u8(PAL_SPRITE_3,   QUICK_PAL_3)
    end,

    win = function() return read_u8(BOSS_HP) == 0 end,

    fail = function()
        local now = read_u8(LIVES)
        if now < prev_lives then return true end
        prev_lives = now
        return false
    end,

    hud = function(state)
        -- Backed timer + small "QUICK ∞" label so the player sees
        -- both the lock and the unlimited-ammo affordance.
        gui.drawRectangle(6, 4, 158, 28, 0xc0000000, 0xc0000000)
        hud.drawTime(10, 8, state.elapsed)
        gui.text(122, 12, "QUICK")
    end,

    result = function(state)
        return { completionTime = state.elapsed }
    end,
}
