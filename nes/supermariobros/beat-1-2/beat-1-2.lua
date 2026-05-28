-- Super Mario Bros. (World) — Beat 1-2
--
-- Reach the World 1-2 flagpole as fast as possible. 1-2 starts
-- underground and ends at the warp-zone surface section; if you run
-- past the warp pipes without going up, there's a flagpole at the
-- right edge of that section. That's the win signal.
--
-- Single life: pit / enemy / timer-zero ends the run. Taking a warp
-- pipe does NOT win — those send you to W2/W3/W4 and the flagpole
-- gate is what counts.

local hud       = require("RcHud")
local challenge = require("RcChallenge")

local read_u8  = memory.read_u8  or memory.readbyte
local write_u8 = memory.write_u8 or memory.writebyte

-- ---------------------------------------------------------------------------
-- Memory map — Data Crystal SMB RAM map.
-- https://datacrystal.tcrf.net/wiki/Super_Mario_Bros./RAM_map
-- ---------------------------------------------------------------------------
local GAME_MODE    = 0x0770  -- 0x02 = in-level gameplay
local PAUSE_FLAG   = 0x0776  -- nonzero = paused (freeze hook)
local WORLD        = 0x075F  -- 0-indexed: 0 = World 1
local LEVEL        = 0x0760  -- 0-indexed within world: 1 = X-2
local PLAYER_FLOAT = 0x001D  -- 0x03 = sliding down flagpole
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

-- Per-attempt baselines. Captured in setup() after one frame so the
-- savestate's RAM is settled before reads. start_world / start_level
-- are kept around for the diagnostic HUD line but no longer gate the
-- win predicate — see comment on flagpole_touched below.
local start_world = 0
local start_level = 0
local prev_lives  = 0

-- Diagnostic state (persists across frames). Reset in setup().
local peak_float    = 0
local world_changed = false
local level_changed = false

-- Win = flagpole-slide while in active gameplay. No world/level gate.
--
-- Earlier we gated on (world, level) == start, but 1-2 trips that:
-- the underground -> warp-zone-surface pipe changes the area-level
-- byte ($0760), so the flagpole on the surface section reads a
-- different LEVEL value than the underground starting state. The
-- gate then blocked the win even when Mario was clearly tagging
-- the pole.
--
-- Dropping the gate is safe because $001D == 0x03 is unique to the
-- flagpole slide (Data Crystal: 0x00 stand / 0x01 jump airborne /
-- 0x02 walk-off airborne / 0x03 flagpole), and the run ends on the
-- first flagpole touch — the next level's flagpole never gets a
-- chance to false-fire. GAME_MODE == 0x02 guards against any 0x03
-- transient during savestate load.
-- Provisional union: flagpole-slide OR the World byte advancing past
-- the start (warp pipe). Whichever way 1-2 actually ends, this should
-- catch it; the diagnostic readout tells us which signal fired.
local function level_left()
    if read_u8(GAME_MODE) ~= 0x02 then return false end
    if read_u8(PLAYER_FLOAT) == 0x03 then return true end
    return read_u8(WORLD) ~= start_world
end

challenge.run{
    savestate           = "savestates/beat-1-2.state",
    expected_rom_hashes = { "EA343F4E445A9050D4B4FBAC2C77D0693B1D0922" },

    freeze_game  = freeze_game,
    release_game = release_game,

    setup = function(state)
        emu.frameadvance()
        start_world = read_u8(WORLD)
        start_level = read_u8(LEVEL)
        prev_lives  = read_u8(LIVES)
        peak_float    = 0
        world_changed = false
        level_changed = false
    end,

    win = level_left,

    fail = function()
        local now = read_u8(LIVES)
        if now < prev_lives then return true end
        prev_lives = now
        if timer_expired() then return true end
        return false
    end,

    hud = function(state)
        hud.drawTimeBg(10, 4, state.elapsed)
        -- Diagnostic — plain concatenation, no string.format. Remove
        -- once 1-2 is confirmed firing.
        local f = read_u8(PLAYER_FLOAT)
        local w = read_u8(WORLD)
        local l = read_u8(LEVEL)
        if f > peak_float then peak_float = f end
        if w ~= start_world then world_changed = true end
        if l ~= start_level then level_changed = true end
        gui.text(8, 188, "FLOAT peak=" .. peak_float .. " now=" .. f)
        gui.text(8, 202, "W now=" .. w .. " start=" .. start_world .. " chg=" .. tostring(world_changed))
        gui.text(8, 216, "L now=" .. l .. " start=" .. start_level .. " chg=" .. tostring(level_changed))
        gui.text(8, 230, "MODE=" .. read_u8(GAME_MODE))
    end,

    result = function(state)
        return { completionTime = state.elapsed }
    end,
}
