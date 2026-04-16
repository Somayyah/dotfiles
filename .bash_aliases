mkcd() {
	mkdir -p "${1}"
	cd "${1}"
}

s() {
	. ~/.bashrc
	pkill -USR1 sxhkd	
}
