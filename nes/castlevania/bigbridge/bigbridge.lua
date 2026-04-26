-- Castlevania Cross the Big Bridge Challenge
-- Savestate drops Simon at the start of the bridge with a loaded loadout
-- (12 hearts, axe subweapon, long whip). Win by defeating the mummy boss
-- at the end. If Simon dies along the way the challenge fails and the
-- player can press R to retry from the same savestate.

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
    -- advancing frames; how the 3-2-1-GO and failure/completion overlays
    -- render without the game continuing underneath.
    USER_PAUSED   = 0x0022,
    -- Simon's current HP. 0x40 (64) is a full heart bar; 0 is dead
    -- (triggers death animation, then either respawn or game-over).
    HEALTH_REAL   = 0x0045,
    HEARTS        = 0x0071,
    SUBWEAPON     = 0x015B,
    WHIP_LEVEL    = 0x0070,
    -- Simon's state machine byte. Pit deaths don't drain HP, but they do
    -- toggle this byte. We display it during play (debug overlay) so we
    -- can identify the "dying from a fall" value and add it as a death
    -- signal in a follow-up.
    SIMON_STATE   = 0x046C,
    -- Mummy boss HP. The challenge ends when this reaches 0.
    BOSS_HEALTH   = 0x01A9,
}

local FULL_HEALTH   = 0x40
local START_HEARTS  = 12
local AXE_WEAPON    = 0x0D
local LONG_WHIP     = 0x02

local SAVESTATE = "savestates/bigbridge.state"  -- prelude resolves against CHALLENGE_DIR

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

local function use_system_bus_domain()
    local ok, domains = pcall(memory.getmemorydomainlist)
    if not ok or not domains then return end
    for _, d in ipairs(domains) do
        if d == "System Bus" then pcall(memory.usememorydomain, d); return end
    end
end

local function play_asset_sound(name)
    return pcall(SoundPlayer.play, RC.ASSETS_PATH .. "/" .. name)
end

local function draw_asset_image(name)
    gui.drawImage(RC.ASSETS_PATH .. "/" .. name, 0, 0)
end

local function asset_exists(name)
    local f = io.open(RC.ASSETS_PATH .. "/" .. name, "r")
    if f then f:close(); return true end
    return false
end

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

-- Poll the keyboard for a one-shot "R pressed" edge. Returns true only on
-- the frame the key goes from up to down, so holding R doesn't spam retries.
local _prev_r = false
local function r_pressed()
    local pressed = (input.get() or {}).R and true or false
    local edge = pressed and not _prev_r
    _prev_r = pressed
    return edge
end

-- ---------------------------------------------------------------------------
-- Gameplay setup
-- ---------------------------------------------------------------------------
-- Hand Simon the loadout the challenge expects. Writing to HEARTS and then
-- briefly zeroing + restoring forces the HUD to repaint.
local function setup_simon()
    write_u8(ADDR.HEARTS, 0)
    emu.frameadvance()
    write_u8(ADDR.HEARTS, START_HEARTS)
    write_u8(ADDR.SUBWEAPON, AXE_WEAPON)
    write_u8(ADDR.WHIP_LEVEL, LONG_WHIP)
    emu.frameadvance()
end

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

-- ---------------------------------------------------------------------------
-- Outcome screens
-- ---------------------------------------------------------------------------
local function show_completion_screen(frames)
    local time_text = format_frames(frames)
    local has_image = asset_exists("completed.png")
    while true do
        freeze_game()
        if has_image then
            draw_asset_image("completed.png")
        else
            gui.text(150, 100, "CHALLENGE COMPLETED!")
        end
        gui.text(10, 200, "Final Time:  " .. time_text)
        gui.text(10, 220, "Mummy boss defeated.")
        gui.text(10, 240, "Return to RetroChallenges for the next one.")
        emu.frameadvance()
    end
end

-- Returns "retry" when the player hits R. Otherwise loops forever so the
-- player can read the screen until they close or switch away.
local function show_failure_screen(frames)
    local time_text = format_frames(frames)
    while true do
        freeze_game()
        gui.text(90,  80, "CHALLENGE FAILED")
        gui.text(70, 100, "Simon didn't make it this time.")
        gui.text(90, 120, "Died at: " .. time_text)
        gui.text(40, 160, "Press R to retry from the start of the bridge.")
        gui.text(40, 180, "Or return to RetroChallenges to pick another.")
        if r_pressed() then return "retry" end
        emu.frameadvance()
    end
end

-- ---------------------------------------------------------------------------
-- One round of play. Win = boss HP 0, fail = Simon HP goes from >0 to 0.
-- Edge detection on death avoids falsely failing on the first frame of
-- the savestate load, where HP memory may briefly read 0 before init.
-- ---------------------------------------------------------------------------
local function play_round()
    local start_frame = emu.framecount()
    local prev_hp = read_u8(ADDR.HEALTH_REAL)
    -- Track the unique values SIMON_STATE has held since the round started.
    -- We log them to the BizHawk Lua console so the player can read off
    -- whatever value appears during a pit death. Cap the set size so a
    -- pathological game can't blow out the log.
    local seen_states = {}
    local seen_count = 0
    local STATE_LOG_CAP = 32

    while true do
        local simon_hp    = read_u8(ADDR.HEALTH_REAL)
        local simon_state = read_u8(ADDR.SIMON_STATE)
        local boss_hp     = read_u8(ADDR.BOSS_HEALTH)
        local elapsed     = emu.framecount() - start_frame

        if boss_hp == 0 then
            play_asset_sound("challengecompleted.wav")
            RC.report_completion{ completionTime = elapsed }
            show_completion_screen(elapsed)
            return "done"  -- never actually returns; completion loop is infinite
        end

        if prev_hp > 0 and simon_hp == 0 then
            return show_failure_screen(elapsed)  -- "retry" or loops forever
        end
        prev_hp = simon_hp

        if not seen_states[simon_state] and seen_count < STATE_LOG_CAP then
            seen_states[simon_state] = true
            seen_count = seen_count + 1
            console.log(string.format(
                "[bigbridge] new SIMON_STATE seen: 0x%02X (%d) at frame %d, hp=%d",
                simon_state, simon_state, elapsed, simon_hp))
        end

        gui.text(10, 10, "Time:  " .. format_frames(elapsed))
        gui.text(10, 25, string.format("HP:    %d / %d", simon_hp, FULL_HEALTH))
        gui.text(10, 40, "Mummy: " .. boss_hp)
        gui.text(10, 55, string.format("State: 0x%02X", simon_state))
        emu.frameadvance()
    end
end

-- ---------------------------------------------------------------------------
-- Main
-- ---------------------------------------------------------------------------
if not memory or not (memory.read_u8 or memory.readbyte) then
    console.log("ERROR: No ROM loaded — cannot start Big Bridge challenge.")
    return
end

use_system_bus_domain()
console.log(string.format("Castlevania Big Bridge Challenge - player: %s", RC.USERNAME))

if not load_start_state() then
    while true do
        gui.text(10, 10, "Savestate missing for bigbridge.")
        gui.text(10, 25, "Reinstall challenge assets from the RetroChallenges app.")
        emu.frameadvance()
    end
end

setup_simon()
countdown()

-- Retry loop. play_round returns "retry" when the player asks to restart;
-- anything else (including the completion-screen infinite loop) never
-- comes back, so falling off the while is the "closed the emulator" path.
while play_round() == "retry" do
    release_game()
    load_start_state()
    setup_simon()
    countdown()
end
