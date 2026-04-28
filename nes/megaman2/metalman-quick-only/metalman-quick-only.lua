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

    setup = function(state)
        write_u8(PLAYER_HP,        MAX_HP)
        write_u8(UNLOCKED_WEAPONS, 0xFF)               -- all weapons unlocked so engine accepts the write
        write_u8(AMMO_QUICK,       MAX_HP)             -- start with max ammo (28)
        write_u8(CURRENT_WEAPON,   WEAPON_QUICK_BOOMERANG)
        write_u8(DIFFICULTY,       NORMAL_DIFFICULTY)
        emu.frameadvance()
        prev_lives = read_u8(LIVES)
    end,

    -- Lock the weapon AND refill the ammo every frame. Pause-menu
    -- switching reverts immediately, and ammo never depletes — so
    -- the only failure mode is dying.
    on_frame = function(state)
        write_u8(CURRENT_WEAPON, WEAPON_QUICK_BOOMERANG)
        write_u8(AMMO_QUICK,     MAX_HP)
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
