## ========================================
## =============== Settings ===============
## ========================================

# Save history
HISTFILE=~/.cache/zsh_history
HISTSIZE=10000
SAVEHIST=1000
setopt share_history
# Don't put commands that start with a space in history
setopt hist_ignore_space

# Use extended globbing
setopt extended_glob

# Enable completion
autoload -Uz compinit && compinit
# Use menu selection for completion
zstyle ':completion:*' menu select
# Completion colors
eval "$(dircolors)"
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

# Enable command correction
setopt correct

# Use bash-like word definition
# This makes things like backward-word and forward-word behave like in bash
# and treat path separators as word boundaries.
autoload -Uz select-word-style
select-word-style bash


## ========================================
## =============== Plugins ================
## ========================================

# Clone antidote if necessary.
if [[ ! -d ${ZDOTDIR:-$HOME}/.antidote ]]; then
  git clone https://github.com/mattmc3/antidote ${ZDOTDIR:-$HOME}/.antidote
fi

# Load antidote
source ${ZDOTDIR:-$HOME}/.antidote/antidote.zsh
antidote load

# Load Powerlevel10k prompt
# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Load direnv
if command -v direnv &> /dev/null; then
    eval "$(direnv hook zsh)"
fi

# Load fzf
if command -v fzf &> /dev/null; then
    source <(fzf --zsh)
fi


## ========================================
## ============= Key bindings =============
## ========================================

# Create a zkbd compatible hash.
typeset -g -A key

key[Home]="${terminfo[khome]}"
key[End]="${terminfo[kend]}"
key[Insert]="${terminfo[kich1]}"
key[Backspace]="${terminfo[kbs]}"
key[Delete]="${terminfo[kdch1]}"
key[Up]="${terminfo[kcuu1]}"
key[Down]="${terminfo[kcud1]}"
key[Left]="${terminfo[kcub1]}"
key[Right]="${terminfo[kcuf1]}"
key[PageUp]="${terminfo[kpp]}"
key[PageDown]="${terminfo[knp]}"
key[Shift-Tab]="${terminfo[kcbt]}"
key[Ctrl-Left]="${terminfo[kLFT5]}"
key[Ctrl-Right]="${terminfo[kRIT5]}"
key[Ctrl-Backspace]="^H"

# Setup key bindings accordingly.
[[ -n "${key[Home]}"           ]] && bindkey -- "${key[Home]}"           beginning-of-line
[[ -n "${key[End]}"            ]] && bindkey -- "${key[End]}"            end-of-line
[[ -n "${key[Insert]}"         ]] && bindkey -- "${key[Insert]}"         overwrite-mode
[[ -n "${key[Backspace]}"      ]] && bindkey -- "${key[Backspace]}"      backward-delete-char
[[ -n "${key[Delete]}"         ]] && bindkey -- "${key[Delete]}"         delete-char
[[ -n "${key[Up]}"             ]] && bindkey -- "${key[Up]}"             history-substring-search-up
[[ -n "${key[Down]}"           ]] && bindkey -- "${key[Down]}"           history-substring-search-down
[[ -n "${key[Left]}"           ]] && bindkey -- "${key[Left]}"           backward-char
[[ -n "${key[Right]}"          ]] && bindkey -- "${key[Right]}"          forward-char
[[ -n "${key[PageUp]}"         ]] && bindkey -- "${key[PageUp]}"         beginning-of-buffer-or-history
[[ -n "${key[PageDown]}"       ]] && bindkey -- "${key[PageDown]}"       end-of-buffer-or-history
[[ -n "${key[Shift-Tab]}"      ]] && bindkey -- "${key[Shift-Tab]}"      reverse-menu-complete
[[ -n "${key[Ctrl-Left]}"      ]] && bindkey -- "${key[Ctrl-Left]}"      backward-word
[[ -n "${key[Ctrl-Right]}"     ]] && bindkey -- "${key[Ctrl-Right]}"     forward-word
[[ -n "${key[Ctrl-Backspace]}" ]] && bindkey -- "${key[Ctrl-Backspace]}" backward-kill-word

# Finally, make sure the terminal is in application mode when zle is active.
# Only then are the values from $terminfo valid.
if (( ${+terminfo[smkx]} && ${+terminfo[rmkx]} )); then
    autoload -Uz add-zle-hook-widget
    function zle_application_mode_start { echoti smkx }
    function zle_application_mode_stop { echoti rmkx }
    add-zle-hook-widget -Uz zle-line-init zle_application_mode_start
    add-zle-hook-widget -Uz zle-line-finish zle_application_mode_stop
fi


## ========================================
## =============== Aliases ================
## ========================================

if command -v bat &> /dev/null; then
    alias cat='bat --style=plain'
fi

if command -v eza &> /dev/null; then
    alias ls='eza --icons=auto'
    alias ll='eza -l --icons=auto'
    alias la='eza -la --icons=auto'
    alias lt='eza -lT --icons=auto'
else
    alias ls='ls --color=auto'
    alias ll='ls -l --color=auto'
    alias la='ls -la --color=auto'
fi

alias lg='lazygit'
alias nv='nvim'

# Create a directory and cd into it
function mkcd {
    mkdir -p $1 && cd $1
}

# Launch application without output and without blocking the shell
function fork {
    nohup $@ &>/dev/null &
    disown
}
