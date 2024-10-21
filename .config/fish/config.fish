if type -q direnv
    direnv hook fish | source
end

if status is-interactive
    function dotfiles --wraps '/usr/bin/env git --git-dir=$HOME/.dotfiles --work-tree=$HOME'
        /usr/bin/env git --git-dir=$HOME/.dotfiles --work-tree=$HOME $argv
    end
    function ollamakill
        ollama ps | tail -n+2 | awk '{print $1}' | xargs -r -n1 ollama stop
    end
end
