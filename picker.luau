-- Mode picker: four tiles (Region, Window, Screen, All screens), chosen with
-- their letter or number key, the arrows/Tab and Enter, or a click. Choosing
-- closes the panel and hands the mode to the service.

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

local selected = 1
local requests = 0

local render

local function choose(index)
  local mode = MODES[index]
  if mode == nil then
    return
  end
  panel.close()
  requests += 1
  noctalia.state.set("request", { mode = mode.id, n = requests })
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
  }))
end

function onOpen()
  selected = 1
  render()
end

function onKey(chord, pressed)
  if not pressed then
    return
  end
  local direct = KEYS[chord]
  if direct ~= nil then
    choose(direct)
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
