mkcd() {
	mkdir -p "${1}"
	cd "${1}"
}

s() {
	stow -d ~/dotfiles -t ~ -R .
	. ~/.bashrc
	pkill -USR1 sxhkd	
}
