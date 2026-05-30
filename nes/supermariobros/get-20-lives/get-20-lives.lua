-- Super Mario Bros. (World) — Get 20 Lives
--
-- Gain 20 1-Ups, starting from World 3-1. The counter shows lives
-- EARNED since the savestate loaded, not Mario's absolute lives
-- total — so it ticks 0 -> 20 regardless of what he had when the run
-- started. Any method counts: hidden 1-Up mushrooms, the 100 coin
-- roll-over, the staircase shell-stomp loop, jumping a Cheep-Cheep
-- chain in 2-3, 8-enemies-no-touch combos.
--
-- No fail predicate — die freely while farming (deaths just push the
-- counter back down). The run ends when LIVES has risen by 20 from
-- the captured start, or you hit R to restart.

local hud       = require("RcHud")
local challenge = require("RcChallenge")

local read_u8  = memory.read_u8  or memory.readbyte
local write_u8 = memory.write_u8 or memory.writebyte

-- ---------------------------------------------------------------------------
-- Memory map — Data Crystal SMB RAM map.
-- https://datacrystal.tcrf.net/wiki/Super_Mario_Bros./RAM_map
-- ---------------------------------------------------------------------------
local PAUSE_FLAG = 0x0776  -- nonzero = paused (freeze hook)
local LIVES      = 0x075A  -- displayed lives count; rolls under 0 = game over

local TARGET_DELTA = 20

-- Captured in setup() so the counter is relative to whatever the
-- savestate loaded with — not pinned to a hard-coded starting value.
local start_lives = 0

local function freeze_game()
    write_u8(PAUSE_FLAG, 1)
    joypad.set({}, 1)
end

local function release_game()
    write_u8(PAUSE_FLAG, 0)
end

local function lives_gained()
    return read_u8(LIVES) - start_lives
end

challenge.run{
    savestate           = "savestates/get-20-lives.State",
    expected_rom_hashes = { "EA343F4E445A9050D4B4FBAC2C77D0693B1D0922" },

    freeze_game  = freeze_game,
    release_game = release_game,

    setup = function(state)
        emu.frameadvance()
        start_lives = read_u8(LIVES)
    end,

    -- Win = LIVES has risen TARGET_DELTA above the captured starting
    -- count. Delta (not absolute) so a different savestate doesn't
    -- silently change the bar.
    win = function()
        return lives_gained() >= TARGET_DELTA
    end,

    hud = function(state)
        hud.drawTimeBg(10, 4, state.elapsed)
        -- Just the count, big digits, on a tight black backdrop.
        -- Placed low on screen (y=210) so it sits well clear of SMB's
        -- own top-row HUD but still inside the visible viewport.
        local count_str = tostring(math.max(0, lives_gained()))
        gui.drawRectangle(8, 210, 50, 26, 0xff000000, 0xff000000)
        hud.drawDigits(12, 214, count_str)
    end,

    result = function(state)
        return { completionTime = state.elapsed }
    end,
}
