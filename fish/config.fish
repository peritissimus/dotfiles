set fish_greeting

eval "$(/opt/homebrew/bin/brew shellenv)"

alias startenv=". .venv/bin/activate.fish"

if status is-interactive
    # Commands to run in interactive sessions can go here
end
