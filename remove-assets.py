#!/usr/bin/env python3
"""
Script to remove asset chain data from Komodo installation.
Scans $HOME/.komodo for asset chain folders and allows selective deletion.
"""

import os
import sys
import shutil
from pathlib import Path

# ANSI color codes
GREEN = '\033[92m'
RESET = '\033[0m'


def is_asset_chain_folder(folder_path):
    """
    Check if a folder is an asset chain folder.
    Criteria:
    - Folder name consists only of uppercase letters
    - Contains a .conf file with the same name as the folder
    """
    folder_name = folder_path.name
    
    # Check if folder name is all uppercase letters
    if not folder_name.isupper() or not folder_name.isalpha():
        return False
    
    # Check if .conf file exists with the same name
    conf_file = folder_path / f"{folder_name}.conf"
    return conf_file.exists()


def scan_asset_chains(komodo_dir):
    """
    Scan the Komodo directory for asset chain folders.
    Returns a list of Path objects for valid asset chain folders.
    """
    asset_chains = []
    
    if not komodo_dir.exists():
        print(f"Error: Komodo directory not found: {komodo_dir}")
        return asset_chains
    
    if not komodo_dir.is_dir():
        print(f"Error: {komodo_dir} is not a directory")
        return asset_chains
    
    # Scan all items in the Komodo directory
    for item in komodo_dir.iterdir():
        if item.is_dir() and is_asset_chain_folder(item):
            asset_chains.append(item)
    
    return sorted(asset_chains, key=lambda x: x.name)


def get_folder_size(folder_path):
    """
    Calculate the total size of a folder in bytes.
    """
    total_size = 0
    try:
        for dirpath, dirnames, filenames in os.walk(folder_path):
            for filename in filenames:
                filepath = os.path.join(dirpath, filename)
                try:
                    total_size += os.path.getsize(filepath)
                except (OSError, FileNotFoundError):
                    # Skip files that can't be accessed
                    pass
    except (OSError, PermissionError):
        # Return 0 if folder can't be accessed
        pass
    return total_size


def format_size(size_bytes):
    """
    Format size in bytes to human-readable format.
    """
    for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
        if size_bytes < 1024.0:
            return f"{size_bytes:.2f} {unit}"
        size_bytes /= 1024.0
    return f"{size_bytes:.2f} PB"


def display_asset_chains(asset_chains):
    """
    Display found asset chains as a numbered list with their sizes.
    Sizes less than 1 MB are displayed in green.
    """
    if not asset_chains:
        print("No asset chains found.")
        return
    
    print("\nFound asset chains:")
    print("-" * 70)
    for idx, chain in enumerate(asset_chains, start=1):
        size = get_folder_size(chain)
        size_str = format_size(size)
        
        # Colorize sizes less than 1 MB (1 * 1024 * 1024 bytes)
        if size < 1024 * 1024:
            size_str = f"{GREEN}{size_str}{RESET}"
        
        print(f"{idx}. {chain.name:<20} ({size_str})")
    print("-" * 70)


def get_items_to_delete(asset_chain_path):
    """
    Get lists of folders and files to delete for the selected asset chain.
    Returns tuple: (folders_to_delete, files_to_delete)
    """
    folders_to_delete = [
        "chainstate",
        "notarisations",
        "blocks"
    ]
    
    files_to_delete = [
        "debug.log",
        "fee_estimates.dat",
        "peers.dat",
        "komodoevents",
        "komodoevents.ind",
        "signedmasks",
        "banlist.dat",
        "db.log",
        ".lock"
    ]
    
    # Filter to only include items that actually exist
    existing_folders = []
    existing_files = []
    
    for folder in folders_to_delete:
        folder_path = asset_chain_path / folder
        if folder_path.exists() and folder_path.is_dir():
            existing_folders.append(folder_path)
    
    for file in files_to_delete:
        file_path = asset_chain_path / file
        if file_path.exists() and file_path.is_file():
            existing_files.append(file_path)
    
    return existing_folders, existing_files


def display_items_to_delete(asset_chain_name, folders, files):
    """
    Display what will be deleted.
    """
    print(f"\nThe following items will be deleted from {asset_chain_name}:")
    print("-" * 50)
    
    if folders:
        print("Folders:")
        for folder in folders:
            print(f"  - {folder.name}/")
    
    if files:
        print("\nFiles:")
        for file in files:
            print(f"  - {file.name}")
    
    if not folders and not files:
        print("No items found to delete.")
    
    print("-" * 50)


def delete_items(folders, files):
    """
    Delete the specified folders and files.
    """
    # Delete folders
    for folder in folders:
        try:
            shutil.rmtree(folder)
            print(f"Deleted folder: {folder.name}/")
        except Exception as e:
            print(f"Error deleting folder {folder.name}: {e}")
    
    # Delete files
    for file in files:
        try:
            file.unlink()
            print(f"Deleted file: {file.name}")
        except Exception as e:
            print(f"Error deleting file {file.name}: {e}")


def main():
    """
    Main function to run the asset chain removal script.
    """
    # Get Komodo directory path
    home_dir = Path.home()
    komodo_dir = home_dir / ".komodo"
    
    print("Scanning for asset chains in:", komodo_dir)
    
    # Scan for asset chains
    asset_chains = scan_asset_chains(komodo_dir)
    
    # Display found asset chains
    display_asset_chains(asset_chains)
    
    if not asset_chains:
        print("\nExiting. No asset chains to process.")
        sys.exit(0)
    
    # Get user selection
    while True:
        try:
            selection = input(f"\nEnter the number of the asset chain to remove (1-{len(asset_chains)}): ").strip()
            selection_num = int(selection)
            
            if 1 <= selection_num <= len(asset_chains):
                selected_chain = asset_chains[selection_num - 1]
                break
            else:
                print(f"Please enter a number between 1 and {len(asset_chains)}")
        except ValueError:
            print("Please enter a valid number")
        except KeyboardInterrupt:
            print("\n\nOperation cancelled by user.")
            sys.exit(0)
    
    # Get items to delete
    folders_to_delete, files_to_delete = get_items_to_delete(selected_chain)
    
    # Display what will be deleted
    display_items_to_delete(selected_chain.name, folders_to_delete, files_to_delete)
    
    if not folders_to_delete and not files_to_delete:
        print("\nNo items found to delete. Exiting.")
        sys.exit(0)
    
    # Warning and confirmation
    print("\n" + "!" * 50)
    print("WARNING: This operation is IRREVERSIBLE!")
    print("All selected folders and files will be permanently deleted.")
    print("!" * 50)
    
    while True:
        try:
            confirm = input("\nDo you want to proceed? (y/n): ").strip().lower()
            
            if confirm == 'y':
                print("\nDeleting items...")
                delete_items(folders_to_delete, files_to_delete)
                print("\nDeletion completed.")
                break
            elif confirm == 'n':
                print("\nOperation cancelled.")
                sys.exit(0)
            else:
                print("Please enter 'y' for yes or 'n' for no")
        except KeyboardInterrupt:
            print("\n\nOperation cancelled by user.")
            sys.exit(0)


if __name__ == "__main__":
    main()
