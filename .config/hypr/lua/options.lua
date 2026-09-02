-- Visual appearance and compositor settings

-- Outlines follow the quickshell bar — ~/.config/quickshell/bar/modules/Theme.qml.
-- Every window carries the bar's own 1px resting outline, focused or not:
-- Qt.rgba(0.70, 0.62, 0.86, 0.25), i.e. Theme.accent at 25%. Focus adds weight
-- rather than changing colour. Replaced the Rosé Pine love→iris gradient
-- (eb6f92 → c4a7e7 over 47495c).
--
-- Mirrored for niri in ~/.config/niri/layout.kdl, but only approximately. niri
-- expresses the focused state as a 2px focus ring outside the border, in the same
-- flat 25% as the border itself. Hyprland has no focus ring and `border_size`
-- cannot vary by focus state, so the extra weight comes from the shadow below
-- instead: the same accent tint, transparent when unfocused. Same idea — extra
-- weight on the focused window, no colour change — different mechanism. The
-- shadow does fade by nature, which niri's flat ring does not; that is the one
-- place the two sessions genuinely differ.
local border_active   = "rgba(b39ddb40)"
local border_inactive = "rgba(b39ddb40)"

hl.config({
    general = {
        gaps_in     = 3,
        gaps_out    = 3,
        border_size = 1,   -- bar outline is 1px
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

        -- Stands in for niri's focus ring: a centred accent halo on the focused
        -- window only, roughly the same weight and fade as the 2px ring.
        -- offset 0 0 keeps it a halo rather than a drop shadow.
        shadow = {
            enabled        = true,
            range          = 3,
            render_power   = 2,
            offset         = { 0, 0 },
            color          = "rgba(b39ddb40)",   -- same 25% as border and ring
            color_inactive = "rgba(b39ddb00)",   -- unfocused: nothing but the 1px border
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
