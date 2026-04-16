# .bashrc
[ -f /etc/bashrc ] && source /etc/bashrc
# Only run in interactive shells
case $- in
  *i*) ;;
    *) return;;
esac

# --- Oh My Bash ---
export OSH="$HOME/.oh-my-bash"

OSH_THEME="wanelo"

# Keep this minimal
plugins=(
  git
)

# Optional — keep light
completions=(
  git
)

OMB_DEFAULT_ALIASES="check"
OMB_TERM_USE_TPUT=no

source "$OSH/oh-my-bash.sh"

[ -f ~/.bash_aliases ] && source ~/.bash_aliases

# Ensure sxhkd is running
if ! pgrep -x sxhkd >/dev/null; then
    nohup sxhkd >/dev/null 2>&1 &
fi
# User specific environment
if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]; then
    PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi
export PATH

# User specific aliases and functions
if [ -d ~/.bashrc.d ]; then
    for rc in ~/.bashrc.d/*; do
        if [ -f "$rc" ]; then
            . "$rc"
        fi
    done
fi
unset rc

export LESS_TERMCAP_mb=$'\E[1;31m'
export LESS_TERMCAP_md=$'\E[1;36m'
export LESS_TERMCAP_me=$'\E[0m'
export LESS_TERMCAP_se=$'\E[0m'
export LESS_TERMCAP_so=$'\E[1;44;33m'
export LESS_TERMCAP_ue=$'\E[0m'
export LESS_TERMCAP_us=$'\E[1;32m'

fastfetch
