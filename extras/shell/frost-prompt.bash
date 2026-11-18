# Frost / Obsidian Glass prompt for bash: your prompt, recoloured.
#   ● user  ~/path (branch)  [:LOCAL]  vaults
#   ❯❯❯
# Same pieces and logic as the prompt in ~/.bashrc, in the Frost colours:
# soft white text, Frost red (#F21D43) for git and the chevrons, a green or red
# dot for the last command's result. Sourced at the end of ~/.bashrc; remove
# that line to go back to the old colours.
[[ $- == *i* ]] || return 0
case "$TERM" in xterm-color|*-256color|xterm-kitty|alacritty|foot*|wezterm) ;; *) return 0 ;; esac

_frost_rgb() { printf '\e[38;2;%d;%d;%dm' "$1" "$2" "$3"; }
_FROST_RED=$(_frost_rgb 242 29 67)
_FROST_TEXT=$(_frost_rgb 236 236 241)
_FROST_PATH=$(_frost_rgb 201 201 209)
_FROST_MUTED=$(_frost_rgb 98 98 110)
_FROST_OK=$(_frost_rgb 74 222 128)
_FROST_GOLD=$(_frost_rgb 250 204 21)

# user colour by where you are (root, SSH, Docker, VM, or here)
_GET_ENV_COLOR() {
    if [[ $EUID -eq 0 ]]; then printf '\e[1m%s' "$_FROST_RED"
    elif [ -n "$SSH_CONNECTION" ] || [ -n "$SSH_CLIENT" ]; then _frost_rgb 96 165 250
    elif [ -f /.dockerenv ]; then _frost_rgb 56 189 248
    elif grep -qi "VirtualBox\|VMware\|KVM\|Hyper-V\|QEMU" /sys/class/dmi/id/sys_vendor 2>/dev/null; then _frost_rgb 251 146 60
    else printf '\e[1m%s' "$_FROST_TEXT"
    fi
}

# vault / phone mounts, in gold (only if your .bashrc defines the check)
# (colour codes wrapped in \001 \002 so readline knows they take no space)
_frost_vaults() { declare -F _VAULT_INDICATOR >/dev/null && _VAULT_INDICATOR | sed -e "s/\x1b\[1;33m/\x01$_FROST_GOLD\x02/g" -e "s/\x1b\[0m/\x01\x1b[0m\x02/g"; }
_frost_env() { declare -F _DETECT_ENVIRONMENT >/dev/null && printf ' [%s]' "$(_DETECT_ENVIRONMENT)"; }
_frost_git() { declare -F __git_ps1 >/dev/null && __git_ps1 " (%s)"; }

PS1='$(EXIT=$?; [ $EXIT -eq 0 ] && printf "\[%s\]● " "$_FROST_OK" || printf "\[%s\]● " "$_FROST_RED")'
PS1+='\[$(_GET_ENV_COLOR)\]\u\[\e[0m\] \[$_FROST_PATH\]\w\[$_FROST_RED\]$(_frost_git)\[\e[0m\]\[$_FROST_MUTED\]$(_frost_env)\[\e[0m\]$(_frost_vaults)\[\e[0m\]\n'
PS1+='\[\e[38;2;90;16;32m\]❯\[\e[38;2;163;23;47m\]❯\[$_FROST_RED\]❯\[\e[0m\] '
