-- Super Mario Bros. (World) — Get 20 Lives
--
-- Push the lives counter up to 20, starting from World 3-1 with the
-- default 3 lives. Any method counts: hidden 1-Up mushrooms, the 100
-- coin roll-over, the staircase shell-stomp loop, jumping a Cheep-
-- Cheep chain in 2-3 (if you get there), 8-enemies-no-touch combos.
--
-- No fail predicate — die freely while farming. The run only ends
-- when LIVES reaches 20 (or you hit R to restart).

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

local TARGET_LIVES = 20

local function freeze_game()
    write_u8(PAUSE_FLAG, 1)
    joypad.set({}, 1)
end

local function release_game()
    write_u8(PAUSE_FLAG, 0)
end

challenge.run{
    savestate           = "savestates/get-20-lives.State",
    expected_rom_hashes = { "EA343F4E445A9050D4B4FBAC2C77D0693B1D0922" },

    freeze_game  = freeze_game,
    release_game = release_game,

    setup = function(state)
        emu.frameadvance()
    end,

    -- Win = lives counter reaches the target. Absolute (not delta-
    -- from-start) so it doesn't matter if the savestate's starting
    -- lives count drifts.
    win = function()
        return read_u8(LIVES) >= TARGET_LIVES
    end,

    hud = function(state)
        hud.drawTimeBg(10, 4, state.elapsed)
        -- LIVES line at the bottom of the screen — SMB's own HUD owns
        -- the top row. drawText covers A-Z 0-9 only; "OF" reads
        -- naturally as the target separator and renders cleanly.
        local now = read_u8(LIVES)
        hud.drawText(10, 218, "LIVES " .. now .. " OF " .. TARGET_LIVES)
    end,

    result = function(state)
        return { completionTime = state.elapsed }
    end,
}
