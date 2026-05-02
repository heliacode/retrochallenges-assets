-- ===========================================================================
-- Mega Man 2 — God Mode Dev Tool
-- ===========================================================================
-- Run this in BizHawk's Lua console (Tools → Lua Console → Open script)
-- while Mega Man 2 is loaded. Pegs Mega Man's HP, refills every weapon
-- on every frame, unlocks all 8 Robot Master weapons + all 3 Wily-stage
-- items, and keeps the lives counter pinned. Useful for scouting boss
-- rooms and stage layouts when authoring savestates.
--
-- Stop with the Stop button in the Lua console.
--
-- What this DOES write every frame:
--   - Player HP                  0x1C (28, the engine's MAX_HP)
--   - Lives                      9
--   - Unlocked-weapon bitfield   0xFF (all 8 Robot Master weapons)
--   - Items 1/2/3 bitfield       0x07 (all three Wily utilities)
--   - Per-weapon ammo            0x1C each across $009C..$00A3
--
-- What this does NOT touch:
--   - $00A9 (current weapon) — leaves your selection alone so you can
--     cycle freely in the pause menu without it snapping back.
--   - Score / stage progress / boss HP.
--
-- See nes/megaman2/RAM.md for the full reference.
-- ===========================================================================

local read_u8  = memory.read_u8  or memory.readbyte
local write_u8 = memory.write_u8 or memory.writebyte

-- RAM addresses (NES Mega Man 2, USA)
local PLAYER_HP        = 0x06C0
local LIVES            = 0x00A8
local WEAPONS_UNLOCKED = 0x009A   -- bitfield, bit i = robot master i defeated
local ITEMS_UNLOCKED   = 0x009B   -- low 3 bits = items 1, 2, 3
local AMMO_FIRST       = 0x009C   -- $009C..$00A3 (8 bytes, one per weapon)
local AMMO_LAST        = 0x00A3

local MAX_HP    = 0x1C   -- 28; same value caps player HP, boss HP, ammo
local PIN_LIVES = 9

local function godmode()
    -- HP pegged so any incoming damage is overwritten before it can
    -- knock you down to 0.
    write_u8(PLAYER_HP, MAX_HP)

    -- Stockpile + unlocks
    write_u8(WEAPONS_UNLOCKED, 0xFF)   -- all 8 weapons usable
    write_u8(ITEMS_UNLOCKED,   0x07)   -- all 3 utility items usable
    for addr = AMMO_FIRST, AMMO_LAST do
        write_u8(addr, MAX_HP)
    end

    -- Lives pinned so death (if it ever sneaks past the HP write —
    -- e.g., spike pits / one-shot kills bypass HP entirely) doesn't
    -- trigger game-over.
    write_u8(LIVES, PIN_LIVES)
end

console.log("Mega Man 2 god-mode tool active. Hit Stop in the Lua console to disable.")
console.log("Pegging HP / lives / weapons / items / ammo every frame.")

while true do
    godmode()
    emu.frameadvance()
end
