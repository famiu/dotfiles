# config.nu
#
# Installed by:
# version = "0.104.0"
#
# This file is used to override default Nushell settings, define
# (or import) custom commands, or run any other startup tasks.
# See https://www.nushell.sh/book/configuration.html
#
# This file is loaded after env.nu and before login.nu
#
# You can open this file in your default editor using:
# config nu
#
# See `help config nu` for more options
#
# You can remove these comments if you want or leave
# them for future reference.

$env.path ++= ["~/.local/bin"]

$env.config.show_banner = false
$env.config.buffer_editor = "nvim"

$env.config.history = {
    file_format: sqlite
    max_size: 1_000_000
    sync_on_enter: true
    isolation: true
}

# Aliases
alias cat = bat --style=plain
alias ls = ls
alias ll = ls -l
alias la = ls -la
alias x = eza --icons auto
alias xa = eza --icons auto --all
alias xl = eza --long
alias xla = eza --long --all
alias xt = eza --icons auto --tree
alias xta = eza --icons auto --tree --all
alias lg = lazygit
alias nv = nvim

# Create directory and cd to it
def --env mkcd [folder: path] {
    mkdir $folder
    cd $folder
}

# Prepare vendor autoload directory to use for sourcing plugins
let vendor_autoload_dir = ($nu.data-dir | path join "vendor/autoload")
mkdir $vendor_autoload_dir

# Carapace completion
$env.CARAPACE_BRIDGES = 'zsh,fish,bash,inshellisense'
carapace _carapace nushell | save -f ($vendor_autoload_dir | path join carapace.nu)

# starship.rs prompt
starship init nu | save -f ($vendor_autoload_dir | path join starship.nu)
$env.TRANSIENT_PROMPT_COMMAND = ^starship module character
$env.TRANSIENT_PROMPT_COMMAND_RIGHT = ^starship module time
$env.TRANSIENT_PROMPT_INDICATOR = ""
$env.TRANSIENT_PROMPT_INDICATOR_VI_INSERT = ""
$env.TRANSIENT_PROMPT_INDICATOR_VI_NORMAL = ""
$env.TRANSIENT_PROMPT_MULTILINE_INDICATOR = ""

# direnv
$env.config.hooks.pre_prompt = $env.config.hooks.pre_prompt | append { ||
    if (which direnv | is-not-empty) {
        direnv export json | from json | default {} | load-env
        if 'ENV_CONVERSIONS' in $env and 'PATH' in $env.ENV_CONVERSIONS {
            $env.PATH = do $env.ENV_CONVERSIONS.PATH.from_string $env.PATH
        }
    }
}

# zoxide
zoxide init nushell | save -f ($vendor_autoload_dir | path join zoxide.nu)
