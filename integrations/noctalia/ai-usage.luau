-- Bar label for Claude/Grok usage. The Python script is the same one Waybar
-- ran; left-click opens its existing GTK popup (Claude and Grok tabs).
local PYTHON = "/usr/bin/python3"
local HOME = os.getenv("HOME") or ""
local SCRIPT = HOME .. "/.config/waybar/scripts/ai-usage.py"
local POPUP = HOME .. "/.config/waybar/scripts/ai-usage-popup.py"

local generation = 0

local function refresh()
  generation = generation + 1
  local ticket = generation
  -- Log scan plus the Claude limits call can take a while when the cache is cold.
  local accepted = noctalia.runAsync({ PYTHON, SCRIPT }, function(result)
    if ticket ~= generation then
      return
    end
    if result.timedOut or result.exitCode ~= 0 then
      noctalia.log("ai-usage: exit " .. tostring(result.exitCode) .. " " .. tostring(result.stderr))
      return
    end
    local data, err = noctalia.json.decode(result.stdout)
    if type(data) ~= "table" or type(data.text) ~= "string" then
      noctalia.log("ai-usage json: " .. tostring(err))
      return
    end
    barWidget.setText(data.text)
  end, 60000)
  if not accepted then
    noctalia.log("ai-usage: could not start python")
  end
end

barWidget.setText("AI")
noctalia.setUpdateInterval(600000)
refresh()

function update()
  refresh()
end

function onClick()
  noctalia.runAsync({ PYTHON, POPUP })
end
