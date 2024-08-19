#!/usr/bin/env python3

# Calculates average blocks per day for last MAX_LOOK_BEFORE_DAYS days and estimates future block height.

import requests
from datetime import datetime, timedelta
import time

MAX_LOOK_BEFORE_DAYS = 100
FUTURE_TIMESTAMP = 1728049053; # dPoW Season 8, Fri Oct 4 2024 13:37:33 GMT+0000

def get_block_height(date_str):
    url = f"https://kmdexplorer.io/insight-api-komodo/blocks?blockDate={date_str}"
    response = requests.get(url)
    
    if response.status_code == 200:
        data = response.json()
        blocks = data.get("blocks", [])
        
        if blocks:
            first_block = blocks[0]
            height = first_block.get("height")
            return height
        else:
            return None
    else:
        return None

def main():
    block_heights = []
    blocks_per_day = []
    
    # Start from today
    datetime_now = datetime.now()
    current_date = datetime_now.strftime("%Y-%m-%d")
    
    # Get block heights for MAX_LOOK_BEFORE_DAYS
    for i in range(MAX_LOOK_BEFORE_DAYS):
        # Move to the previous day
        current_date = (datetime_now - timedelta(days=i+1)).strftime("%Y-%m-%d")
        print(f"Processing: {current_date} [{i}]")

        block_height = get_block_height(current_date)
        if block_height is not None:
            block_heights.append(block_height)
        # Pause for 1 second
        time.sleep(1)
    
    # Calculate blocks per day
    for i in range(1, len(block_heights)):
        blocks_per_day.append(block_heights[i-1] - block_heights[i])
    
    # Calculate the average, min, and max blocks per day
    if blocks_per_day:
        average_blocks_per_day = sum(blocks_per_day) / len(blocks_per_day)
        min_blocks_per_day = min(blocks_per_day)
        max_blocks_per_day = max(blocks_per_day)
    else:
        average_blocks_per_day = 0
        min_blocks_per_day = 0
        max_blocks_per_day = 0
    
    # Output the average, min, and max blocks per day
    print(f"Average blocks per day: {average_blocks_per_day}")
    print(f"Min blocks per day: {min_blocks_per_day}")
    print(f"Max blocks per day: {max_blocks_per_day}")
    
    # Estimate future block height
    future_datetime = datetime.utcfromtimestamp(FUTURE_TIMESTAMP)
    days_to_future = (future_datetime - datetime_now).days

    if block_heights:
        current_height = block_heights[0]  # Most recent block height
        estimated_future_height = int(current_height + (days_to_future * average_blocks_per_day))

        print(f"Current height: {current_height}")
        print(f"Days to future: {days_to_future}")
        print(f"Estimated block height at {future_datetime}: {estimated_future_height}")
    else:
        print("Insufficient data to estimate future block height.")

if __name__ == "__main__":
    main()
