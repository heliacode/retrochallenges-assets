-- RcHud: shared HUD primitives for RetroChallenges Lua scripts.
--
-- Each primitive renders a PNG when the matching asset exists under
-- <ASSETS_PATH>/, otherwise falls back to gui.text / gui.drawRectangle so
-- callers can ship today and add art incrementally without code changes.
--
-- Usage from a challenge script:
--
--   local hud = require("RcHud")
--   hud.drawTime    (10, 10, emu.framecount() - start_frame)
--   hud.drawScore   (10, 26, current_score, target_score)
--   hud.drawLives   (10, 42, lives_count, 3)
--   hud.drawBar     (10, 58, 80, simon_hp, 64, "hp")
--   hud.drawKeyPrompt(60, 180, "R", "Retry")
--   hud.banner.win()
--   hud.banner.fail()
--
-- Asset filename conventions (relative to <ASSETS_PATH>/):
--
--   Digits (existing pixel-art set, ~23x29 each):
--     _sSmall0blue.png ... _sSmall9blue.png
--     _sSmallSemiblue.png            (used for ":" and "." separators)
--   Keys (24x24, derived from Kenney CC0 Input Prompts):
--     keys/k_r.png, keys/k_escape.png, keys/k_space.png
--   Banners (full-screen 256x240 overlays):
--     completed.png                  (win)
--     failed.png                     (fail; falls back to text)
--     personal_best.png              (NEW BEST; falls back to text)
--   HUD chrome (optional; programmatic fallback otherwise):
--     hud/strip_top.png, hud/heart_full.png, hud/heart_empty.png,
--     hud/bar_frame.png

local M = {}

-- ---------------------------------------------------------------------------
-- Asset resolution + existence cache
-- ---------------------------------------------------------------------------
local RC = _G.RC

local function asset_path(relative)
    if not RC or not RC.ASSETS_PATH or not relative then return nil end
    return RC.ASSETS_PATH .. "/" .. relative
end

local exists_cache = {}
function M.assetExists(relative)
    local cached = exists_cache[relative]
    if cached ~= nil then return cached end
    local p = asset_path(relative)
    if not p then exists_cache[relative] = false; return false end
    local f = io.open(p, "r")
    if f then f:close(); exists_cache[relative] = true; return true end
    exists_cache[relative] = false
    return false
end

-- ---------------------------------------------------------------------------
-- Time formatting (also useful on its own — exported)
-- ---------------------------------------------------------------------------
function M.formatTime(frames)
    if type(frames) ~= "number" or frames < 0 then return "0:00.000" end
    local total_ms = math.floor((frames / 60) * 1000)
    local m  = math.floor(total_ms / 60000)
    local s  = math.floor((total_ms % 60000) / 1000)
    local ms = total_ms % 1000
    return string.format("%d:%02d.%03d", m, s, ms)
end

-- ---------------------------------------------------------------------------
-- Digit rendering
-- ---------------------------------------------------------------------------
-- The existing pixel-art set is named `_sSmall<N>blue.png` (23x29). We give
-- each digit + separator a small horizontal advance; if the sprite is
-- missing we fall through to gui.text so any character we haven't drawn
-- art for still appears.
local DIGIT_W = 14   -- tighter than the 23-px sprite width — digits overlap slightly for a kerned look
local FALLBACK_W = 8

local DIGIT_NAME = {
    ["0"] = "_sSmall0blue", ["1"] = "_sSmall1blue", ["2"] = "_sSmall2blue",
    ["3"] = "_sSmall3blue", ["4"] = "_sSmall4blue", ["5"] = "_sSmall5blue",
    ["6"] = "_sSmall6blue", ["7"] = "_sSmall7blue", ["8"] = "_sSmall8blue",
    ["9"] = "_sSmall9blue",
    -- One separator sprite covers both colon and dot — looks the same at
    -- this size and is what's currently in the asset set.
    [":"] = "_sSmallSemiblue",
    ["."] = "_sSmallSemiblue",
}

function M.drawDigits(x, y, str)
    str = tostring(str or "")
    local cx = x
    for i = 1, #str do
        local ch = str:sub(i, i)
        local glyph = DIGIT_NAME[ch]
        local rel = glyph and (glyph .. ".png")
        if rel and M.assetExists(rel) then
            gui.drawImage(asset_path(rel), cx, y)
            cx = cx + DIGIT_W
        else
            gui.text(cx, y, ch)
            cx = cx + FALLBACK_W
        end
    end
end

function M.drawTime(x, y, frames)
    M.drawDigits(x, y, M.formatTime(frames))
end

function M.drawScore(x, y, current, target)
    local s = tostring(current or 0)
    if target then s = s .. " / " .. tostring(target) end
    M.drawDigits(x, y, s)
end

-- ---------------------------------------------------------------------------
-- Top HUD strip (optional — only renders if the artist supplies it)
-- ---------------------------------------------------------------------------
function M.drawTopStrip()
    if M.assetExists("hud/strip_top.png") then
        gui.drawImage(asset_path("hud/strip_top.png"), 0, 0)
    end
end

-- ---------------------------------------------------------------------------
-- Lives / hearts row
-- ---------------------------------------------------------------------------
local LIFE_ADVANCE = 14

function M.drawLives(x, y, count, max)
    count = count or 0
    max = max or count
    for i = 1, max do
        local rel = (i <= count) and "hud/heart_full.png" or "hud/heart_empty.png"
        if M.assetExists(rel) then
            gui.drawImage(asset_path(rel), x + (i - 1) * LIFE_ADVANCE, y)
        else
            local glyph = (i <= count) and "*" or "."
            gui.text(x + (i - 1) * FALLBACK_W, y, glyph)
        end
    end
end

-- ---------------------------------------------------------------------------
-- Progress / HP bar (always renders programmatically; bar_frame.png if any
-- is overlaid on top)
-- ---------------------------------------------------------------------------
local BAR_FILL_COLORS = {
    hp     = 0xff10b981,
    boss   = 0xffdc2626,
    timer  = 0xfff59e0b,
    other  = 0xff6366f1,
}
local BAR_BG_COLOR = 0xa0000000

function M.drawBar(x, y, width, current, max, kind)
    width = math.max(width or 0, 4)
    local fill_color = BAR_FILL_COLORS[kind] or BAR_FILL_COLORS.other
    local pct = (max and max > 0) and math.min(1, math.max(0, current / max)) or 0
    local inner_w = math.floor((width - 4) * pct)

    gui.drawRectangle(x, y, width, 8, BAR_BG_COLOR, BAR_BG_COLOR)
    if inner_w > 0 then
        gui.drawRectangle(x + 2, y + 2, inner_w, 4, fill_color, fill_color)
    end
    if M.assetExists("hud/bar_frame.png") then
        gui.drawImage(asset_path("hud/bar_frame.png"), x, y)
    end
end

-- ---------------------------------------------------------------------------
-- Key prompts (24x24 sprites under keys/, fallback to "[X] Label" text)
-- ---------------------------------------------------------------------------
local KEY_W = 24
local KEY_GAP = 4

-- Keyboard glyph filename uses the BizHawk input.get() name lowercased.
-- We map a couple of friendlier aliases so callers can pass "ESC".
local KEY_ALIAS = {
    ["esc"]    = "escape",
    ["return"] = "enter",
}

function M.drawKeyPrompt(x, y, key, label)
    key = tostring(key or "")
    label = label or ""
    local lower = key:lower()
    lower = KEY_ALIAS[lower] or lower
    local rel = "keys/k_" .. lower .. ".png"
    if M.assetExists(rel) then
        gui.drawImage(asset_path(rel), x, y)
        if label ~= "" then gui.text(x + KEY_W + KEY_GAP, y + 6, label) end
    else
        gui.text(x, y, "[" .. key .. "] " .. label)
    end
end

-- ---------------------------------------------------------------------------
-- Outcome banners
-- ---------------------------------------------------------------------------
-- The existing completed.png is a 256x240 full-screen overlay. We draw at
-- (0, 0) when present so it covers the playfield.
local function draw_banner_fullscreen(rel, fallback_text, fallback_y)
    if M.assetExists(rel) then
        gui.drawImage(asset_path(rel), 0, 0)
    else
        gui.text(80, fallback_y or 100, fallback_text)
    end
end

M.banner = {}
function M.banner.win()           draw_banner_fullscreen("completed.png",     "CHALLENGE COMPLETE!", 100) end
function M.banner.fail()          draw_banner_fullscreen("failed.png",        "CHALLENGE FAILED",    100) end
function M.banner.personalBest()  draw_banner_fullscreen("personal_best.png", "NEW BEST!",           120) end

return M
