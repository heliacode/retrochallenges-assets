-- RcHud: shared HUD primitives for RetroChallenges Lua scripts.
--
-- Every drawing primitive in here works two ways:
--   1. If the matching PNG exists under <ASSETS_PATH>/<subdir>/, we
--      gui.drawImage it. Crisp pixel-art HUD.
--   2. If the asset is missing, we fall back to gui.text / gui.drawRectangle
--      so callers can ship the API now and add art later without code changes.
--
-- Usage from a challenge script:
--   local hud = require("RcHud")
--   hud.drawTopStrip()
--   hud.drawTime(10, 10, emu.framecount() - start_frame)
--   hud.drawScore(10, 26, current_score, target_score)
--   hud.drawLives(10, 42, lives_count, 3)
--   hud.drawBar(10, 58, 80, simon_hp, 64, "hp")
--   hud.banner.fail()
--   hud.drawKeyPrompt(60, 180, "R", "Retry")
--
-- Asset filename conventions (relative to <ASSETS_PATH>/):
--   digits/d_0.png ... d_9.png      (16x24 each, recommended)
--   digits/d_colon.png, d_dot.png, d_slash.png, d_minus.png
--   hud/strip_top.png               (256x32, full-width HUD strip)
--   hud/heart_full.png, heart_empty.png  (12x12)
--   hud/bar_frame.png               (64x8 frame; fill is drawn programmatically)
--   keys/k_r.png, k_esc.png, k_space.png ... (16x16 each)
--   banners/complete.png, failed.png, personal_best.png  (centered, ~256 wide)

local M = {}

-- ---------------------------------------------------------------------------
-- Asset resolution + existence cache
-- ---------------------------------------------------------------------------
local RC = _G.RC

local function asset_path(relative)
    if not RC or not RC.ASSETS_PATH or not relative then return nil end
    return RC.ASSETS_PATH .. "/" .. relative
end

-- Cache: filename -> bool. Asset directory doesn't change at runtime, so
-- one io.open per file per session is enough.
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
-- Time / score formatting (also useful on its own — exported)
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
local DIGIT_W = 16   -- pixel advance per digit when sprites exist
local DIGIT_H = 24
local FALLBACK_W = 8 -- gui.text approximate per-char advance

local DIGIT_NAME = {
    ["0"] = "d_0",  ["1"] = "d_1",  ["2"] = "d_2",  ["3"] = "d_3",
    ["4"] = "d_4",  ["5"] = "d_5",  ["6"] = "d_6",  ["7"] = "d_7",
    ["8"] = "d_8",  ["9"] = "d_9",
    [":"] = "d_colon", ["."] = "d_dot",
    ["/"] = "d_slash", ["-"] = "d_minus",
}

-- Draw a string of digits + separators. Anything not in DIGIT_NAME (letters,
-- spaces, punctuation we haven't drawn yet) falls through to gui.text so the
-- caller never sees a hole.
function M.drawDigits(x, y, str)
    str = tostring(str or "")
    local cx = x
    for i = 1, #str do
        local ch = str:sub(i, i)
        local glyph = DIGIT_NAME[ch]
        local rel = glyph and ("digits/" .. glyph .. ".png")
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

-- "5000 / 5000" style readout. Either argument may be nil.
function M.drawScore(x, y, current, target)
    local s = tostring(current or 0)
    if target then s = s .. " / " .. tostring(target) end
    M.drawDigits(x, y, s)
end

-- ---------------------------------------------------------------------------
-- Top HUD strip
-- ---------------------------------------------------------------------------
function M.drawTopStrip()
    if M.assetExists("hud/strip_top.png") then
        gui.drawImage(asset_path("hud/strip_top.png"), 0, 0)
    end
    -- No fallback: leave the playfield clean if the strip art isn't there.
end

-- ---------------------------------------------------------------------------
-- Lives / hearts row
-- ---------------------------------------------------------------------------
local LIFE_ADVANCE = 14   -- 12px sprite + 2px gap

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
-- Progress / HP bar
-- ---------------------------------------------------------------------------
-- AARRGGBB. BizHawk gui.drawRectangle takes (x, y, w, h, lineColor, fillColor).
local BAR_FILL_COLORS = {
    hp     = 0xff10b981,  -- emerald
    boss   = 0xffdc2626,  -- danger red
    timer  = 0xfff59e0b,  -- amber
    other  = 0xff6366f1,  -- indigo (default)
}
local BAR_BG_COLOR = 0xa0000000   -- 60%-opaque black backing

function M.drawBar(x, y, width, current, max, kind)
    width = math.max(width or 0, 4)
    local fill_color = BAR_FILL_COLORS[kind] or BAR_FILL_COLORS.other
    local pct = (max and max > 0) and math.min(1, math.max(0, current / max)) or 0
    local inner_w = math.floor((width - 4) * pct)

    -- Solid backing so the bar reads on any background.
    gui.drawRectangle(x, y, width, 8, BAR_BG_COLOR, BAR_BG_COLOR)
    if inner_w > 0 then
        gui.drawRectangle(x + 2, y + 2, inner_w, 4, fill_color, fill_color)
    end

    -- Optional frame overlay if the artist supplies one.
    if M.assetExists("hud/bar_frame.png") then
        gui.drawImage(asset_path("hud/bar_frame.png"), x, y)
    end
end

-- ---------------------------------------------------------------------------
-- Key prompts
-- ---------------------------------------------------------------------------
local KEY_ADVANCE = 20    -- 16px key + 4px gap before label

function M.drawKeyPrompt(x, y, key, label)
    key = tostring(key or "")
    label = label or ""
    local rel = "keys/k_" .. key:lower() .. ".png"
    if M.assetExists(rel) then
        gui.drawImage(asset_path(rel), x, y)
        if label ~= "" then gui.text(x + KEY_ADVANCE, y + 2, label) end
    else
        gui.text(x, y, "[" .. key .. "] " .. label)
    end
end

-- ---------------------------------------------------------------------------
-- Outcome banners
-- ---------------------------------------------------------------------------
-- NES playfield is 256x240. Banners sit centered around y=80 by default;
-- pass y to override (e.g. for a complete + personal-best stack).
local function draw_banner(rel, fallback_text, y)
    y = y or 80
    if M.assetExists(rel) then
        gui.drawImage(asset_path(rel), 0, y)
    else
        gui.text(80, y + 20, fallback_text)
    end
end

M.banner = {}
function M.banner.win(y)            draw_banner("banners/complete.png",      "CHALLENGE COMPLETE!", y) end
function M.banner.fail(y)           draw_banner("banners/failed.png",        "CHALLENGE FAILED",    y) end
function M.banner.personalBest(y)   draw_banner("banners/personal_best.png", "NEW BEST!",           y) end

return M
