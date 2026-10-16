-- Runs captures for the picker and opens the preview with the result. It's a
-- service so a capture outlives the picker panel, which closes first to keep
-- out of the shot.
--
-- State channel:
--   "request"  set by the picker: { mode = "region"|"window"|"screen"|"all", n }
--   "result"   set here:          { path = "/abs/file.png", n }

local SCRIPT = noctalia.pluginDir() .. "/capture.sh"
local PREVIEW = "filedesless/snap:preview"
-- Interactive captures wait on the user, so give them plenty of time.
local CAPTURE_TIMEOUT_MS = 10 * 60 * 1000

local busy = false
local results = 0

local function setting(path)
  local value = noctalia.getSetting(path)
  return type(value) == "string" and value or ""
end

local function capture(mode)
  if busy then
    return
  end
  busy = true
  local argv = {
    SCRIPT,
    mode,
    setting("shell.screenshot.directory"),
    setting("shell.screenshot.filename_pattern"),
  }
  noctalia.runAsync(argv, function(res)
    busy = false
    if res.exitCode == 10 then
      return -- cancelled
    end
    local path = noctalia.string.trim(res.stdout or "")
    if res.exitCode ~= 0 or path == "" then
      local why = noctalia.string.trim(res.stderr or "")
      if why == "" then
        why = "capture.sh exited with " .. tostring(res.exitCode)
      end
      noctalia.notifyError("Screenshot failed", why)
      return
    end
    results += 1
    noctalia.state.set("result", { path = path, n = results })
    noctalia.runAsync({ "noctalia", "msg", "panel-open", PREVIEW })
  end, CAPTURE_TIMEOUT_MS)
end

noctalia.state.watch("request", function(req)
  if type(req) == "table" and type(req.mode) == "string" then
    capture(req.mode)
  end
end)

-- `noctalia msg plugin filedesless/snap:service all capture <mode>` skips the
-- picker, for a direct keybind.
function onIpc(event, payload)
  if event == "capture" and payload ~= nil and payload ~= "" then
    capture(payload)
  end
end
