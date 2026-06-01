-- Metal Gear (NES) — global timer helper
--
-- Standalone BizHawk 2.11 Lua script (NOT an RcChallenge). Use it to watch the
-- universal timer byte while exploring RAM or capturing savestates.
--
-- Run it:  BizHawk → Tools → Lua Console → Open Script… → this file.
--
-- Address source: nes/metalgear/RAM.md  ($0012 = universal timer — provisional).

local read_u8 = memory.read_u8 or memory.readbyte

local ADDR_TIMER = 0x0012   -- universal timer

local prev   = read_u8(ADDR_TIMER)
local frames = 0            -- frames elapsed since the script started

while true do
    local t     = read_u8(ADDR_TIMER)
    local delta = t - prev          -- per-frame change (wraps at the byte boundary)
    prev   = t
    frames = frames + 1

    gui.text(8,  8, string.format("TIMER $0012 : %3d   0x%02X", t, t))
    gui.text(8, 26, string.format("delta/frame : %+d", delta))
    gui.text(8, 44, string.format("script frames: %d", frames))

    emu.frameadvance()
end
