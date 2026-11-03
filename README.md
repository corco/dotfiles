# dotfiles

Managed with [chezmoi](https://www.chezmoi.io/): `chezmoi init --apply git@github.com:corco/dotfiles.git`.

The sections below cover setup chezmoi doesn't do: binaries, vendor installs, system state, and client configuration that lives outside tracked files.

## AMD Vivado / Ross agentic AI assistant

chezmoi provides:

- `~/.config/environment.d/13-xilinx.conf`: adds `~/xilinx/2026.1/{Vivado,Vitis}/bin` to the end of `PATH`
- `~/.config/systemd/user/vivado-mcp-server.service`, and the link in `default.target.wants/` that enables it at login

Everything below has to be done by hand, in order.

### 1. Vivado / Vitis 2026.1

Install to `~/xilinx/2026.1` (the path used by `13-xilinx.conf` and the service unit). The license server comes from `11-work.conf`. Log out and back in afterwards so `environment.d` changes take effect.

### 2. Vivado MCP server binary

Download `vivado-mcp-server-linux-amd64-<version>` from the [AMD Ross download page](https://www.amd.com/en/support/downloads/ross-agentic-ai.html), then:

```sh
mkdir -p ~/.local/lib/vivado-mcp-server
mv vivado-mcp-server-linux-amd64-<version> ~/.local/lib/vivado-mcp-server/
chmod +x ~/.local/lib/vivado-mcp-server/vivado-mcp-server-linux-amd64-<version>
ln -sfn ~/.local/lib/vivado-mcp-server/vivado-mcp-server-linux-amd64-<version> ~/.local/bin/vivado-mcp-server

systemctl --user daemon-reload
systemctl --user restart vivado-mcp-server   # already enabled by the chezmoi-managed link
loginctl enable-linger "$USER"               # start at boot, not only at login
```

To upgrade, move the new binary into place, point the symlink at it, and restart the service. Keep the version the same as the skills plugin (step 4).

### 3. Local doc search (`amd-embedded-doc-search`, needs Docker)

Get the knowledge-base package (the qwen3-embedding variant) from AMD and extract it to `~/xilinx/amd-embedded-doc-search`. Then:

```sh
cd ~/xilinx/amd-embedded-doc-search
./amd-embedded-doc-search configure --mcp-port 8080 --no-start
```

`configure` writes to `~/.config/amd-embedded-doc-search-$USER/`. Two fixes are needed afterwards, and again after every re-run of `configure`:

- Restrict the MCP port to this machine. In `docker-compose.yaml`, change `- ${DOCSEARCH_MCP_PORT}:8080` to `- 127.0.0.1:${DOCSEARCH_MCP_PORT}:8080`.
- Start the stack detached. `amd-embedded-doc-search start` runs `docker compose up` attached, and closing that terminal stops the stack. Use this instead:

  ```sh
  docker compose -f ~/.config/amd-embedded-doc-search-$USER/docker-compose.yaml up -d
  ```

The first start imports the snapshot, which takes about 5–10 minutes. The containers use `restart: always`, so they come back at boot as long as `docker.service` is enabled. Never switch embedding models without running `amd-embedded-doc-search purge --yes` first.

### 4. Claude Code: MCP servers and skills plugin

Claude Code keeps these in `~/.claude.json` and `~/.claude/plugins/`, which aren't tracked here.

```sh
claude mcp add --transport http --scope user vivado http://127.0.0.1:18090/mcp
claude mcp add --transport http --scope user amd-embedded-doc-search http://127.0.0.1:8080/mcp/doc-search

git clone https://github.com/Xilinx/ross-ai-assistant ~/xilinx/ross-ai-assistant
claude plugin marketplace add ~/xilinx/ross-ai-assistant
claude plugin install amd-ross-agentic-ai-assistant@amd-ross-agentic-ai-assistant
```

To update the plugin, run `git -C ~/xilinx/ross-ai-assistant pull`, then uninstall and reinstall it. Claude Code runs a cached copy, so pulling alone changes nothing. Don't also install the skills with `npx skills add`, or every skill loads twice.

### Verify

```sh
systemctl --user is-active vivado-mcp-server
claude mcp list   # vivado and amd-embedded-doc-search should both show "Connected"
command -v vitis-run
```

Hardware debug connects to a remote `hw_server` (`connect_hw_server -url TCP:<host>:3121`), so no local JTAG cable drivers or udev rules are needed. The remote `hw_server` version must match the local Vivado version.

## Desktops: sway, Hyprland, COSMIC (i3-style keys)

niri stays the default. Each desktop below installs next to it; pick one on the login screen. All three use the old Manjaro i3 keys, so your hands don't change when you switch.

chezmoi always writes all of these configs, installed or not. Unused ones do nothing.

| File | Used by |
|---|---|
| `~/.config/sway/config` | sway |
| `~/.config/uwsm/env-sway` | sway (sets `DISPLAY` for xwayland-satellite) |
| `~/.config/hypr/hyprland.lua` | Hyprland 0.57+ (Lua only; `hyprland.conf` is no longer read) |
| `~/.config/cosmic/com.system76.CosmicSettings.Shortcuts/v1/custom` | COSMIC keyboard shortcuts |
| `~/.config/cosmic/com.system76.CosmicComp/v1/*` | COSMIC tiling on, workspaces per monitor, keyboard layouts |
| `~/.config/environment.d/20-java.conf` | all (Java apps like Vivado need it) |
| `~/.local/bin/screenshot` | sway and Hyprland |

### Keys (Mod = Super)

| Keys | Action | Differences |
|---|---|---|
| `Mod+Return` / `Mod+d` | terminal / launcher | |
| `Mod+F2` / `Mod+F3` | Firefox / Thunar | |
| `Mod+j k l ;` or arrows | focus left / down / up / right | |
| `Mod+Shift+j k l ;` or arrows | move window | |
| `Mod+Shift+q` | close window | |
| `Mod+h` / `Mod+v` | split horizontal / vertical | Hyprland: picks where the next window opens. COSMIC: sets the orientation |
| `Mod+q` / `Mod+e` | toggle split direction | |
| `Mod+w` / `Mod+s` | tabbed / stacked | only sway has stacked; elsewhere both keys toggle tabs |
| `Mod+f` | fullscreen | |
| `Mod+Shift+space` / `Mod+space` | float / focus floating vs tiled | `Mod+space` is sway only |
| `Mod+Shift+s` | sticky | |
| `Mod+a` | focus parent | not in Hyprland |
| `Mod+Shift+minus` / `Mod+minus` | to scratchpad / show scratchpad | not in COSMIC |
| `Mod+1..8` | go to workspace | |
| `Mod+Ctrl+1..8` / `Mod+Shift+1..8` | send window / send window and follow | |
| `Mod+b` / `Mod+Shift+b` | previous workspace / send window there | |
| `Mod+Ctrl+Left/Right` | previous / next workspace | |
| `Mod+Ctrl+Shift+arrows` | **move the whole workspace to another monitor** | new, not in Manjaro |
| `Mod+r` | resize mode (`j k l ;` or arrows, Esc to leave) | COSMIC: `Mod+r` grows, `Mod+Shift+r` shrinks |
| `Print` / `Mod+Print` / `Mod+Shift+Print` | screenshot screen / window / area | COSMIC: `Print` opens its screenshot tool |
| `Mod+9` / `Mod+0` | lock / power menu | |
| `Mod+Shift+e` / `Mod+Shift+c` | exit / reload config | COSMIC reloads by itself, so `Mod+Shift+c` isn't bound |

Dropped from Manjaro: menus and apps that don't exist anymore (`morc_menu`, `bmenu`, compton, `Mod+m` bar toggle, gaps mode).

### Common tools (sway and Hyprland)

```sh
sudo pacman -S --needed uwsm grim slurp jq wl-clipboard libnotify wl-mirror brightnessctl playerctl
```

### sway

Install:

```sh
sudo pacman -S --needed sway xwayland-satellite xdg-desktop-portal-wlr xdg-desktop-portal-gtk
sudo tee /usr/share/wayland-sessions/sway-uwsm.desktop >/dev/null <<'END'
[Desktop Entry]
Name=Sway (uwsm-managed)
Exec=uwsm start -e -D sway sway.desktop
TryExec=uwsm
DesktopNames=sway
Type=Application
END
```

On the login screen, pick **Sway (uwsm-managed)**, not plain "Sway". The uwsm session loads `environment.d` (Xilinx `PATH`, licence server) and `~/.config/uwsm/env-sway`.

- X11 apps go through xwayland-satellite on `:0` (sway's own XWayland is turned off). To check, run `echo $DISPLAY` in a terminal; it should print `:0`.
- 1Password can't be hidden from screen sharing on sway (niri's `block-out-from`).

Uninstall:

```sh
sudo rm /usr/share/wayland-sessions/sway-uwsm.desktop
sudo pacman -Rns sway xdg-desktop-portal-wlr   # keep xwayland-satellite and uwsm, niri uses them
rm -r ~/.config/sway ~/.config/uwsm/env-sway
```

To stop chezmoi from putting the config back, delete `dot_config/sway` and `dot_config/uwsm/env-sway` from this repo.

### Hyprland

Install:

```sh
sudo pacman -S --needed hyprland xdg-desktop-portal-hyprland
hyprctl version   # must be 0.57 or later: the config is Lua
```

On the login screen, pick **Hyprland (uwsm-managed)** (the package installs it).

- X11 apps use Hyprland's own XWayland with `force_zero_scaling`, which is how Vivado was fine there before.
- Tabs are Hyprland groups. `Mod+j` / `Mod+;` move through the tabs before moving to the next window.
- No hy3 plugin: plugins break on every Hyprland update.
- An old `~/.config/hypr/hyprland.conf` from before is ignored by 0.57. Delete it to avoid confusion.

Uninstall:

```sh
sudo pacman -Rns hyprland xdg-desktop-portal-hyprland
rm -r ~/.config/hypr
```

To stop chezmoi from putting the config back, delete `dot_config/hypr` from this repo.

### COSMIC

Install:

```sh
sudo pacman -S --needed cosmic   # the whole desktop: panel, launcher, settings, apps
```

If this also installs `cosmic-greeter` (COSMIC's login screen), don't enable it. Your current login screen will list **COSMIC**.

- COSMIC has its own panel, so Noctalia isn't used.
- Set monitor layout and scale in Settings > Displays. COSMIC stores them itself, not in this repo.
- X11 apps (Vivado) are drawn at native resolution by default, like niri. If Vivado looks wrong, try Settings > Displays first.
- COSMIC doesn't go through uwsm. In a COSMIC terminal, check that `echo $PATH` has the Xilinx paths and that `echo $_JAVA_AWT_WM_NONREPARENTING` prints `1`.
- Changing shortcuts in COSMIC Settings rewrites the shortcuts file. `chezmoi diff` will show it; use `chezmoi re-add` to keep the change.

Uninstall:

```sh
pacman -Qgq cosmic | sudo pacman -Rns -
rm -rf ~/.config/cosmic ~/.local/state/cosmic*
```

To stop chezmoi from putting the config back, delete `dot_config/cosmic` from this repo.
