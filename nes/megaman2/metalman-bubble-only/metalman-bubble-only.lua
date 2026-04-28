-- Mega Man 2 — Metal Man, Bubble Lead Only
-- Same boss room as boss-metalman, but the only weapon you can use
-- is Bubble Lead. Every frame we write Bubble Lead's weapon ID back
-- to $00A9 so the pause-menu switch reverts immediately. Bubble
-- Lead isn't Metal Man's weakness, so this hurts.
--
-- Loadout: full HP (28), Bubble Lead unlocked + equipped + full
-- ammo, difficulty pinned to Difficult. Die once and the run is over.
--
-- Built on RcChallenge — savestate, countdown, win banner, retry,
-- ROM hash check, leaderboard submission all come from the framework.

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
local UNLOCKED_WEAPONS = 0x009A   -- bitfield
local AMMO_BUBBLE_LEAD = 0x009F
local DIFFICULTY       = 0x00CB

local MAX_HP                 = 0x1C   -- 28
local WEAPON_BUBBLE_LEAD     = 0x04
local NORMAL_DIFFICULTY      = 0x00

-- ---------------------------------------------------------------------------
-- Per-attempt state (lives baseline for the death detector).
-- ---------------------------------------------------------------------------
local prev_lives = 0

-- ---------------------------------------------------------------------------
-- Run the challenge
-- ---------------------------------------------------------------------------
challenge.run{
    savestate           = "savestates/metalman-bubble-only.state",
    expected_rom_hashes = { "2290D8D839A303219E9327EA1451C5EEA430F53D" },  -- Mega Man 2 (USA, iNES file SHA1)

    setup = function(state)
        write_u8(PLAYER_HP,        MAX_HP)
        -- Unlock everything so the engine accepts our weapon write.
        -- Doesn't matter visually — on_frame forces Bubble Lead, so
        -- the player can't fire any of the others.
        write_u8(UNLOCKED_WEAPONS, 0xFF)
        write_u8(AMMO_BUBBLE_LEAD, MAX_HP)   -- max ammo == MAX_HP (28)
        write_u8(CURRENT_WEAPON,   WEAPON_BUBBLE_LEAD)
        write_u8(DIFFICULTY,       NORMAL_DIFFICULTY)
        emu.frameadvance()
        prev_lives = read_u8(LIVES)
    end,

    -- Lock the weapon every frame. Pause-menu switch reverts the
    -- next frame, so the player can never actually fire anything
    -- other than Bubble Lead. No need for a fail-on-switch — the
    -- switch is mechanically impossible.
    on_frame = function(state)
        write_u8(CURRENT_WEAPON, WEAPON_BUBBLE_LEAD)
    end,

    win = function() return read_u8(BOSS_HP) == 0 end,

    fail = function()
        local now = read_u8(LIVES)
        if now < prev_lives then return true end
        prev_lives = now
        return false
    end,

    hud = function(state)
        -- Backed timer + a small "BUBBLE LEAD ONLY" label so the
        -- player isn't confused when their pause-menu switch silently
        -- reverts. "0:00.000" is ~102 px wide at 18×22 digits.
        gui.drawRectangle(6, 4, 158, 28, 0xc0000000, 0xc0000000)
        hud.drawTime(10, 8, state.elapsed)
        gui.text(124, 12, "BUBBLE")
    end,

    result = function(state)
        return { completionTime = state.elapsed }
    end,
}
