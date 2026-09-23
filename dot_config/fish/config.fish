source /usr/share/cachyos-fish-config/cachyos-config.fish

# overwrite greeting
# potentially disabling fastfetch
#function fish_greeting
#    # smth smth
#end
if status is-interactive
    fish_config theme choose catppuccin-mocha

    set -Ux FZF_DEFAULT_OPTS "\
--color=bg+:#313244,bg:#1E1E2E,spinner:#F5E0DC,hl:#F38BA8 \
--color=fg:#CDD6F4,header:#F38BA8,info:#CBA6F7,pointer:#F5E0DC \
--color=marker:#B4BEFE,fg+:#CDD6F4,prompt:#CBA6F7,hl+:#F38BA8 \
--color=selected-bg:#45475A \
--color=border:#6C7086,label:#CDD6F4"

    starship init fish | source
    zoxide init fish --cmd cd | source
    fzf --fish | source
    atuin init fish --disable-up-arrow | source

    set -gx GPG_TTY (tty)
    gpgconf --launch gpg-agent
end


# Added by Antigravity CLI installer
set -gx PATH "/home/drolet/.local/bin" $PATH
