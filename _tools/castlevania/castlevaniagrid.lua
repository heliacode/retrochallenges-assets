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

-- Top HUD strip — 256x40 semi-transparent black bar across the full
-- width, anchored at y=0. Drawn BEFORE the grid so the gridlines
-- overlay it, making it easy to lay out HUD elements within the strip
-- against the 8/32 px tile boundaries.
local HUD_STRIP_BG = 0xff000000   -- fully opaque black

-- ---------------------------------------------------------------------------
-- font_1 pixel-font renderer.
--
-- Glyphs are individual PNGs in assets/font_1/<UPPER>.png — see
-- assets/font_1.md for the character map. We resolve the path off the
-- script's own location so it works regardless of BizHawk's CWD.
-- Each glyph is ~13 px wide; 16 px advance keeps them on the minor
-- grid with a ~3 px breathing gap.
-- ---------------------------------------------------------------------------
local function script_dir()
    local src = debug.getinfo(1, "S").source
    if src:sub(1, 1) == "@" then src = src:sub(2) end
    return src:match("(.*[/\\])") or "./"
end

local FONT_DIR             = script_dir() .. "../../assets/font_1/"
local FONT_NATIVE          = 16   -- approximate native glyph box (px)
local FONT_SCALE           = 0.75 -- 75% — preserves more pixel-art detail than 50%
local FONT_GLYPH_SIZE      = math.floor(FONT_NATIVE * FONT_SCALE)  -- 12 px square

-- Letter advance was 14 (12 glyph + 2 breathing); reduced 25% → 11 (so
-- glyphs draw at 12 wide with -1 visual overlap, which the glyph
-- sprites' own padding absorbs cleanly).
local FONT_LETTER_ADVANCE  = 11
-- Word break (space char) was 14; reduced 50% → 7. Keeps word
-- separation visible without making spaces dominate the line.
local FONT_WORD_ADVANCE    = 7

-- Punctuation that doesn't follow the simple "<UPPER>.png" rule. See
-- assets/font_1.md for the full character map.
local FONT_PUNCT = {
    ["!"] = "excl_2.png",   -- no canonical excl.png — only the GLOVER!!! sprites
    ["?"] = "qmark.png",
    [","] = "comma.png",
    ["-"] = "dash.png",
    ["/"] = "slash.png",
}

local function draw_font_text(x, y, text)
    local cur_x = x
    for i = 1, #text do
        local c = text:sub(i, i)
        if c == " " then
            cur_x = cur_x + FONT_WORD_ADVANCE
        else
            local file = FONT_PUNCT[c] or (c:upper() .. ".png")
            gui.drawImage(FONT_DIR .. file, cur_x, y, FONT_GLYPH_SIZE, FONT_GLYPH_SIZE)
            cur_x = cur_x + FONT_LETTER_ADVANCE
        end
    end
end

while true do
    poll_toggle()
    gui.drawRectangle(0, 0, SCREEN_W, 40, HUD_STRIP_BG, HUD_STRIP_BG)
    draw_font_text(8, 8, "Kill the Bat !")
    if _grid_visible then
        draw_grid()
    end
    -- Tiny banner so the player remembers the toggle key even when grid is hidden.
    gui.text(SCREEN_W - 60, SCREEN_H - 12,
             _grid_visible and "[G] grid ON" or "[G] grid OFF",
             INSTR_FG, INSTR_BG)
    emu.frameadvance()
end
