# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
	. /etc/bashrc
fi

# User specific environment
if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]
then
    PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi
export PATH

# Uncomment the following line if you don't like systemctl's auto-paging feature:
# export SYSTEMD_PAGER=

# User specific aliases and functions
alias react-new-c='bash ~/.my_custom_commands/create_react_component.sh'
alias react-new-v='bash ~/.my_custom_commands/create_react_view.sh'
alias react-new-h='bash ~/.my_custom_commands/create_react_hook.sh'
alias w='nitrogen --set-zoom-fill --random ~/Pictures'
alias reload_bspwn='bash ~/.config/bspwm/bspwmrc'
[ -f ~/.fzf.bash ] && source ~/.fzf.bash
neofetch --w3m $HOME

