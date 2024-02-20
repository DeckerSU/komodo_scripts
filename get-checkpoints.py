#!/usr/bin/env python3
#
# Copyright (c) 2013-2022 The Bitcoin Core developers
# Distributed under the MIT software license, see the accompanying
# file COPYING or http://www.opensource.org/licenses/mit-license.php.
#
# Copyright (c) 2023-2024 DeckerSU
#
# This script will retrieve checkpoints for an asset chain specified 
# in the first argument. Checkpoints will be captured every 'blocks_step' 
# blocks as defined in the settings. If the selected block for a checkpoint 
# is not a regular PoW block (i.e., an easy-mined block), then the script 
# will attempt to use the previous block instead.

from http.client import HTTPConnection
import json
import re
import base64
import sys
import os
import os.path
import struct

settings = {}

class BitcoinRPC:
    def __init__(self, host, port, username, password):
        authpair = "%s:%s" % (username, password)
        authpair = authpair.encode('utf-8')
        self.authhdr = b"Basic " + base64.b64encode(authpair)
        self.conn = HTTPConnection(host, port=port, timeout=30)

    def execute(self, obj):
        try:
            self.conn.request('POST', '/', json.dumps(obj),
                { 'Authorization' : self.authhdr,
                  'Content-type' : 'application/json' })
        except ConnectionRefusedError:
            print('RPC connection refused. Check RPC settings and the server status.',
                  file=sys.stderr)
            return None

        resp = self.conn.getresponse()
        if resp is None:
            print("JSON-RPC: no response", file=sys.stderr)
            return None

        body = resp.read().decode('utf-8')
        resp_obj = json.loads(body)
        return resp_obj

    @staticmethod
    def build_request(idx, method, params):
        obj = { 'version' : '1.1',
            'method' : method,
            'id' : idx }
        if params is None:
            obj['params'] = []
        else:
            obj['params'] = params
        return obj

    @staticmethod
    def response_is_error(resp_obj):
        return 'error' in resp_obj and resp_obj['error'] is not None

def parse_config():

    if settings['chain'] == 'KMD':
        config_file_path = os.path.join(os.environ['HOME'], '.komodo', 'komodo.conf')

    else:
        config_file_path = os.path.join(os.environ['HOME'], '.komodo', settings['chain'], f"{settings['chain']}.conf")

    try:
        # with open(config_file_path, 'r') as config_file:
        #     for line in config_file:
        #         key, value = map(str.strip, line.split('=', 1))
        #         if key in ['rpcuser', 'rpcpassword', 'rpcport']:
        #             settings[key] = value

        with open(config_file_path, encoding="utf8") as config_file:
            for line in config_file:
                # skip comment lines
                m = re.search(r'^\s*#', line)
                if m:
                    continue
                m = re.search(r'^(\w+)\s*=\s*(\S.*)$', line)
                if m is None:
                    continue
                if m.group(1) in ['rpcuser', 'rpcpassword', 'rpcport']:
                    settings[m.group(1)] = m.group(2)

        if 'host' not in settings:
            settings['host'] = '127.0.0.1'
        if 'rpcport' not in settings:
            settings['rpcport'] = 7771
        settings['rpcport'] = int(settings['rpcport'])
        settings['port'] = int(settings['rpcport']) - 1
        settings['port'] = int(settings['port'])

    except FileNotFoundError:
        print(f"Config file not found: {config_file_path}")
    except Exception as e:
        print(f"Error parsing config file: {str(e)}")

def deser_uint256(f):
    r = 0
    for i in range(8):
        t = struct.unpack("<I", f.read(4))[0]
        r += t << (i * 32)
    return r


def ser_uint256(u):
    rs = b""
    for _ in range(8):
        rs += struct.pack("<I", u & 0xFFFFFFFF)
        u >>= 32
    return rs


def uint256_from_str(s):
    if isinstance(s, str):
        s = bytes.fromhex(s)[::-1]
    r = 0
    t = struct.unpack("<IIIIIIII", s[:32])
    for i in range(8):
        r += t[i] << (i * 32)
    return r

def uint256_from_compact(c):
    if isinstance(c, str):
        c = int(c, 16)
    nbytes = (c >> 24) & 0xFF
    v = (c & 0xFFFFFF) << (8 * (nbytes - 3))
    return v

def get_blockheader(rpc, hash):
    blockheader = None
    reply = rpc.execute([rpc.build_request('test', 'getblockheader', [hash])])
    if reply is None:
        print('Cannot continue. Program will halt.')
        return None
    for resp_obj in reply:
        if rpc.response_is_error(resp_obj):
            print('JSON-RPC: error: ', resp_obj['error'], file=sys.stderr)
            sys.exit(1)
        blockheader = resp_obj['result']
    return blockheader

def get_blockhash(rpc, height):
    hash = None
    reply = rpc.execute([rpc.build_request('test', 'getblockhash', [height])])
    if reply is None:
        print('Cannot continue. Program will halt.')
        return None
    for resp_obj in reply:
        if rpc.response_is_error(resp_obj):
            print('JSON-RPC: error: ', resp_obj['error'], file=sys.stderr)
            sys.exit(1)
        hash = resp_obj['result']
    if hash is None:
        print(f'Cannot get block hash for height #{height}', file=sys.stderr)
        sys.exit(1)
    return hash

def get_checkpoints(settings):
    rpc = BitcoinRPC(settings['host'], settings['rpcport'], settings['rpcuser'], settings['rpcpassword'])

    best_block_hash = None
    height = None
    nbits = None

    reply = rpc.execute([rpc.build_request('test', 'getchaintxstats', [])])
    if reply is None:
        print('Cannot continue. Program will halt.')
        return None
    for resp_obj in reply:
        if rpc.response_is_error(resp_obj):
            print('JSON-RPC: error: ', resp_obj['error'], file=sys.stderr)
            sys.exit(1)
        result = resp_obj['result']
        txcount = result['txcount']
        timechain = result['time']
    
    if txcount is None:
        print('Cannot obtain chain stats.', file=sys.stderr)
        sys.exit(1)
            
    reply = rpc.execute([rpc.build_request('test', 'getbestblockhash', [])])
    if reply is None:
        print('Cannot continue. Program will halt.')
        return None
    for resp_obj in reply:
        if rpc.response_is_error(resp_obj):
            print('JSON-RPC: error: ', resp_obj['error'], file=sys.stderr)
            sys.exit(1)
        best_block_hash = resp_obj['result']
    
    if best_block_hash is None:
        print('Cannot obtain best block hash.', file=sys.stderr)
        sys.exit(1)

    print("Searching for the latest PoW block (not easy mined) ...", file=sys.stderr)
    while True:
        blockheader = get_blockheader(rpc, best_block_hash)
        height = blockheader['height']
        nbits = blockheader['bits']
        timestamp = blockheader['time']

        bits_value = uint256_from_compact(nbits)
        hash_value = uint256_from_str(best_block_hash)
        
        if hash_value > bits_value:
            best_block_hash = blockheader['previousblockhash']
        else:
            break

    max_height = height
    height = 0
    if settings['blocks_step'] is None:
        blocks_step = 50000
    else:
        blocks_step = settings['blocks_step']

    print(f"Height: {max_height}, Hash: {best_block_hash}", file=sys.stderr)

    print(f"checkpointData{settings['chain']} = {{\n" \
                   "            boost::assign::map_list_of")
    
    while height < max_height+1:
        hash = get_blockhash(rpc, height)
        while True:
            blockheader = get_blockheader(rpc, hash)
            height = blockheader['height']
            nbits = blockheader['bits']

            bits_value = uint256_from_compact(nbits)
            hash_value = uint256_from_str(hash)

            if height != 0 and hash_value > bits_value:
                hash = blockheader['previousblockhash']
            else:
                break
            
        print(f'            (	{height},	uint256S("0x{hash}"))')
        height = height + blocks_step

    print(f'            (	{max_height},	uint256S("0x{best_block_hash}")),')
    print(f'            {timestamp},     // * UNIX timestamp of last checkpoint block\n' \
          f'            {txcount},       // * total number of transactions between genesis and last checkpoint ({timechain})\n' \
           '                            //   (the tx=... number in the SetBestChain debug.log lines)\n' \
           '            2777            // * estimated number of transactions per day after checkpoint\n' \
           '                            //   total number of tx / (checkpoint block height / (24 * 24))\n' \
           '            };')

    
    
    # print(ser_uint256(uint256_from_compact(nbits))[::-1].hex())
    # print(ser_uint256(uint256_from_compact("200f0f0f"))[::-1].hex())
    # print(ser_uint256(uint256_from_str("0f0f0f0000000000000000000000000000000000000000000000000000000000")).hex())

if __name__ == '__main__':
    if len(sys.argv) != 2:
        print("Usage: get-checkpoints.py [acname]", file=sys.stderr)
        sys.exit(1)

settings['chain'] = sys.argv[1].upper()
settings['blocks_step'] = 50000

parse_config()
print(f"Settings: {settings}", file=sys.stderr)
get_checkpoints(settings)