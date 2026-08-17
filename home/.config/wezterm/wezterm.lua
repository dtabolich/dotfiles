local wezterm = require("wezterm")

local config = wezterm.config_builder()

config.color_scheme = "rose-pine-moon"
-- Home Manager installs WezTerm nerd-fonts here; point WezTerm at it so a
-- cold start after a switch doesn't miss the family before CoreText indexes it.
config.font_dirs = { wezterm.home_dir .. "/Library/Fonts/HomeManager" }
config.font = wezterm.font("FiraMono Nerd Font")
config.font_size = 15.0
config.harfbuzz_features = { "calt=0", "liga=0", "dlig=0" }
config.window_background_opacity = 0.8
config.macos_window_background_blur = 50
config.hide_tab_bar_if_only_one_tab = true
config.window_decorations = "RESIZE"
-- Native fullscreen: WezTerm gets its own macOS Space with menu bar + dock
-- hidden. Other desktops keep the normal menu bar/dock. Non-native mode
-- (false) only maximizes in place and leaves you on the current Space.
config.native_macos_fullscreen_mode = true

-- New windows / unresolved panes start here. Explicit --cwd and OSC-7
-- pane cwd still win when present (see default_cwd docs).
local DEFAULT_CWD = wezterm.home_dir .. "/Projects"
config.default_cwd = DEFAULT_CWD

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

-- Candidate fonts for live evaluation (all Nerd Font builds via home.nix).
-- Cycle with Alt+Shift+F / Alt+Shift+B. Toast shows the family name.
local CANDIDATE_FONTS = {
	"FiraMono Nerd Font",
	"FiraCode Nerd Font",
	"Hack Nerd Font",
	"JetBrainsMono Nerd Font",
	"CaskaydiaCove Nerd Font", -- Cascadia Code
	"GeistMono Nerd Font",
	"CommitMono Nerd Font",
	-- Nerd Fonts shortens Monaspace names (PostScript 31-char limit).
	"MonaspiceNe Nerd Font", -- Monaspace Neon
	"MonaspiceAr Nerd Font", -- Monaspace Argon
	"IosevkaTerm Nerd Font",
	"BlexMono Nerd Font", -- IBM Plex Mono
	"IntoneMono Nerd Font", -- Intel One Mono
	"VictorMono Nerd Font",
	"ZedMono Nerd Font",
	"MartianMono Nerd Font",
	"SauceCodePro Nerd Font", -- Source Code Pro
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

-- Dock/Finder often pass a SpawnCommand with no cwd; gui-startup then bypasses
-- default_cwd unless we put Projects on the spawn table ourselves.
local function spawn_command_for(cmd)
	local spawn = { cwd = DEFAULT_CWD }
	if cmd == nil then
		return spawn
	end
	if cmd.cwd ~= nil and cmd.cwd ~= "" then
		spawn.cwd = cmd.cwd
	end
	if cmd.args ~= nil then
		spawn.args = cmd.args
	end
	if cmd.domain ~= nil then
		spawn.domain = cmd.domain
	end
	if cmd.set_environment_variables ~= nil then
		spawn.set_environment_variables = cmd.set_environment_variables
	end
	if cmd.workspace ~= nil then
		spawn.workspace = cmd.workspace
	end
	return spawn
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
	-- Sanitized paste: Cmd+Shift+V pipes the clipboard through ~/.local/bin/
	-- sanitize-paste (strips markdown fences, prompt chars, curly quotes,
	-- trailing whitespace, dedents) and types the result. The real clipboard
	-- is left untouched, and Cmd+V stays a raw bracketed paste. Falls back to
	-- a normal paste if the sanitizer isn't installed or the clipboard is empty.
	{
		key = "V",
		mods = "CMD|SHIFT",
		action = wezterm.action_callback(function(window, pane)
			local ok, out = pcall(wezterm.run_child_process, {
				wezterm.home_dir .. "/.local/bin/sanitize-paste",
			})
			if ok and out and #out > 0 then
				pane:send_text(out)
			else
				window:perform_action(wezterm.action.PasteFrom("Clipboard"), pane)
			end
		end),
	},
	-- New windows should not inherit whatever pane cwd you were last in.
	{
		key = "n",
		mods = "CMD",
		action = wezterm.action.SpawnCommandInNewWindow({ cwd = DEFAULT_CWD }),
	},
	{
		key = "t",
		mods = "CMD",
		action = wezterm.action.SpawnCommandInNewTab({ cwd = DEFAULT_CWD }),
	},
}

wezterm.on("gui-startup", function(cmd)
	local _, pane, window = wezterm.mux.spawn_window(spawn_command_for(cmd))
	local gui_win = window:gui_window()
	-- Defer so the window exists before macOS native fullscreen assigns a Space.
	-- ToggleFullScreen action (not :toggle_fullscreen()) honors native mode.
	wezterm.time.call_after(0.3, function()
		gui_win:perform_action(wezterm.action.ToggleFullScreen, pane)
	end)
end)

-- Pretty path for Mission Control / Spaces labels (and the (hidden) title bar).
-- Prefer ~/… over /Users/…, keep a process suffix for non-shells, and
-- middle-ellipsis truncate when the path would dominate the Space strip.
local SHELL_PROCESSES = {
	zsh = true,
	bash = true,
	fish = true,
	sh = true,
	nu = true,
	login = true,
}

local function pretty_cwd(pane)
	local cwd_uri = pane.current_working_dir
	if not cwd_uri then
		return nil
	end
	local path = cwd_uri.file_path
	if not path or path == "" then
		return nil
	end
	path = path:gsub("/+$", "")
	if path == "" then
		path = "/"
	end
	local home = wezterm.home_dir
	if path == home then
		return "~"
	end
	if path:sub(1, #home + 1) == home .. "/" then
		return "~" .. path:sub(#home + 1)
	end
	return path
end

local function truncate_middle(s, max_len)
	if #s <= max_len then
		return s
	end
	local keep = max_len - 1
	local head = math.floor(keep * 0.4)
	local tail = keep - head
	return s:sub(1, head) .. "…" .. s:sub(#s - tail + 1)
end

local function process_basename(pane)
	local name = pane.foreground_process_name
	if not name or name == "" then
		return nil
	end
	return name:match("([^/]+)$") or name
end

wezterm.on("format-window-title", function(tab, pane, tabs, _, _)
	local zoomed = ""
	if tab.active_pane.is_zoomed then
		zoomed = "[Z] "
	end

	local index = ""
	if #tabs > 1 then
		index = string.format("[%d/%d] ", tab.tab_index + 1, #tabs)
	end

	local cwd = pretty_cwd(pane)
	local proc = process_basename(pane)
	local title
	if cwd then
		title = truncate_middle(cwd, 72)
		if proc and not SHELL_PROCESSES[proc] then
			title = title .. " · " .. proc
		end
	else
		title = tab.active_pane.title
	end

	return zoomed .. index .. title
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
