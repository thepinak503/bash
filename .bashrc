#!/usr/bin/env bash

# =============================================================================
# UNIVERSAL BASH CONFIGURATION (MASTER EDITION)
# =============================================================================

# =============================================================================
# 1. PERFORMANCE GUARD
# =============================================================================
# If not running interactively, stop here.
[[ $- != *i* ]] && return

# =============================================================================
# 2. ENVIRONMENT & EXPORTS
# =============================================================================

# History Settings
export HISTFILESIZE=10000
export HISTSIZE=500
export HISTTIMEFORMAT="%F %T "
export HISTCONTROL=erasedups:ignoredups:ignorespace

# Default Editor
export EDITOR=nvim
export VISUAL=nvim

# XDG Standard Directories
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME="$HOME/.cache"

# Tooling & Colors
export LINUXTOOLBOXDIR="$HOME/linuxtoolbox"
export CLICOLOR=1
export VIRTUAL_ENV_DISABLE_PROMPT="1" 

# Comprehensive LS_COLORS
export LS_COLORS='no=00:fi=00:di=00;34:ln=01;36:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:ex=01;32:*.tar=01;31:*.tgz=01;31:*.arj=01;31:*.taz=01;31:*.lzh=01;31:*.zip=01;31:*.z=01;31:*.Z=01;31:*.gz=01;31:*.bz2=01;31:*.deb=01;31:*.rpm=01;31:*.jar=01;31:*.jpg=01;35:*.jpeg=01;35:*.gif=01;35:*.bmp=01;35:*.pbm=01;35:*.pgm=01;35:*.ppm=01;35:*.tga=01;35:*.xbm=01;35:*.xpm=01;35:*.tif=01;35:*.tiff=01;35:*.png=01;35:*.mov=01;35:*.mpg=01;35:*.mpeg=01;35:*.avi=01;35:*.fli=01;35:*.gl=01;35:*.dl=01;35:*.xcf=01;35:*.xwd=01;35:*.ogg=01;35:*.mp3=01;35:*.wav=01;35:*.xml=00;31:'

# Manpage Colors
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

path_append() {
    if [ -d "$1" ] && [[ ":$PATH:" != *":$1:"* ]]; then
        export PATH="$PATH:$1"
    fi
}

path_append "$HOME/.local/bin"
path_append "$HOME/.cargo/bin"
path_append "/var/lib/flatpak/exports/bin"
path_append "/.local/share/flatpak/exports/bin"
path_append "$HOME/Applications/depot_tools"
[ -d "/snap/bin" ] && path_append "/snap/bin"

# Linuxbrew initialization
if [ -d "/home/linuxbrew/.linuxbrew/bin" ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi
HOMEBREW_NO_INSTALL_CLEANUP=1
HOMEBREW_NO_ENV_HINTS=1

# =============================================================================
# 4. SOURCING & IMPORTS
# =============================================================================

[ -f /etc/bashrc ] && . /etc/bashrc
[ -f ~/.profile ] && . ~/.profile
[ -f ~/.bash_aliases ] && . ~/.bash_aliases

# Bash Completion
if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
fi

# Pywal Colors
[ -f ~/.cache/wal/sequences ] && cat ~/.cache/wal/sequences

# Command-not-found hook (Arch)
[ -f /usr/share/doc/find-the-command/ftc.bash ] && source /usr/share/doc/find-the-command/ftc.bash

# =============================================================================
# 5. SHELL OPTIONS & BINDINGS
# =============================================================================

shopt -s checkwinsize
shopt -s histappend
shopt -s autocd
shopt -s nocaseglob
PROMPT_COMMAND='history -a'
stty -ixon 

# Bindings
bind "set bell-style visible"
bind "set completion-ignore-case on"
bind "set show-all-if-ambiguous On"
bind '"\C-f":"zi\n"' # Ctrl+f for zoxide

# History Search
bind '"\e[5~": history-search-backward'
bind '"\e[6~": history-search-forward'
bind '"\e[A": history-search-backward'
bind '"\e[B": history-search-forward'

# Navigation Keys
bind '"\e[H": beginning-of-line'
bind '"\e[F": end-of-line'
bind '"\e[1;5D": backward-word'
bind '"\e[1;5C": forward-word'

# =============================================================================
# 6. CORE FUNCTIONS
# =============================================================================

# Robust Distro Detection
robust_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    elif type lsb_release >/dev/null 2>&1; then
        lsb_release -si | tr '[:upper:]' '[:lower:]'
    elif [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        echo "$DISTRIB_ID" | tr '[:upper:]' '[:lower:]'
    elif [ -f /etc/debian_version ]; then
        echo "debian"
    elif [ -f /etc/redhat-release ]; then
        echo "rhel"
    else
        echo "unknown"
    fi
}

# -----------------------------------------------------------------------------
# AUTO-INSTALLER (Dependency Resolution)
# -----------------------------------------------------------------------------
# This function installs every single tool used in the aliases below.
# Includes: eza, bat, zoxide, trash, fzf, rg, ugrep, starship, fastfetch
# Plus helpers: jq, curl, strace, xclip, xdotool, hwinfo, net-tools, multitail
install_bashrc_support() {
    local distro=$(robust_distro)
    echo "Detected Distribution: $distro"
    
    # Core list of packages to map to distro-specific names
    # nvim, trash-cli, eza, bat, zoxide, fzf, ripgrep, ugrep, starship, fastfetch
    # xclip (clipboard), xdotool (macros), hwinfo, net-tools (netstat), strace (cpp), jq (json), curl, multitail

    case $distro in
        *arch*|manjaro|endeavouros|garuda)
            local aurhelper="pacman"
            command -v yay &> /dev/null && aurhelper="yay"
            command -v paru &> /dev/null && aurhelper="paru"
            
            echo "Installing Full Suite via $aurhelper..."
            local pkg_list="neovim trash-cli eza bat zoxide fzf ripgrep ugrep starship fastfetch xclip xdotool hwinfo net-tools strace curl jq multitail expac reflector"
            
            if [ "$aurhelper" == "pacman" ]; then
                sudo pacman -S --noconfirm $pkg_list
            else
                $aurhelper -S --noconfirm $pkg_list
            fi
            ;;

        debian|ubuntu|linuxmint|pop|kali)
            echo "Installing available packages via apt..."
            sudo apt update
            # 'bat' is 'batcat' in Debian
            # 'fd-find' is 'fd'
            sudo apt install -y neovim trash-cli bat zoxide fzf ripgrep curl jq net-tools strace xclip xdotool multitail hwinfo
            
            # Install items often missing from stable Apt repos
            if ! command -v starship &> /dev/null; then
                echo "Installing Starship..."
                curl -sS https://starship.rs/install.sh | sh
            fi
            if ! command -v eza &> /dev/null; then
                echo "Manual install required for 'eza' on Debian (check github.com/eza-community/eza)"
            fi
            if ! command -v fastfetch &> /dev/null; then
                 echo "Manual install required for 'fastfetch' on Debian"
            fi
            if ! command -v ugrep &> /dev/null; then
                 echo "Manual install required for 'ugrep' on Debian"
            fi
            ;;

        fedora|rhel|centos|almalinux)
            echo "Installing packages via dnf..."
            sudo dnf install -y neovim trash-cli eza bat zoxide fzf ripgrep ugrep starship fastfetch xclip xdotool hwinfo net-tools strace curl jq multitail
            ;;

        opensuse*|suse)
            echo "Installing packages via zypper..."
            sudo zypper install -y neovim trash-cli eza bat zoxide fzf ripgrep ugrep starship fastfetch xclip xdotool hwinfo net-tools strace curl jq multitail
            ;;

        alpine)
            echo "Installing packages via apk..."
            sudo apk add neovim trash-cli eza bat zoxide fzf ripgrep starship fastfetch xclip xdotool hwinfo net-tools strace curl jq multitail
            ;;

        *)
            echo "Unsupported distro. Please manually install: neovim trash-cli eza bat zoxide fzf ripgrep ugrep starship fastfetch xclip xdotool hwinfo net-tools strace curl jq multitail"
            ;;
    esac
}

# Copy with Progress (Req: strace)
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

# Extract Archives
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

# Text Search
ftext() {
    grep -iIHrn --color=always "$1" . | less -r
}

# Directory Helpers
mkdirg() { mkdir -p "$1" && cd "$1"; }
cpg() { [ -d "$2" ] && cp "$1" "$2" && cd "$2" || cp "$1" "$2"; }
mvg() { [ -d "$2" ] && mv "$1" "$2" && cd "$2" || mv "$1" "$2"; }
up() {
    local d=""
    local limit=$1
    for ((i = 1; i <= limit; i++)); do d=$d/..; done
    d=$(echo $d | sed 's/^\///')
    [ -z "$d" ] && d=..
    cd $d
}

# Hastebin Upload (Req: curl, jq)
hb() {
    if [ $# -eq 0 ]; then echo "No file path specified."; return; fi
    if [ ! -f "$1" ]; then echo "File path does not exist."; return; fi
    uri="http://bin.christitus.com/documents"
    response=$(curl -s -X POST -d @"$1" "$uri")
    if [ $? -eq 0 ]; then
        hasteKey=$(echo $response | jq -r '.key')
        echo "http://bin.christitus.com/$hasteKey"
    else
        echo "Failed to upload the document."
    fi
}

# Network Info
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

# Server Logs (Req: multitail)
apachelog() {
    if [ -f /etc/httpd/conf/httpd.conf ]; then
        cd /var/log/httpd && ls -xAh && multitail --no-repeat -c -s 2 /var/log/httpd/*_log
    else
        cd /var/log/apache2 && ls -xAh && multitail --no-repeat -c -s 2 /var/log/apache2/*.log
    fi
}

# =============================================================================
# 7. UNIVERSAL PACKAGE MANAGER WRAPPER
# =============================================================================

DISTRO=$(robust_distro)

case $DISTRO in
    *arch*|manjaro|endeavouros|garuda)
        alias sysupdate='sudo pacman -Syu'
        alias install='sudo pacman -S'
        alias remove='sudo pacman -Rs'
        alias clean='sudo pacman -Rns $(pacman -Qtdq)'
        alias search='pacman -Ss'
        alias upd='sudo pacman -Syu'
        alias cleanup='sudo pacman -Rns $(pacman -Qtdq)'
        alias fixpacman='sudo rm /var/lib/pacman/db.lck'
        alias gitpkg='pacman -Q | grep -i "\-git" | wc -l'
        alias rmpkg='sudo pacman -Rdd'
        # Arch-specific tools (Req: reflector, expac)
        alias mirror='sudo reflector -f 30 -l 30 --number 10 --verbose --save /etc/pacman.d/mirrorlist'
        alias mirrora='sudo reflector --latest 50 --number 20 --sort age --save /etc/pacman.d/mirrorlist'
        alias mirrord='sudo reflector --latest 50 --number 20 --sort delay --save /etc/pacman.d/mirrorlist'
        alias mirrors='sudo reflector --latest 50 --number 20 --sort score --save /etc/pacman.d/mirrorlist'
        alias rip='expac --timefmt="%Y-%m-%d %T" "%l\t%n %v" | sort | tail -200 | nl'
        
        if command -v paru &> /dev/null; then
            alias yay='paru'
            alias aup='paru -Syu'
        elif command -v yay &> /dev/null; then
            alias aup='yay -Syu'
        fi
        ;;

    debian|ubuntu|linuxmint|pop|kali)
        alias sysupdate='sudo apt update && sudo apt upgrade -y'
        alias install='sudo apt install'
        alias remove='sudo apt remove'
        alias clean='sudo apt autoremove'
        alias search='apt search'
        alias bat='batcat'
        ;;

    fedora|rhel|centos|almalinux)
        alias sysupdate='sudo dnf update'
        alias install='sudo dnf install'
        alias remove='sudo dnf remove'
        alias clean='sudo dnf autoremove'
        alias search='dnf search'
        ;;

    opensuse*|suse)
        alias sysupdate='sudo zypper ref && sudo zypper dup'
        alias install='sudo zypper install'
        alias remove='sudo zypper remove'
        alias clean='sudo zypper clean'
        alias search='zypper search'
        ;;

    alpine)
        alias sysupdate='sudo apk update && sudo apk upgrade'
        alias install='sudo apk add'
        alias remove='sudo apk del'
        alias search='apk search'
        ;;
esac

# =============================================================================
# 8. ALIASES
# =============================================================================

# --- Navigation ---
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias bd='cd "$OLDPWD"'
alias home='cd ~'
alias mkdir='mkdir -p'

# --- Safety & Operations (Req: trash-cli) ---
alias cp='cp -i'
alias mv='mv -i'
if command -v trash &> /dev/null; then
    alias rm='trash -v'
else
    alias rm='rm -i'
fi

# --- Modern Tools (Req: eza) ---
if command -v eza &> /dev/null; then
    alias ls='eza -al --color=always --group-directories-first --icons'
    alias la='eza -a --color=always --group-directories-first --icons'
    alias ll='eza -l --color=always --group-directories-first --icons'
    alias tree='eza --tree --icons'
    alias l.='eza -ald --color=always --group-directories-first --icons .*'
    alias lx='eza -al --group-directories-first --icons --sort=extension'
    alias lk='eza -al --group-directories-first --icons --sort=size'
    alias lt='eza -al --group-directories-first --icons --sort=modified'
elif command -v exa &> /dev/null; then
    alias ls='exa -al --color=always --group-directories-first --icons'
    alias la='exa -a --color=always --group-directories-first --icons'
    alias ll='exa -l --color=always --group-directories-first --icons'
    alias tree='exa --tree --icons'
else
    alias ls='ls --color=auto'
    alias ll='ls -alF'
    alias la='ls -Alh'
fi

# --- Modern Cat (Req: bat) ---
if command -v bat &> /dev/null; then
    alias cat='bat --style header --style rules --style snip --style changes'
    export MANPAGER="sh -c 'col -bx | bat -l man -p'"
    export MANROFFOPT="-c"
elif command -v batcat &> /dev/null; then
    alias cat='batcat --style header --style rules --style snip --style changes'
    export MANPAGER="sh -c 'col -bx | batcat -l man -p'"
    export MANROFFOPT="-c"
fi

# --- Modern Grep (Req: ugrep or ripgrep) ---
if command -v ugrep &> /dev/null; then
    alias grep='ugrep --color=auto'
    alias egrep='ugrep -E --color=auto'
    alias fgrep='ugrep -F --color=auto'
elif command -v rg &> /dev/null; then
    alias grep='rg'
    alias egrep='rg'
    alias fgrep='rg -F'
else
    alias grep='grep --color=auto'
    alias egrep='grep -E --color=auto'
    alias fgrep='grep -F --color=auto'
fi

# --- Git ---
alias g='git'
alias gi="git init"
alias ga='git add'
alias gaa='git add .'
alias gcom='git add . && git commit -m'
alias lazyg='git add . && git commit -m "$1" && git push'
alias gclone='git clone'
alias gpull='git pull'
alias gpush='git push'

# --- System & Hardware (Req: hwinfo, net-tools) ---
alias ps='ps auxf'
alias ping='ping -c 10'
alias cls='clear'
alias hw='hwinfo --short'
alias psmem='ps auxf | sort -nr -k 4'
alias psmem10='ps auxf | sort -nr -k 4 | head -10'
alias big='expac -H M "%m\t%n" | sort -h | nl' 
alias rebootsafe='sudo shutdown -r now'
alias rebootforce='sudo shutdown -r -n now'
alias jctl="journalctl -p 3 -xb"
alias open='xdg-open'
alias ebrc='nvim ~/.bashrc'
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# --- Network & Utils ---
alias whatismyip="whatsmyip"
alias myip="whatsmyip"
alias openports='netstat -nape --inet'
alias tb='nc termbin.com 9999'
alias helpme='cht.sh --shell'
alias checkcommand="type -t"
alias da='date "+%Y-%m-%d %A %T %Z"'

# --- Clipboard (Req: xclip, xdotool) ---
alias pbcopy='xclip -selection clipboard'
alias pbpaste='xclip -o -selection clipboard'
alias clickpaste='sleep 3; xdotool type "$(xclip -o -selection clipboard)"'

# =============================================================================
# 9. INITIALIZATION
# =============================================================================

# Starship Prompt
if command -v starship &> /dev/null; then
    eval "$(starship init bash)"
fi

# Zoxide
if command -v zoxide &> /dev/null; then
    eval "$(zoxide init bash)"
fi

# Fastfetch (Interactive only)
if [[ $- == *i* ]] && command -v fastfetch &> /dev/null; then
    fastfetch
fi
