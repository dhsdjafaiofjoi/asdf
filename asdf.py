#!/usr/bin/env python3
import os
import sys
import json
import subprocess
import anthropic
import re
from collections import OrderedDict

def get_api_key():
    # Check environment variable
    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if api_key:
        return api_key
    
    # Check current directory
    try:
        with open('.anthropic_api_key', 'r') as f:
            api_key = f.read().strip()
            if api_key:
                return api_key
    except FileNotFoundError:
        pass
    
    # Check home directory
    try:
        home_dir = os.path.expanduser("~")
        with open(os.path.join(home_dir, '.anthropic_api_key'), 'r') as f:
            api_key = f.read().strip()
            if api_key:
                return api_key
    except FileNotFoundError:
        pass
    
    return None

def get_command(prompt, explain=False):
    api_key = get_api_key()
    if not api_key:
        print("Error: Anthropic API key not found. Please set the ANTHROPIC_API_KEY environment variable or create an .anthropic_api_key file.")
        sys.exit(1)
    
    client = anthropic.Anthropic(api_key=api_key)
    
    system_prompt = """Assistant generates valid bash commands. 
    
Respond ONLY in JSON matching format: {"thinking": "detailed thought process", "command": "bash command here"}

The command should be a valid bash command that can be executed directly.

Do not include any markdown formatting or code blocks in your response or text outside of the JSON brackets.

Always output only as JSON.
"""
    
    try:
        message = client.messages.create(
            model="claude-3-7-sonnet-20250219",
            max_tokens=1000,
            system=system_prompt,
            messages=[
                {"role": "user", "content": prompt}
            ]
        )
        
        response_content = message.content[0].text.strip()
        
        # Simple JSON extraction - find everything between the first { and the last }
        if '{' in response_content and '}' in response_content:
            start_idx = response_content.find('{')
            end_idx = response_content.rfind('}') + 1
            json_str = response_content[start_idx:end_idx]
            
            try:
                response_json = json.loads(json_str, strict=False)
                return {
                    "thinking": response_json.get("thinking", ""),
                    "command": response_json.get("command", "")
                }
            except json.JSONDecodeError:
                # If JSON parsing fails, just give up and have caller print full response
                return {"thinking": "", "command": response_content}
        else: 
            # If JSON parsing fails, just give up and have caller print full response
            return {"thinking": "", "command": response_content}
        
    except Exception as e:
        print(f"Error calling Anthropic API: {e}")
        sys.exit(1)

def show_help():
    print("""Usage: asdf your prompt here

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
  3. File: .anthropic_api_key in home directory""")

def execute_command(command):
    """Execute a command and return the result"""
    try:
        # Execute the command
        # Don't use check=True so we don't raise an exception on non-zero exit codes
        result = subprocess.run(command, shell=True, text=True, capture_output=True)
        print(result.stdout, end="")
        if result.stderr:
            print(result.stderr, file=sys.stderr, end="")
        # Return the exit code
        return result.returncode
    except Exception as e:
        print(f"Error executing command: {e}")
        return 1

def main():
    if len(sys.argv) < 2:
        show_help()
        sys.exit(1)
    
    if sys.argv[1] == "--help":
        show_help()
        sys.exit(0)
    
    # Concatenate all arguments after the command name
    prompt = " ".join(sys.argv[1:])
    
    # Get the initial command
    current_response = get_command(prompt)
    command = current_response.get("command", "")
    
    if not command:
        print("Error: Could not generate a valid command.")
        sys.exit(1)
    
    # Flag to track if we're revising
    revising = False
    
    while True:
        # Show thinking if we're revising (not on first revision)
        if (revising and "thinking" in current_response):
            print(current_response["thinking"])
        print(f"Generated command: {command}")
        print("Execute this command? Type YES to confirm, or anything else to revise:")

        try:
            user_input = input()
            
            if user_input.strip().upper() == "YES":
                exit_code = execute_command(command)
                sys.exit(exit_code)
            else:
                # Set revising to true for next iteration
                revising = True
                
                # Get revised command
                revised_prompt = f"{prompt}\nThe initial command was: {command}\nUser feedback: {user_input}\nPlease provide a revised command."
                current_response = get_command(revised_prompt)
                command = current_response.get("command", "")
                
                if not command:
                    print("Error: Could not generate a valid revised command.")
                    sys.exit(1)
                
        except EOFError:
            print("\nInput was interrupted. Command not executed.")
            sys.exit(1)

if __name__ == "__main__":
    main()
