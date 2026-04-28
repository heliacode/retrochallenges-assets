-- Donkey Kong (NES, USA) — Get 2000 Points
-- Score 2000+ in a single run. Three lives, run ends if Mario dies
-- (lives counter decrements). Same playbook as Castlevania's
-- 5000pts: BCD score read, lives-counter death detector, win on
-- threshold, framework handles the rest.

local hud       = require("RcHud")
local challenge = require("RcChallenge")

local read_u8 = memory.read_u8 or memory.readbyte

-- ---------------------------------------------------------------------------
-- Memory map (NES Donkey Kong, USA)
-- Source: Data Crystal — Donkey Kong (NES, FDS) / RAM map
-- https://datacrystal.tcrf.net/wiki/Donkey_Kong_(NES,_Famicom_Disk_System)/RAM_map
-- ---------------------------------------------------------------------------
local SCORE_HI = 0x0025   -- BCD: high two digits (digits 6,5)
local SCORE_MID = 0x0026  -- BCD: middle two digits (digits 4,3)
local SCORE_LO = 0x0027   -- BCD: low two digits (digits 2,1)
local LIVES    = 0x0055   -- "Marios remaining" (Data Crystal annotates "graphic only";
                          -- still decrements on death for our universal-death pattern)

local TARGET_SCORE = 2000

-- ---------------------------------------------------------------------------
-- Score decode. Each byte holds two BCD digits (high nibble = leading digit).
-- score = d6 d5 d4 d3 d2 d1 (six-digit display).
-- ---------------------------------------------------------------------------
local function bcd_byte(b) return math.floor(b / 16) * 10 + (b % 16) end

local function read_score()
    return bcd_byte(read_u8(SCORE_HI))  * 10000
         + bcd_byte(read_u8(SCORE_MID)) * 100
         + bcd_byte(read_u8(SCORE_LO))
end

-- ---------------------------------------------------------------------------
-- Per-attempt state (lives baseline for the death detector).
-- ---------------------------------------------------------------------------
local prev_lives = 0

-- ---------------------------------------------------------------------------
-- Run the challenge
-- ---------------------------------------------------------------------------
challenge.run{
    savestate           = "savestates/2000pts.state",
    expected_rom_hashes = { "D8DFACBFEC34CDC871D73C901811551FE1706923" },  -- Donkey Kong (NES, USA, iNES file SHA1)

    setup = function(state)
        emu.frameadvance()
        prev_lives = read_u8(LIVES)
    end,

    win = function() return read_score() >= TARGET_SCORE end,

    fail = function()
        local now = read_u8(LIVES)
        if now < prev_lives then return true end
        prev_lives = now
        return false
    end,

    hud = function(state)
        gui.text(10, 6, "SCORE")
        hud.drawScore(48, 4, read_score(), TARGET_SCORE)
        gui.text(10, 24, "TIME")
        hud.drawTime(48, 22, state.elapsed)
    end,

    result = function(state)
        return {
            score          = read_score(),
            completionTime = state.elapsed,
        }
    end,
}
