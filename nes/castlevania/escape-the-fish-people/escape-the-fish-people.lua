-- Castlevania — Escape the Fish-People
-- Simon spawns deep in the swampy sunken-city area with a quarter-bar
-- of HP and has to climb the stairs out before the merman / fish-men
-- knock him into the water for good.
--
-- Win  = the engine's Floor byte ($0046) increments past its captured
--        value (Simon completed a stair traversal).
-- Fail = lives counter decrements (universal death detection — handles
--        merman knockback into pits, instakill water, HP zero, etc.).
--
-- Built on RcChallenge — savestate, countdown, win banner, leaderboard
-- submission, and R-anywhere-to-retry come from the framework.

local hud       = require("RcHud")
local challenge = require("RcChallenge")

local read_u8  = memory.read_u8  or memory.readbyte
local write_u8 = memory.write_u8 or memory.writebyte

-- ---------------------------------------------------------------------------
-- Memory map (US NES Castlevania)
-- See nes/castlevania/castlevania_raminfo.md
-- ---------------------------------------------------------------------------
local USER_PAUSED  = 0x0022
local LIVES        = 0x002A
local SIMON_Y      = 0x003F   -- (unused in win predicate but documented for HUD use)
local FLOOR        = 0x0046   -- Stair-floor counter; increments when Simon
                              -- completes a staircase transition.
local HEALTH_REAL  = 0x0045

-- "1 bar of HP left" — Simon's HP runs 0–64; the on-screen bar has 16
-- ticks at 4 HP each, so 1 visible tick = 4 HP. Brutal: most enemies
-- one-shot Simon at this HP, hence the "Medium" rating leaning hard.
local START_HP   = 0x04

-- ---------------------------------------------------------------------------
-- Game-specific freeze trick
-- ---------------------------------------------------------------------------
local function freeze_game()
    write_u8(USER_PAUSED, 1)
    joypad.set({}, 1)
end

local function release_game()
    write_u8(USER_PAUSED, 0)
end

-- ---------------------------------------------------------------------------
-- Fish-people rain: 3 seconds in, sprites start raining from the top
-- of the screen at random x positions and varying fall speeds. Pure
-- visual harassment — doesn't touch the game state. Designed to
-- obscure Simon's path to the stairs without affecting hitboxes.
-- ---------------------------------------------------------------------------
local RAIN_START_FRAMES     = 180   -- 3 sec at 60fps
local SPAWN_INTERVAL_FRAMES = 4     -- a new fish every 4 frames = 15 spawns/sec
local FALL_SPEED_MIN        = 2     -- px/frame
local FALL_SPEED_MAX        = 4
local FISH_SPRITE_W         = 16    -- approximate; lets us spawn the right edge correctly
local SCREEN_W              = 256
local SCREEN_H              = 240

-- Per-attempt state.
local prev_lives     = 0
local floor_at_start = 0
local fish_rain      = {}   -- list of { x, y, speed }

-- ---------------------------------------------------------------------------
-- Run the challenge
-- ---------------------------------------------------------------------------
challenge.run{
    savestate           = "savestates/escape-the-fish-people.state",
    expected_rom_hashes = { "7A20C44F302FB2F1B7ADFFA6B619E3E1CAE7B546" },  -- Castlevania (USA, iNES file SHA1)
    countdown           = true,
    freeze_game         = freeze_game,
    release_game        = release_game,

    setup = function(state)
        write_u8(HEALTH_REAL, START_HP)
        emu.frameadvance()
        prev_lives     = read_u8(LIVES)
        floor_at_start = read_u8(FLOOR)
        -- Reset rain state on retry so each attempt gets the fresh
        -- 3-second grace window before the harassment starts.
        fish_rain = {}
        math.randomseed(os.time())
    end,

    on_frame = function(state)
        if state.elapsed < RAIN_START_FRAMES then return end
        -- Spawn a new fish every SPAWN_INTERVAL_FRAMES at a random x
        -- (allowed to peek off either edge so the strip looks organic).
        if state.elapsed % SPAWN_INTERVAL_FRAMES == 0 then
            table.insert(fish_rain, {
                x     = math.random(-FISH_SPRITE_W, SCREEN_W),
                y     = -FISH_SPRITE_W,
                speed = math.random(FALL_SPEED_MIN, FALL_SPEED_MAX),
            })
        end
        -- Update positions; reap anything past the bottom edge so the
        -- list doesn't grow without bound.
        for i = #fish_rain, 1, -1 do
            fish_rain[i].y = fish_rain[i].y + fish_rain[i].speed
            if fish_rain[i].y > SCREEN_H then
                table.remove(fish_rain, i)
            end
        end
    end,

    win = function() return read_u8(FLOOR) > floor_at_start end,

    fail = function()
        local now = read_u8(LIVES)
        if now < prev_lives then return true end
        prev_lives = now
        return false
    end,

    hud = function(state)
        -- Rain drawn first so the timer/HP overlay sits on top — the
        -- player can still read their stats even mid-rain.
        for _, fish in ipairs(fish_rain) do
            gui.drawImage(RC.ASSETS_PATH .. "/fishpeople_sprite.png", fish.x, fish.y)
        end
        gui.text(10, 6, "TIME")
        hud.drawTime(48, 4, state.elapsed)
        gui.text(10, 24, "HP")
        gui.text(48, 24, tostring(read_u8(HEALTH_REAL)) .. "/64")
    end,

    result = function(state)
        return { completionTime = state.elapsed }
    end,
}
