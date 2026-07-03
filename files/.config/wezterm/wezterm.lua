local wezterm = require("wezterm")

local config = wezterm.config_builder()

local is_windows = os.getenv("OS") and os.getenv("OS"):lower():find("windows")
local is_macos = wezterm.target_triple:lower():find("darwin") ~= nil

-- ui
config.color_scheme = "rose-pine-moon"
config.max_fps = 120
config.font = wezterm.font("Hack Nerd Font", { weight = "Regular" })

config.enable_tab_bar = true
config.hide_tab_bar_if_only_one_tab = true
config.window_decorations = "RESIZE"
config.window_frame = {
	font = wezterm.font("Hack Nerd Font", { weight = "Bold" }),
}
config.inactive_pane_hsb = {
	saturation = 0.0,
	brightness = 0.5,
}

-- 启动 login zsh，默认进入 home 目录
config.default_prog = { "/bin/zsh", "-l" }
config.default_cwd = wezterm.home_dir

-- 保留更多终端历史
config.scrollback_lines = 100000

-- 使用闪烁竖线光标
config.default_cursor_style = "BlinkingBar"
config.cursor_blink_rate = 500

-- 给窗口边缘留白
config.window_padding = {
	left = 8,
	right = 8,
	top = 8,
	bottom = 8,
}

-- 使用 WezTerm 全屏以保留透明和模糊效果
config.native_macos_fullscreen_mode = false

-- 简洁标签栏
config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = false

-- 识别可点击链接
config.hyperlink_rules = wezterm.default_hyperlink_rules()

-- 剪贴板、分屏和 pane 移动快捷键
config.keys = {
	{
		key = "c",
		mods = "CMD",
		action = wezterm.action.CopyTo("Clipboard"),
	},
	{
		key = "v",
		mods = "CMD",
		action = wezterm.action.PasteFrom("Clipboard"),
	},
	{
		key = "f",
		mods = "CTRL|CMD",
		action = wezterm.action.ToggleFullScreen,
	},
	{
		key = "|",
		mods = "CMD|SHIFT",
		action = wezterm.action.SplitHorizontal({ domain = "CurrentPaneDomain" }),
	},
	{
		key = "_",
		mods = "CMD|SHIFT",
		action = wezterm.action.SplitVertical({ domain = "CurrentPaneDomain" }),
	},
	{
		key = "h",
		mods = "CMD|SHIFT",
		action = wezterm.action.ActivatePaneDirection("Left"),
	},
	{
		key = "j",
		mods = "CMD|SHIFT",
		action = wezterm.action.ActivatePaneDirection("Down"),
	},
	{
		key = "k",
		mods = "CMD|SHIFT",
		action = wezterm.action.ActivatePaneDirection("Up"),
	},
	{
		key = "l",
		mods = "CMD|SHIFT",
		action = wezterm.action.ActivatePaneDirection("Right"),
	},
}

if is_windows then
	config.win32_system_backdrop = "Acrylic"
	config.window_background_opacity = 0.7
	config.window_frame.font_size = 10.0
end

if is_macos then
	config.window_background_opacity = 0.8
	config.macos_window_background_blur = 50
	config.font_size = 15.0
	config.window_frame.font_size = 13.0
end

return config
