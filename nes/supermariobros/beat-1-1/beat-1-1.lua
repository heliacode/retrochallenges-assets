-- Super Mario Bros. (World) — Beat 1-1
--
-- NO SAVESTATE. The framework reboots the core to power-on, then this
-- challenge's `setup` drives the title screen via scripted Start
-- presses until the game lands on World 1-1, frame 0 of gameplay.
-- The 3-2-1-GO countdown then plays over the paused first frame and
-- the clock starts when the player gets control.
--
-- Win: Mario triggers the end-of-level animation in 1-1 (touched the
-- flagpole). Fail: lost a life, or the in-game timer hit 0.

local hud       = require("RcHud")
local challenge = require("RcChallenge")

local read_u8  = memory.read_u8  or memory.readbyte
local write_u8 = memory.write_u8 or memory.writebyte

-- ---------------------------------------------------------------------------
-- Memory map — verified against Data Crystal's SMB RAM map
-- https://datacrystal.tcrf.net/wiki/Super_Mario_Bros./RAM_map
-- ---------------------------------------------------------------------------
local GAME_MODE      = 0x0770  -- 0x00 boot, 0x01 title/demo, 0x02 in-level
local OPERATION_MODE = 0x0772  -- 0x04 = end-of-level animation (flagpole→castle)
local PAUSE_FLAG     = 0x0776  -- nonzero = paused
local WORLD          = 0x075F  -- 0-indexed; 0 = World 1
local LEVEL          = 0x0760  -- 0-indexed within world; 0 = X-1
local LIVES          = 0x075A
local TIMER_HI       = 0x07F8
local TIMER_MID      = 0x07F9
local TIMER_LO       = 0x07FA
local SCORE_BASE     = 0x07DD  -- 6 BCD digits, one per byte

-- ---------------------------------------------------------------------------
-- Freeze: SMB's pause register at $0776. Writing 1 stops gameplay (player,
-- enemies, timer) while the renderer keeps running, so countdown / banner
-- overlays stay drawn. Input neutralised to prevent the auto-unpause
-- cooldown at $0777 from kicking us out.
-- ---------------------------------------------------------------------------
local function freeze_game()
    write_u8(PAUSE_FLAG, 1)
    joypad.set({}, 1)
end

local function release_game()
    write_u8(PAUSE_FLAG, 0)
end

-- ---------------------------------------------------------------------------
-- Score = 6 BCD digits at $07DD-$07E2. In-game value is always ×10
-- (the ones-digit is unused / locked at 0).
-- ---------------------------------------------------------------------------
local function read_score()
    local s = 0
    for i = 0, 5 do
        s = s * 10 + read_u8(SCORE_BASE + i)
    end
    return s * 10
end

local function timer_expired()
    return read_u8(TIMER_HI)  == 0
       and read_u8(TIMER_MID) == 0
       and read_u8(TIMER_LO)  == 0
       and read_u8(GAME_MODE) == 0x02
end

-- ---------------------------------------------------------------------------
-- Boot-to-start: framework rebooted the core before us, so the NES is on
-- the Nintendo logo / title sequence. Pump Start until gameplay begins.
--
-- The alternate-press pattern (one-frame on, one-frame off) handles the
-- title-screen's input edge detection: SMB only consumes Start on the
-- press edge, not while held.
-- ---------------------------------------------------------------------------
local function press_start_until(predicate, max_frames)
    max_frames = max_frames or 600
    for f = 0, max_frames - 1 do
        joypad.set({ Start = (f % 2 == 0) }, 1)
        emu.frameadvance()
        if predicate() then
            joypad.set({}, 1)
            return true
        end
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Per-attempt state.
-- ---------------------------------------------------------------------------
local start_lives = 0

-- ---------------------------------------------------------------------------
-- Run the challenge.
-- ---------------------------------------------------------------------------
challenge.run{
    -- No savestate: the framework will reboot the core to power-on and
    -- hand us a fresh NES on the SMB title sequence.
    expected_rom_hashes = { "EA343F4E445A9050D4B4FBAC2C77D0693B1D0922" },  -- SMB (World), iNES file SHA1

    freeze_game  = freeze_game,
    release_game = release_game,

    setup = function(state)
        -- Let the BIOS / title intro initialise before we start pressing
        -- buttons. Without this, the first few Start presses get swallowed
        -- by the boot animation.
        for _ = 1, 60 do emu.frameadvance() end

        -- Mash Start until $0770 says "in-level gameplay" (0x02). If we
        -- run past max_frames, something is wrong — the framework's
        -- universal R-key will be the recovery path.
        local ok = press_start_until(function()
            return read_u8(GAME_MODE) == 0x02
        end, 600)

        if not ok then
            console.log("[beat-1-1] setup: failed to enter gameplay after 600 frames")
        end

        -- Confirm we landed in 1-1. If somehow we're not (save data on
        -- cart? — unlikely on an emulator power-on), log it; the win
        -- predicate is gated on World==0 / Level==0 so it'll never fire
        -- on the wrong stage anyway.
        local w, l = read_u8(WORLD), read_u8(LEVEL)
        if w ~= 0 or l ~= 0 then
            console.log(string.format("[beat-1-1] WARN: expected W1-1, got W%d-%d", w + 1, l + 1))
        end

        start_lives = read_u8(LIVES)
    end,

    -- Win = end-of-level animation playing in 1-1. $0772 == 0x04 is set
    -- the instant Mario touches the flagpole and persists until the
    -- castle "BOWSER OR PRINCESS" room loads. Gating on World==0 /
    -- Level==0 is paranoia: if a future attempt somehow starts past 1-1,
    -- this win predicate won't false-positive on the flagpole of 1-2.
    win = function()
        return read_u8(OPERATION_MODE) == 0x04
           and read_u8(WORLD) == 0
           and read_u8(LEVEL) == 0
    end,

    -- Fail = dropped a life (any cause — pit, enemy contact, timer
    -- death). The lives counter is the universal death detector.
    fail = function()
        if read_u8(LIVES) < start_lives then return true end
        if timer_expired() then return true end
        return false
    end,

    hud = function(state)
        gui.text(10, 6, "SCORE")
        hud.drawScore(48, 4, read_score(), 0)
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
