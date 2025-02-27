#!/bin/bash

# Function to get the Anthropic API key
get_api_key() {
    # Check environment variable
    if [ -n "$ANTHROPIC_API_KEY" ]; then
        echo "$ANTHROPIC_API_KEY"
        return 0
    fi
    
    # Check current directory
    if [ -f ".anthropic_api_key" ]; then
        cat ".anthropic_api_key" | tr -d '\n'
        return 0
    fi
    
    # Check home directory
    if [ -f "$HOME/.anthropic_api_key" ]; then
        cat "$HOME/.anthropic_api_key" | tr -d '\n'
        return 0
    fi
    
    return 1
}

# Function to call the Anthropic API and get a command
get_command() {
    local prompt="$1"
    local api_key
    
    api_key=$(get_api_key)
    if [ -z "$api_key" ]; then
        echo "Error: Anthropic API key not found. Please set the ANTHROPIC_API_KEY environment variable or create an .anthropic_api_key file." >&2
        return 1
    fi
    
    # Create properly escaped JSON payload for the API request
    local payload=$(jq -n \
        --arg model "claude-3-7-sonnet-20250219" \
        --arg max_tokens "1000" \
        --arg system "Assistant generates valid bash commands. Respond ONLY in JSON matching format: {\"thinking\": \"detailed thought process\", \"command\": \"bash command here\"}. The command should be a valid bash command that can be executed directly. Do not include any markdown formatting or code blocks in your response or text outside of the JSON brackets. Always output only as JSON." \
        --arg prompt "$prompt" \
        '{
            model: $model,
            max_tokens: $max_tokens | tonumber,
            system: $system,
            messages: [
                {role: "user", content: $prompt}
            ]
        }'
    )
    
    # Make API request using curl
    local response
    response=$(curl -s -X POST https://api.anthropic.com/v1/messages \
        -H "Content-Type: application/json" \
        -H "x-api-key: $api_key" \
        -H "anthropic-version: 2023-06-01" \
        --data "$payload")
    
    # Check if we got an error response
    if [[ "$response" == *"error"* ]]; then
        echo "API Error: $(echo "$response" | grep -o '"error":{[^}]*}' | sed 's/"error":/Error:/')" >&2
        return 1
    fi
    
    # Use jq to extract content from the response
    local content=$(echo "$response" | jq -r '.content[0].text' 2>/dev/null)
    
    if [ -z "$content" ]; then
        echo "Error: Failed to extract content from API response" >&2
        echo "DEBUG: Full response: $response" >&2
        return 1
    fi
    
    # Try to parse as JSON
    if [[ "$content" == *"{"* && "$content" == *"}"* ]]; then
        # Extract the JSON part
        local start_idx=$(echo "$content" | grep -b -o "{" | head -n 1 | cut -d: -f1)
        local end_idx=$(echo "$content" | grep -b -o "}" | tail -n 1 | cut -d: -f1)
        local json_str="${content:$start_idx:$((end_idx - start_idx + 1))}"
        
        
        # Use jq to extract thinking and command
        # Temporarily write to a file to avoid escaping issues
        echo "$json_str" > /tmp/asdf_response.json
        local thinking=$(jq -r '.thinking // ""' /tmp/asdf_response.json 2>/dev/null)
        local command=$(jq -r '.command // ""' /tmp/asdf_response.json 2>/dev/null)
        rm /tmp/asdf_response.json
        
        echo "THINKING:$thinking"
        echo "COMMAND:$command"
    else
        # If not JSON, use the content as the command
        echo "DEBUG: No JSON found, using content as command" >&2
        echo "COMMAND:$content"
    fi
}

# Function to show help
show_help() {
    cat <<EOF
Usage: asdf your prompt here

A simple CLI tool that uses the Anthropic API to generate and execute bash commands.

Options:
  --help     Show this help message and exit

Examples:
  asdf write a grep command to recursively look for the string 'test'
  sudo asdf restart nginx

Authentication:
  Your Anthropic API key will be loaded from one of these locations (in order):
  1. Environment variable: ANTHROPIC_API_KEY
  2. File: .anthropic_api_key in current directory
  3. File: .anthropic_api_key in home directory
EOF
}

# Main function to handle the asdf command
asdf() {
    if [ $# -eq 0 ]; then
        show_help
        return 1
    fi
    
    if [ "$1" = "--help" ]; then
        show_help
        return 0
    fi
    
    # Concatenate all arguments as the prompt
    local prompt="$*"
    
    # Get the initial command
    local response
    response=$(get_command "$prompt")
    
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    local thinking=$(echo "$response" | grep "^THINKING:" | sed 's/^THINKING://')
    local command=$(echo "$response" | grep "^COMMAND:" | sed 's/^COMMAND://')
    
    if [ -z "$command" ]; then
        echo "Error: Could not generate a valid command." >&2
        return 1
    fi
    
    # Flag to track if we're revising
    local revising=false
    
    while true; do
        # Show thinking if we're revising
        if $revising && [ -n "$thinking" ]; then
            echo "$thinking"
        fi
        
        echo "Generated command: $command"
        echo "Execute this command? Type YES to confirm, or anything else to revise:"
        
        read -r user_input
        
        if [ "$user_input" = "YES" ]; then
            eval "$command"
            return $?
        else
            # Set revising to true for next iteration
            revising=true
            
            # Get revised command
            local revised_prompt="$prompt
The initial command was: $command
User feedback: $user_input
Please provide a revised command."
            
            response=$(get_command "$revised_prompt")
            
            if [ $? -ne 0 ]; then
                return 1
            fi
            
            thinking=$(echo "$response" | grep "^THINKING:" | sed 's/^THINKING://')
            command=$(echo "$response" | grep "^COMMAND:" | sed 's/^COMMAND://')
            
            if [ -z "$command" ]; then
                echo "Error: Could not generate a valid revised command." >&2
                return 1
            fi
        fi
    done
}

# If the script is executed directly (not sourced), show an error
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Error: This script should be sourced, not executed directly."
    echo "Please use: source asdf.sh"
    exit 1
fi

echo "asdf function loaded. Use 'asdf your prompt here' to generate commands."
