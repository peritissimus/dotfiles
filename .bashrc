#
# ~/.bashrc
#

[[ $- != *i* ]] && return

# colors() {
# 	local fgc bgc vals seq0

# 	printf "Color escapes are %s\n" '\e[${value};...;${value}m'
# 	printf "Values 30..37 are \e[33mforeground colors\e[m\n"
# 	printf "Values 40..47 are \e[43mbackground colors\e[m\n"
# 	printf "Value  1 gives a  \e[1mbold-faced look\e[m\n\n"

# 	# foreground colors
# 	for fgc in {30..37}; do
# 		# background colors
# 		for bgc in {40..47}; do
# 			fgc=${fgc#37} # white
# 			bgc=${bgc#40} # black

# 			vals="${fgc:+$fgc;}${bgc}"
# 			vals=${vals%%;}

# 			seq0="${vals:+\e[${vals}m}"
# 			printf "  %-9s" "${seq0:-(default)}"
# 			printf " ${seq0}TEXT\e[m"
# 			printf " \e[${vals:+${vals+$vals;}}1mBOLD\e[m"
# 		done
# 		echo; echo
# 	done
# }

[ -r /usr/share/bash-completion/bash_completion ] && . /usr/share/bash-completion/bash_completion

use_color=true

# Set colorful PS1 only on colorful terminals.
# dircolors --print-database uses its own built-in database
# instead of using /etc/DIR_COLORS.  Try to use the external file
# first to take advantage of user additions.  Use internal bash
# globbing instead of external grep binary.
# safe_term=${TERM//[^[:alnum:]]/?}   # sanitize TERM
# match_lhs=""
# [[ -f ~/.dir_colors   ]] && match_lhs="${match_lhs}$(<~/.dir_colors)"
# [[ -f /etc/DIR_COLORS ]] && match_lhs="${match_lhs}$(</etc/DIR_COLORS)"
# [[ -z ${match_lhs}    ]] \
# 	&& type -P dircolors >/dev/null \
# 	&& match_lhs=$(dircolors --print-database)
# [[ $'\n'${match_lhs} == *$'\n'"TERM "${safe_term}* ]] && use_color=true


unset use_color
 # safe_term match_lhs sh

alias cp="cp -i"                          # confirm before overwriting something
alias df='df -h'                          # human-readable sizes
alias free='free -m'                      # show sizes in MB
alias np='nano -w PKGBUILD'
alias more=less
alias ls="ls -p -G"
alias la="ls -A"
alias ll="ls -l"
alias lla="ll -A"
alias gf="git fetch"
alias gp="git pull"
alias nrd="npm run dev"
#####################################################################################
#include gitpropmpt 
#source ~/.git-prompt.sh

# +-----------------+
# + Git Integration +
# +-----------------+
# +--- Dirty State ---+
# Show unstaged (*) and staged (+) changes.
# Also configurable per repository via "bash.showDirtyState".
GIT_PS1_SHOWDIRTYSTATE=true

# +--- Stash State ---+
# Show currently stashed ($) changes.
GIT_PS1_SHOWSTASHSTATE=false

# +--- Untracked Files ---+
# Show untracked (%) changes.
# Also configurable per repository via "bash.showUntrackedFiles".
GIT_PS1_SHOWUNTRACKEDFILES=true

# +--- Upstream Difference ---+
# Show indicator for difference between HEAD and its upstream.
#
# <  Behind upstream
# >  Ahead upstream
# <> Diverged upstream
# =  Equal upstream
#
# Control behaviour by setting to a space-separated list of values:
#   auto     Automatically show indicators
#   verbose  Show number of commits ahead/behind (+/-) upstream
#   name     If verbose, then also show the upstream abbrev name
#   legacy   Do not use the '--count' option available in recent versions of git-rev-list
#   git      Always compare HEAD to @{upstream}
#   svn      Always compare HEAD to your SVN upstream
#
# By default, __git_ps1 will compare HEAD to SVN upstream ('@{upstream}' if not available).
# Also configurable per repository via "bash.showUpstream".
GIT_PS1_SHOWUPSTREAM="auto verbose name"

# +--- Describe Style ---+
# Show more information about the identity of commits checked out as a detached HEAD.
#
# Control behaviour by setting to one of these values:
#   contains  Relative to newer annotated tag (v1.6.3.2~35)
#   branch    Relative to newer tag or branch (master~4)
#   describe  Relative to older annotated tag (v1.6.3.1-13-gdd42c2f)
#   default   Exactly matching tag
GIT_PS1_DESCRIBE_STYLE="contains"

# +--- Colored Hints ---+
# Show colored hints about the current dirty state. The colors are based on the colored output of "git status -sb".
# NOTE: Only available when using __git_ps1 for PROMPT_COMMAND!
GIT_PS1_SHOWCOLORHINTS=true

# +--- pwd Ignore ---+
# Disable __git_ps1 output when the current directory is set up to be ignored by git.
# Also configurable per repository via "bash.hideIfPwdIgnored".
GIT_PS1_HIDE_IF_PWD_IGNORED=false

function virtualenv_info(){
    # Get Virtual Env
    if [[ -n "$VIRTUAL_ENV" ]]; then
        # Strip out the path and just leave the env name
        venv="${VIRTUAL_ENV##*/}"
    else
        # In case you don't have one activated
        venv='0'
    fi
    [[ -n "$venv" ]] && echo "$venv"
}

export VIRTUAL_ENV_DISABLE_PROMPT=1
VENV="\$(virtualenv_info)";

#nodejs version
parse_git_branch() {
  if [ -n "$(git rev-parse --git-dir 2> /dev/null)" ]; then
    echo "$(git rev-parse --abbrev-ref HEAD)"
  fi
}

sps() {
    current_path=${PWD/#$HOME/'~'}
    if [ "$current_path" = "~" ]; then
       echo $current_path
    else
       path_parent=${current_path%\/*}
       path_parent_short=`echo $path_parent | sed -r 's|/(.)[^/]*|/\1|g'`
       directory=${current_path##*\/}
       echo "$path_parent_short/$directory"
    fi
}


compile_prompt () {
  local EXIT=$?
  local CONNECTBAR_DOWN=$'\u250C\u2500\u257C'
  local CONNECTBAR_UP=$'\u2514\u2500\u257C'
  local GITSPLITBAR=$'\u2570\u257C'
  local SPLITBAR=$'\u257E\u2500\u257C'
  local ARROW=$'\u25B6'
  local c_gray='\e[01;30m'
  local c_blue='\e[0;34m'
  local c_cyan='\e[0;36m'
  local c_reset='\e[0m'
  local c_yellow='\e[0;33m'
  local c_red='\e[0;31m'
  local c_green='\e[0;32m'
  local c_magenta='\e[0;35m'
  local c_white='\e[0;37m'

  # PS1="\n${c_blue}${VENV}${c_yellow}"
  # PS1+="$(sps)"
  # # PS1+="${c_green}${c_magenta}"
  # PS1+="${c_magenta}${c_red}${c_green} ${c_reset}"
  # # PS1=$(printf "%*s\r%s\$ " "$(tput cols)" '${c_green}[$(parse_git_branch)]''${c_yellow}\w${c_green}${c_magenta}${c_green} ${c_red}${c_yellow} ${c_reset}' )

  # > Connectbar Down
  # Format:
  #   (newline)(bright colors)(connectbar down)
  PS1="\n${c_gray}"
  PS1+="$CONNECTBAR_DOWN"

  # > Username
  # Format:
  #   (bracket open)(username)(bracket close)(splitbar)
  PS1+="[${c_blue}\u${c_gray}]"
  PS1+="$SPLITBAR"

  # > Jobs
  # Format:
  #   (bracket open)(jobs)(bracket close)(splitbar)
  PS1+="[${c_blue}${VENV}${c_gray}]"

  # > Exit Status
  # Format:
  #   (bracket open)(last exit status)(bracket close)(splitbar)
  PS1+="[${c_blue}${EXIT}${c_gray}]"
  PS1+="$SPLITBAR"

  # > Time
  # Format:
  #   (bracket open)(time)(bracket close)(newline)(connectbar up)
  PS1+="[${c_blue}\D{%H:%M:%S}${c_gray}]\n"
  PS1+="$CONNECTBAR_UP"

  # > Working Directory
  # Format:
  #   (bracket open)(working directory)(bracket close)(newline)
  PS1+="[${c_blue}\w${c_gray}]\n"

  # > Git
  # Format:
  #   (gitsplitbar)(bracket open)(git branch)(bracket close)(splitbar)
  #   (bracket open)(HEAD-SHA)(bracket close)
  #PS1+="$(__git_ps1 " \\u2570\\u257C[${c_cyan}%s${c_gray}]\\u257E\\u2500\\u257C[${c_cyan}$(git rev-parse --short HEAD 2> /dev/null)${c_gray}]")"
  # Append additional newline if in git repository
  #if [[ ! -z $(__git_ps1) ]]; then
   # PS1+='\n'
  #fi

  # > Arrow
  # NOTE: Color must be escaped with '\[\]' to fix the text overflow bug!
  # Format:
  #   (arrow)(color reset)
  PS1+="$ARROW \[\e[0m\]"
}

PROMPT_COMMAND='compile_prompt'

#####################################################################################

xhost +local:root > /dev/null 2>&1

# eval "$(starship init bash)"


# [[ $TERM != "screen" ]] && exec tmux
export GOROOT=/usr/lib/go
export GOPATH=$HOME/go
export PATH=$PATH:$GOROOT/bin:$GOPATH/bin

test -r "~/.dir_colors" && eval $(dircolors ~/.dir_colors)

PATH="/home/peritissimus/perl5/bin${PATH:+:${PATH}}"; export PATH;
PERL5LIB="/home/peritissimus/perl5/lib/perl5${PERL5LIB:+:${PERL5LIB}}"; export PERL5LIB;
PERL_LOCAL_LIB_ROOT="/home/peritissimus/perl5${PERL_LOCAL_LIB_ROOT:+:${PERL_LOCAL_LIB_ROOT}}"; export PERL_LOCAL_LIB_ROOT;
PERL_MB_OPT="--install_base \"/home/peritissimus/perl5\""; export PERL_MB_OPT;
PERL_MM_OPT="INSTALL_BASE=/home/peritissimus/perl5"; export PERL_MM_OPT;

#####################################################################################


export LC_ALL="en_US.UTF-8"
export EDITOR='nvim'
exec zsh


