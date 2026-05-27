-- metronome.lua — frame-accurate metronome for BizHawk.
--
-- Plays assets/tock.wav once every INTERVAL emulated frames. Load it
-- directly in the Lua Console (or via --lua) with any ROM running;
-- stop the script to silence it.
--
-- At the NES's ~60.1 fps, INTERVAL = 16 gives ~3.76 tocks/second.

local INTERVAL = 16

-- Resolve this script's own directory so SoundPlayer.lua (same folder)
-- and tock.wav (../assets/) are found regardless of BizHawk's cwd.
local script_dir = (debug.getinfo(1, "S").source:sub(2):match("^(.*[\\/])")) or "./"

package.path = script_dir .. "?.lua;" .. package.path
local sound = require("SoundPlayer")

local TOCK = script_dir .. "..\\assets\\tock.wav"

console.log(string.format("[metronome] tock every %d frames", INTERVAL))

local frame = 0
while true do
    if frame % INTERVAL == 0 then
        sound.play(TOCK)
    end
    frame = frame + 1
    emu.frameadvance()
end
