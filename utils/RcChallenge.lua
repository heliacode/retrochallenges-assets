-- RcChallenge: standard challenge runner.
--
-- Owns the bits every RetroChallenges challenge does the same way:
--   1. Memory-domain selection.
--   2. Savestate load (with a "missing savestate" fallback screen).
--   3. Optional setup callback (write starting RAM state).
--   4. 3-2-1-GO countdown.
--   5. Play loop with win predicate, optional fail predicate, HUD callback.
--   6. Completion path: 60-frame play-on, RC.report_completion, banner forever.
--   7. Failure path: banner + retry-prompt forever.
--   8. Universal R-to-retry: pressing R at ANY moment during the run
--      reloads the savestate and starts the challenge over.
--
-- A challenge becomes ~30 lines:
--
--   local hud = require("RcHud")
--   local challenge = require("RcChallenge")
--
--   local read_u8 = memory.read_u8 or memory.readbyte
--
--   challenge.run{
--       savestate           = "savestates/foo.state",
--       expected_rom_hashes = { "8DC0FC30FF8A7BBDFE5172956C3F88141B7DBD45" },  -- optional
--       win                 = function() return read_u8(0x07FC) >= 0x50 end,
--       hud                 = function(state)
--           hud.drawTime (48,  4, state.elapsed)
--           hud.drawScore(48, 22, read_u8(0x07FC), 0x50)
--       end,
--       result              = function(state) return { score = read_u8(0x07FC), completionTime = state.elapsed } end,
--   }
--
-- The framework logs gameinfo.getromhash() to BizHawk's Lua console on
-- every launch so authors can capture canonical values for new challenges.
--
-- Per-game freeze tricks (Castlevania's USER_PAUSED=1 write, etc.) are
-- per-game state; the framework calls into freeze_game / release_game
-- callbacks if you provide them. Without them, the game keeps animating
-- under the countdown / completion banners — usually harmless.

local RC = _G.RC or error(
    "RcChallenge requires the RetroChallenges launcher. Start the app rather\n" ..
    "than loading a challenge .lua directly in BizHawk."
)

local hud = require("RcHud")

local M = {}

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
local function noop() end
local function always_false() return false end

local function safe_play_sound(name)
    local ok_req, sp = pcall(require, "SoundPlayer")
    if not ok_req or not sp then return end
    pcall(sp.play, RC.ASSETS_PATH .. "/" .. name)
end

local function asset_exists(rel)
    local f = io.open(RC.ASSETS_PATH .. "/" .. rel, "r")
    if f then f:close(); return true end
    return false
end

local function draw_asset(name)
    gui.drawImage(RC.ASSETS_PATH .. "/" .. name, 0, 0)
end

local function use_system_bus_domain()
    if not (memory.getmemorydomainlist and memory.usememorydomain) then return end
    local ok, domains = pcall(memory.getmemorydomainlist)
    if not ok or not domains then return end
    for _, d in ipairs(domains) do
        if d == "System Bus" then pcall(memory.usememorydomain, d); return end
    end
end

-- Edge-triggered R-key detection (once per press, not held).
local _prev_r = false
local function r_pressed()
    local now = (input.get() or {}).R and true or false
    local edge = now and not _prev_r
    _prev_r = now
    return edge
end

-- ---------------------------------------------------------------------------
-- ROM hash verification
-- ---------------------------------------------------------------------------
-- Returns the loaded ROM's SHA1 hash (uppercase hex), or nil if BizHawk's
-- gameinfo API isn't available. BizHawk hashes the iNES file with its
-- 16-byte header included — this is NOT the No-Intro / GoodNES headerless
-- convention. The value printed to the Lua console can be pasted directly
-- into a challenge's expected_rom_hashes list as-is.
local function get_rom_hash()
    if not gameinfo or not gameinfo.getromhash then return nil end
    local ok, h = pcall(gameinfo.getromhash)
    if not ok or not h or h == "" then return nil end
    return h:upper()
end

-- True if the loaded ROM is in the spec's allowlist (or no allowlist
-- given). Always logs the actual hash on first call so authors can
-- capture and pin canonical values for new challenges.
local _hash_logged = false
local function verify_rom_hash(spec)
    local actual = get_rom_hash()
    if not _hash_logged then
        if actual then
            console.log("[RC] ROM SHA1: " .. actual)
        else
            console.log("[RC] ROM hash unavailable (gameinfo.getromhash missing)")
        end
        _hash_logged = true
    end
    local allow = spec.expected_rom_hashes
    if not allow or #allow == 0 then return true end  -- not enforced
    if not actual then return true end                -- can't enforce, don't fail-close
    for _, expected in ipairs(allow) do
        if actual == tostring(expected):upper() then return true end
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Internal: countdown
-- ---------------------------------------------------------------------------
local COUNTDOWN_STEPS = {
    { name = "3.png",  frames = 60,  tick = true },
    { name = "2.png",  frames = 60,  tick = true },
    { name = "1.png",  frames = 60,  tick = true },
    { name = "go.png", frames = 120, tick = false },
}

-- Returns true if the player asked to retry mid-countdown (which means the
-- caller should reload + restart from the top).
local function play_countdown(spec)
    gui.clearGraphics()
    for _, step in ipairs(COUNTDOWN_STEPS) do
        if step.tick then safe_play_sound("tock.wav") end
        for _ = 1, step.frames do
            spec.freeze_game()
            -- Belt-and-suspenders input neutralization: per-game
            -- freeze_game callbacks usually do this themselves, but
            -- games without a documented freeze byte (DK NES, etc.)
            -- have a no-op freeze_game and would let the player move
            -- during the countdown otherwise. Cheap to do unconditionally.
            joypad.set({}, 1)
            if asset_exists(step.name) then draw_asset(step.name) end
            if r_pressed() then return true end
            emu.frameadvance()
        end
    end
    gui.clearGraphics()
    spec.freeze_game()
    emu.frameadvance()
    spec.release_game()
    return false
end

-- ---------------------------------------------------------------------------
-- Internal: overlays that loop forever (until R or BizHawk close)
-- ---------------------------------------------------------------------------
local function draw_play_on_frames(spec, frames)
    -- Game continues normally for `frames` frames so the win/loss feels
    -- like it lands rather than being yanked out from under the player.
    -- R during this window cancels the win and restarts.
    for _ = 1, frames do
        if r_pressed() then return true end
        emu.frameadvance()
    end
    return false
end

local function show_complete_screen_forever(spec, payload, time_text)
    while true do
        spec.freeze_game()
        hud.banner.win()
        if payload.completionTime then gui.text(10, 200, "Final Time:  " .. time_text) end
        if payload.score then           gui.text(10, 220, "Final Score: " .. tostring(payload.score)) end
        -- Pixel-art [R] glyph + label, falls back to "[R] Retry" text if
        -- the key sprite isn't shipped.
        hud.drawKeyPrompt(10, 232, "R", "Retry — or return to RetroChallenges")
        if r_pressed() then return end
        emu.frameadvance()
    end
end

local function show_failure_screen_forever(spec, time_text)
    while true do
        spec.freeze_game()
        hud.banner.fail()
        gui.text(10, 200, "Failed at: " .. time_text)
        hud.drawKeyPrompt(10, 220, "R", "Retry — or return to RetroChallenges")
        if r_pressed() then return end
        emu.frameadvance()
    end
end

-- ---------------------------------------------------------------------------
-- Internal: one play attempt. Returns "win" / "fail" / "retry".
-- ---------------------------------------------------------------------------
local function play_attempt(spec, attempt_index)
    local start_frame = emu.framecount()
    while true do
        local elapsed = emu.framecount() - start_frame
        local state = {
            attempt        = attempt_index,
            elapsed        = elapsed,
            absolute_frame = emu.framecount(),
            phase          = "playing",
        }

        if r_pressed() then return "retry", state end
        spec.on_frame(state)
        if spec.win(state)  then return "win",  state end
        if spec.fail(state) then return "fail", state end

        spec.hud(state)
        emu.frameadvance()
    end
end

-- ---------------------------------------------------------------------------
-- Public: run the challenge
-- ---------------------------------------------------------------------------
function M.run(spec_in)
    -- Defaults / spec normalization
    local spec = {
        savestate           = assert(spec_in.savestate, "RcChallenge: spec.savestate is required"),
        win                 = assert(spec_in.win,       "RcChallenge: spec.win is required"),
        fail                = spec_in.fail              or always_false,
        setup               = spec_in.setup             or noop,
        countdown           = (spec_in.countdown ~= false),  -- default true
        hud                 = spec_in.hud               or noop,
        on_frame            = spec_in.on_frame          or noop,
        result              = spec_in.result            or function() return {} end,
        freeze_game         = spec_in.freeze_game       or noop,
        release_game        = spec_in.release_game      or noop,
        play_on_frames      = spec_in.play_on_frames    or 60,
        expected_rom_hashes = spec_in.expected_rom_hashes,
    }

    if not memory or not (memory.read_u8 or memory.readbyte) then
        console.log("RcChallenge: ERROR — no ROM loaded.")
        return
    end
    use_system_bus_domain()

    -- ROM hash check (only enforced when spec.expected_rom_hashes is set).
    -- Hangs on a friendly screen rather than running the challenge against
    -- the wrong RAM map — far better than weird memory addresses appearing
    -- to "kind of work" because of coincidental layout overlap.
    if not verify_rom_hash(spec) then
        local actual = get_rom_hash() or "?"
        while true do
            spec.freeze_game()
            gui.text(10, 10, "Wrong ROM for this challenge.")
            gui.text(10, 25, "Expected: " .. (spec.expected_rom_hashes[1] or "?"))
            gui.text(10, 40, "Got:      " .. actual)
            gui.text(10, 60, "Load the correct ROM in BizHawk and relaunch.")
            emu.frameadvance()
        end
    end

    console.log(string.format(
        "RcChallenge: %s / %s — player: %s",
        RC.GAME or "?", RC.CHALLENGE_NAME or "?", RC.USERNAME or "?"))

    local function load_savestate_or_show_missing()
        -- BizHawk's savestate.load() prints "could not find file: ..." but
        -- doesn't raise a Lua error, so pcall always returns ok=true. Pre-
        -- check existence ourselves before handing off, otherwise the
        -- challenge proceeds against power-on RAM and the win predicate
        -- can fire instantly on uninitialized memory (we hit a 0-frame
        -- bogus completion submission this way once already).
        local f = io.open(spec.savestate, "rb")
        if f then f:close() else
            while true do
                spec.freeze_game()
                gui.text(10, 10, "Savestate missing for this challenge.")
                gui.text(10, 25, "Reinstall challenge assets, then press R.")
                gui.text(10, 45, "Path: " .. spec.savestate)
                if r_pressed() then return false end
                emu.frameadvance()
            end
        end
        local ok, err = pcall(function() savestate.load(spec.savestate) end)
        if not ok then
            console.log("RcChallenge: savestate.load raised: " .. tostring(err))
            while true do
                spec.freeze_game()
                gui.text(10, 10, "Savestate failed to load.")
                gui.text(10, 25, tostring(err or "(unknown error)"))
                if r_pressed() then return false end
                emu.frameadvance()
            end
        end
        console.log("Savestate loaded: " .. spec.savestate)
        return true
    end

    local attempt = 0
    while true do
        if not load_savestate_or_show_missing() then
            -- savestate file went missing — caller asked for retry; loop
            -- back and try the load again. attempt count not bumped.
            goto continue
        end
        spec.setup({ attempt = attempt, phase = "setup" })

        if spec.countdown then
            local cancelled = play_countdown(spec)
            if cancelled then goto continue end
        end

        local outcome, state = play_attempt(spec, attempt)
        if outcome == "retry" then
            -- fall through to the next iteration -> reload + restart
        elseif outcome == "fail" then
            local time_text = hud.formatTime(state.elapsed)
            local cancelled = draw_play_on_frames(spec, spec.play_on_frames)
            if not cancelled then
                show_failure_screen_forever(spec, time_text)
            end
            -- Either play-on or failure-screen returned because R was
            -- pressed; either way we restart.
        elseif outcome == "win" then
            -- Submit to the leaderboard before showing the celebration so
            -- the run is recorded even if the player closes BizHawk
            -- immediately (or hits R) during the post-win delay.
            local payload = spec.result(state) or {}
            payload.completionTime = payload.completionTime or state.elapsed
            -- Sanity guard: refuse to submit completions that fired with no
            -- elapsed gameplay. This means the win predicate matched on the
            -- savestate's first frame — usually because the savestate was
            -- missing and we ran against power-on RAM (uninitialized bytes
            -- happen to satisfy "boss_hp == 0"). Still show the player a
            -- screen so they understand what happened.
            if (payload.completionTime or 0) <= 0 then
                console.log("RcChallenge: refusing to submit 0-frame completion — likely a missing-savestate / wrong-RAM win-predicate trigger.")
                while true do
                    spec.freeze_game()
                    gui.text(10, 10, "Win predicate fired on frame 0.")
                    gui.text(10, 25, "Most likely the savestate didn't load")
                    gui.text(10, 40, "and uninitialized RAM happened to")
                    gui.text(10, 55, "satisfy the win condition.")
                    gui.text(10, 80, "Run was NOT submitted. Press R to retry.")
                    if r_pressed() then break end
                    emu.frameadvance()
                end
                goto continue
            end
            safe_play_sound("challengecompleted.wav")
            if RC.report_completion then RC.report_completion(payload) end

            local time_text = hud.formatTime(payload.completionTime)
            local cancelled = draw_play_on_frames(spec, spec.play_on_frames)
            if not cancelled then
                show_complete_screen_forever(spec, payload, time_text)
            end
        end

        attempt = attempt + 1
        ::continue::
    end
end

return M
