if type -q direnv
    direnv hook fish | source
end

if status is-interactive
    function dotfiles --wraps '/usr/bin/env git --git-dir=$HOME/Dev/dotfiles/.git --work-tree=$HOME/Dev/dotfiles/'
        /usr/bin/env git --git-dir=$HOME/Dev/dotfiles/.git --work-tree=$HOME/Dev/dotfiles/ $argv
    end

    function mkcd
        mkdir -p $argv[1]; and cd $argv[1]
    end

    function nv
        nvim $argv
    end
end
