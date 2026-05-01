-- ===========================================================================
-- Dragon Warrior — Max Stats Dev Tool
-- ===========================================================================
-- Run this in BizHawk's Lua console (Tools → Lua Console → Open script)
-- while Dragon Warrior is loaded. Maxes XP, level, HP, MP, gold, keys,
-- herbs, and gives all the useful spells every frame so you can roam the
-- map freely while authoring savestates for new challenges.
--
-- Stop with the Stop button in the Lua console.
--
-- What this DOES write every frame:
--   - XP                       65535 (level-30 cap)
--   - Level                    30
--   - HP / Max HP              210 / 210
--   - MP / Max MP              220 / 220
--   - Gold                     65535
--   - Magic Keys               6
--   - Herbs                    6
--   - Spells (basic)           ALL (Heal, Hurt, Sleep, Radiant, Stopspell,
--                              Outside, Return, Repel)
--   - Spells (extended)        Healmore, Hurtmore, Rainbow Bridge built,
--                              Dragon's Scale, Fighter's Ring (no Cursed
--                              Belt or Death Necklace — those debuff you)
--
-- What this does NOT touch:
--   - Equipment ($00BE)        — leaves the savestate's loadout intact;
--                                use the in-game menu to equip if needed
--   - Map ID / X / Y           — for teleporting, edit the addresses at
--                                the bottom of this file (commented out)
--   - Random encounter rate    — no clean disable; you'll still get
--                                fights, but one-shot them with Hurtmore
--
-- See nes/dragonwarrior/dragonwarrior_raminfo.md for the full RAM map.
-- ===========================================================================

local read_u8  = memory.read_u8  or memory.readbyte
local write_u8 = memory.write_u8 or memory.writebyte

-- RAM addresses (NES Dragon Warrior, both PRG0 and PRG1 use same map)
local XP_LO       = 0x00BA   -- 16-bit LE: XP_LO + XP_LO+1
local GOLD_LO     = 0x00BC   -- 16-bit LE
local CURRENT_HP  = 0x00C5
local CURRENT_MP  = 0x00C6
local PLAYER_LVL  = 0x00C7
local MAX_HP      = 0x00CA
local MAX_MP      = 0x00CB
local KEYS        = 0x00BF
local HERBS       = 0x00C0
local SPELLS_BASE = 0x00CE   -- bit0 Heal, bit1 Hurt, bit2 Sleep, bit3 Radiant,
                             -- bit4 Stopspell, bit5 Outside, bit6 Return, bit7 Repel
local SPELLS_EXT  = 0x00CF   -- bit0 Healmore, bit1 Hurtmore, bit2 Secret stairs,
                             -- bit3 Rainbow Bridge, bit4 Dragon's Scale,
                             -- bit5 Fighter's Ring, bit6 Cursed Belt (DEBUFF),
                             -- bit7 Death Necklace (DEBUFF)

-- Skip the two debuff bits (6 + 7) so the dev tool doesn't curse the player.
-- 0x3F = 0011 1111 = bits 0..5.
local SAFE_SPELLS_EXT = 0x3F

local function maxout()
    -- XP at the level-30 cap
    write_u8(XP_LO,     0xFF)
    write_u8(XP_LO + 1, 0xFF)
    write_u8(PLAYER_LVL, 30)

    -- HP / MP pegged so random encounters can't dent us
    write_u8(MAX_HP,     210)
    write_u8(CURRENT_HP, 210)
    write_u8(MAX_MP,     220)
    write_u8(CURRENT_MP, 220)

    -- Spells: every basic + the safe extended ones
    write_u8(SPELLS_BASE, 0xFF)
    write_u8(SPELLS_EXT,  SAFE_SPELLS_EXT)

    -- Stockpile
    write_u8(GOLD_LO,     0xFF)
    write_u8(GOLD_LO + 1, 0xFF)
    write_u8(KEYS,  6)
    write_u8(HERBS, 6)
end

console.log("Dragon Warrior max-stats tool active. Hit Stop in the Lua console to disable.")
console.log("Maxing every frame — character is at level 30 with full kit.")

while true do
    maxout()
    emu.frameadvance()
end

-- ---------------------------------------------------------------------------
-- Teleport snippets — uncomment + tweak as needed, then re-run the script.
-- Map IDs from the RAM doc:
--   $01 World, $04 Tantegel Castle, $05 Throne Room, $07 Kol, $08 Brecconary,
--   $09 Garinham, $0A Cantlin, $0B Rimuldar, $0C Sun Shrine, $0D Rain Shrine,
--   $0E Magic Temple, $15 Swamp Cave, $1C–$1D Erdrick's Cave B1–B2,
--   $0F–$14 Charlock B1–B6, etc.
-- ---------------------------------------------------------------------------
-- write_u8(0x0045, 0x09)    -- map: Garinham
-- write_u8(0x003A, 12)      -- player X (tile)
-- write_u8(0x003B, 14)      -- player Y (tile)
