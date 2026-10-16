-- Result preview, like macOS's floating thumbnail. The capture is already
-- saved (and copied, per [shell.screenshot]); this panel offers what to do
-- next. Each action has a key; Enter or Esc just closes the preview.

local result = noctalia.state.get("result")

local render

local function basename(path)
  return string.match(path, "([^/]+)$") or path
end

local function dirname(path)
  return string.match(path, "^(.*)/[^/]*$") or "."
end

local function annotate()
  noctalia.runAsync({ "noctalia", "msg", "annotate", result.path })
  panel.close()
end

local function open()
  noctalia.runAsync({ "xdg-open", result.path })
  panel.close()
end

local function copy()
  noctalia.runAsync({ "sh", "-c", 'wl-copy --type image/png < "$1"', "sh", result.path }, function(res)
    if res.exitCode == 0 then
      noctalia.notify("Screenshot copied", basename(result.path))
    else
      noctalia.notifyError("Copy failed", noctalia.string.trim(res.stderr or ""))
    end
  end)
  panel.close()
end

local function showInFolder()
  -- FileManager1 selects the file in the file manager (Nautilus here);
  -- fall back to opening the folder.
  local uri = "file://" .. result.path
  noctalia.runAsync({
    "gdbus", "call", "--session",
    "--dest", "org.freedesktop.FileManager1",
    "--object-path", "/org/freedesktop/FileManager1",
    "--method", "org.freedesktop.FileManager1.ShowItems",
    "['" .. uri .. "']", "",
  }, function(res)
    if res.exitCode ~= 0 then
      noctalia.runAsync({ "xdg-open", dirname(result.path) })
    end
  end)
  panel.close()
end

local function delete()
  local ok, err = noctalia.removeFile(result.path)
  if ok then
    noctalia.notify("Screenshot deleted", basename(result.path))
  else
    noctalia.notifyError("Couldn't delete the screenshot", tostring(err))
  end
  panel.close()
end

local ACTIONS = {
  { key = "A", label = "Annotate", glyph = "pencil", run = annotate, variant = "primary" },
  { key = "O", label = "Open", glyph = "photo", run = open },
  { key = "C", label = "Copy", glyph = "copy", run = copy },
  { key = "F", label = "Folder", glyph = "folder", run = showInFolder },
  { key = "D", label = "Delete", glyph = "trash", run = delete, variant = "destructive" },
}

render = function()
  if result == nil or not noctalia.fileExists(result.path) then
    panel.render(ui.column({ align = "center", justify = "center", flexGrow = 1 }, {
      ui.label({ text = "No screenshot yet", color = "on_surface_variant" }),
    }))
    return
  end
  local buttons = {}
  for _, action in ipairs(ACTIONS) do
    table.insert(buttons, ui.button({
      key = action.label,
      text = action.label,
      glyph = action.glyph,
      tooltip = action.label .. " (" .. action.key .. ")",
      variant = action.variant or "default",
      controlSize = "sm",
      flexGrow = 1,
      onClick = function() action.run() end,
    }))
  end
  panel.render(ui.column({ gap = 12, padding = 4 }, {
    ui.image({
      key = result.path,
      path = result.path,
      fit = "contain",
      radius = 12,
      height = 340,
    }),
    ui.row({ align = "center", justify = "space_between" }, {
      ui.label({ text = basename(result.path), fontSize = 12, color = "on_surface_variant", maxLines = 1 }),
      ui.label({ text = "A annotate · O open · C copy · F folder · D delete", fontSize = 11, color = "on_surface_variant" }),
    }),
    ui.row({ gap = 8 }, buttons),
  }))
end

noctalia.state.watch("result", function(value)
  result = value
  render()
end)

function onOpen()
  result = noctalia.state.get("result")
  render()
end

local BY_KEY = { a = annotate, o = open, c = copy, f = showInFolder, d = delete, Delete = delete }

function onKey(chord, pressed)
  if not pressed or result == nil then
    return
  end
  local action = BY_KEY[chord]
  if action ~= nil then
    action()
  elseif chord == "Return" then
    panel.close()
  end
end
