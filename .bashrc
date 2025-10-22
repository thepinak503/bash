#!/usr/bin/env bash

#######################################################
# INITIAL SETUP & SOURCING
#######################################################

iatest=$(expr index "$-" i)

# Source global definitions
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

# Enable bash programmable completion features
if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
fi

# Fastfetch on startup
if [ -f /usr/bin/fastfetch ]; then
    fastfetch
fi

#######################################################
# FUNCTIONS
#######################################################

# System information functions first since they're used in aliases
distribution() {
    local dtype="unknown"
    if [ -r /etc/os-release ]; then
        source /etc/os-release
        case $ID in
            fedora|rhel|centos) dtype="redhat" ;;
            sles|opensuse*) dtype="suse" ;;
            ubuntu|debian) dtype="debian" ;;
            gentoo) dtype="gentoo" ;;
            arch|manjaro) dtype="arch" ;;
            slackware) dtype="slackware" ;;
            *)
                if [ -n "$ID_LIKE" ]; then
                    case $ID_LIKE in
                        *fedora*|*rhel*|*centos*) dtype="redhat" ;;
                        *sles*|*opensuse*) dtype="suse" ;;
                        *ubuntu*|*debian*) dtype="debian" ;;
                        *gentoo*) dtype="gentoo" ;;
                        *arch*) dtype="arch" ;;
                        *slackware*) dtype="slackware" ;;
                    esac
                fi
                ;;
        esac
    fi
    echo $dtype
}

# File operations
extract() {
    for archive in "$@"; do
        if [ -f "$archive" ]; then
            case $archive in
            *.tar.bz2) tar xvjf $archive ;;
            *.tar.gz) tar xvzf $archive ;;
            *.bz2) bunzip2 $archive ;;
            *.rar) rar x $archive ;;
            *.gz) gunzip $archive ;;
            *.tar) tar xvf $archive ;;
            *.tbz2) tar xvjf $archive ;;
            *.tgz) tar xvzf $archive ;;
            *.zip) unzip $archive ;;
            *.Z) uncompress $archive ;;
            *.7z) 7z x $archive ;;
            *) echo "don't know how to extract '$archive'..." ;;
            esac
        else
            echo "'$archive' is not a valid file!"
        fi
    done
}

ftext() {
    grep -iIHrn --color=always "$1" . | less -r
}

cpp() {
    set -e
    strace -q -ewrite cp -- "${1}" "${2}" 2>&1 |
    awk '{
        count += $NF
        if (count % 10 == 0) {
            percent = count / total_size * 100
            printf "%3d%% [", percent
            for (i=0;i<=percent;i++)
                printf "="
            printf ">"
            for (i=percent;i<100;i++)
                printf " "
            printf "]\r"
        }
    }
    END { print "" }' total_size="$(stat -c '%s' "${1}")" count=0
}

cpg() {
    if [ -d "$2" ]; then
        cp "$1" "$2" && cd "$2"
    else
        cp "$1" "$2"
    fi
}

mvg() {
    if [ -d "$2" ]; then
        mv "$1" "$2" && cd "$2"
    else
        mv "$1" "$2"
    fi
}

mkdirg() {
    mkdir -p "$1"
    cd "$1"
}

backup() {
    cp "$1" "$1.bak"
}

copy() {
    if [ "$#" -eq 2 ] && [ -d "$1" ]; then
        from="${1%/}"
        to="$2"
        cp -r "$from" "$to"
    else
        cp "$@"
    fi
}

# Directory navigation
up() {
    local d=""
    limit=$1
    for ((i = 1; i <= limit; i++)); do
        d=$d/..
    done
    d=$(echo $d | sed 's/^\///')
    if [ -z "$d" ]; then
        d=..
    fi
    cd $d
}

cd() {
    if [ -n "$1" ]; then
        builtin cd "$@" && ls
    else
        builtin cd ~ && ls
    fi
}

pwdtail() {
    pwd | awk -F/ '{nlast = NF -1;print $nlast"/"$NF}'
}

# System information
ver() {
    local dtype
    dtype=$(distribution)
    case $dtype in
        "redhat")
            if [ -s /etc/redhat-release ]; then
                cat /etc/redhat-release
            else
                cat /etc/issue
            fi
            uname -a
            ;;
        "suse") cat /etc/SuSE-release ;;
        "debian") lsb_release -a ;;
        "gentoo") cat /etc/gentoo-release ;;
        "arch") cat /etc/os-release ;;
        "slackware") cat /etc/slackware-version ;;
        *)
            if [ -s /etc/issue ]; then
                cat /etc/issue
            else
                echo "Error: Unknown distribution"
                exit 1
            fi
            ;;
    esac
}

# Network functions
whatsmyip() {
    if command -v ip &> /dev/null; then
        echo -n "Internal IP: "
        ip addr show wlan0 | grep "inet " | awk '{print $2}' | cut -d/ -f1
    else
        echo -n "Internal IP: "
        ifconfig wlan0 | grep "inet " | awk '{print $2}'
    fi
    echo -n "External IP: "
    curl -4 ifconfig.me
}

# Service management
apachelog() {
    if [ -f /etc/httpd/conf/httpd.conf ]; then
        cd /var/log/httpd && ls -xAh && multitail --no-repeat -c -s 2 /var/log/httpd/*_log
    else
        cd /var/log/apache2 && ls -xAh && multitail --no-repeat -c -s 2 /var/log/apache2/*.log
    fi
}

apacheconfig() {
    if [ -f /etc/httpd/conf/httpd.conf ]; then
        sedit /etc/httpd/conf/httpd.conf
    elif [ -f /etc/apache2/apache2.conf ]; then
        sedit /etc/apache2/apache2.conf
    else
        echo "Error: Apache config file could not be found."
        echo "Searching for possible locations:"
        sudo updatedb && locate httpd.conf && locate apache2.conf
    fi
}

phpconfig() {
    if [ -f /etc/php.ini ]; then
        sedit /etc/php.ini
    elif [ -f /etc/php/php.ini ]; then
        sedit /etc/php/php.ini
    elif [ -f /etc/php5/php.ini ]; then
        sedit /etc/php5/php.ini
    elif [ -f /usr/bin/php5/bin/php.ini ]; then
        sedit /usr/bin/php5/bin/php.ini
    elif [ -f /etc/php5/apache2/php.ini ]; then
        sedit /etc/php5/apache2/php.ini
    else
        echo "Error: php.ini file could not be found."
        echo "Searching for possible locations:"
        sudo updatedb && locate php.ini
    fi
}

mysqlconfig() {
    if [ -f /etc/my.cnf ]; then
        sedit /etc/my.cnf
    elif [ -f /etc/mysql/my.cnf ]; then
        sedit /etc/mysql/my.cnf
    elif [ -f /usr/local/etc/my.cnf ]; then
        sedit /usr/local/etc/my.cnf
    elif [ -f /usr/bin/mysql/my.cnf ]; then
        sedit /usr/bin/mysql/my.cnf
    elif [ -f ~/my.cnf ]; then
        sedit ~/my.cnf
    elif [ -f ~/.my.cnf ]; then
        sedit ~/.my.cnf
    else
        echo "Error: my.cnf file could not be found."
        echo "Searching for possible locations:"
        sudo updatedb && locate my.cnf
    fi
}

# Development
gcom() {
    git add .
    git commit -m "$1"
}

lazyg() {
    git add .
    git commit -m "$1"
    git push
}

hb() {
    if [ $# -eq 0 ]; then
        echo "No file path specified."
        return
    elif [ ! -f "$1" ]; then
        echo "File path does not exist."
        return
    fi
    uri="http://bin.christitus.com/documents"
    response=$(curl -s -X POST -d @"$1" "$uri")
    if [ $? -eq 0 ]; then
        hasteKey=$(echo $response | jq -r '.key')
        echo "http://bin.christitus.com/$hasteKey"
    else
        echo "Failed to upload the document."
    fi
}

chat() {
    local response
    response=$(curl -s ch.at/v1/chat/completions --data "{\"messages\":[{\"role\":\"user\",\"content\":\"$1\"}]}" | jq -r '.choices[0].message.content')
    echo "$response"
}

coder() {
    local user_prompt="$1"
    local outfile="$2"
    local system_prompt="You are a code generator. Always and only output raw, runnable code with no explanations, comments, markdown fences, or prose. Do not include code block syntax like triple backticks."
    local full_prompt="$system_prompt $user_prompt"
    local response
    response=$(curl -s ch.at/v1/chat/completions \
        --data "{\"messages\":[{\"role\":\"user\",\"content\":\"$full_prompt\"}]}" |
        jq -r '.choices[0].message.content')
    echo "$response" | sed '/^[[:space:]]*$/d' > "$outfile"
    echo "✅ Code saved to $outfile"
}

# Utilities
trim() {
    local var=$*
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"
    echo -n "$var"
}

install_bashrc_support() {
    local dtype
    dtype=$(distribution)
    case $dtype in
        "redhat")
            sudo yum install multitail tree zoxide trash-cli fzf bash-completion fastfetch
            ;;
        "suse")
            sudo zypper install multitail tree zoxide trash-cli fzf bash-completion fastfetch
            ;;
        "debian")
            sudo apt-get install multitail tree zoxide trash-cli fzf bash-completion
            FASTFETCH_URL=$(curl -s https://api.github.com/repos/fastfetch-cli/fastfetch/releases/latest | grep "browser_download_url.*linux-amd64.deb" | cut -d '"' -f 4)
            curl -sL $FASTFETCH_URL -o /tmp/fastfetch_latest_amd64.deb
            sudo apt-get install /tmp/fastfetch_latest_amd64.deb
            ;;
        "arch")
            yay -S multitail tree zoxide trash-cli fzf bash-completion fastfetch
            ;;
        "slackware")
            echo "No install support for Slackware"
            ;;
        *)
            echo "Unknown distribution"
            ;;
    esac
}

history() {
    HISTTIMEFORMAT='%F %T '
    builtin history "$@"
}

#######################################################
# EXPORTS
#######################################################

# History settings
export HISTFILESIZE=10000
export HISTSIZE=500
export HISTTIMEFORMAT="%F %T"
export HISTCONTROL=erasedups:ignoredups:ignorespace

# XDG directories
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME="$HOME/.cache"

# Toolbox directory
export LINUXTOOLBOXDIR="$HOME/linuxtoolbox"

# Editor
export EDITOR=nvim
export VISUAL=nvim

# Colors and display
export CLICOLOR=1
export LS_COLORS='no=00:fi=00:di=00;34:ln=01;36:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:ex=01;32:*.tar=01;31:*.tgz=01;31:*.arj=01;31:*.taz=01;31:*.lzh=01;31:*.zip=01;31:*.z=01;31:*.Z=01;31:*.gz=01;31:*.bz2=01;31:*.deb=01;31:*.rpm=01;31:*.jar=01;31:*.jpg=01;35:*.jpeg=01;35:*.gif=01;35:*.bmp=01;35:*.pbm=01;35:*.pgm=01;35:*.ppm=01;35:*.tga=01;35:*.xbm=01;35:*.xpm=01;35:*.tif=01;35:*.tiff=01;35:*.png=01;35:*.mov=01;35:*.mpg=01;35:*.mpeg=01;35:*.avi=01;35:*.fli=01;35:*.gl=01;35:*.dl=01;35:*.xcf=01;35:*.xwd=01;35:*.ogg=01;35:*.mp3=01;35:*.wav=01;35:*.xml=00;31:'

# Less colors for manpages
export LESS_TERMCAP_mb=$'\E[01;31m'
export LESS_TERMCAP_md=$'\E[01;31m'
export LESS_TERMCAP_me=$'\E[0m'
export LESS_TERMCAP_se=$'\E[0m'
export LESS_TERMCAP_so=$'\E[01;44;33m'
export LESS_TERMCAP_ue=$'\E[0m'
export LESS_TERMCAP_us=$'\E[01;32m'

# PATH additions
export PATH="$PATH:$HOME/.local/bin:$HOME/.cargo/bin:/var/lib/flatpak/exports/bin:/.local/share/flatpak/exports/bin:$HOME/Applications/depot_tools"

#######################################################
# SHELL OPTIONS
#######################################################

# Bash options
shopt -s checkwinsize
shopt -s histappend
PROMPT_COMMAND='history -a'

# Interactive shell bindings
if [[ $iatest -gt 0 ]]; then
    bind "set bell-style visible"
    bind "set completion-ignore-case on"
    bind "set show-all-if-ambiguous On"
fi

# Allow ctrl-S for history navigation
[[ $- == *i* ]] && stty -ixon

# Bind Ctrl+f to insert 'zi'
if [[ $- == *i* ]]; then
    bind '"\C-f":"zi\n"'
fi

#######################################################
# ALIASES
#######################################################

# Editor aliases
alias spico='sudo pico'
alias snano='sudo nano'
alias vi='nvim'
alias vim='nvim'
alias svi='sudo vi'
alias vis='nvim "+set si"'
alias n='nvim -O'

# Directory navigation
alias home='cd ~'
alias cd..='cd ..'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias ......='cd ../../../../..'
alias bd='cd "$OLDPWD"'
alias web='cd /var/www/html'

# Safe commands
alias cp='cp -i'
alias mv='mv -i'
alias rm='trash -v'
alias mkdir='mkdir -p'

# Enhanced commands
alias ps='ps auxf'
alias ping='ping -c 10'
alias less='less -R'
alias cls='clear'
alias multitail='multitail --no-repeat -c'
alias freshclam='sudo freshclam'

# Listing aliases (using exa)
alias ls='exa -al --color=always --group-directories-first --icons'
alias la='exa -a --color=always --group-directories-first --icons'
alias ll='exa -l --color=always --group-directories-first --icons'
alias lt='exa -aT --color=always --group-directories-first --icons'
alias l.='exa -a | egrep "^\."'

# Alternative ls aliases (fallback)
alias lx='ls -lXBh'               # sort by extension
alias lk='ls -lSrh'               # sort by size
alias lc='ls -ltcrh'              # sort by change time
alias lu='ls -lturh'              # sort by access time
alias lr='ls -lRh'                # recursive ls
alias lm='ls -alh |more'          # pipe through 'more'
alias lw='ls -xAh'                # wide listing format
alias labc='ls -lap'              # alphabetical sort
alias lf="ls -l | egrep -v '^d'"  # files only
alias ldir="ls -l | egrep '^d'"   # directories only

# System information
alias da='date "+%Y-%m-%d %A %T %Z"'
alias diskspace="du -S | sort -n -r |more"
alias folders='du -h --max-depth=1'
alias folderssort='find . -maxdepth 1 -type d -print0 | xargs -0 du -sk | sort -rn'
alias tree='tree -CAhF --dirsfirst'
alias treed='tree -CAFd'
alias mountedinfo='df -hT'
alias openports='netstat -nape --inet'
alias p="ps aux | grep "
alias topcpu="/bin/ps -eo pcpu,pid,user,args | sort -k 1 -r | head -10"
alias jctl="journalctl -p 3 -xb"

# Search aliases
alias h="history | grep "
alias f="find . | grep "
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# File operations
alias countfiles="for t in files links directories; do echo \`find . -type \${t:0:1} | wc -l\` \$t; done 2> /dev/null"
alias checkcommand="type -t"

# Archives
alias mktar='tar -cvf'
alias mkbz2='tar -cvjf'
alias mkgz='tar -cvzf'
alias untar='tar -xvf'
alias unbz2='tar -xvjf'
alias ungz='tar -xvzf'
alias tarnow='tar -acf '

# Permissions
alias mx='chmod a+x'
alias 000='chmod -R 000'
alias 644='chmod -R 644'
alias 666='chmod -R 666'
alias 755='chmod -R 755'
alias 777='chmod -R 777'

# Package management
alias apt-get='sudo apt-get'
alias aup="pamac upgrade --aur"
alias grubup="sudo update-grub"
alias big="expac -H M '%m\t%n' | sort -h | nl"
alias rip="expac --timefmt='%Y-%m-%d %T' '%l\t%n %v' | sort | tail -200 | nl"

# System control
alias rebootsafe='sudo shutdown -r now'
alias rebootforce='sudo shutdown -r -n now'
alias hug="systemctl --user restart hugo"
alias lanm="systemctl --user restart lan-mouse"

# Network
alias whatismyip="whatsmyip"
alias logs="sudo find /var/log -type f -exec file {} \; | grep 'text' | cut -d' ' -f1 | sed -e's/:$//g' | grep -v '[0-9]$' | xargs tail -f"

# Development
alias yayf="yay -Slq | fzf --multi --preview 'yay -Sii {1}' --preview-window=down:75% | xargs -ro yay -S"
alias kssh="kitty +kitten ssh"
alias docker-clean=' \
  docker container prune -f ; \
  docker image prune -f ; \
  docker network prune -f ; \
  docker volume prune -f '

# Utilities
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'
alias ebrc='edit ~/.bashrc'
alias hlp='less ~/.bashrc_help'
alias pbcopy='xclip -selection clipboard'
alias pbpaste='sleep 3; xdotool type "$(xclip -o -selection clipboard)"'
alias open=xdg-open
alias helpme='cht.sh --shell'
alias please='sudo'
alias tb='nc termbin.com 9999'
alias sha1='openssl sha1'
alias hw='hwinfo --short'
alias psmem='ps auxf | sort -nr -k 4'
alias psmem10='ps auxf | sort -nr -k 4 | head -10'

# yay fallback to paru
if ! command -v yay >/dev/null && command -v paru >/dev/null; then
    alias yay='paru --bottomup'
fi

# Use bat instead of cat (distribution-specific)
if [ "$(distribution)" = "redhat" ] || [ "$(distribution)" = "arch" ]; then
    alias cat='bat --style header --style rules --style snip --style changes --style header'
else
    alias cat='batcat --style header --style rules --style snip --style changes --style header'
fi

# Ripgrep fallback
if command -v rg &> /dev/null; then
    alias grep='rg'
else
    alias grep="/usr/bin/grep --color=auto"
fi

#######################################################
# STARTUP COMMANDS
#######################################################

# Initialize starship and zoxide
eval "$(starship init bash)"
eval "$(zoxide init bash)"

# Import wal colors
[ -f ~/.cache/wal/sequences ] && cat ~/.cache/wal/sequences

# Source profile
[ -f ~/.profile ] && . ~/.profile

# Source find-the-command
source /usr/share/doc/find-the-command/ftc.bash 2>/dev/null || true

# Auto start X on tty1
if [[ -z $DISPLAY ]] && [[ $(tty) = /dev/tty1 ]]; then
    exec startx
fi

# Ensure local bin in PATH
if [ -d "$HOME/.local/bin" ] && [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    export PATH="$HOME/.local/bin:$PATH"
fi
