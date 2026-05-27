-- Super Mario Bros. (World) — Get 20 Coins
--
-- Collect 20 coins as fast as you can. Counts from whatever the savestate
-- starts at, so a "fresh" Mario starting at 0 needs to grab 20. Single
-- life: pit / enemy / timer-zero ends the run.

local hud       = require("RcHud")
local challenge = require("RcChallenge")

local read_u8  = memory.read_u8  or memory.readbyte
local write_u8 = memory.write_u8 or memory.writebyte

-- ---------------------------------------------------------------------------
-- Memory map — verified against Data Crystal's SMB RAM map.
-- ---------------------------------------------------------------------------
local GAME_MODE  = 0x0770
local PAUSE_FLAG = 0x0776
local COINS      = 0x075E  -- BINARY 0..99 (see RAM.md note)
local LIVES      = 0x075A
local TIMER_HI   = 0x07F8
local TIMER_MID  = 0x07F9
local TIMER_LO   = 0x07FA

local TARGET_COINS = 20

local function freeze_game()
    write_u8(PAUSE_FLAG, 1)
    joypad.set({}, 1)
end

local function release_game()
    write_u8(PAUSE_FLAG, 0)
end

local function timer_expired()
    return read_u8(TIMER_HI)  == 0
       and read_u8(TIMER_MID) == 0
       and read_u8(TIMER_LO)  == 0
       and read_u8(GAME_MODE) == 0x02
end

-- ---------------------------------------------------------------------------
-- Per-attempt state. `start_coins` is captured in setup so the challenge
-- works whether the savestate puts Mario at 0 coins or partway through a
-- run with some coins already banked.
-- ---------------------------------------------------------------------------
local start_coins = 0
local prev_lives  = 0

challenge.run{
    savestate           = "savestates/get-20-coins.state",
    expected_rom_hashes = { "EA343F4E445A9050D4B4FBAC2C77D0693B1D0922" },

    freeze_game  = freeze_game,
    release_game = release_game,

    setup = function(state)
        emu.frameadvance()
        start_coins = read_u8(COINS)
        prev_lives  = read_u8(LIVES)
    end,

    -- Win = collected TARGET_COINS coins since the savestate loaded.
    -- The counter wraps at 100 (+1 life), but 20 is well below that.
    win = function()
        return read_u8(COINS) >= start_coins + TARGET_COINS
    end,

    fail = function()
        local now = read_u8(LIVES)
        if now < prev_lives then return true end
        prev_lives = now
        if timer_expired() then return true end
        return false
    end,

    hud = function(state)
        hud.drawTimeBg(10, 4, state.elapsed)
    end,

    result = function(state)
        return { completionTime = state.elapsed }
    end,
}
