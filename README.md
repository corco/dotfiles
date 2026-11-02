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
