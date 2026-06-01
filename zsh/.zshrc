# `.zshrc' is sourced in interactive shells.
# It should contain commands to set up aliases, functions, options, key bindings, etc.

# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH


# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="robbyrussell"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder


############################
# Ghostty
# https://github.com/ghostty-org/ghostty/blob/main/src/shell-integration/README.md
############################

# https://ghostty.org/docs/features/shell-integration#manual-shell-integration-setup

if [[ -n $GHOSTTY_RESOURCES_DIR ]]; then
  source "$GHOSTTY_RESOURCES_DIR"/shell-integration/zsh/ghostty-integration
fi


############################
# Plugins
############################

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
# Browser Standard Plugins on GitHub: https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins
#
# NOTE: do NOT add the "ssh-agent" plugin. SSH keys are served by the Bitwarden
# desktop SSH agent (SSH_AUTH_SOCK is set in .zshenv to its socket). The
# ssh-agent plugin starts its own empty agent and overwrites SSH_AUTH_SOCK,
# which makes ssh fall back to the on-disk .pub files and fail with
# "Permission denied (publickey)". Leave SSH to Bitwarden.
plugins=(
    "fzf"
    "z"
    "git"
    "zsh-autosuggestions"
    "zsh-syntax-highlighting"
    "colored-man-pages"
    "docker"
    "docker-compose"
    "mvn"
    "node"
    "npm"
    "tmux"
)

source $ZSH/oh-my-zsh.sh

############################
# Compilation flags
############################

# export ARCHFLAGS="-arch x86_64"

############################
# Aliases
############################

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

alias c="clear"
alias t="tmux -2"
alias tmux="tmux -2"
alias f="fzf"
alias e="nvim"
alias nvimdiff='nvim -d'
alias vim="nvim"
alias vi="nvim"
alias oldvim="vim"
############################
# GPG (interactive signing / pinentry)
############################

# Tell gpg-agent which terminal to prompt on. Lives here, not .zshenv, because
# $(tty) assumes an attached terminal and .zshenv must stay tty-free.
export GPG_TTY=$(tty)

############################
# Key Bindings Completion
############################

# Ctrl + Space for zsh auto-completion
bindkey '^ ' autosuggest-accept
# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# uv (Astral) completions
if command -v uv >/dev/null; then
  eval "$(uv generate-shell-completion zsh)"
  eval "$(uvx --generate-shell-completion zsh)"
fi
