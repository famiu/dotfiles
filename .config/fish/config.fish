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

    function update_nvim
        echo "Updating Neovim..."

        set pwd (pwd)
        set tmpdir (mktemp -d); or return 1
        echo "Using temporary directory $tmpdir"

        function cleanup -a tmpdir -a pwd
            cd $pwd; or return 1
            sudo rm -rf $tmpdir; or return 1
            trap - SIGINT SIGTERM SIGQUIT; or return 1
        end

        function handle_abort -a tmpdir -a pwd
            echo "Aborted. Cleaning up..."
            cleanup $tmpdir $pwd; or return 1
        end

        sudo -v; or return 1
        cd $tmpdir; or return 1

        trap "handle_abort $tmpdir $pwd" SIGINT SIGTERM SIGQUIT

        git clone https://github.com/neovim/neovim --depth 1; or handle_abort $tmpdir $pwd
        cd neovim; or handle_abort $tmpdir $pwd
        make CMAKE_BUILD_TYPE=RelWithDebInfo; or handle_abort $tmpdir $pwd
        sudo make install; or handle_abort $tmpdir $pwd

        echo "Installation complete"
        cleanup $tmpdir $pwd
    end
end
