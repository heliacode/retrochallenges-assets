-- NES screen coordinate-grid overlay (BizHawk Lua dev tool).
--
-- Drop this into BizHawk's Lua console alongside any game to see exactly
-- where (x, y) coordinates land on screen — useful for designing HUD
-- layouts (gui.text, gui.drawImage, hud.drawBar, etc.).
--
-- The NES screen is 256x240. The script draws:
--   - Minor gridlines every 8 px (semi-transparent gray)
--   - Major gridlines every 32 px (brighter cyan)
--   - X-axis labels along the top edge, every 32 px
--   - Y-axis labels along the left edge, every 32 px
--   - Toggle with the G key (edge-triggered, once per press)
--
-- Sized off the NES PPU's 8x8 background tiles: every minor gridline
-- corresponds to one tile boundary, every major gridline to four. So a
-- glyph that's exactly 16 px wide spans two minor cells.
--
-- Usage:
--   1. Open BizHawk: Tools → Lua Console
--   2. Open Script → load _tools/grid_overlay.lua
--   3. Press G in the BizHawk window to toggle the grid

local SCREEN_W = 256
local SCREEN_H = 240

local MINOR_STEP = 8
local MAJOR_STEP = 32

-- ARGB hex; high byte is alpha. 40 = ~25% opaque, A0 = ~63% opaque.
local MINOR_COLOR    = 0x40808080
local MAJOR_COLOR    = 0xa000ffff
local LABEL_FG       = 0xffffffff
local LABEL_BG       = 0xc0000000
local INSTR_FG       = 0xffffff00
local INSTR_BG       = 0xc0000000

local _grid_visible  = true
local _g_was_pressed = false

local function draw_grid()
    -- Vertical gridlines + X-axis labels
    for x = 0, SCREEN_W, MINOR_STEP do
        local color = (x % MAJOR_STEP == 0) and MAJOR_COLOR or MINOR_COLOR
        gui.drawLine(x, 0, x, SCREEN_H, color)
    end
    for x = MAJOR_STEP, SCREEN_W, MAJOR_STEP do
        gui.text(x + 2, 1, tostring(x), LABEL_FG, LABEL_BG)
    end

    -- Horizontal gridlines + Y-axis labels
    for y = 0, SCREEN_H, MINOR_STEP do
        local color = (y % MAJOR_STEP == 0) and MAJOR_COLOR or MINOR_COLOR
        gui.drawLine(0, y, SCREEN_W, y, color)
    end
    for y = MAJOR_STEP, SCREEN_H, MAJOR_STEP do
        gui.text(1, y + 1, tostring(y), LABEL_FG, LABEL_BG)
    end

    -- Origin marker
    gui.text(2, 1, "0,0", LABEL_FG, LABEL_BG)
end

local function poll_toggle()
    local keys = input.get() or {}
    local now  = keys.G and true or false
    if now and not _g_was_pressed then
        _grid_visible = not _grid_visible
    end
    _g_was_pressed = now
end

while true do
    poll_toggle()
    if _grid_visible then
        draw_grid()
    end
    -- Tiny banner so the player remembers the toggle key even when grid is hidden.
    gui.text(SCREEN_W - 60, SCREEN_H - 12,
             _grid_visible and "[G] grid ON" or "[G] grid OFF",
             INSTR_FG, INSTR_BG)
    emu.frameadvance()
end
