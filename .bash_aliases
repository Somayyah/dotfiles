mkcd() {
	mkdir -p "${1}"
	cd "${1}"
}

s() {
	clear
	stow -d ~/dotfiles -t ~ -R .
	. ~/.bashrc
	pkill -USR1 sxhkd	
}

alias glow="glow -p"

kkeys() {
cat << 'EOF'

┌──────────────────────────────────────────────┐
│ ctrl + t              → New Tab              │
│ ctrl + w              → Close Tab            │
│ alt + 1–9             → Switch to Tab        │
│ ctrl + shift + alt+t  → Rename Tab           │
│ ctrl + shift + pgup   → Move Tab Backward    │
│ ctrl + shift + pgdn   → Move Tab Forward     │
└──────────────────────────────────────────────┘

EOF
}
