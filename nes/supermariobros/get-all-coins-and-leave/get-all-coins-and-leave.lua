-- Super Mario Bros. (World) — Get All Coins And Leave
--
-- Underground secret room in 1-1. Grab all 19 coins, then take the exit
-- pipe out. Win the run by leaving the underground with 19 coins
-- collected; fail by leaving with fewer (or by dying / timer expiring).
--
-- Savestate starts Mario inside the underground secret room with 0
-- coins. The level palette ($0773) is 0x03 (underground); when the
-- exit pipe transports him back to the 1-1 surface, the palette
-- flips to 0x00 — that transition is our "left the underground"
-- signal.

local hud       = require("RcHud")
local challenge = require("RcChallenge")

local read_u8  = memory.read_u8  or memory.readbyte
local write_u8 = memory.write_u8 or memory.writebyte

-- ---------------------------------------------------------------------------
-- Memory map — verified against Data Crystal's SMB RAM map.
-- https://datacrystal.tcrf.net/wiki/Super_Mario_Bros./RAM_map
-- ---------------------------------------------------------------------------
local GAME_MODE      = 0x0770  -- 0x02 = in-level gameplay
local PAUSE_FLAG     = 0x0776  -- nonzero = paused (used to freeze)
local LEVEL_PALETTE  = 0x0773  -- 0x00 overworld, 0x03 underground
local COINS          = 0x075E  -- BCD-ish counter, 0..99 (single byte)
local LIVES          = 0x075A
local TIMER_HI       = 0x07F8
local TIMER_MID      = 0x07F9
local TIMER_LO       = 0x07FA
local SCORE_BASE     = 0x07DD  -- 6 BCD bytes — see read_score()

local UNDERGROUND_PALETTE = 0x03
local TARGET_COINS        = 19

-- ---------------------------------------------------------------------------
-- Freeze: same trick as beat-1-1 — write 1 to $0776 to pause gameplay
-- while the renderer keeps running. Inputs neutralised so the
-- $0777 auto-unpause cooldown can't kick us out.
-- ---------------------------------------------------------------------------
local function freeze_game()
    write_u8(PAUSE_FLAG, 1)
    joypad.set({}, 1)
end

local function release_game()
    write_u8(PAUSE_FLAG, 0)
end

local function bcd_byte(b) return math.floor(b / 16) * 10 + (b % 16) end

local function read_score()
    local s = 0
    for i = 0, 5 do
        s = s * 10 + read_u8(SCORE_BASE + i)
    end
    return s * 10
end

-- Coin counter is a single-byte BCD value (top nibble = tens, bottom =
-- ones). 19 collected reads as 0x19, not 19 decimal.
local function read_coins()
    return bcd_byte(read_u8(COINS))
end

-- Timer reaches 000 when all three digits are zero AND game is in level.
local function timer_expired()
    return read_u8(TIMER_HI)  == 0
       and read_u8(TIMER_MID) == 0
       and read_u8(TIMER_LO)  == 0
       and read_u8(GAME_MODE) == 0x02
end

-- ---------------------------------------------------------------------------
-- Per-attempt state.
--
-- `entered_underground` is the latch that makes "left the underground"
-- meaningful. The savestate starts Mario on the 1-1 surface (palette
-- == 0x00) about to drop down the entry pipe, so naively checking
-- "palette != 0x03" fires on frame 1 — before Mario has even entered
-- the room. We arm the latch via on_frame() once we actually observe
-- the underground palette, then "left" only counts after.
-- ---------------------------------------------------------------------------
local start_lives          = 0
local entered_underground  = false

-- True if Mario was inside the underground room and is no longer there.
local function left_underground()
    return entered_underground
       and read_u8(LEVEL_PALETTE) ~= UNDERGROUND_PALETTE
end

-- ---------------------------------------------------------------------------
-- Run the challenge.
-- ---------------------------------------------------------------------------
challenge.run{
    savestate           = "savestates/get-all-coins-and-leave.state",
    expected_rom_hashes = { "EA343F4E445A9050D4B4FBAC2C77D0693B1D0922" },  -- SMB (World), iNES file SHA1

    freeze_game  = freeze_game,
    release_game = release_game,

    setup = function(state)
        emu.frameadvance()
        start_lives         = read_u8(LIVES)
        entered_underground = false
    end,

    -- Latch the "we've been in the underground" flag the first frame
    -- the engine reports the underground palette. Runs every play
    -- frame, before win/fail.
    on_frame = function(state)
        if read_u8(LEVEL_PALETTE) == UNDERGROUND_PALETTE then
            entered_underground = true
        end
    end,

    -- Win = left the underground AND grabbed all 19 coins. Win is
    -- checked before fail every frame, so a "left with 19 coins"
    -- frame submits cleanly; "left with <19 coins" falls through
    -- to fail on the same frame.
    win = function()
        return left_underground() and read_coins() >= TARGET_COINS
    end,

    fail = function()
        -- Exited without all coins.
        if left_underground() and read_coins() < TARGET_COINS then
            return true
        end
        -- Lost a life (pit, enemy, anything).
        if read_u8(LIVES) < start_lives then return true end
        -- Timer ran out.
        if timer_expired() then return true end
        return false
    end,

    hud = function(state)
        gui.text(10,  6, "COINS")
        gui.text(48,  6, tostring(read_coins()) .. " / " .. tostring(TARGET_COINS))
        gui.text(10, 18, "SCORE")
        hud.drawScore(48, 16, read_score(), 0)
        gui.text(10, 30, "TIME")
        hud.drawTime(48, 28, state.elapsed)
    end,

    result = function(state)
        return {
            score          = read_score(),
            completionTime = state.elapsed,
        }
    end,
}
