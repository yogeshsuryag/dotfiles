local wezterm = require("wezterm")

local config = wezterm.config_builder()

config.color_scheme = "rose-pine-moon"
config.font = wezterm.font("Hack Nerd Font")
config.font_size = 15.0
config.window_background_opacity = 0.8
config.hide_tab_bar_if_only_one_tab = true
config.window_decorations = "RESIZE"

-- Dim unfocused windows so the focused one is obvious at a glance.
local UNFOCUSED_FOREGROUND_TEXT_HSB = { hue = 1.0, saturation = 0.25, brightness = 0.45 }
local UNFOCUSED_WINDOW_BACKGROUND_OPACITY = 0.62

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
					file:close()
					return value
				end
			end
			file:close()
		end
	end
	return os.getenv(name)
end

local function find_msys2_shell()
	local candidates = {}
	local scoop_root = os.getenv("SCOOP")
	local user_profile = os.getenv("USERPROFILE") or wezterm.home_dir
	append_unique(candidates, join_path(scoop_root, "apps\\msys2\\current\\msys2_shell.cmd"))
	append_unique(candidates, join_path(join_path(user_profile, "scoop"), "apps\\msys2\\current\\msys2_shell.cmd"))

	for _, path in ipairs(candidates) do
		local file = io.open(path, "r")
		if file ~= nil then
			file:close()
			return path
		end
	end
	return nil
end

if read_config_value("DOTFILES_INSTALL_ZSH") == "1" then
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
