# History substring search on up/down
ble-bind -f up   'history-search-backward'
ble-bind -f down 'history-search-forward'

# Transient prompt — replace previous prompt with starship's character symbol
bleopt prompt_ps1_transient=trim:same-dir
bleopt prompt_ps1_final='$(starship module character)'

# Enable history share
bleopt history_share=1

# Ctrl+Backspace / Ctrl+Delete delete a word (Ghostty sends Ctrl+Backspace as C-h)
ble-bind -f C-BS     'delete-backward-cword'
ble-bind -f C-DEL    'delete-backward-cword'
ble-bind -f C-h      'delete-backward-cword'
ble-bind -f C-delete 'delete-forward-cword'
