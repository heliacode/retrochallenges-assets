-- input-test.lua — live controller-input diagnostic for BizHawk.
--
-- Draws two things every frame so you can localise where a missing
-- diagonal (e.g. Down+Right) gets lost:
--
--   HOST  — input.get(): the raw host signals BizHawk receives from
--           your gamepad, by device name. This is BEFORE BizHawk's
--           controller bindings are applied.
--   NES   — joypad.getimmediate(): the emulated NES pad state AFTER
--           BizHawk maps the host input through your bindings.
--
-- How to read it — press Down+Right, then Down+Left, and compare:
--   * HOST drops a direction          -> pad / driver / OS lost it;
--     BizHawk can't fix it (confirm in Windows joy.cpl).
--   * HOST shows both, NES drops one  -> BizHawk binding/decoding;
--     re-bind, or bind the DirectInput instance of the pad.
--
-- The DOWN+RIGHT / DOWN+LEFT lines at the bottom report the final
-- NES pad state — the asymmetry should show up there directly.
--
-- Load directly in the Lua Console with any ROM running.

local HOST_SLOTS = 11   -- fixed line count so stale entries always clear

while true do
    gui.clearGraphics()

    -- HOST: every host input currently held, by device name.
    local host  = input.get() or {}
    local names = {}
    for k in pairs(host) do names[#names + 1] = tostring(k) end
    table.sort(names)

    gui.text(6, 6, "HOST  input.get()")
    for i = 1, HOST_SLOTS do
        gui.text(6, 6 + i * 14, "  " .. (names[i] or ""))
    end

    -- NES: emulated pad state after BizHawk's bindings.
    local pad  = joypad.getimmediate() or {}
    local btns = { "Up", "Down", "Left", "Right", "A", "B", "Select", "Start" }

    gui.text(150, 6, "NES P1 pad")
    for i, b in ipairs(btns) do
        local on = pad["P1 " .. b] or pad[b]
        gui.text(150, 6 + i * 14, string.format("  %-7s%s", b, on and "[#]" or "[ ]"))
    end

    local down  = pad["P1 Down"]  or pad["Down"]
    local right = pad["P1 Right"] or pad["Right"]
    local left  = pad["P1 Left"]  or pad["Left"]
    gui.text(150, 150, "DOWN+RIGHT: " .. ((down and right) and "YES" or "no"))
    gui.text(150, 164, "DOWN+LEFT : " .. ((down and left)  and "YES" or "no"))

    emu.frameadvance()
end
