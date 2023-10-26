#!/bin/bash
# 2018-01-26 03:34:38 UpdateTip: new best=0000243296b9b26c040f471fdd9398ef72e57062cf05c19b9ba2fefac8165306  height=681777  log2_work=46.821454  tx=1253783  date=2018-01-26 00:02:07 progress=0.999648  cache=0.8MiB(1525tx)
# 2019-11-13 00:15:04 UpdateTip: new best=049140623cc54a4a3d5868f720611e180ba0cafa21eab1edd0bc9ec2e6b7c374  height=1615921  log2_work=50.75492  log2_stake=-inf  tx=7371665  date=2019-11-13 00:15:04 progress=1.000000  cache=5.5MiB(10794tx)
echo '        checkpointData = (Checkpoints::CCheckpointData)
        {
            boost::assign::map_list_of
'
for height in {0..3648244..50000}
do
	block_hash=$(./komodo-cli getblockhash $height)
	block=$(./komodo-cli getblock $block_hash)	
	#echo $block
	time=$(echo $block | grep -Po '"time": \K\w+')
	#echo $time
	hash=$(echo $block | grep -Po '"hash": "\K\w+')
	#echo $hash
	bits=$(echo $block | grep -Po '"bits": "\K\w+')
	#echo $bits
	#echo '{      0, "000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f", 1231006505, 0x1d00ffff },'
	#echo -e '{\t'$height',\t "'$hash'", '$time', 0x'$bits' },'
	# (15000, uint256S("0x00f0bd236790e903321a2d22f85bd6bf8a505f6ef4eddb20458a65d37e14d142")),
	if [ $height == 0 ] 
	then
		echo '            (0, consensus.hashGenesisBlock)'
	else
		echo -e '            (\t'$height',\tuint256S("0x'$hash'"))'
	fi
done
# request last block again
#
height=3648244

	block_hash=$(./komodo-cli getblockhash $height)
	block=$(./komodo-cli getblock $block_hash)	
	#echo $block
	time=$(echo $block | grep -Po '"time": \K\w+')
	#echo $time
	hash=$(echo $block | grep -Po '"hash": "\K\w+')
	#echo $hash
	bits=$(echo $block | grep -Po '"bits": "\K\w+')
	#echo $bits
	#echo '{      0, "000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f", 1231006505, 0x1d00ffff },'
	#echo -e '{\t'$height',\t "'$hash'", '$time', 0x'$bits' },'
	# (15000, uint256S("0x00f0bd236790e903321a2d22f85bd6bf8a505f6ef4eddb20458a65d37e14d142")),
	if [ $height == 0 ] 
	then
		echo '            (0, consensus.hashGenesisBlock),'
	else
		echo -e '            (\t'$height',\tuint256S("0x'$hash'")),'
	fi
#

echo '            '$time',     // * UNIX timestamp of last checkpoint block
            21906511,         // * total number of transactions between genesis and last checkpoint
                            //   (the tx=... number in the SetBestChain debug.log lines)
            2777            // * estimated number of transactions per day after checkpoint
                            //   total number of tx / (checkpoint block height / (24 * 24))
        };
'