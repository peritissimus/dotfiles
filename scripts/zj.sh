#!/usr/bin/env bash

# Zellij session manager (like tmuxinator)
# Usage: zj [command] [args]

ZELLIJ_LAYOUTS_DIR="$HOME/dotfiles/zellij/layouts"
ZELLIJ_PROJECTS_DIR="$HOME/dotfiles/zellij/projects"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Ensure projects directory exists
mkdir -p "$ZELLIJ_PROJECTS_DIR"

# Helper functions
log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# List available layouts
list_layouts() {
    echo -e "${BLUE}Available layouts:${NC}"
    for layout in "$ZELLIJ_LAYOUTS_DIR"/*.kdl; do
        if [ -f "$layout" ]; then
            basename "$layout" .kdl
        fi
    done
}

# List project configurations
list_projects() {
    echo -e "${BLUE}Available projects:${NC}"
    for project in "$ZELLIJ_PROJECTS_DIR"/*.kdl; do
        if [ -f "$project" ]; then
            basename "$project" .kdl
        fi
    done
}

# Create a new project configuration
new_project() {
    local name=$1
    local layout=${2:-dev}
    
    if [ -z "$name" ]; then
        error "Project name required"
        echo "Usage: zj new <project-name> [layout]"
        return 1
    fi
    
    local project_file="$ZELLIJ_PROJECTS_DIR/$name.kdl"
    
    if [ -f "$project_file" ]; then
        error "Project '$name' already exists"
        return 1
    fi
    
    # Create project configuration
    cat > "$project_file" << EOF
// Project: $name
// Created: $(date)

layout {
    cwd "$HOME/projects/$name"
    
    default_tab_template {
        children
        pane size=1 borderless=true {
            plugin location="zellij:tab-bar"
        }
    }
    
    tab name="editor" focus=true {
        pane split_direction="vertical" {
            pane size="70%" {
                command "nvim"
            }
            pane size="30%" split_direction="horizontal" {
                pane name="terminal"
                pane name="server"
            }
        }
    }
    
    tab name="git" {
        pane {
            command "lazygit"
        }
    }
    
    tab name="logs" {
        pane
    }
}
EOF
    
    success "Created project configuration: $name"
    echo "Edit $project_file to customize your layout"
}

# Edit a project configuration
edit_project() {
    local name=$1
    
    if [ -z "$name" ]; then
        error "Project name required"
        return 1
    fi
    
    local project_file="$ZELLIJ_PROJECTS_DIR/$name.kdl"
    
    if [ ! -f "$project_file" ]; then
        error "Project '$name' not found"
        return 1
    fi
    
    ${EDITOR:-nvim} "$project_file"
}

# Start or attach to a session
start_session() {
    local name=$1
    
    if [ -z "$name" ]; then
        # No name provided, show interactive selection
        echo -e "${BLUE}Select a session:${NC}"
        echo "1) New session with layout"
        echo "2) Project session"
        echo "3) Default session"
        read -p "Choice: " choice
        
        case $choice in
            1)
                list_layouts
                read -p "Layout name: " layout
                read -p "Session name: " session_name
                
                if [ -f "$ZELLIJ_LAYOUTS_DIR/$layout.kdl" ]; then
                    zellij --layout "$ZELLIJ_LAYOUTS_DIR/$layout.kdl" --session "$session_name"
                else
                    error "Layout '$layout' not found"
                fi
                ;;
            2)
                list_projects
                read -p "Project name: " project
                start_session "$project"
                ;;
            3)
                zellij
                ;;
        esac
        return
    fi
    
    # Check if it's a project
    local project_file="$ZELLIJ_PROJECTS_DIR/$name.kdl"
    if [ -f "$project_file" ]; then
        log "Starting project session: $name"
        zellij --layout "$project_file" --session "$name"
        return
    fi
    
    # Check if it's a layout
    local layout_file="$ZELLIJ_LAYOUTS_DIR/$name.kdl"
    if [ -f "$layout_file" ]; then
        log "Starting session with layout: $name"
        zellij --layout "$layout_file" --session "$name"
        return
    fi
    
    # Try to attach to existing session
    if zellij list-sessions 2>/dev/null | grep -q "^$name"; then
        log "Attaching to existing session: $name"
        zellij attach "$name"
    else
        log "Creating new session: $name"
        zellij --session "$name"
    fi
}

# Kill a session
kill_session() {
    local name=$1
    
    if [ -z "$name" ]; then
        error "Session name required"
        return 1
    fi
    
    zellij kill-session "$name"
    success "Killed session: $name"
}

# Main command handler
case "${1:-start}" in
    list|ls)
        zellij list-sessions
        ;;
    layouts)
        list_layouts
        ;;
    projects)
        list_projects
        ;;
    new)
        new_project "$2" "$3"
        ;;
    edit)
        edit_project "$2"
        ;;
    start|s)
        start_session "$2"
        ;;
    kill|k)
        kill_session "$2"
        ;;
    help|h)
        echo "Zellij session manager"
        echo ""
        echo "Usage: zj [command] [args]"
        echo ""
        echo "Commands:"
        echo "  list, ls         List active sessions"
        echo "  layouts          List available layouts"
        echo "  projects         List project configurations"
        echo "  new <name>       Create new project configuration"
        echo "  edit <name>      Edit project configuration"
        echo "  start, s <name>  Start or attach to session"
        echo "  kill, k <name>   Kill a session"
        echo "  help, h          Show this help"
        echo ""
        echo "Examples:"
        echo "  zj                    # Interactive session start"
        echo "  zj myproject          # Start/attach to 'myproject'"
        echo "  zj new webapp dev     # Create webapp project with dev layout"
        echo "  zj edit webapp        # Edit webapp configuration"
        ;;
    *)
        # Default to start session with given name
        start_session "$1"
        ;;
esac