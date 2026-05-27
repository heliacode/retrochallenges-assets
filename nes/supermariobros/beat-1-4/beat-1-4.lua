-- Super Mario Bros. (World) — Beat 1-4 (Bowser castle)
--
-- Cross Bowser's castle and touch the axe at the end of the bridge.
-- 1-4 is a castle level, so there is no flagpole — the win signal is
-- $07A1 (EndOfLevelTimer) flipping from 0 to non-zero, which the
-- engine sets the frame Mario contacts the axe. The bridge collapse /
-- Bowser fall / Mario auto-walk / Toadstool dialogue all happen
-- AFTER that, so the run ends at the moment of axe contact rather
-- than the scoring screen ($0772 == 0x04, which is what we tried
-- first and was way too late).
--
-- Single life: fire / Podoboo / enemy / pit / timer-zero ends the run.

local hud       = require("RcHud")
local challenge = require("RcChallenge")

local read_u8  = memory.read_u8  or memory.readbyte
local write_u8 = memory.write_u8 or memory.writebyte

-- ---------------------------------------------------------------------------
-- Memory map — Data Crystal SMB RAM map.
-- https://datacrystal.tcrf.net/wiki/Super_Mario_Bros./RAM_map
-- ---------------------------------------------------------------------------
local GAME_MODE    = 0x0770  -- 0x02 = in-level gameplay
local OP_MODE      = 0x0772  -- diagnostic only (was the wrong signal)
local PAUSE_FLAG   = 0x0776  -- nonzero = paused (freeze hook)
local WORLD        = 0x075F  -- diagnostic only
local LEVEL        = 0x0760  -- diagnostic only
local END_LV_TIMER = 0x07A1  -- non-zero once axe-touch / flagpole fires
local LIVES        = 0x075A
local TIMER_HI     = 0x07F8
local TIMER_MID    = 0x07F9
local TIMER_LO     = 0x07FA

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

-- Per-attempt baselines.
local prev_lives    = 0
local end_lv_was_zero = true   -- rising-edge guard for $07A1

-- Win = $07A1 (EndOfLevelTimer) rising from 0 to non-zero, which the
-- engine sets the frame Mario walks into the axe. Rising-edge guard
-- protects against any leftover non-zero value carried in by the
-- savestate.
local function axe_touched()
    local t = read_u8(END_LV_TIMER)
    if end_lv_was_zero and t > 0 then return true end
    if t == 0 then end_lv_was_zero = true end
    return false
end

challenge.run{
    savestate           = "savestates/beat-1-4.State",
    expected_rom_hashes = { "EA343F4E445A9050D4B4FBAC2C77D0693B1D0922" },

    freeze_game  = freeze_game,
    release_game = release_game,

    setup = function(state)
        emu.frameadvance()
        prev_lives      = read_u8(LIVES)
        end_lv_was_zero = (read_u8(END_LV_TIMER) == 0)
    end,

    win = axe_touched,

    fail = function()
        local now = read_u8(LIVES)
        if now < prev_lives then return true end
        prev_lives = now
        if timer_expired() then return true end
        return false
    end,

    hud = function(state)
        hud.drawTimeBg(10, 4, state.elapsed)
        -- Diagnostic. T is the End-of-Level timer; should jump from 0
        -- to non-zero the frame Mario touches the axe. O is the
        -- Operation mode ($0772) for cross-checking.
        gui.text(8, 224, string.format(
            "W:%d L:%d T:%02X O:%02X G:%02X",
            read_u8(WORLD), read_u8(LEVEL),
            read_u8(END_LV_TIMER), read_u8(OP_MODE), read_u8(GAME_MODE)))
    end,

    result = function(state)
        return { completionTime = state.elapsed }
    end,
}
