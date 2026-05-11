-- Super Mario Bros. (World) — Get All Coins And Leave
--
-- Underground secret room in 1-1. Grab all 19 coins, then take the
-- exit pipe out. Win = enter the exit pipe with 19 coins. Fail =
-- enter the exit pipe with fewer, OR die, OR run out the in-game
-- timer.
--
-- Savestate starts Mario on the 1-1 surface about to drop down the
-- entry pipe. The first attempt at this challenge gated on level
-- palette ($0773) transitioning off underground, but that byte
-- flickers during pipe-warp animations (engine pre-loads the
-- destination palette mid-pan), causing spurious fails. We now key
-- off $000E — the player-state register that the SMB engine sets
-- exactly when Mario is touching the horizontal exit pipe.

local hud       = require("RcHud")
local challenge = require("RcChallenge")

local read_u8  = memory.read_u8  or memory.readbyte
local write_u8 = memory.write_u8 or memory.writebyte

-- ---------------------------------------------------------------------------
-- Memory map — verified against Data Crystal's SMB RAM map.
-- https://datacrystal.tcrf.net/wiki/Super_Mario_Bros./RAM_map
-- ---------------------------------------------------------------------------
local GAME_MODE      = 0x0770  -- 0x02 = in-level gameplay
local PAUSE_FLAG     = 0x0776  -- nonzero = paused (used to freeze)
local PLAYER_STATE   = 0x000E  -- player-state register (see ENTERING_EXIT_PIPE)
local COINS          = 0x075E  -- BINARY 0..99; the engine writes the BCD
                               -- display digits to $07ED/$07EE separately.
                               -- 19 coins reads as 0x13 here, NOT 0x19 —
                               -- earlier BCD-decoded reads of this byte
                               -- made "win at 19 coins" fail spuriously.
local LIVES          = 0x075A
local TIMER_HI       = 0x07F8
local TIMER_MID      = 0x07F9
local TIMER_LO       = 0x07FA

-- $000E values per Data Crystal:
--   0x02 - Entering reversed-L pipe (horizontal pipe = the exit pipe
--          in 1-1 underground)
--   0x03 - Going down a pipe (vertical pipe = the entry pipe Mario
--          uses to GET TO the underground; we ignore this)
-- So a value of 0x02 unambiguously means "Mario is leaving the
-- underground room via its only exit". No latch needed.
local ENTERING_EXIT_PIPE = 0x02
local TARGET_COINS       = 19

-- ---------------------------------------------------------------------------
-- Freeze: write 1 to $0776 to pause gameplay while the renderer keeps
-- running, then neutralise inputs so $0777's auto-unpause can't kick
-- us out.
-- ---------------------------------------------------------------------------
local function freeze_game()
    write_u8(PAUSE_FLAG, 1)
    joypad.set({}, 1)
end

local function release_game()
    write_u8(PAUSE_FLAG, 0)
end

local function read_coins() return read_u8(COINS) end

local function timer_expired()
    return read_u8(TIMER_HI)  == 0
       and read_u8(TIMER_MID) == 0
       and read_u8(TIMER_LO)  == 0
       and read_u8(GAME_MODE) == 0x02
end

local function entering_exit_pipe()
    return read_u8(PLAYER_STATE) == ENTERING_EXIT_PIPE
end

-- ---------------------------------------------------------------------------
-- Per-attempt state. Edge-trigger on lives (mirrors beat-1-1) so a 1-Up
-- collected before a death doesn't mask the decrement.
-- ---------------------------------------------------------------------------
local prev_lives = 0

-- ---------------------------------------------------------------------------
-- Run the challenge.
-- ---------------------------------------------------------------------------
challenge.run{
    savestate           = "savestates/get-all-coins-and-leave.state",
    expected_rom_hashes = { "EA343F4E445A9050D4B4FBAC2C77D0693B1D0922" },  -- SMB (World), iNES file SHA1

    freeze_game  = freeze_game,
    release_game = release_game,

    setup = function(state)
        emu.frameadvance()
        prev_lives = read_u8(LIVES)
    end,

    -- Win = entering the horizontal exit pipe with all 19 coins.
    -- Win is checked first every frame, so "entered with 19" wins
    -- and "entered with <19" falls through to fail on the same frame.
    win = function()
        return entering_exit_pipe() and read_coins() >= TARGET_COINS
    end,

    fail = function()
        -- Entered the exit pipe without all coins.
        if entering_exit_pipe() and read_coins() < TARGET_COINS then
            return true
        end
        -- Lost a life (pit, enemy, timer-zero-death). Edge-trigger.
        local now = read_u8(LIVES)
        if now < prev_lives then return true end
        prev_lives = now
        -- Timer hit 000 explicitly.
        if timer_expired() then return true end
        return false
    end,

    hud = function(state)
        hud.drawTime(10, 4, state.elapsed)
    end,

    result = function(state)
        return {
            completionTime = state.elapsed,
        }
    end,
}
