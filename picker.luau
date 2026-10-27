-- Mode picker: four tiles (Region, Window, Screen, All screens), chosen with
-- their letter or number key, the arrows/Tab and Enter, or a click. Choosing
-- closes the panel and hands the mode to the service. T cycles a timer that
-- delays the capture; the choice is remembered in the plugin's data folder.

local MODES = {
  { id = "region", label = "Region", glyph = "crop", key = "R", hint = "Drag an area" },
  { id = "window", label = "Window", glyph = "app-window", key = "W", hint = "Click a window" },
  { id = "screen", label = "Screen", glyph = "device-desktop", key = "S", hint = "Click a monitor" },
  { id = "all", label = "All screens", glyph = "devices", key = "A", hint = "Every monitor" },
}
local KEYS = {
  r = 1, w = 2, s = 3, a = 4,
  ["1"] = 1, ["2"] = 2, ["3"] = 3, ["4"] = 4,
}

local DELAYS = { 0, 3, 5, 10 }

local selected = 1
local requests = 0
local delay = 0

local render

local function delayFile()
  local dir = noctalia.pluginDataDir()
  return dir and (dir .. "/delay") or nil
end

local function loadDelay()
  local path = delayFile()
  local saved = path and tonumber(noctalia.readFile(path) or "") or nil
  delay = 0
  for _, d in ipairs(DELAYS) do
    if d == saved then
      delay = d
    end
  end
end

local function cycleDelay()
  local following = DELAYS[1]
  for i, d in ipairs(DELAYS) do
    if d == delay then
      following = DELAYS[i % #DELAYS + 1]
    end
  end
  delay = following
  local path = delayFile()
  if path then
    noctalia.writeFile(path, tostring(delay))
  end
  render()
end

local function choose(index)
  local mode = MODES[index]
  if mode == nil then
    return
  end
  panel.close()
  requests += 1
  noctalia.state.set("request", { mode = mode.id, delay = delay, n = requests })
end

local function tile(index, mode)
  local active = index == selected
  return ui.column({
    key = mode.id,
    width = 124,
    gap = 8,
    padding = 14,
    align = "center",
    radius = 14,
    fill = active and "primary/0.18" or "surface_variant/0.5",
    border = active and "primary" or "outline/0.4",
    borderWidth = active and 2 or 1,
    onClick = function() choose(index) end,
    onHover = function(state)
      if state == "true" and selected ~= index then
        selected = index
        render()
      end
    end,
  }, {
    ui.glyph({ name = mode.glyph, size = 30, color = active and "primary" or "on_surface" }),
    ui.label({ text = mode.label, fontSize = 14, fontWeight = "bold", textAlign = "center" }),
    ui.label({ text = mode.hint, fontSize = 11, color = "on_surface_variant", textAlign = "center" }),
    ui.row({ radius = 6, fill = "on_surface/0.08", paddingH = 8, paddingV = 2, align = "center" }, {
      ui.label({ text = mode.key, fontSize = 11, fontWeight = "bold", color = active and "primary" or "on_surface_variant" }),
    }),
  })
end

render = function()
  local tiles = {}
  for index, mode in ipairs(MODES) do
    table.insert(tiles, tile(index, mode))
  end
  panel.render(ui.column({ gap = 14, padding = 4 }, {
    ui.row({ align = "center", justify = "space_between" }, {
      ui.row({ gap = 8, align = "center" }, {
        ui.glyph({ name = "camera", size = 18, color = "primary" }),
        ui.label({ text = "Screenshot", fontSize = 15, fontWeight = "bold" }),
      }),
      ui.label({ text = "Enter to capture · Esc to cancel", fontSize = 11, color = "on_surface_variant" }),
    }),
    ui.row({ gap = 12, justify = "center" }, tiles),
    ui.row({ align = "center", justify = "center" }, {
      ui.row({
        gap = 8,
        align = "center",
        radius = 8,
        paddingH = 10,
        paddingV = 4,
        fill = delay > 0 and "primary/0.18" or "surface_variant/0.5",
        onClick = function() cycleDelay() end,
      }, {
        ui.glyph({ name = "stopwatch", size = 14, color = delay > 0 and "primary" or "on_surface_variant" }),
        ui.label({
          text = delay > 0 and ("Timer: " .. delay .. " s") or "Timer: off",
          fontSize = 12,
          color = delay > 0 and "primary" or "on_surface_variant",
        }),
        ui.row({ radius = 6, fill = "on_surface/0.08", paddingH = 6, paddingV = 1, align = "center" }, {
          ui.label({ text = "T", fontSize = 11, fontWeight = "bold", color = "on_surface_variant" }),
        }),
      }),
    }),
  }))
end

function onOpen()
  selected = 1
  loadDelay()
  render()
end

function onKey(chord, pressed)
  if not pressed then
    return
  end
  local direct = KEYS[chord]
  if direct ~= nil then
    choose(direct)
  elseif chord == "t" then
    cycleDelay()
  elseif chord == "Left" or chord == "shift+Tab" then
    selected = (selected - 2) % #MODES + 1
    render()
  elseif chord == "Right" or chord == "Tab" then
    selected = selected % #MODES + 1
    render()
  elseif chord == "Return" or chord == "space" then
    choose(selected)
  end
end
