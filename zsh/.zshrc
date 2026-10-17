# `.zshrc' is sourced in interactive shells.
# It should contain commands to set up aliases, functions, options, key bindings, etc.

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

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
    "git"
    "zsh-autosuggestions"
    "zsh-syntax-highlighting"
    "colored-man-pages"
    "docker"
    "docker-compose"
    "mvn"
    "nvm"
    "node"
    "npm"
    "extract"      # `extract <archive>` unpacks zip, tar.*, 7z, ...
    "copypath"     # `copypath [path]` copies a path to the clipboard
    "copybuffer"   # Ctrl-O copies the command line being typed
)
[[ "$OSTYPE" == darwin* ]] && plugins+=("macos")   # `cdf`: cd to the front Finder window
(( $+commands[gh] )) && plugins+=("gh")             # gh completions, only where gh is installed

# Load nvm on first use of nvm/node/npm (saves ~600ms per shell). Node's bin is
# already on PATH via .zshenv. Must be set before oh-my-zsh is sourced.
zstyle ':omz:plugins:nvm' lazy yes

# Skip oh-my-zsh's per-start compaudit (~15ms): it only flags completion dirs that
# other users can write to, which doesn't apply on a single-user machine.
ZSH_DISABLE_COMPFIX=true

# uv/uvx/bun completions load on first <Tab> from this fpath dir instead of being
# sourced every start. _uv/_uvx are regenerated when the uv binary changes.
_zcomp="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/completions"
if (( $+commands[uv] )) && [[ ! -s "$_zcomp/_uv" || "$_zcomp/_uv" -ot "$commands[uv]" ]]; then
  mkdir -p "$_zcomp"
  uv generate-shell-completion zsh >| "$_zcomp/_uv"
  uvx --generate-shell-completion zsh >| "$_zcomp/_uvx"
fi
[[ -s "$HOME/.bun/_bun" && ! -e "$_zcomp/_bun" ]] && mkdir -p "$_zcomp" && ln -s "$HOME/.bun/_bun" "$_zcomp/_bun"
fpath=("$_zcomp" $fpath)
unset _zcomp

source $ZSH/oh-my-zsh.sh

############################
# History
############################

# Set after sourcing oh-my-zsh so these override its smaller defaults.
HISTSIZE=100000
SAVEHIST=100000
setopt HIST_IGNORE_ALL_DUPS   # drop older duplicates of a command
setopt HIST_REDUCE_BLANKS     # trim superfluous whitespace before saving
setopt HIST_VERIFY            # expand !! etc. into the line for confirmation, don't run blind
setopt SHARE_HISTORY          # share history live across open shells
setopt EXTENDED_HISTORY       # record when each command ran and how long it took
setopt HIST_IGNORE_SPACE      # a command typed with a leading space stays out of history

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
alias oldvim='command vim'   # bypass the vim->nvim alias

# Quality of life
alias mkdir='mkdir -p'
alias ..='cd ..'
alias ...='cd ../..'
alias reload='exec zsh'          # restart the shell to pick up config changes

# Dotfiles management
alias dot='cd ~/.dotfiles'   # not `df`, which would hide disk-free
alias dfs='~/.dotfiles/setup.sh'

# Claude Code (not `cc`, which is the C compiler)
alias cl='claude'
alias clc='claude --continue'   # resume the most recent session in this directory

# clone <url|owner/repo> [account]: clone into ~/source-code/<account>/<repo> and
# cd there; an existing checkout is just entered. Account: the argument if given,
# else the account whose remote rules (from `git account add`) match the URL, else
# `personal`. owner/repo shorthand uses the host from the account's
# ~/.ssh/config.d/<account>.conf (personal: github.com). The ~/source-code/<account>/
# folder then selects the identity whatever the remote looks like.
clone() {
  local src="$1" category="$2" line acct pat
  local rule='[includeIf "hasconfig:remote.*.url:' header='# >>> account: '
  if [[ -z "$src" ]]; then
    echo "usage: clone <url|owner/repo> [account]" >&2
    return 2
  fi
  if [[ -z "$category" && -r "$HOME/.gitconfig.d/accounts.config" ]]; then
    while IFS= read -r line; do
      [[ "$line" == "$header"* ]] && acct="${line#"$header"}"
      [[ "$line" == "$rule"* ]] || continue
      pat=${line#"$rule"}
      pat=${pat%'"]'}
      [[ "$src" == ${~pat} ]] && { category="$acct"; break }
    done < "$HOME/.gitconfig.d/accounts.config"
  fi
  category="${category:-personal}"
  if [[ "$category" != personal && ! -f "$HOME/.gitconfig.d/$category.config" ]]; then
    echo "clone: unknown account '$category' (see: git account list)" >&2
    return 2
  fi
  if [[ "$src" =~ '^[^/:]+/[^/:]+$' ]]; then
    local host=github.com
    if [[ "$category" != personal ]]; then
      host="$(awk '$1 == "Host" { print $2; exit }' "$HOME/.ssh/config.d/$category.conf" 2>/dev/null)"
      if [[ -z "$host" ]]; then
        echo "clone: no SSH alias for '$category'; pass a full URL" >&2
        return 2
      fi
    fi
    src="git@${host}:${src}.git"
  fi
  local dest="$HOME/source-code/$category/${${src:t}%.git}"
  if [[ -d "$dest/.git" ]]; then
    echo "clone: already cloned, entering $dest"
  else
    git clone "$src" "$dest" || return
  fi
  cd "$dest"
}

# Modern CLI replacements (only aliased if the tool is installed, so configs stay portable)
command -v eza >/dev/null && alias ls='eza --group-directories-first' && alias ll='eza -lah --git'
command -v bat >/dev/null && alias cat='bat -pp'
if (( $+commands[fd] )); then
  # fzf pickers: Ctrl-T (files) and Alt-C (dirs) use fd; previews use bat/eza.
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_ALT_C_COMMAND='fd --type d --hidden --exclude .git'
fi
(( $+commands[bat] )) && export FZF_CTRL_T_OPTS="--preview 'bat -n --color=always --line-range :200 {}'"
(( $+commands[eza] )) && export FZF_ALT_C_OPTS="--preview 'eza --tree --level 2 --color=always {} | head -100'"
############################
# GPG (interactive signing / pinentry)
############################

# Tell gpg-agent which terminal to prompt on. Lives here, not .zshenv, because it
# assumes an attached terminal and .zshenv must stay tty-free. $TTY avoids forking tty(1).
export GPG_TTY=$TTY

############################
# Key Bindings Completion
############################

# Ctrl + Space for zsh auto-completion
bindkey '^ ' autosuggest-accept

############################
# Version Managers
############################

# PATH entries live in .zshenv (so scripts/ssh see them). Both managers load on
# first use: nvm via the oh-my-zsh plugin's lazy mode (above), and sdkman via
# this stub, which sources sdkman-init (~600ms) the first time `sdk` runs.
if [[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]]; then
  sdk() {
    unfunction sdk
    source "$SDKMAN_DIR/bin/sdkman-init.sh" && sdk "$@"
  }
fi

############################
# zoxide (`z <partial>` jumps to frequent dirs; replaces the oh-my-zsh z plugin)
############################

# Init output cached; regenerated when zoxide is upgraded. Must run after compinit.
if (( $+commands[zoxide] )); then
  _zoxide_init="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zoxide-init.zsh"
  if [[ ! -s "$_zoxide_init" || "$_zoxide_init" -ot "$commands[zoxide]" ]]; then
    mkdir -p "${_zoxide_init:h}"
    zoxide init zsh >| "$_zoxide_init"
  fi
  source "$_zoxide_init"
  unset _zoxide_init
fi
