set -g fish_greeting ""

if status is-interactive
    # Dotfiles bare repo
    alias dotfiles='git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'
end

# PATH
fish_add_path ~/.local/bin
fish_add_path ~/.opencode/bin
