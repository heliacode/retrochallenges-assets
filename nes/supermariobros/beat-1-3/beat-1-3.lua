-- Super Mario Bros. (World) — Beat 1-3
--
-- Reach the World 1-3 flagpole as fast as possible. 1-3 is the
-- bouncing-platforms-over-pits level. Single life: pit / enemy /
-- timer-zero ends it.

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
local WORLD        = 0x075F  -- 0-indexed world
local LEVEL        = 0x0760  -- 0-indexed level within world
local PLAYER_FLOAT = 0x001D  -- 0x03 = sliding down flagpole (per RAM.md)
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

local start_world = 0
local start_level = 0
local prev_lives  = 0

-- Diagnostic state (persists across frames). Reset in setup().
local peak_float    = 0
local world_changed = false
local level_changed = false
local change_snap   = nil

-- Debug log beside challenge_data.json (Lua console is hidden in the
-- custom EmuHawk). TEMPORARY.
local function debug_path()
    local base = _G.RC and _G.RC.CHALLENGE_DATA_PATH
    if not base then return "smb-1-3-debug.log" end
    return (base:gsub("[^/\\]+$", "smb-1-3-debug.log"))
end
local DBG = debug_path()

local function log_debug(f, w, l, g)
    if (w ~= start_world or l ~= start_level) and not change_snap then
        change_snap = "CHANGE @ peak_float=" .. peak_float
            .. "  W " .. start_world .. "->" .. w
            .. "  L " .. start_level .. "->" .. l
            .. "  float=" .. f .. "  mode=" .. g
    end
    local fh = io.open(DBG, "w")
    if not fh then return end
    fh:write("peak_float=" .. peak_float .. "\n")
    fh:write("start  W=" .. start_world .. " L=" .. start_level .. "\n")
    fh:write("now    W=" .. w .. " L=" .. l .. " FLOAT=" .. f .. " MODE=" .. g .. "\n")
    fh:write("world_changed=" .. tostring(world_changed)
        .. " level_changed=" .. tostring(level_changed) .. "\n")
    fh:write((change_snap or "no change yet") .. "\n")
    fh:close()
end

-- Provisional union: flagpole-slide OR world/level advancing past the
-- start. 1-3 has no internal sub-areas, so a world/level change can
-- only mean the level was completed (-> 1-4). The diagnostic readout
-- tells us whether the flagpole signal ($001D == 0x03) ever fired or
-- whether it was the level-change that carried the win.
local function level_left()
    if read_u8(GAME_MODE) ~= 0x02 then return false end
    if read_u8(PLAYER_FLOAT) == 0x03 then return true end
    return read_u8(WORLD) ~= start_world or read_u8(LEVEL) ~= start_level
end

challenge.run{
    savestate           = "savestates/beat-1-3.State",
    expected_rom_hashes = { "EA343F4E445A9050D4B4FBAC2C77D0693B1D0922" },

    freeze_game  = freeze_game,
    release_game = release_game,

    setup = function(state)
        emu.frameadvance()
        start_world   = read_u8(WORLD)
        start_level   = read_u8(LEVEL)
        prev_lives    = read_u8(LIVES)
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
        local f = read_u8(PLAYER_FLOAT)
        local w = read_u8(WORLD)
        local l = read_u8(LEVEL)
        if f > peak_float then peak_float = f end
        if w ~= start_world then world_changed = true end
        if l ~= start_level then level_changed = true end
        pcall(log_debug, f, w, l, read_u8(GAME_MODE))
        gui.text(8, 188, "FLOAT peak=" .. peak_float .. " now=" .. f)
        gui.text(8, 202, "W now=" .. w .. " start=" .. start_world .. " chg=" .. tostring(world_changed))
        gui.text(8, 216, "L now=" .. l .. " start=" .. start_level .. " chg=" .. tostring(level_changed))
        gui.text(8, 230, "MODE=" .. read_u8(GAME_MODE))
    end,

    result = function(state)
        return { completionTime = state.elapsed }
    end,
}
