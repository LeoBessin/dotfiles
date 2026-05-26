-- Visual appearance and compositor settings

local border_active   = { colors = { "rgba(eb6f92ee)", "rgba(c4a7e7ee)" }, angle = 45 }
local border_inactive = "rgba(47495caa)"

hl.config({
    general = {
        gaps_in     = 3,
        gaps_out    = 3,
        border_size = 2,
        col = {
            active_border   = border_active,
            inactive_border = border_inactive,
        },
        resize_on_border = false,
        allow_tearing    = false,
        layout           = "dwindle",
    },

    decoration = {
        rounding       = 10,
        rounding_power = 2,
        active_opacity   = 1.0,
        inactive_opacity = 1.0,
        fullscreen_opacity = 1.0,

        shadow = {
            enabled      = false,
            range        = 4,
            render_power = 3,
            color        = 0xee1a1a1a,
        },

        blur = {
            enabled  = true,
            size     = 6,
            passes   = 3,
            xray     = false,
            vibrancy = 0.17,
        },
    },

    animations = {
        enabled = true,
    },

    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
        focus_on_activate       = true,
    },

    dwindle = {
        preserve_split   = true,
        smart_split      = false,
    },

    master = {
        new_status = "master",
    },

    ecosystem = {
        no_update_news = true,
    },
})

-- Workflow presets (uncomment one block to activate)
--
-- Gaming: disable all visual effects
-- hl.config({ general = { gaps_in = 0, gaps_out = 0, border_size = 1 }, decoration = { rounding = 0, shadow = { enabled = false }, blur = { enabled = false } }, animations = { enabled = false } })
--
-- Powersaver: minimal visuals
-- hl.config({ general = { gaps_in = 0, gaps_out = 0, border_size = 1 }, decoration = { rounding = 0, shadow = { enabled = false }, blur = { enabled = false } }, animations = { enabled = false } })
--
-- Snappy: no rounding, no gaps
-- hl.config({ general = { gaps_in = 0, gaps_out = 0, border_size = 1 }, decoration = { rounding = 0 } })
