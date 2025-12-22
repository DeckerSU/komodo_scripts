#!/usr/bin/env python3
"""
Script to gracefully stop and optionally restart all komodod/komodo-qt processes.

Copyright (c) Decker, 2025
Created with AI assistance (Cursor AI - Auto agent router)
"""

import os
import re
import sys
import time
import subprocess
import json
import shlex
from datetime import datetime
from typing import List, Dict, Optional

# ANSI color codes
YELLOW = '\033[33m'
GRAY = '\033[90m'
RED = '\033[31m'
RESET = '\033[0m'

# Configuration
RESTART_INTERVAL = 10  # Seconds to wait between daemon restarts


class DaemonInfo:
    """Stores information about a running daemon process."""
    
    def __init__(self, pid: int, binary: str, args: str, cwd: str):
        self.pid = pid
        self.binary = binary
        self.args = args
        self.cwd = cwd
        self.ac_name: Optional[str] = None
        self.datadir: Optional[str] = None
        self.conf: Optional[str] = None
        self.config_path: Optional[str] = None
        self.rpcuser: Optional[str] = None
        self.rpcpassword: Optional[str] = None
        self.rpcport: Optional[str] = None
        self.rpcbind: Optional[str] = None
        
    def __repr__(self):
        return f"DaemonInfo(pid={self.pid}, binary={self.binary}, ac_name={self.ac_name})"


def find_komodo_processes() -> List[DaemonInfo]:
    """
    Find all running komodod or komodo-qt processes and extract their information.
    
    Returns:
        List of DaemonInfo objects containing process information.
    """
    daemons = []
    
    try:
        # Use ps to get process information
        result = subprocess.run(
            ['ps', 'ax', '-o', 'pid,command'],
            capture_output=True,
            text=True,
            check=True
        )
        
        for line in result.stdout.split('\n'):
            # Match komodod or komodo-qt processes
            if 'komodod' in line or 'komodo-qt' in line:
                # Skip grep process itself
                if '[komodod]' in line or '[komodo-qt]' in line:
                    continue
                    
                # Extract PID and command
                match = re.match(r'^\s*(\d+)\s+(.+)', line)
                if match:
                    pid = int(match.group(1))
                    full_cmd = match.group(2)
                    
                    # Extract binary path (first word)
                    parts = full_cmd.split()
                    if not parts:
                        continue
                        
                    binary = parts[0]
                    args = ' '.join(parts[1:]) if len(parts) > 1 else ''
                    
                    # Get actual executable path from /proc/PID/exe (more reliable)
                    try:
                        actual_binary = os.readlink(f'/proc/{pid}/exe')
                        if actual_binary:
                            # Check if binary was deleted
                            if actual_binary.endswith(' (deleted)'):
                                binary = actual_binary[:-10]  # Remove " (deleted)"
                                print(f"{RED}Warning: Binary was deleted for PID {pid}: {binary}{RESET}", file=sys.stderr)
                            else:
                                binary = actual_binary
                    except (OSError, FileNotFoundError):
                        # Fallback to parsed binary if /proc/PID/exe is not available
                        pass
                    
                    # Get working directory from /proc/PID/cwd
                    try:
                        cwd = os.readlink(f'/proc/{pid}/cwd')
                    except (OSError, FileNotFoundError):
                        cwd = os.getcwd()
                    
                    daemon = DaemonInfo(pid, binary, args, cwd)
                    
                    # Parse arguments
                    daemon.ac_name = extract_arg_value(args, '-ac_name')
                    daemon.datadir = extract_arg_value(args, '-datadir')
                    daemon.conf = extract_arg_value(args, '-conf')
                    
                    daemons.append(daemon)
                    
    except subprocess.CalledProcessError as e:
        print(f"Error finding processes: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Unexpected error: {e}", file=sys.stderr)
        sys.exit(1)
    
    return daemons


def extract_arg_value(args: str, arg_name: str) -> Optional[str]:
    """
    Extract value from command line arguments.
    Handles both -arg=value and -arg value formats, including quoted values.
    
    Args:
        args: Command line arguments string
        arg_name: Argument name to extract (e.g., '-ac_name')
        
    Returns:
        Argument value or None if not found
    """
    # Pattern to match -arg=value (handles quoted and unquoted values)
    pattern1 = rf'{re.escape(arg_name)}=([^\s"\'=]+|"[^"]*"|\'[^\']*\')'
    match = re.search(pattern1, args)
    if match:
        value = match.group(1)
        # Remove quotes if present
        return value.strip('"\'')
    
    # Pattern to match -arg value (space separated, handles quoted values)
    pattern2 = rf'{re.escape(arg_name)}\s+([^\s"\'=]+|"[^"]*"|\'[^\']*\')'
    match = re.search(pattern2, args)
    if match:
        value = match.group(1)
        # Remove quotes if present
        return value.strip('"\'')
    
    return None


def determine_config_path(daemon: DaemonInfo) -> str:
    """
    Determine the configuration file path based on daemon arguments.
    
    Args:
        daemon: DaemonInfo object with parsed arguments
        
    Returns:
        Path to configuration file
    """
    home = os.path.expanduser('~')
    
    # If -conf is specified, use it directly
    if daemon.conf:
        return os.path.expanduser(daemon.conf)
    
    # Determine base directory
    if daemon.datadir:
        base_dir = os.path.expanduser(daemon.datadir)
    elif daemon.ac_name:
        base_dir = os.path.join(home, '.komodo', daemon.ac_name)
    else:
        base_dir = os.path.join(home, '.komodo')
    
    # Determine config filename
    if daemon.ac_name:
        config_file = f'{daemon.ac_name}.conf'
    else:
        config_file = 'komodo.conf'
    
    return os.path.join(base_dir, config_file)


def read_config(config_path: str) -> Dict[str, Optional[str]]:
    """
    Read configuration file and extract RPC settings.
    
    Args:
        config_path: Path to configuration file
        
    Returns:
        Dictionary with rpcuser, rpcpassword, rpcport, rpcbind
    """
    config = {
        'rpcuser': None,
        'rpcpassword': None,
        'rpcport': None,
        'rpcbind': None
    }
    
    if not os.path.exists(config_path):
        print(f"Warning: Config file not found: {config_path}")
        return config
    
    try:
        # Read config file line by line (not using ConfigParser as komodo.conf format is simple)
        with open(config_path, 'r') as f:
            for line in f:
                line = line.strip()
                # Skip comments and empty lines
                if not line or line.startswith('#'):
                    continue
                
                # Parse key=value format
                if '=' in line:
                    key, value = line.split('=', 1)
                    key = key.strip()
                    value = value.strip()
                    
                    if key in config:
                        config[key] = value
                        
    except Exception as e:
        print(f"Error reading config file {config_path}: {e}", file=sys.stderr)
    
    return config


def stop_daemon(daemon: DaemonInfo) -> bool:
    """
    Stop a daemon using RPC stop command via curl.
    
    Args:
        daemon: DaemonInfo object with RPC credentials
        
    Returns:
        True if successful, False otherwise
    """
    if not daemon.rpcport:
        print(f"Warning: No RPC port found for PID {daemon.pid}, skipping RPC stop")
        return False
    
    # Use 127.0.0.1 if rpcbind is not specified
    rpcbind = daemon.rpcbind if daemon.rpcbind else '127.0.0.1'
    
    url = f'http://{rpcbind}:{daemon.rpcport}/'
    
    # Prepare RPC request
    payload = {
        "jsonrpc": "1.0",
        "id": "curltest",
        "method": "stop",
        "params": []
    }
    
    try:
        # Build curl command
        curl_cmd = ['curl']
        
        # Add authentication if credentials are available
        if daemon.rpcuser and daemon.rpcpassword:
            curl_cmd.extend(['--user', f'{daemon.rpcuser}:{daemon.rpcpassword}'])
        
        curl_cmd.extend([
            '--data-binary', json.dumps(payload),
            '-H', 'content-type: text/plain;',
            url
        ])
        
        # Display curl command in gray color
        # Format command for display (quote arguments with spaces or special chars)
        curl_cmd_display = []
        for arg in curl_cmd:
            if ' ' in arg or any(c in arg for c in ['&', '|', ';', '(', ')', '<', '>']):
                curl_cmd_display.append(f"'{arg}'")
            else:
                curl_cmd_display.append(arg)
        curl_cmd_str = ' '.join(curl_cmd_display)
        print(f"{GRAY}  {curl_cmd_str}{RESET}")
        
        result = subprocess.run(
            curl_cmd,
            capture_output=True,
            text=True,
            timeout=10
        )
        
        if result.returncode == 0:
            print(f"Successfully sent stop command to PID {daemon.pid} ({daemon.ac_name or 'KMD'})")
            return True
        else:
            print(f"Warning: RPC stop failed for PID {daemon.pid}: {result.stderr}")
            return False
            
    except subprocess.TimeoutExpired:
        print(f"Error: Timeout stopping daemon PID {daemon.pid}", file=sys.stderr)
        return False
    except Exception as e:
        print(f"Error stopping daemon PID {daemon.pid}: {e}", file=sys.stderr)
        return False


def is_process_running(pid: int) -> bool:
    """
    Check if a process is still running by checking /proc/PID/ directory.
    More reliable than os.kill() as it checks actual process existence.
    Also verifies it's still a komodod/komodo-qt process (not a reused PID).
    
    Args:
        pid: Process ID to check
        
    Returns:
        True if process is running, False otherwise
    """
    proc_path = f'/proc/{pid}'
    if not os.path.exists(proc_path):
        return False
    
    # Verify it's still the same process (not a reused PID)
    # by checking the command name via ps
    try:
        result = subprocess.run(
            ['ps', '-p', str(pid), '-o', 'comm='],
            capture_output=True,
            text=True,
            timeout=2
        )
        if result.returncode == 0 and result.stdout.strip():
            comm = result.stdout.strip()
            if 'komodod' in comm or 'komodo-qt' in comm:
                return True
    except (subprocess.TimeoutExpired, subprocess.CalledProcessError, FileNotFoundError):
        # If ps fails, fall back to checking if /proc/PID/stat exists
        # (process might be in zombie state)
        if os.path.exists(f'/proc/{pid}/stat'):
            # Process entry exists, assume it's still running
            return True
    
    return False


def wait_for_processes(daemons: List[DaemonInfo], timeout: int = 300) -> bool:
    """
    Wait for all processes to terminate.
    
    Args:
        daemons: List of DaemonInfo objects
        timeout: Maximum time to wait in seconds
        
    Returns:
        True if all processes terminated, False if timeout
    """
    start_time = time.time()
    remaining_pids = {d.pid for d in daemons}
    
    print(f"\nWaiting for {len(remaining_pids)} process(es) to terminate...")
    
    while remaining_pids and (time.time() - start_time) < timeout:
        still_running = set()
        
        for pid in remaining_pids:
            if is_process_running(pid):
                still_running.add(pid)
        
        if still_running:
            remaining_pids = still_running
            print(f"Still waiting for {len(remaining_pids)} process(es): {remaining_pids}")
            time.sleep(2)
        else:
            remaining_pids = set()
    
    if remaining_pids:
        print(f"Warning: {len(remaining_pids)} process(es) did not terminate within timeout: {remaining_pids}")
        return False
    
    print("All processes have terminated.")
    return True


def restart_daemon(daemon: DaemonInfo, index: int, total: int) -> bool:
    """
    Restart a daemon process.
    
    Args:
        daemon: DaemonInfo object with process information
        index: Current daemon index (1-based)
        total: Total number of daemons to restart
        
    Returns:
        True if successful, False otherwise
    """
    name = daemon.ac_name or 'KMD'
    print(f"\nRestarting daemon {index}/{total}: {YELLOW}{name}{RESET}")
    print(f"  Working directory: {GRAY}{daemon.cwd}{RESET}")
    print(f"  Binary: {GRAY}{daemon.binary}{RESET}")
    args_display = daemon.args if daemon.args else "(no arguments)"
    print(f"  Arguments: {GRAY}{args_display}{RESET}")
    
    # Build command - use shlex.split to properly handle quoted arguments
    cmd = [daemon.binary]
    if daemon.args:
        try:
            cmd.extend(shlex.split(daemon.args))
        except ValueError:
            # Fallback to simple split if shlex fails
            cmd.extend(daemon.args.split())
    
    try:
        # Start process in background
        process = subprocess.Popen(
            cmd,
            cwd=daemon.cwd,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True
        )
        
        print(f"  Started with PID {process.pid}")
        return True
        
    except Exception as e:
        print(f"  Error restarting daemon: {e}", file=sys.stderr)
        return False


def create_restart_script(daemons: List[DaemonInfo], script_path: str) -> bool:
    """
    Create a shell script to restart all daemons.
    
    Args:
        daemons: List of DaemonInfo objects
        script_path: Path where to create the script
        
    Returns:
        True if successful, False otherwise
    """
    try:
        with open(script_path, 'w') as f:
            f.write("#!/bin/bash\n")
            f.write("# Auto-generated restart script\n")
            f.write("# Created by restart_daemons.py\n\n")
            
            for i, daemon in enumerate(daemons):
                if i > 0:
                    f.write(f"sleep {RESTART_INTERVAL}\n\n")
                
                name = daemon.ac_name or 'KMD'
                f.write(f"# Restart {name} (original PID: {daemon.pid})\n")
                f.write(f"cd {daemon.cwd}\n")
                
                cmd = daemon.binary
                if daemon.args:
                    cmd = f"{cmd} {daemon.args}"
                
                f.write(f"{cmd} &\n")
                f.write("echo \"Started " + name + " in background\"\n\n")
        
        # Make script executable
        os.chmod(script_path, 0o755)
        
        # print(f"Restart script created: {script_path}")
        return True
        
    except Exception as e:
        print(f"Error creating restart script: {e}", file=sys.stderr)
        return False


def main():
    """Main function."""
    print("=" * 60)
    print("Komodo Daemon Restart Script")
    print("=" * 60)
    
    # Step 1: Find all komodo processes
    print("\n[Step 1] Finding komodod/komodo-qt processes...")
    daemons = find_komodo_processes()
    
    if not daemons:
        print("No komodod or komodo-qt processes found.")
        return
    
    print(f"Found {len(daemons)} process(es):")
    for i, daemon in enumerate(daemons):
        name = daemon.ac_name or 'KMD'
        print(f"\n  Process {i + 1}/{len(daemons)}: PID {daemon.pid} - {YELLOW}{name}{RESET}")
        print(f"    Working directory: {GRAY}{daemon.cwd}{RESET}")
        print(f"    Binary: {GRAY}{daemon.binary}{RESET}")
        args_display = daemon.args if daemon.args else "(no arguments)"
        print(f"    Arguments: {GRAY}{args_display}{RESET}")
    
    # Step 2: Determine config files and read RPC settings
    print("\n[Step 2] Reading configuration files...")
    for daemon in daemons:
        daemon.config_path = determine_config_path(daemon)
        print(f"  PID {daemon.pid}: config = {daemon.config_path}")
        
        config = read_config(daemon.config_path)
        daemon.rpcuser = config['rpcuser']
        daemon.rpcpassword = config['rpcpassword']
        daemon.rpcport = config['rpcport']
        daemon.rpcbind = config['rpcbind']
        
        if not daemon.rpcport:
            # Use default port 7771 for KMD if RPC port is not found in config
            if not daemon.ac_name or daemon.ac_name == 'KMD':
                daemon.rpcport = '7771'
                print(f"    No RPC port found in config for PID {daemon.pid}, using default port 7771 for KMD")
            else:
                print(f"    Warning: No RPC port found in config for PID {daemon.pid}")
    
    # Step 3: Ask for confirmation before stopping
    print("\n[Step 3] Confirmation required before stopping daemons...")
    print("\nThe following daemon(s) will be stopped:")
    for daemon in daemons:
        name = daemon.ac_name or 'KMD'
        print(f"  - {YELLOW}{name}{RESET} (PID {daemon.pid})")
    
    while True:
        confirm = input("\nDo you want to proceed with stopping all daemons? (yes/no): ").strip().lower()
        if confirm in ['yes', 'y']:
            break
        elif confirm in ['no', 'n']:
            print("Aborted by user. Exiting.")
            return
        else:
            print("Please enter 'yes' or 'no'.")
    
    # Step 4: Stop all daemons via RPC
    print("\n[Step 4] Stopping daemons via RPC...")
    for daemon in daemons:
        if daemon.rpcport:
            stop_daemon(daemon)
        else:
            print(f"Skipping PID {daemon.pid} (no RPC port configured)")
    
    # Step 5: Wait for processes to terminate
    print("\n[Step 5] Waiting for processes to terminate...")
    wait_for_processes(daemons)
    
    # Step 6: Ask user what to do
    print("\n[Step 6] All daemons stopped.")
    print("\nWhat would you like to do?")
    print(f"  1. Restart all daemons now (with {RESTART_INTERVAL} second intervals)")
    print("  2. Create a shell script to restart daemons later")
    print("  3. Exit without restarting")
    
    while True:
        choice = input("\nEnter your choice (1-3): ").strip()
        
        if choice == '1':
            print("\nRestarting daemons...")
            total = len(daemons)
            for i, daemon in enumerate(daemons):
                if i > 0:
                    print(f"\nWaiting {RESTART_INTERVAL} seconds before next restart...")
                    time.sleep(RESTART_INTERVAL)
                restart_daemon(daemon, i + 1, total)
            print("\n\nAll daemons have been restarted.")
            break
            
        elif choice == '2':
            # Generate unique filename with timestamp
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            script_filename = f'restart_daemons_{timestamp}.sh'
            script_path = os.path.join(os.path.dirname(__file__), script_filename)
            if create_restart_script(daemons, script_path):
                print(f"\nRestart script created: {script_path}")
                print(f"You can run it later with: ./{script_filename}")
            break
            
        elif choice == '3':
            print("Exiting without restarting.")
            break
            
        else:
            print("Invalid choice. Please enter 1, 2, or 3.")


if __name__ == '__main__':
    main()

