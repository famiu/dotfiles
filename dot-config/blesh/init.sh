# History substring search on up/down
ble-bind -f up   'history-search-backward'
ble-bind -f down 'history-search-forward'

# Transient prompt — replace previous prompt with starship's character symbol
bleopt prompt_ps1_transient=trim:same-dir
bleopt prompt_ps1_final='$(starship module character)'
