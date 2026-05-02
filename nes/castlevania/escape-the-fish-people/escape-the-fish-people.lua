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
-- Sound effect at the 1-second mark — telegraphs that something's
-- about to go very wrong. Latched so retries get fresh playback.
-- ---------------------------------------------------------------------------
local SOUND_TRIGGER_FRAMES = 60   -- 1 sec at 60fps
local sound_played = false

local function safe_play_sound(name)
    local ok_req, sp = pcall(require, "SoundPlayer")
    if not ok_req or not sp then return end
    pcall(sp.play, RC.ASSETS_PATH .. "/" .. name)
end

-- ---------------------------------------------------------------------------
-- Fish-people rain: 2 seconds in, sprites start raining from the top
-- of the screen at random x positions and varying fall speeds. Pure
-- visual harassment — doesn't touch the game state. Designed to
-- obscure Simon's path to the stairs without affecting hitboxes.
-- ---------------------------------------------------------------------------
local RAIN_START_FRAMES     = 120   -- 2 sec at 60fps
local SPAWN_INTERVAL_FRAMES = 4     -- a new fish every 4 frames = 15 spawns/sec
local FALL_SPEED_MIN        = 2     -- px/frame
local FALL_SPEED_MAX        = 4
local FISH_SPRITE_W         = 16    -- approximate; lets us spawn the right edge correctly
local SCREEN_W              = 256
local SCREEN_H              = 240

-- Per-attempt state. lives_at_start is captured once in setup() and
-- never written again (unlike prev_lives which the fail predicate
-- updates each frame). The win predicate uses lives_at_start to lock
-- itself out permanently the moment a death happens this attempt — see
-- the comment on `win` below.
local prev_lives     = 0
local lives_at_start = 0
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
        lives_at_start = prev_lives   -- snapshot, never updated this attempt
        floor_at_start = read_u8(FLOOR)
        -- Reset rain + sound state on retry so each attempt gets the
        -- fresh sound at +1s and the rain at +2s.
        fish_rain    = {}
        sound_played = false
        math.randomseed(os.time())
    end,

    on_frame = function(state)
        -- Sound trigger at +1s, fires once per attempt.
        if not sound_played and state.elapsed >= SOUND_TRIGGER_FRAMES then
            sound_played = true
            safe_play_sound("mikumikuMiii.wav")
        end
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

    -- Win = Simon completed a stair traversal AND he's still alive.
    -- Reported bug: dying right after the countdown teleports Simon to
    -- a checkpoint where $0046 (FLOOR) reads greater than the captured
    -- start, and the framework checks win() before fail() — so a death
    -- was registering as a completion. Locking the win predicate behind
    -- "lives unchanged from start" makes it impossible to win after any
    -- death this attempt; the next frame's fail() catches the death and
    -- routes to the failure banner cleanly.
    win = function()
        if read_u8(LIVES) < lives_at_start then return false end
        return read_u8(FLOOR) > floor_at_start
    end,

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
