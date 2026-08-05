local wezterm = require("wezterm")

local config = wezterm.config_builder()
local IS_WINDOWS = wezterm.target_triple:find("windows") ~= nil
local IS_MACOS = wezterm.target_triple:find("darwin") ~= nil

-- The setup UI persists one of the two built-in themes below. Tokyo Night
-- Storm remains the fallback when the config file is missing or invalid.
local DEFAULT_WEZTERM_THEME = "Tokyo Night Storm"
config.color_scheme = DEFAULT_WEZTERM_THEME
config.font = wezterm.font("Hack Nerd Font")
config.font_size = 15.0
config.scrollback_lines = 10000

-- Windows uses Acrylic for real blur. The opacity must be below 1.0 or the
-- system backdrop is not visible. macOS keeps its native blur equivalent.
config.window_background_opacity = 0.82
config.window_padding = { left = 18, right = 18, top = 14, bottom = 14 }
config.window_decorations = "INTEGRATED_BUTTONS|RESIZE"

if IS_WINDOWS then
	config.win32_system_backdrop = "Acrylic"
	config.win32_acrylic_accent_color = "#1a1b26"
elseif IS_MACOS then
	config.macos_window_background_blur = 50
end

-- Keep the tab bar visible so workspaces and the active pane always have a
-- clear visual home, while avoiding the stock high-contrast tab treatment.
config.enable_tab_bar = true
config.hide_tab_bar_if_only_one_tab = false
config.use_fancy_tab_bar = false
config.show_new_tab_button_in_tab_bar = false
config.tab_max_width = 32

-- Native easing makes the cursor and visual bell feel deliberate instead of
-- flashing. animation_fps controls the smoothness of those transitions.
config.animation_fps = 60
config.default_cursor_style = "BlinkingBar"
config.cursor_thickness = 2
config.cursor_blink_rate = 720
config.cursor_blink_ease_in = "EaseInOut"
config.cursor_blink_ease_out = "EaseInOut"
config.visual_bell = {
	target = "CursorColor",
	fade_in_function = "EaseIn",
	fade_in_duration_ms = 90,
	fade_out_function = "EaseOut",
	fade_out_duration_ms = 180,
}
config.audible_bell = "Disabled"
config.status_update_interval = 1000

local function native_path(value)
	if value == nil or value == "" then
		return nil
	end

	local drive, rest = value:match("^/([A-Za-z])/(.*)$")
	if drive == nil then
		drive = value:match("^/([A-Za-z])$")
		rest = ""
	end
	if drive ~= nil then
		rest = rest:gsub("/", "\\")
		if rest == "" then
			return drive:upper() .. ":\\"
		end
		return drive:upper() .. ":\\" .. rest
	end
	return value:gsub("/", "\\")
end

local function join_path(base, child)
	if base == nil or base == "" then
		return nil
	end
	local normalized_base = native_path(base)
	while normalized_base:sub(-1) == "\\" or normalized_base:sub(-1) == "/" do
		normalized_base = normalized_base:sub(1, -2)
	end
	return normalized_base .. "\\" .. child
end

local function append_unique(paths, value)
	if value == nil or value == "" then
		return
	end
	for _, existing in ipairs(paths) do
		if existing == value then
			return
		end
	end
	table.insert(paths, value)
end

local function read_config_value(name)
	local config_paths = {}
	local config_file = os.getenv("DOTFILES_CONFIG_FILE")
	local dotfiles_root = os.getenv("DOTFILES_ROOT")
	local dotfiles_link = os.getenv("DOTFILES_DOTFILES_LINK")
	append_unique(config_paths, native_path(config_file))
	append_unique(config_paths, join_path(dotfiles_root, "windows-config.env"))
	append_unique(config_paths, join_path(dotfiles_link, "windows-config.env"))
	append_unique(config_paths, join_path(join_path(wezterm.home_dir, ".dotfiles"), "windows-config.env"))

	for _, path in ipairs(config_paths) do
		local file = io.open(path, "r")
		if file ~= nil then
			for line in file:lines() do
				local value = line:match("^%s*" .. name .. "%s*=%s*(.-)%s*$")
				if value ~= nil then
					value = value:match('^"(.*)"$') or value:match("^'(.*)'$") or value
					value = value:gsub("\\\\ ", " ")
					file:close()
					return value
				end
			end
			file:close()
		end
	end
	return os.getenv(name)
end

local configured_theme = read_config_value("DOTFILES_WEZTERM_THEME")
if configured_theme == "Tokyo Night Storm" or configured_theme == "rose-pine-moon" then
	config.color_scheme = configured_theme
end

local THEME_PALETTES = {
	["Tokyo Night Storm"] = {
		titlebar_bg = "#16161e",
		titlebar_fg = "#c0caf5",
		inactive_titlebar_fg = "#565f89",
		cursor_bg = "#c0caf5",
		cursor_fg = "#1a1b26",
		selection_bg = "#33467c",
		selection_fg = "#c0caf5",
		split = "#3b4261",
		visual_bell = "#bb9af7",
		tab_background = "#16161e",
		inactive_tab_bg = "#24283b",
		inactive_tab_fg = "#737aa2",
		hover_bg = "#2d3f76",
		hover_fg = "#c0caf5",
		accent = "#7aa2f7",
		accent_fg = "#1a1b26",
		status_accent = "#bb9af7",
		status_info = "#7dcfff",
		status_muted = "#565f89",
	},
	["rose-pine-moon"] = {
		titlebar_bg = "#232136",
		titlebar_fg = "#e0def4",
		inactive_titlebar_fg = "#6e6a86",
		cursor_bg = "#e0def4",
		cursor_fg = "#232136",
		selection_bg = "#44415a",
		selection_fg = "#e0def4",
		split = "#44415a",
		visual_bell = "#c4a7e7",
		tab_background = "#232136",
		inactive_tab_bg = "#2a273f",
		inactive_tab_fg = "#908caa",
		hover_bg = "#393552",
		hover_fg = "#e0def4",
		accent = "#c4a7e7",
		accent_fg = "#232136",
		status_accent = "#eb6f92",
		status_info = "#9ccfd8",
		status_muted = "#6e6a86",
	},
}

local palette = THEME_PALETTES[config.color_scheme] or THEME_PALETTES[DEFAULT_WEZTERM_THEME]
config.window_frame = {
	active_titlebar_bg = palette.titlebar_bg,
	inactive_titlebar_bg = palette.titlebar_bg,
	active_titlebar_fg = palette.titlebar_fg,
	inactive_titlebar_fg = palette.inactive_titlebar_fg,
}
config.colors = {
	cursor_bg = palette.cursor_bg,
	cursor_fg = palette.cursor_fg,
	cursor_border = palette.cursor_bg,
	selection_bg = palette.selection_bg,
	selection_fg = palette.selection_fg,
	split = palette.split,
	visual_bell = palette.visual_bell,
	tab_bar = {
		background = palette.tab_background,
		inactive_tab = { bg_color = palette.inactive_tab_bg, fg_color = palette.inactive_tab_fg },
		inactive_tab_hover = { bg_color = palette.hover_bg, fg_color = palette.hover_fg },
		new_tab = { bg_color = palette.tab_background, fg_color = palette.accent },
		new_tab_hover = { bg_color = palette.hover_bg, fg_color = palette.hover_fg },
	},
}

local function file_exists(path)
	local file = io.open(path, "r")
	if file == nil then
		return false
	end
	file:close()
	return true
end

local function find_msys2_shell()
	local roots = {}
	local scoop_root = os.getenv("SCOOP")
	local user_profile = os.getenv("USERPROFILE") or wezterm.home_dir
	append_unique(roots, join_path(scoop_root, "apps\\msys2\\current"))
	append_unique(roots, join_path(join_path(user_profile, "scoop"), "apps\\msys2\\current"))

	for _, root in ipairs(roots) do
		local shell = join_path(root, "msys2_shell.cmd")
		local zsh = join_path(root, "usr\\bin\\zsh.exe")
		if file_exists(shell) and file_exists(zsh) then
			return shell
		end
	end
	return nil
end

-- Prefer the managed MSYS2 zsh whenever it is installed. The setup defaults
-- install it, and checking the executable avoids launching a broken wrapper
-- when a user has MSYS2 but has not installed its zsh package yet.
if IS_WINDOWS and read_config_value("DOTFILES_INSTALL_ZSH") ~= "0" then
	local msys2_shell = find_msys2_shell()
	if msys2_shell ~= nil then
		config.default_prog = {
			"cmd.exe",
			"/d",
			"/c",
			msys2_shell,
			"-defterm",
			"-here",
			"-no-start",
			"-msys",
			"-shell",
			"zsh",
		}
	end
end

local SOLID_LEFT_ARROW = wezterm.nerdfonts.pl_right_hard_divider
local SOLID_RIGHT_ARROW = wezterm.nerdfonts.pl_left_hard_divider

local function tab_edge(background, foreground, text)
	return wezterm.format({
		{ Background = { Color = background } },
		{ Foreground = { Color = foreground } },
		{ Text = text },
	})
end

config.tab_bar_style = {
	active_tab_left = tab_edge(palette.tab_background, palette.accent, SOLID_LEFT_ARROW),
	active_tab_right = tab_edge(palette.accent, palette.tab_background, SOLID_RIGHT_ARROW),
	inactive_tab_left = tab_edge(palette.tab_background, palette.inactive_tab_bg, SOLID_LEFT_ARROW),
	inactive_tab_right = tab_edge(palette.inactive_tab_bg, palette.tab_background, SOLID_RIGHT_ARROW),
	inactive_tab_hover_left = tab_edge(palette.tab_background, palette.hover_bg, SOLID_LEFT_ARROW),
	inactive_tab_hover_right = tab_edge(palette.hover_bg, palette.tab_background, SOLID_RIGHT_ARROW),
}

local function tab_title(tab_info)
	local title = tab_info.tab_title
	if title == nil or title == "" then
		title = tab_info.active_pane.title
	end
	return title or "shell"
end

wezterm.on("format-tab-title", function(tab, tabs, panes, pane_config, hover, max_width)
	local title = tab_title(tab)
	if max_width ~= nil and max_width > 8 then
		title = wezterm.truncate_right(title, max_width - 8)
	end

	local background = palette.inactive_tab_bg
	local foreground = palette.inactive_tab_fg
	if tab.is_active then
		background = palette.accent
		foreground = palette.accent_fg
	elseif hover then
		background = palette.hover_bg
		foreground = palette.hover_fg
	end

	return {
		{ Background = { Color = background } },
		{ Foreground = { Color = foreground } },
		{ Text = " " .. tostring(tab.tab_index + 1) .. " " .. title .. " " },
	}
end)

-- A slow, low-distraction pulse gives the status bar life without a timer
-- loop or constant config reloads. The built-in cursor easing supplies the
-- genuinely smooth animation at the frame rate above.
local PULSE_FRAMES = { ".", "o", "O", "0", "O", "o" }

local function pulse_frame()
	local seconds = tonumber(wezterm.time.now():format("%S")) or 0
	return PULSE_FRAMES[(seconds % #PULSE_FRAMES) + 1]
end

wezterm.on("update-status", function(window, pane)
	local workspace = window:active_workspace() or "default"
	local process = pane:get_foreground_process_name() or "zsh"
	local process_name = process:match("[^\\/]+$") or process
	process_name = process_name:gsub("%.exe$", "")

	window:set_left_status(wezterm.format({
		{ Background = { Color = palette.tab_background } },
		{ Foreground = { Color = palette.status_accent } },
		{ Text = "  " .. pulse_frame() .. "  " },
		{ Foreground = { Color = palette.titlebar_fg } },
		{ Text = workspace .. " " },
	}))

	window:set_right_status(wezterm.format({
		{ Foreground = { Color = palette.status_info } },
		{ Text = " " .. process_name },
		{ Foreground = { Color = palette.status_muted } },
		{ Text = "  " .. wezterm.strftime("%H:%M") .. " " },
	}))
end)

-- Dim unfocused windows so the focused one is obvious at a glance.
local UNFOCUSED_FOREGROUND_TEXT_HSB = { hue = 1.0, saturation = 0.2, brightness = 0.58 }
local UNFOCUSED_WINDOW_BACKGROUND_OPACITY = 0.62

-- get_config_overrides() hands back a copy, so compare fields instead of
-- relying on table identity when deciding whether a reload is necessary.
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

	if same_text_hsb(overrides.foreground_text_hsb, text_hsb) and overrides.window_background_opacity == opacity then
		return
	end

	overrides.foreground_text_hsb = text_hsb
	overrides.window_background_opacity = opacity
	window:set_config_overrides(overrides)
end)

return config
