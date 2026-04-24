-- Castlevania 5000 Points Challenge
-- Load a savestate that drops the player in a known starting position and
-- measure how fast they can score 5000 points.

local RC = _G.RC or error(
    "This challenge requires the RetroChallenges launcher. Start it from the\n" ..
    "app rather than loading this .lua directly in BizHawk."
)

local SoundPlayer = require("SoundPlayer")

-- ---------------------------------------------------------------------------
-- Memory map (US NES release)
-- ---------------------------------------------------------------------------
local ADDR = {
    -- Writing 1 freezes the game's own state machine while BizHawk keeps
    -- advancing emulation frames. That's how the 3-2-1-GO countdown draws
    -- without the player sprite actually moving.
    USER_PAUSED = 0x0022,
    -- Score is three bytes of BCD at 0x07FC. The six digits map to
    -- 100000s, 10000s, 1000s, 100s, 10s, and a trailing "tenths" slot that
    -- is always 0 in Castlevania — the displayed score is always a multiple
    -- of 10.
    SCORE = 0x07FC,
}

local TARGET_SCORE = 5000
local SAVESTATE = "savestates/5000pts.state"  -- prelude resolves against CHALLENGE_DIR

-- Countdown image name -> frames to display it. The last entry ("GO") gets
-- extra frames so the transition to active play feels deliberate.
local COUNTDOWN = {
    { name = "3.png",  frames = 60,  tick = true },
    { name = "2.png",  frames = 60,  tick = true },
    { name = "1.png",  frames = 60,  tick = true },
    { name = "go.png", frames = 120, tick = false },
}

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
local read_u8  = memory.read_u8  or memory.readbyte
local write_u8 = memory.write_u8 or memory.writebyte

local function bcd_byte(b)
    return math.floor(b / 16) * 10 + (b % 16)
end

local function read_score()
    -- Three BCD bytes, six digits total. Positional multipliers below
    -- already reconstruct the full displayed score — DO NOT multiply the
    -- sum by 10 on top of that (earlier mistake: made the challenge
    -- trigger at displayed 500 instead of 5000).
    local hi = bcd_byte(read_u8(ADDR.SCORE))       -- 100000s + 10000s
    local mi = bcd_byte(read_u8(ADDR.SCORE + 1))   -- 1000s + 100s
    local lo = bcd_byte(read_u8(ADDR.SCORE + 2))   -- 10s + ones (ones is always 0 in Castlevania)
    return hi * 10000 + mi * 100 + lo
end

local function use_system_bus_domain()
    local ok, domains = pcall(memory.getmemorydomainlist)
    if not ok or not domains then return end
    for _, d in ipairs(domains) do
        if d == "System Bus" then pcall(memory.usememorydomain, d); return end
    end
end

local function play_asset_sound(name)
    local ok = pcall(SoundPlayer.play, RC.ASSETS_PATH .. "/" .. name)
    return ok
end

local function draw_asset_image(name)
    gui.drawImage(RC.ASSETS_PATH .. "/" .. name, 0, 0)
end

local function asset_exists(name)
    local f = io.open(RC.ASSETS_PATH .. "/" .. name, "r")
    if f then f:close(); return true end
    return false
end

-- Freeze the game while the overlay is up. joypad.set({}, 1) drops any
-- queued input so the player doesn't start moving the frame we release.
local function freeze_game()
    write_u8(ADDR.USER_PAUSED, 1)
    joypad.set({}, 1)
end

local function release_game()
    write_u8(ADDR.USER_PAUSED, 0)
end

local function format_frames(frames)
    local total_ms = math.floor((frames / 60) * 1000)
    local m = math.floor(total_ms / 60000)
    local s = math.floor((total_ms % 60000) / 1000)
    local ms = total_ms % 1000
    return string.format("%d:%02d.%03d", m, s, ms)
end

-- ---------------------------------------------------------------------------
-- Challenge flow
-- ---------------------------------------------------------------------------
local function countdown()
    gui.clearGraphics()
    for _, step in ipairs(COUNTDOWN) do
        if step.tick then play_asset_sound("tock.wav") end
        for _ = 1, step.frames do
            freeze_game()
            if asset_exists(step.name) then draw_asset_image(step.name) end
            emu.frameadvance()
        end
    end
    gui.clearGraphics()
    freeze_game()
    emu.frameadvance()
    release_game()
end

local function load_start_state()
    local ok, err = pcall(function() savestate.load(SAVESTATE) end)
    if not ok then
        console.log("Savestate load failed: " .. tostring(err))
        return false
    end
    console.log("Savestate loaded: " .. SAVESTATE)
    return true
end

local function announce_completion(score, frames)
    play_asset_sound("challengecompleted.wav")
    RC.report_completion{
        score = score,
        completionTime = frames,
    }
end

local function show_completion_screen(score, frames)
    local time_text = format_frames(frames)
    local has_image = asset_exists("completed.png")
    while true do
        -- Same USER_PAUSED freeze trick the countdown uses: stops game state
        -- from advancing (Simon no longer walks under the overlay) while the
        -- emulator keeps advancing frames so gui.text keeps rendering.
        freeze_game()
        if has_image then
            draw_asset_image("completed.png")
        else
            gui.text(150, 100, "CHALLENGE COMPLETED!")
        end
        gui.text(10, 200, "Final Time:  " .. time_text)
        gui.text(10, 220, "Final Score: " .. tostring(score))
        gui.text(10, 240, "Close BizHawk when you're done.")
        emu.frameadvance()
    end
end

-- ---------------------------------------------------------------------------
-- Main
-- ---------------------------------------------------------------------------
if not memory or not (memory.read_u8 or memory.readbyte) then
    console.log("ERROR: No ROM loaded — cannot start Castlevania 5000 points.")
    return
end

use_system_bus_domain()
console.log(string.format("Castlevania 5000 Points Challenge - player: %s", RC.USERNAME))

if not load_start_state() then
    -- Surface a visible message rather than sitting silently in an empty game.
    while true do
        gui.text(10, 10, "Savestate missing for 5000pts.")
        gui.text(10, 25, "Reinstall challenge assets from the RetroChallenges app.")
        emu.frameadvance()
    end
end

countdown()

local start_frame = emu.framecount()
while true do
    local score = read_score()
    local elapsed = emu.framecount() - start_frame

    gui.text(10, 10, string.format("Score: %d / %d", score, TARGET_SCORE))
    gui.text(10, 25, "Time:  " .. format_frames(elapsed))

    if score >= TARGET_SCORE then
        announce_completion(score, elapsed)
        show_completion_screen(score, elapsed)
        -- show_completion_screen never returns (infinite draw loop).
    end

    emu.frameadvance()
end
