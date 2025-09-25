local wezterm = require 'wezterm'

local M = {}

local function build_scheme()
    return {
        foreground = "#d4c4a9",
        background = "#2b2a27",
        cursor_bg = "#e0d6c2",
        cursor_fg = "#2b2a27",
        cursor_border = "#e0d6c2",
        selection_bg = "#3a382f",
        selection_fg = "#e6dccb",
        split = "#3a3832",
        scrollbar_thumb = "#3c3a34",

        ansi = {
            "#3a3732", -- black
            "#cc5d5d", -- red
            "#86b17e", -- green
            "#c7a368", -- yellow
            "#6fa3c8", -- blue
            "#a98db6", -- magenta
            "#79b1b0", -- cyan
            "#ddd4c7", -- white
        },
        brights = {
            "#4a4742",
            "#dd6c6c",
            "#97c28f",
            "#d7b478",
            "#7fb3d8",
            "#b99ec6",
            "#89c1c0",
            "#efe6d9",
        },

        tab_bar = {
            background = "#2f2e2b",
            active_tab = {
                bg_color = "#3b3a36",
                fg_color = "#e6dccb",
                intensity = "Bold",
            },
            inactive_tab = {
                bg_color = "#2f2e2b",
                fg_color = "#b9b1a2",
            },
            inactive_tab_hover = {
                bg_color = "#35342f",
                fg_color = "#e6dccb",
            },
            new_tab = {
                bg_color = "#2f2e2b",
                fg_color = "#b9b1a2",
            },
            new_tab_hover = {
                bg_color = "#3b3a36",
                fg_color = "#e6dccb",
            },
        },
    }
end

M.scheme = build_scheme()

function M.apply_to_config(config, opts)
    opts = opts or {}
    local scheme_name = opts.scheme_name or "GruvSoft"

    -- Register scheme and select it
    config.color_schemes = config.color_schemes or {}
    config.color_schemes[scheme_name] = M.scheme
    config.color_scheme = scheme_name

    -- Keep tabs at top and ensure a draggable native title bar
    config.tab_bar_at_bottom = false
    config.use_fancy_tab_bar = true
    config.hide_tab_bar_if_only_one_tab = false
    config.tab_max_width = opts.tab_max_width or 40
    config.window_decorations = opts.window_decorations or "TITLE | RESIZE"

    -- Gentle dimming for inactive panes; reduce bright “pop” for bolds
    config.inactive_pane_hsb = opts.inactive_pane_hsb or { saturation = 0.9, brightness = 0.8 }
    config.bold_brightens_ansi_colors = opts.bold_brightens_ansi_colors or "BrightOnly"

    -- Compact right-status: workspace · cwd · time · battery
    wezterm.on("update-status", function(window, pane)
        local cwd_uri = pane:get_current_working_dir()
        local cwd = ""
        if cwd_uri then
            if type(cwd_uri) == "userdata" then
                cwd = cwd_uri.file_path or ""
            else
                local s = tostring(cwd_uri)
                local slash = s:find("/")
                if slash then
                    cwd = s:sub(slash)
                end
            end
        end

        local cells = {}
        table.insert(cells, window:active_workspace())
        if cwd ~= "" then
            local name = cwd:gsub("[/\\]+$", "")
            local last = name:match("([^/\\]+)$") or name
            table.insert(cells, last)
        end
        table.insert(cells, wezterm.strftime("%a %b %-d %H:%M"))
        for _, b in ipairs(wezterm.battery_info()) do
            table.insert(cells, string.format("🔋 %d%%", math.floor(b.state_of_charge * 100)))
            break
        end

        local elements = {}
        local sep = utf8.char(0xe0b2) -- Powerline solid left arrow
        for i, cell in ipairs(cells) do
            table.insert(elements, { Foreground = { Color = M.scheme.tab_bar.active_tab.fg_color } })
            table.insert(elements, { Background = { Color = M.scheme.tab_bar.active_tab.bg_color } })
            table.insert(elements, { Text = " " .. cell .. " " })
            if i < #cells then
                table.insert(elements, { Foreground = { Color = M.scheme.tab_bar.background } })
                table.insert(elements, { Text = sep })
            end
        end
        window:set_right_status(wezterm.format(elements))
    end)

    -- Tab titles: index + pane title, highlighted when active
    wezterm.on("format-tab-title", function(tab, tabs, panes, c, hover, max_width)
        local title = tab.tab_title
        if not title or #title == 0 then
            title = tab.active_pane.title
        end

        if #title > max_width - 12 then
            title = string.sub(title, 1, max_width - 15) .. "..."
        end

        local idx = tostring(tab.tab_index + 1)
        local bg = tab.is_active and M.scheme.tab_bar.active_tab.bg_color or M.scheme.tab_bar.background
        local fg = tab.is_active and M.scheme.tab_bar.active_tab.fg_color or M.scheme.tab_bar.inactive_tab.fg_color
        return {
            { Background = { Color = bg } },
            { Foreground = { Color = fg } },
            { Text = "    " .. idx .. "    " .. title .. "    " }
        }
    end)

    -- Zen Mode: toggle minimal UI and a slightly larger font for focus
    local act = wezterm.action
    wezterm.on("toggle-zen-mode", function(window, pane)
        local overrides = window:get_config_overrides() or {}
        local zen_active = overrides.enable_tab_bar == false

        if zen_active then
            overrides.enable_tab_bar = nil
            overrides.window_decorations = nil
            overrides.font_size = nil
            overrides.window_background_opacity = nil
            overrides.macos_window_background_blur = nil
        else
            overrides.enable_tab_bar = false
            overrides.window_decorations = "RESIZE"
            overrides.font_size = (config.font_size or 12) + 2
            overrides.window_background_opacity = 0.92
            overrides.macos_window_background_blur = 12
        end

        window:set_config_overrides(overrides)
    end)

    -- Keybinding for Zen Mode (Ctrl+Shift+Z by default)
    config.keys = config.keys or {}
    table.insert(config.keys, {
        key = (opts.zen_key and opts.zen_key.key) or "Z",
        mods = (opts.zen_key and opts.zen_key.mods) or "CTRL|SHIFT",
        action = act.EmitEvent("toggle-zen-mode"),
    })

    return config
end

return M
