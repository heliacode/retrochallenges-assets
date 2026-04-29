-- Mega Man 2 — QuickMan Stage fall part 2
-- Continuation of the death-laser corridor. Survive 8 vertical
-- screen transitions this time.
--
-- Win  = current_screen ($0038) has incremented by 8 from the
--        captured value.
-- Fail = lives counter decrements (laser hits, pits, HP zero).
--
-- Mirrors quickman-level.lua's structure; only the screen budget
-- and savestate path differ.

local hud       = require("RcHud")
local challenge = require("RcChallenge")

local read_u8  = memory.read_u8  or memory.readbyte
local write_u8 = memory.write_u8 or memory.writebyte

local PLAYER_HP      = 0x06C0
local LIVES          = 0x00A8
local CURRENT_SCREEN = 0x0038
local DIFFICULTY     = 0x00CB
local GAME_MODE      = 0x00AA   -- bit 2 = "pause entities"

local MAX_HP             = 0x1C
local NORMAL             = 0x00
local SCREENS_TO_SURVIVE = 8

-- Screen-5 flair: when the player hits the 5th screen of the descent,
-- splash ink.png on screen for 3 seconds and play slime.wav once.
-- Pure presentation — doesn't affect win/fail logic.
local FLAIR_TRIGGER_SCREEN  = 5
local FLAIR_DURATION_FRAMES = 180   -- 3 sec at 60fps

local function safe_play_sound(name)
    local ok_req, sp = pcall(require, "SoundPlayer")
    if not ok_req or not sp then return end
    pcall(sp.play, RC.ASSETS_PATH .. "/" .. name)
end

local function freeze_game()
    write_u8(GAME_MODE, 0x04)
    joypad.set({}, 1)
end

local function release_game()
    write_u8(GAME_MODE, 0x00)
end

local prev_lives        = 0
local screen_at_start   = 0
local flair_started_at  = nil   -- frame counter when ink-splash kicked off

challenge.run{
    savestate           = "savestates/quickman-fall-part-2.state",
    expected_rom_hashes = { "2290D8D839A303219E9327EA1451C5EEA430F53D" },  -- Mega Man 2 (USA, iNES file SHA1)

    freeze_game  = freeze_game,
    release_game = release_game,

    setup = function(state)
        write_u8(PLAYER_HP,  MAX_HP)
        write_u8(DIFFICULTY, NORMAL)
        emu.frameadvance()
        prev_lives        = read_u8(LIVES)
        screen_at_start   = read_u8(CURRENT_SCREEN)
        flair_started_at  = nil  -- reset on retry so the splash fires again
    end,

    on_frame = function(state)
        -- Rising-edge trigger: once the player crosses into screen 5,
        -- kick off the ink splash + slime sound. Only ever fires once
        -- per attempt (latched on flair_started_at being non-nil).
        if flair_started_at == nil then
            local screens = (read_u8(CURRENT_SCREEN) - screen_at_start) % 256
            if screens >= FLAIR_TRIGGER_SCREEN then
                flair_started_at = state.elapsed
                safe_play_sound("slime.wav")
            end
        end
    end,

    win = function()
        local now = read_u8(CURRENT_SCREEN)
        return ((now - screen_at_start) % 256) >= SCREENS_TO_SURVIVE
    end,

    fail = function()
        local now = read_u8(LIVES)
        if now < prev_lives then return true end
        prev_lives = now
        return false
    end,

    hud = function(state)
        -- Ink splash: drawn first so the rest of the HUD sits on top.
        if flair_started_at and (state.elapsed - flair_started_at) < FLAIR_DURATION_FRAMES then
            gui.drawImage(RC.ASSETS_PATH .. "/ink.png", 0, 0)
        end
        local screens = (read_u8(CURRENT_SCREEN) - screen_at_start) % 256
        gui.drawRectangle(6, 4, 158, 28, 0xc0000000, 0xc0000000)
        hud.drawTime(10, 8, state.elapsed)
        gui.text(112, 12, screens .. "/" .. SCREENS_TO_SURVIVE)
    end,

    result = function(state)
        return { completionTime = state.elapsed }
    end,
}
