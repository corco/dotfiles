-- Hyprland config: Manjaro i3 (2020) keybindings, plus Noctalia.
-- Hyprland 0.57+ only reads Lua (hyprland.conf is no longer supported).
-- Reference: https://wiki.hypr.land/configuring/
--
-- Keys follow the old Manjaro i3 defaults:
--   focus j k l ; (left down up right), splits on h / v, tabs on w,
--   SUPER+SHIFT+Q kills, SUPER+0 is the power menu, SUPER+9 locks.
-- Differences from i3 (Hyprland has no i3 tree):
--   * "split h/v" picks where the NEXT window opens (dwindle preselect).
--   * Tabs are Hyprland "groups"; there is no stacked layout, so SUPER+S
--     also toggles tabs. Focus left/right walks through the tabs first.
--   * The scratchpad is the special workspace "scratchpad".

local mod      = "SUPER"
local terminal = "ghostty"
local noctalia = "qs -c noctalia-shell ipc call "

-- Manjaro i3 movement keys
local keys = { left = "J", down = "K", up = "L", right = "semicolon" }

local function bind(k, action, opts) hl.bind(mod .. " + " .. k, action, opts) end
local function run(cmd) return hl.dsp.exec_cmd(cmd) end

------------------
---- MONITORS ----
------------------
-- Positions are in scaled pixels; same layout as niri.

hl.monitor({ output = "eDP-1", mode = "1920x1200@60", position = "0x0", scale = "1" })
hl.monitor({ output = "desc:ASUSTek COMPUTER INC ASUS PA279 0x00038786", mode = "3840x2160@60", position = "1920x0", scale = "1.5" })
hl.monitor({ output = "desc:Acer Technologies XV275K P5 251100E414HA1", mode = "3840x2160@60", position = "4480x0", scale = "1.5" })
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function()
    hl.exec_cmd("uwsm app -- qs -c noctalia-shell")
end)

hl.env("XCURSOR_THEME", "catppuccin-mocha-mauve-cursors")
hl.env("XCURSOR_SIZE", "24")

-------------------
---- SETTINGS -----
-------------------

hl.config({
    general = {
        layout      = "dwindle",
        gaps_in     = 3,
        gaps_out    = 5,
        border_size = 2,
        col = {
            active_border   = "rgb(7fc8ff)",
            inactive_border = "rgb(505050)",
        },
    },

    dwindle = {
        preserve_split = true, -- splits stay the way you set them, like i3
    },

    animations = { enabled = false },

    misc = {
        disable_hyprland_logo   = true,
        force_default_wallpaper = 0,
    },

    binds = {
        workspace_back_and_forth     = 1,    -- like i3's workspace_auto_back_and_forth
        allow_workspace_cycles       = true,
        movefocus_cycles_groupfirst  = true, -- focus left/right walks through tabs
    },

    -- X11 apps (Vivado) are drawn unscaled instead of blurry at 1.5,
    -- the same result as xwayland-satellite on niri.
    xwayland = { force_zero_scaling = true },

    input = {
        kb_layout          = "us,ca",
        kb_variant         = ",multix",
        kb_options         = "grp:caps_toggle,grp_led:caps",
        numlock_by_default = true,
        follow_mouse       = 1,
        touchpad = {
            natural_scroll = true,
        },
    },
})

---------------------
---- KEYBINDINGS ----
---------------------

-- Apps
bind("Return",       run(terminal))
bind("D",            run(noctalia .. "launcher toggle"))
bind("F2",           run("firefox"))
bind("F3",           run("thunar"))
bind("P",            run([[wl-mirror $(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')]]))

-- Screenshots (Manjaro: Print = screen, SUPER+Print = window, SUPER+SHIFT+Print = area)
hl.bind("Print",     run("~/.local/bin/screenshot screen"))
bind("Print",        run("~/.local/bin/screenshot window"))
bind("SHIFT + Print", run("~/.local/bin/screenshot area"))

-- Windows
bind("SHIFT + Q",    hl.dsp.window.close())

for dir, key in pairs(keys) do
    bind(key,                  hl.dsp.focus({ direction = dir }))
    bind("SHIFT + " .. key,    hl.dsp.window.move({ direction = dir }))
end
for _, dir in ipairs({ "left", "down", "up", "right" }) do
    bind(dir,                  hl.dsp.focus({ direction = dir }))
    bind("SHIFT + " .. dir,    hl.dsp.window.move({ direction = dir }))
end

bind("H",            hl.dsp.layout("preselect r")) -- split h: next window opens to the right
bind("V",            hl.dsp.layout("preselect d")) -- split v: next window opens below
bind("Q",            hl.dsp.layout("togglesplit"))
bind("E",            hl.dsp.layout("togglesplit"))

bind("F",            hl.dsp.window.fullscreen())
bind("W",            hl.dsp.group.toggle())        -- tabbed
bind("S",            hl.dsp.group.toggle())        -- no stacked layout in Hyprland

bind("SHIFT + space", hl.dsp.window.float({ action = "toggle" }))
bind("SHIFT + S",    hl.dsp.window.pin())          -- sticky

bind("SHIFT + minus", hl.dsp.window.move({ workspace = "special:scratchpad", follow = false }))
bind("minus",        hl.dsp.workspace.toggle_special("scratchpad"))

bind("mouse:272",    hl.dsp.window.drag(),   { mouse = true })
bind("mouse:273",    hl.dsp.window.resize(), { mouse = true })

-- Workspaces: SUPER+N go to, SUPER+CTRL+N send window, SUPER+SHIFT+N send window and follow
for i = 1, 8 do
    bind(tostring(i),              hl.dsp.focus({ workspace = i }))
    bind("CTRL + " .. i,           hl.dsp.window.move({ workspace = i, follow = false }))
    bind("SHIFT + " .. i,          hl.dsp.window.move({ workspace = i }))
end

bind("B",            hl.dsp.focus({ workspace = "previous" }))
bind("SHIFT + B",    hl.dsp.window.move({ workspace = "previous" }))
bind("CTRL + right", hl.dsp.focus({ workspace = "m+1" }))
bind("CTRL + left",  hl.dsp.focus({ workspace = "m-1" }))

-- Move the whole workspace to another monitor (not in Manjaro; added for you)
bind("CTRL + SHIFT + left",  hl.dsp.workspace.move({ monitor = "l" }))
bind("CTRL + SHIFT + right", hl.dsp.workspace.move({ monitor = "r" }))
bind("CTRL + SHIFT + up",    hl.dsp.workspace.move({ monitor = "u" }))
bind("CTRL + SHIFT + down",  hl.dsp.workspace.move({ monitor = "d" }))

-- Session
bind("9",            run(noctalia .. "lockScreen lock"))
bind("0",            run(noctalia .. "sessionMenu toggle"))
bind("SHIFT + E",    run(noctalia .. "sessionMenu toggle"))
bind("SHIFT + C",    hl.dsp.reload_config())

-- Resize mode, like i3: SUPER+R, then j k l ; or arrows, Return/Escape to leave
bind("R",            hl.dsp.submap("resize"))
hl.define_submap("resize", function()
    local step = {
        [keys.left]  = { -40, 0 }, [keys.right] = { 40, 0 },
        [keys.up]    = { 0, -40 }, [keys.down]  = { 0, 40 },
        left  = { -80, 0 }, right = { 80, 0 },
        up    = { 0, -80 }, down  = { 0, 80 },
    }
    for key, xy in pairs(step) do
        hl.bind(key, hl.dsp.window.resize({ x = xy[1], y = xy[2], relative = true }), { repeating = true })
    end
    hl.bind("Return", hl.dsp.submap("reset"))
    hl.bind("Escape", hl.dsp.submap("reset"))
end)

-- Media keys (work on the lock screen too)
local media = {
    XF86AudioRaiseVolume  = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1+ -l 1.0",
    XF86AudioLowerVolume  = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1-",
    XF86AudioMute         = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle",
    XF86AudioMicMute      = "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle",
    XF86AudioPlay         = "playerctl play-pause",
    XF86AudioStop         = "playerctl stop",
    XF86AudioPrev         = "playerctl previous",
    XF86AudioNext         = "playerctl next",
    XF86MonBrightnessUp   = "brightnessctl --class=backlight set +10%",
    XF86MonBrightnessDown = "brightnessctl --class=backlight set 10%-",
}
for key, cmd in pairs(media) do
    hl.bind(key, run(cmd), { locked = true, repeating = true })
end

----------------------
---- WINDOW RULES ----
----------------------

hl.window_rule({ name = "firefox-pip", match = { class = "firefox$", title = "^Picture-in-Picture$" }, float = true })
hl.window_rule({ name = "1password",   match = { class = "^1password$" }, float = true, no_screen_share = true })
hl.window_rule({ name = "vivado-ip",   match = { class = "Vivado$", title = "Customizing IP" }, float = true })
