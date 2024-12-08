if type -q direnv
    direnv hook fish | source
end

if status is-interactive
    function dotfiles --wraps '/usr/bin/env git --git-dir=$HOME/.dotfiles --work-tree=$HOME'
        /usr/bin/env git --git-dir=$HOME/.dotfiles --work-tree=$HOME $argv
    end

    function mkcd
        mkdir -p $argv[1]; and cd $argv[1]
    end
end
