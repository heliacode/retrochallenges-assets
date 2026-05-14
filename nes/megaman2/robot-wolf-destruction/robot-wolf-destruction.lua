-- Mega Man 2 — Robot Wolf Destruction (Wood Man stage)
--
-- Push three screens to the right through the Friender (robot wolf)
-- encounter at the start of Wood Man's stage. Loadout is whatever the
-- savestate ships with — no HP / weapon overrides.
--
-- Win:  $0440 (Mega Man X-screen index) rolls forward by 3 from the
--       savestate's starting value.
-- Fail: death (lives decrement, edge-trigger) OR Mega Man takes the
--       up-route shortcut. Detected via $001B (camera state) flipping
--       to 0x80 = "scrolling vertically" per the RAM doc. Wood Man's
--       opening corridor is pure horizontal, so any vertical scroll
--       at all means the player climbed something they shouldn't.

local hud       = require("RcHud")
local challenge = require("RcChallenge")

local read_u8  = memory.read_u8  or memory.readbyte
local write_u8 = memory.write_u8 or memory.writebyte

-- ---------------------------------------------------------------------------
-- Memory map (US NES Mega Man 2) — see nes/megaman2/RAM.md
-- ---------------------------------------------------------------------------
local LIVES        = 0x00A8
local GAME_MODE    = 0x00AA   -- bit 2 = "pause entities" (freeze trick)
local CAMERA_STATE = 0x001B   -- 0x80 = scrolling vertically
local X_SCREEN     = 0x0440   -- ent_x_screen + 0 (Mega Man's screen index)

local TARGET_SCREENS_RIGHT = 3
local CAMERA_VERTICAL_BIT  = 0x80

-- ---------------------------------------------------------------------------
-- Freeze trick: write 0x04 to game_mode to set bit 2 — same pattern as
-- every other MM2 challenge.
-- ---------------------------------------------------------------------------
local function freeze_game()
    write_u8(GAME_MODE, 0x04)
    joypad.set({}, 1)
end

local function release_game()
    write_u8(GAME_MODE, 0x00)
end

-- ---------------------------------------------------------------------------
-- Per-attempt state.
-- ---------------------------------------------------------------------------
local start_x_screen = 0
local prev_lives     = 0
local cheated_up     = false

challenge.run{
    savestate           = "savestates/robot-wolf-destruction.state",
    expected_rom_hashes = { "2290D8D839A303219E9327EA1451C5EEA430F53D" },  -- Mega Man 2 (USA, iNES file SHA1)

    freeze_game  = freeze_game,
    release_game = release_game,

    setup = function(state)
        emu.frameadvance()
        start_x_screen = read_u8(X_SCREEN)
        prev_lives     = read_u8(LIVES)
        cheated_up     = false
    end,

    -- Latch the cheat detection every frame. If $001B ever reads 0x80
    -- (vertical scroll), we trip the latch — fail predicate reads it
    -- next.
    on_frame = function(state)
        if read_u8(CAMERA_STATE) == CAMERA_VERTICAL_BIT then
            cheated_up = true
        end
    end,

    win = function()
        return read_u8(X_SCREEN) >= start_x_screen + TARGET_SCREENS_RIGHT
    end,

    fail = function()
        if cheated_up then return true end
        local now = read_u8(LIVES)
        if now < prev_lives then return true end
        prev_lives = now
        return false
    end,

    hud = function(state)
        gui.drawRectangle(6, 4, 110, 28, 0xc0000000, 0xc0000000)
        hud.drawTime(10, 8, state.elapsed)
    end,

    result = function(state)
        return { completionTime = state.elapsed }
    end,
}
