function startenv --description 'Initialize project environment'
    # This is a placeholder for the startenv command used in your tmuxinator configs
    # Replace this with your actual environment initialization logic
    
    # Example: Load project-specific environment variables
    if test -f .env
        export (cat .env | grep -v '^#' | xargs)
    end
    
    # Example: Activate virtual environment if exists
    if test -f venv/bin/activate
        source venv/bin/activate
    else if test -f .venv/bin/activate
        source .venv/bin/activate
    end
    
    # Example: Load project-specific aliases
    if test -f .aliases
        source .aliases
    end
    
    # Return success
    return 0
end