#!/usr/bin/env bash

# =============================================================================
# 1. EARLY EXIT (PERFORMANCE GUARD)
# =============================================================================
# If not running interactively, stop here. 
# This prevents SCP/SFTP connections and scripts from breaking or loading slowly.
[[ $- != *i* ]] && return

# =============================================================================
# 2. GLOBAL ENVIRONMENT & EXPORTS
# =============================================================================

# History Settings
export HISTFILESIZE=10000
export HISTSIZE=500
export HISTTIMEFORMAT="%F %T "
export HISTCONTROL=erasedups:ignoredups:ignorespace
shopt -s histappend

# Default Editor
export EDITOR=nvim
export VISUAL=nvim

# XDG Directories
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME="$HOME/.cache"

# Custom Variables
export LINUXTOOLBOXDIR="$HOME/linuxtoolbox"
export CLICOLOR=1

# Manpage Colors (colored man pages using less)
export LESS_TERMCAP_mb=$'\E[01;31m'
export LESS_TERMCAP_md=$'\E[01;31m'
export LESS_TERMCAP_me=$'\E[0m'
export LESS_TERMCAP_se=$'\E[0m'
export LESS_TERMCAP_so=$'\E[01;44;33m'
export LESS_TERMCAP_ue=$'\E[0m'
export LESS_TERMCAP_us=$'\E[01;32m'

# =============================================================================
# 3. PATH MANAGEMENT
# =============================================================================

# Helper function to add paths only if they exist and aren't duplicates
path_append() {
    if [ -d "$1" ] && [[ ":$PATH:" != *":$1:"* ]]; then
        export PATH="$PATH:$1"
    fi
}

# Append custom paths
path_append "$HOME/.local/bin"
path_append "$HOME/.cargo/bin"
path_append "/var/lib/flatpak/exports/bin"
path_append "/.local/share/flatpak/exports/bin"
path_append "$HOME/Applications/depot_tools"

# Initialize Linuxbrew (if present) - Done early so aliases pick up brew tools
if [ -d "/home/linuxbrew/.linuxbrew/bin" ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# =============================================================================
# 4. SOURCING & IMPORTS
# =============================================================================

# Source global definitions
[ -f /etc/bashrc ] && . /etc/bashrc

# Source user profile
[ -f ~/.profile ] && . ~/.profile

# Enable bash completion
if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
fi

# Pywal Colors
[ -f ~/.cache/wal/sequences ] && cat ~/.cache/wal/sequences

# Arch Linux specific: Find-the-command
[ -f /usr/share/doc/find-the-command/ftc.bash ] && source /usr/share/doc/find-the-command/ftc.bash

# =============================================================================
# 5. SHELL OPTIONS & BINDINGS
# =============================================================================

shopt -s checkwinsize
PROMPT_COMMAND='history -a'

# Key Bindings
bind "set bell-style visible"
bind "set completion-ignore-case on"
bind "set show-all-if-ambiguous On"

# Disable flow control (Allow Ctrl-S for history navigation)
stty -ixon

# Bind Ctrl+f to insert 'zi'
bind '"\C-f":"zi\n"'

# =============================================================================
# 6. FUNCTIONS
# =============================================================================

# --- System Info Helper ---
distribution() {
    local dtype="unknown"
    if [ -r /etc/os-release ]; then
        source /etc/os-release
        case $ID in
            fedora|rhel|centos) dtype="redhat" ;;
            sles|opensuse*)     dtype="suse" ;;
            ubuntu|debian)      dtype="debian" ;;
            gentoo)             dtype="gentoo" ;;
            arch|manjaro|endeavouros) dtype="arch" ;;
            slackware)          dtype="slackware" ;;
            *)
                if [[ "$ID_LIKE" == *"arch"* ]]; then dtype="arch";
                elif [[ "$ID_LIKE" == *"debian"* ]]; then dtype="debian";
                elif [[ "$ID_LIKE" == *"rhel"* ]]; then dtype="redhat";
                fi ;;
        esac
    fi
    echo $dtype
}

# --- File Operations ---
extract() {
    for archive in "$@"; do
        if [ -f "$archive" ]; then
            case $archive in
                *.tar.bz2) tar xvjf "$archive" ;;
                *.tar.gz)  tar xvzf "$archive" ;;
                *.bz2)     bunzip2 "$archive" ;;
                *.rar)     rar x "$archive" ;;
                *.gz)      gunzip "$archive" ;;
                *.tar)     tar xvf "$archive" ;;
                *.tbz2)    tar xvjf "$archive" ;;
                *.tgz)     tar xvzf "$archive" ;;
                *.zip)     unzip "$archive" ;;
                *.Z)       uncompress "$archive" ;;
                *.7z)      7z x "$archive" ;;
                *)         echo "don't know how to extract '$archive'..." ;;
            esac
        else
            echo "'$archive' is not a valid file!"
        fi
    done
}

# --- Advanced Copy with Progress (requires strace) ---
cpp() {
    set -e
    strace -q -ewrite cp -- "${1}" "${2}" 2>&1 |
    awk '{
        count += $NF
        if (count % 10 == 0) {
            percent = count / total_size * 100
            printf "%3d%% [", percent
            for (i=0;i<=percent;i++) printf "="
            printf ">"
            for (i=percent;i<100;i++) printf " "
            printf "]\r"
        }
    }
    END { print "" }' total_size="$(stat -c '%s' "${1}")" count=0
}

# --- Navigation Wrappers ---
mkdirg() { mkdir -p "$1" && cd "$1"; }
cpg() { [ -d "$2" ] && cp "$1" "$2" && cd "$2" || cp "$1" "$2"; }
mvg() { [ -d "$2" ] && mv "$1" "$2" && cd "$2" || mv "$1" "$2"; }
backup() { cp "$1" "$1.bak"; }
up() {
    local d=""
    local limit=$1
    for ((i = 1; i <= limit; i++)); do d=$d/..; done
    d=$(echo $d | sed 's/^\///')
    [ -z "$d" ] && d=..
    cd $d
}

# --- Network & Info ---
whatsmyip() {
    echo -n "Internal IP: "
    if command -v ip &> /dev/null; then
        ip addr | grep "inet " | grep -v "127.0.0.1" | awk '{print $2}' | cut -d/ -f1 | head -n 1
    else
        ifconfig | grep "inet " | grep -v "127.0.0.1" | awk '{print $2}' | head -n 1
    fi
    echo -n "External IP: "
    curl -s -4 ifconfig.me
    echo ""
}

# --- Config Editors (Legacy Support) ---
apacheconfig() {
    if [ -f /etc/httpd/conf/httpd.conf ]; then $EDITOR /etc/httpd/conf/httpd.conf
    elif [ -f /etc/apache2/apache2.conf ]; then $EDITOR /etc/apache2/apache2.conf
    else echo "Apache config not found."; fi
}
phpconfig() {
    if [ -f /etc/php.ini ]; then $EDITOR /etc/php.ini
    elif [ -f /etc/php/php.ini ]; then $EDITOR /etc/php/php.ini
    else echo "PHP config not found."; fi
}

# --- AI Helpers ---
chat() {
    local response
    response=$(curl -s ch.at/v1/chat/completions --data "{\"messages\":[{\"role\":\"user\",\"content\":\"$1\"}]}" | jq -r '.choices[0].message.content')
    echo "$response"
}
coder() {
    local user_prompt="$1"
    local outfile="$2"
    local full_prompt="You are a code generator. Always and only output raw, runnable code with no explanations, comments, or markdown. $user_prompt"
    local response
    response=$(curl -s ch.at/v1/chat/completions --data "{\"messages\":[{\"role\":\"user\",\"content\":\"$full_prompt\"}]}" | jq -r '.choices[0].message.content')
    echo "$response" | sed '/^[[:space:]]*$/d' > "$outfile"
    echo "✅ Code saved to $outfile"
}

# =============================================================================
# 7. ALIASES
# =============================================================================

# --- Editor ---
alias vi='nvim'
alias vim='nvim'
alias svi='sudo nvim'
alias n='nvim -O'
alias ebrc='nvim ~/.bashrc'
alias reload='source ~/.bashrc'

# --- Navigation ---
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias bd='cd "$OLDPWD"'
alias home='cd ~'

# --- Safety ---
alias cp='cp -i'
alias mv='mv -i'
alias mkdir='mkdir -p'
# Use trash-cli if available, otherwise fallback to standard rm
if command -v trash &> /dev/null; then
    alias rm='trash -v'
else
    alias rm='rm -i'
fi

# --- Modern Replacements (eza, bat, rg) ---

# ls -> eza (fallback to exa, then ls)
if command -v eza &> /dev/null; then
    alias ls='eza -al --color=always --group-directories-first --icons'
    alias la='eza -a --color=always --group-directories-first --icons'
    alias ll='eza -l --color=always --group-directories-first --icons'
    alias tree='eza --tree --icons'
elif command -v exa &> /dev/null; then
    alias ls='exa -al --color=always --group-directories-first --icons'
    alias la='exa -a --color=always --group-directories-first --icons'
    alias ll='exa -l --color=always --group-directories-first --icons'
    alias tree='exa --tree --icons'
else
    alias ls='ls --color=auto'
    alias ll='ls -alF'
fi

# cat -> bat
if command -v bat &> /dev/null; then
    alias cat='bat --style header --style rules --style snip --style changes'
elif command -v batcat &> /dev/null; then
    alias cat='batcat --style header --style rules --style snip --style changes'
fi

# grep -> rg
if command -v rg &> /dev/null; then
    alias grep='rg'
else
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# --- Git ---
alias gcom='git add . && git commit -m'
alias lazyg='git add . && git commit -m "$1" && git push'

# --- System & Utils ---
alias ps='ps auxf'
alias ping='ping -c 10'
alias cls='clear'
alias open='xdg-open'
alias pbcopy='xclip -selection clipboard'
alias pbpaste='xclip -o -selection clipboard'
alias jctl="journalctl -p 3 -xb"
alias rebootsafe='sudo shutdown -r now'
alias whatismyip="whatsmyip"
alias checkcommand="type -t"

# --- Package Management (Arch Specific Fallbacks) ---
if [ "$(distribution)" == "arch" ]; then
    alias pac="sudo pacman"
    alias big="expac -H M '%m\t%n' | sort -h | nl"
    if ! command -v yay >/dev/null && command -v paru >/dev/null; then
        alias yay='paru --bottomup'
    fi
    alias aup="yay -Syu"
fi

# =============================================================================
# 8. STARTUP INITIALIZATION
# =============================================================================

# Initialize Starship (Prompt)
if command -v starship &> /dev/null; then
    eval "$(starship init bash)"
fi

# Initialize Zoxide (Smarter cd)
if command -v zoxide &> /dev/null; then
    eval "$(zoxide init bash)"
fi

# Fastfetch - Loaded LAST for UI pop
if command -v fastfetch &> /dev/null; then
    fastfetch
fi
