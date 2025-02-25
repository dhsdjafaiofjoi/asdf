# asdf

A simple Python CLI tool that uses the Anthropic API to generate and execute bash commands.

The intention is to solve for "tip of my tongue" use cases in which you know what you want to happen, but you don't remember the names of the commands or the syntax.

Note: doesn't work with sudo.

## Installation

```
pip install git+https://github.com/dhsdjafaiofjoi/asdf.git
```
And then add your Anthropic API key to one of these locations (checked in order):
1. Environment variable: `ANTHROPIC_API_KEY`
2. File: `.anthropic_api_key` in current directory
3. File: `.anthropic_api_key` in home directory

API key can be obtained from: https://console.anthropic.com/settings/keys

## Example Usage

```
asdf print hello world
asdf write a grep command to recursively look for the string 'test' in the current dir and exclude the .venv and node_modules directory
asdf nmap command localhost to see if 8065 is open
```

## How it works

1. Your prompt is sent to the claude-3-7-sonnet-20250219 model via the Anthropic API
2. A bash command is generated and shown to you
3. If you type "YES", the command is executed
4. Any other response will:
   - Show an explanation of the command (if available)
   - Send your feedback to the API to get a revised command
   - Ask you again whether to execute the revised command


## Example Workflow
Confirm before running commands:
```
asdf write out hello world
Generated command: echo 'hello world'
Execute this command? Type YES to confirm, or anything else to revise:
YES
hello world
```
Run an ffmpeg command I can't remember.
```
asdf ffmpeg command to trim the video between the 21st and 150th second and change the audio to music.mp3
Generated command: ffmpeg -i input.mp4 -i music.mp3 -map 0:v -map 1:a -ss 00:00:21 -to 00:02:30 -c:v copy -shortest output.mp4
Execute this command? Type YES to confirm, or anything else to revise:
YES
```
Responding anything besides "yes" to interactively revise the command:
```
asdf portscan localhost to see if my nodejs project is online
Generated command: netstat -tulpn 2>/dev/null | grep LISTEN | grep -v '127.0.0.1' | grep -v '::1' || echo 'No listening ports found'
Execute this command? Type YES to confirm, or anything else to revise:
no let's use nmap
The user wants to use nmap to scan localhost for open ports, particularly to verify if a Node.js project is running. Node.js applications commonly run on ports like 3000, 8080, etc. Nmap is a powerful network scanning tool that can identify open ports. A basic nmap scan of localhost would work well for this purpose.
Generated command: nmap -p- localhost
Execute this command? Type YES to confirm, or anything else to revise:
it's probably on 3000 or 8065
The user wants to scan specific ports on localhost to check if their Node.js project is running. Since they mentioned it's likely on port 3000 or 8065, we can use nmap to scan just those specific ports instead of scanning all ports (-p-) which would be much slower. We'll use the -p flag to specify the ports 3000 and 8065.
Generated command: nmap -p 3000,8065 localhost
Execute this command? Type YES to confirm, or anything else to revise:
YES
Starting Nmap 7.94SVN ( https://nmap.org ) at 2025-02-24 18:39 PST
Nmap scan report for localhost (127.0.0.1)
Host is up (0.00011s latency).

PORT     STATE SERVICE
3000/tcp open  ppp
8065/tcp open  unknown

Nmap done: 1 IP address (1 host up) scanned in 0.03 seconds
```

## Inspiration
The goal of this project was to test the Claude code agent: https://docs.anthropic.com/en/docs/agents-and-tools/claude-code/overview

Here is the initial prompt that was used:
```
Making a simple python LLM utility called "asdf"

The idea is that it's installed with pip install github.com/dhsdjafaiofjoi/asdf, and used like this:

asdf "write a grep command to recursively look for the string 'test' in the current dir and exclude the .venv and node_modules directory"

or sudo asdf "restart nginx"

This calls the Anthropic API with the latest model and returns a .json, containing a bash command

If the user accepts the command with YES, it is executed. Any other response is sent back to the API as a message in the thread to return a revised command to run

Anthropic API key loaded with the following logic:
1. check os.environ.get("ANTHROPIC_API_KEY")
2. check .anthropic_api_key in current directory
3. check .anthropic_api_key in home directory (~)
```

Total spend on API credits: $3.88
Total duration (API): 15m 31.2s
Total duration (wall): 1h 57m 11.2s
