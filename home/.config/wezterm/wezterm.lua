local wezterm = require("wezterm")

local config = wezterm.config_builder()

config.color_scheme = "rose-pine-moon"
-- Home Manager installs nerd-fonts.hack here; point WezTerm at it so a
-- cold start after a switch doesn't miss the family before CoreText indexes it.
config.font_dirs = { wezterm.home_dir .. "/Library/Fonts/HomeManager" }
config.font = wezterm.font("Hack Nerd Font")
config.font_size = 15.0
config.window_background_opacity = 0.8
config.macos_window_background_blur = 50
config.hide_tab_bar_if_only_one_tab = true
config.window_decorations = "RESIZE"

-- Candidate color schemes for live evaluation. Names verified against the
-- builtin catalog bundled in this WezTerm build. Cycling sets a runtime
-- config override only, so a restart reverts to config.color_scheme above;
-- once a favorite is chosen, hardcode it in config.color_scheme.
local CANDIDATE_SCHEMES = {
	"rose-pine-moon",
	"rose-pine",
	"rose-pine-dawn",
	"Kanagawa (Gogh)",
	"Kanagawa Dragon (Gogh)",
	"kanagawabones",
	"Tokyo Night Storm",
	"Tokyo Night",
	"Catppuccin Mocha",
	"Catppuccin Macchiato",
	"Gruvbox Material (Gogh)",
	"Everforest Dark Hard (Gogh)",
	"Nord (Gogh)",
}

-- Candidate fonts for live evaluation. Only the Nerd Font entries carry
-- Nerd Font glyphs; the others will render nvim icons (Snacks picker, lualine,
-- etc.) as missing-glyph boxes, which is expected when comparing the letterforms.
local CANDIDATE_FONTS = {
	"Hack Nerd Font",
	"JetBrainsMono Nerd Font",
	"JetBrains Mono",
	"Menlo",
	"Monaco",
	"Andale Mono",
}
local current_font_idx = 1

local function cycle_color_scheme(window, offset)
	local overrides = window:get_config_overrides() or {}
	local current = overrides.color_scheme or config.color_scheme
	local idx = 1
	for i, s in ipairs(CANDIDATE_SCHEMES) do
		if s == current then
			idx = i
			break
		end
	end
	local next_scheme = CANDIDATE_SCHEMES[((idx - 1 + offset) % #CANDIDATE_SCHEMES) + 1]
	overrides.color_scheme = next_scheme
	window:set_config_overrides(overrides)
	window:toast_notification("wezterm", next_scheme, 4000)
end

local function cycle_font(window, offset)
	current_font_idx = ((current_font_idx - 1 + offset) % #CANDIDATE_FONTS) + 1
	local name = CANDIDATE_FONTS[current_font_idx]
	local overrides = window:get_config_overrides() or {}
	overrides.font = wezterm.font(name)
	window:set_config_overrides(overrides)
	window:toast_notification("wezterm", "font: " .. name, 4000)
end

config.keys = {
	{ key = "T", mods = "ALT|SHIFT", action = wezterm.action_callback(function(window, _)
		cycle_color_scheme(window, 1)
	end) },
	{ key = "R", mods = "ALT|SHIFT", action = wezterm.action_callback(function(window, _)
		cycle_color_scheme(window, -1)
	end) },
	{ key = "F", mods = "ALT|SHIFT", action = wezterm.action_callback(function(window, _)
		cycle_font(window, 1)
	end) },
	{ key = "B", mods = "ALT|SHIFT", action = wezterm.action_callback(function(window, _)
		cycle_font(window, -1)
	end) },
}

wezterm.on("gui-startup", function(cmd)
	local _, _, window = wezterm.mux.spawn_window(cmd or {})
	-- Non-native fullscreen: skips the slow macOS Space animation and
	-- keeps the window on the current Space. See :toggle_fullscreen docs.
	window:gui_window():toggle_fullscreen()
end)

-- Dim unfocused windows so the focused one is obvious at a glance.
local UNFOCUSED_FOREGROUND_TEXT_HSB = { hue = 1.0, saturation = 0.25, brightness = 0.45 }
local UNFOCUSED_WINDOW_BACKGROUND_OPACITY = 0.62

-- get_config_overrides() hands back a copy, so the current value is never the
-- same table we last stored; compare the fields instead of the identity.
local function same_text_hsb(actual, expected)
	if actual == nil or expected == nil then
		return actual == expected
	end
	return actual.hue == expected.hue
		and actual.saturation == expected.saturation
		and actual.brightness == expected.brightness
end

wezterm.on("window-focus-changed", function(window)
	local overrides = window:get_config_overrides() or {}
	local text_hsb, opacity
	if not window:is_focused() then
		text_hsb = UNFOCUSED_FOREGROUND_TEXT_HSB
		opacity = UNFOCUSED_WINDOW_BACKGROUND_OPACITY
	end

	-- Only write when one of the two values we own actually changes; a redundant
	-- set_config_overrides() call would trigger another config reload.
	if same_text_hsb(overrides.foreground_text_hsb, text_hsb) and overrides.window_background_opacity == opacity then
		return
	end

	overrides.foreground_text_hsb = text_hsb
	overrides.window_background_opacity = opacity
	window:set_config_overrides(overrides)
end)

return config
