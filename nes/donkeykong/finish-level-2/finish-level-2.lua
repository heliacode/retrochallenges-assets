-- Donkey Kong (NES, USA) — Finish Level 2 (in the rain)
-- Standard "clear the stage" objective layered on top of a torrential
-- rain effect — diagonal streaks falling across the entire screen
-- after a 1-second courtesy delay. Pure visual harassment; the rain
-- doesn't touch game state, but it makes barrels and ladders harder
-- to read at a glance.
--
-- Win  = the zone byte ($0053) advances past whatever it was at
--        savestate load (Mario completed the stage).
-- Fail = lives counter decrements (universal-death pattern).
--
-- Built on RcChallenge — savestate, countdown, banner, leaderboard,
-- R-anywhere-to-retry. Reuses the GameControlFlag freeze trick from
-- the 2000pts challenge ($004F = 0 halts gameplay).

local hud       = require("RcHud")
local challenge = require("RcChallenge")

local read_u8  = memory.read_u8  or memory.readbyte
local write_u8 = memory.write_u8 or memory.writebyte

-- ---------------------------------------------------------------------------
-- Memory map (NES Donkey Kong, USA)
-- See nes/donkeykong/2000pts/2000pts.lua for sources.
-- $0053: Current Zone (1..3) — advances when Mario clears a stage.
-- $0096: Mario's state — $FF = Dead. Flips the frame Mario takes a
--        fatal hit, well before the death animation finishes; makes
--        for snappier fail detection than watching the "lives remaining"
--        counter at $0055 which Data Crystal flags as graphic-only.
-- Source: Data Crystal RAM map.
-- ---------------------------------------------------------------------------
local CURRENT_ZONE      = 0x0053
local MARIO_STATE       = 0x0096
local MARIO_STATE_DEAD  = 0xFF
local GAME_CONTROL_FLAG = 0x004F

-- ---------------------------------------------------------------------------
-- Freeze trick (DK pauses on ZERO).
-- ---------------------------------------------------------------------------
local function freeze_game()
    write_u8(GAME_CONTROL_FLAG, 0)
    joypad.set({}, 1)
end

local function release_game()
    write_u8(GAME_CONTROL_FLAG, 1)
end

-- ---------------------------------------------------------------------------
-- Rain effect
-- ---------------------------------------------------------------------------
-- Each drop is a short diagonal streak that falls at a per-drop random
-- speed and respawns at the top once it leaves the bottom. We draw via
-- gui.drawLine so there's no PNG asset dependency.
local SCREEN_W = 256
local SCREEN_H = 240
local RAIN_DROP_COUNT      = 500   -- biblical
local RAIN_DROP_SPEED_MIN  = 6
local RAIN_DROP_SPEED_MAX  = 16
local RAIN_DROP_LENGTH     = 10
local RAIN_DROP_SLANT      = 3     -- horizontal pixels per streak length (steeper)
local RAIN_COLOR           = 0xE0D8F0FF  -- ARGB, near-white blue, ~88% alpha
local RAIN_START_FRAMES    = 60    -- 1 sec courtesy delay after countdown ends

-- Per-attempt state — reset in setup so retries get a fresh-feeling
-- spawn pattern + the zone baseline for the win detector.
local start_zone    = 0
local rain          = {}

local function reset_rain()
    rain = {}
    for i = 1, RAIN_DROP_COUNT do
        rain[i] = {
            x = math.random(0, SCREEN_W),
            -- Stagger initial Y above the screen so the rain ramps in
            -- gradually rather than all hitting the top at once.
            y = math.random(-SCREEN_H, 0),
            speed = math.random(RAIN_DROP_SPEED_MIN, RAIN_DROP_SPEED_MAX),
        }
    end
end

local function update_rain()
    for _, d in ipairs(rain) do
        d.y = d.y + d.speed
        if d.y > SCREEN_H then
            d.y = math.random(-30, 0)
            d.x = math.random(0, SCREEN_W)
            d.speed = math.random(RAIN_DROP_SPEED_MIN, RAIN_DROP_SPEED_MAX)
        end
    end
end

local function draw_rain()
    for _, d in ipairs(rain) do
        gui.drawLine(d.x, d.y, d.x - RAIN_DROP_SLANT, d.y - RAIN_DROP_LENGTH, RAIN_COLOR)
    end
end

-- ---------------------------------------------------------------------------
-- Run the challenge
-- ---------------------------------------------------------------------------
challenge.run{
    savestate           = "savestates/finish-level-2.state",
    expected_rom_hashes = { "D8DFACBFEC34CDC871D73C901811551FE1706923" },  -- Donkey Kong (NES, USA)
    countdown           = true,
    freeze_game         = freeze_game,
    release_game        = release_game,

    setup = function(state)
        emu.frameadvance()
        start_zone = read_u8(CURRENT_ZONE)
        math.randomseed(os.time())
        reset_rain()
    end,

    on_frame = function(state)
        if state.elapsed < RAIN_START_FRAMES then return end
        update_rain()
    end,

    win = function() return read_u8(CURRENT_ZONE) > start_zone end,

    -- Direct read of Mario's state byte: $FF = Dead, set the frame the
    -- fatal hit lands. Snappier than the lives-decrement pattern.
    fail = function() return read_u8(MARIO_STATE) == MARIO_STATE_DEAD end,

    hud = function(state)
        -- Rain drawn first so HUD overlays sit on top — the player can
        -- still read their stats even mid-downpour.
        draw_rain()
        gui.text(10,  6, "TIME")
        hud.drawTime(48,  4, state.elapsed)
        gui.text(10, 24, "ZONE " .. read_u8(CURRENT_ZONE))
    end,

    result = function(state)
        return { completionTime = state.elapsed }
    end,
}
