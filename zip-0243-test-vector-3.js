/* Node JS Example how to calculate sapling sighash. 

   Deps: bitgo-utxo-lib

   In this small example we will calculate sighash for Test Vector 3 - https://github.com/zcash/zips/blob/master/zip-0243.rst#test-vector-3
   from zip-0243 :

   Preimage: 

   bitgo:utxolib:transaction 0400008085202f89fae31b8dec7b0b77e2c8d6b6eb0e7e4e55abc6574c26dd44464d9408a8e33f116c80d37f12d89b6f17ff198723e7db1247c4811d1a695d74d930f99e98418790d2b04118469b7810a0d1cc59568320aad25a84f407ecac40b4f605a4e686845400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000029b0040048b00400000000000000000001000000a8c685478265f4c14dada651969c45a65e1aeb8cd6791f2f5bb6a1d9952104d9010000001976a914507173527b4c3318a2aecd793bf1cfed705950cf88ac80f0fa0200000000feffffff +0ms
   sighash: f3148f80dfab5e573d5edfe7a850f5fd39234f80b5429d3a57edcc11e34c585b

   Also, here is 2 examples, how to import transaction from hex and how to create it manually.

*/

// This shows how to denug NodeJS applications:
// https://stackoverflow.com/questions/26112075/express-debug-module-not-working
// https://developer.ibm.com/node/2016/10/12/the-node-js-debug-module-advanced-usage/

//process.env['DEBUG'] = 'decker:server,bitgo:utxolib:txbuilder';
//process.env['DEBUG'] = 'decker:*,bitgo:*';
process.env['DEBUG'] = '*';
var debug = require('debug')('decker:server');

debug('Nice brain exercise :)')

// https://github.com/zcash/zips/blob/master/zip-0243.rst - Test Vector 3
// https://explorer.testnet.z.cash/tx/97d8814886d07fc12bbac90c089a10f90906cbb53402ee26e576ef99276c492d
// https://explorer.testnet.z.cash/api/tx/97d8814886d07fc12bbac90c089a10f90906cbb53402ee26e576ef99276c492d

const bitcoinZcashSapling = require('bitgo-utxo-lib'); 
const rawtx = "0400008085202f8901a8c685478265f4c14dada651969c45a65e1aeb8cd6791f2f5bb6a1d9952104d9010000006b483045022100a61e5d557568c2ddc1d9b03a7173c6ce7c996c4daecab007ac8f34bee01e6b9702204d38fdc0bcf2728a69fde78462a10fb45a9baa27873e6a5fc45fb5c76764202a01210365ffea3efa3908918a8b8627724af852fc9b86d7375b103ab0543cf418bcaa7ffeffffff02005a6202000000001976a9148132712c3ff19f3a151234616777420a6d7ef22688ac8b959800000000001976a9145453e4698f02a38abdaa521cd1ff2dee6fac187188ac29b0040048b004000000000000000000000000";

/*

header:          04000080
nVersionGroupId: 85202f89
vin:             01 a8c685478265f4c14dada651969c45a65e1aeb8cd6791f2f5bb6a1d9952104d9 01000000 6b483045022100a61e5d557568c2ddc1d9b03a7173c6ce7c996c4daecab007ac8f34bee01e6b9702204d38fdc0bcf2728a69fde78462a10fb45a9baa27873e6a5fc45fb5c76764202a01210365ffea3efa3908918a8b8627724af852fc9b86d7375b103ab0543cf418bcaa7f feffffff
vout:            02 005a620200000000 1976a9148132712c3ff19f3a151234616777420a6d7ef22688ac // 0.40000000 (40000000)
                    8b95980000000000 1976a9145453e4698f02a38abdaa521cd1ff2dee6fac187188ac // 0.09999755 (9999755)
nLockTime:       29b00400
nExpiryHeight:   48b00400
valueBalance:    0000000000000000
vShieldedSpend:  00
vShieldedOutput: 00
vJoinSplit:      00

Input:
    prevout:    a8c685478265f4c14dada651969c45a65e1aeb8cd6791f2f5bb6a1d9952104d9 01000000
    scriptCode: 1976a914507173527b4c3318a2aecd793bf1cfed705950cf88ac
    amount:     80f0fa0200000000 // 0.5 (50000000)
    nSequence:  feffffff

*/

const network = bitcoinZcashSapling.networks.zcashTest;

// (1)
// tx = new bitcoinZcashSapling.TransactionBuilder.fromTransaction(bitcoinZcashSapling.Transaction.fromHex(rawtx, network), network);


// (2)
tx = new bitcoinZcashSapling.TransactionBuilder(network);

tx.setVersion(4);
tx.setVersionGroupId(bitcoinZcashSapling.Transaction.SAPLING_VERSION_GROUP_ID);
tx.setLockTime(307241);
tx.setExpiryHeight(307272);

tx.addInput(Buffer.from('a8c685478265f4c14dada651969c45a65e1aeb8cd6791f2f5bb6a1d9952104d9','hex').reverse().toString('hex'), 1, 0xFFFFFFFE);
tx.addOutput(Buffer.from('76a9148132712c3ff19f3a151234616777420a6d7ef22688ac', 'hex'), 40000000);
tx.addOutput(Buffer.from('76a9145453e4698f02a38abdaa521cd1ff2dee6fac187188ac', 'hex'), 9999755);

console.log(tx.inputs);

/*
// for (1)
tx.inputs = [ {} ]; // if tx in TransactionBuilder is "copied" from another tx via fromTransaction we should do a small hack to clean inputs array (!),
// if we have just one input tx.inputs = [ {} ], if two - tx.inputs = [ {}, {} ] and and so on.  if tx is built "from scratch" - no actions required,
// tx.inputs is already in needed state for sign.
*/

//debug(tx);
//debug(tx.tx.ins);
//debug(tx.tx.ins.script);

// cUPJEYuhf9SmBXbu7LbsJUozn6CSsvaKvGb3UZDfyojM4L1abfH1 - cafecafecafecafecafecafecafecafecafecafecafecafecafecafecafecafe

const keyPair = bitcoinZcashSapling.ECPair.fromWIF("cUPJEYuhf9SmBXbu7LbsJUozn6CSsvaKvGb3UZDfyojM4L1abfH1", network);
console.log(keyPair.getPrivateKeyBuffer().toString('hex'));
console.log(keyPair.getPublicKeyBuffer().toString('hex'));
console.log(keyPair.getAddress());
console.log(keyPair.toWIF());

const hashType = bitcoinZcashSapling.Transaction.SIGHASH_ALL;

// inIndex, prevOutScript, value, hashType
var sighash = tx.tx.hashForZcashSignature(0, Buffer.from('76a914507173527b4c3318a2aecd793bf1cfed705950cf88ac' , 'hex'), 50000000, hashType).toString('hex');
console.log("sighash: " + sighash);

/* Important note: when we actually sign transaction with tx.sign we don't know correct privkey for this
transaction and address tmH3hJCHa9bnVqfx839CupCkyvMY7e8TCUa, so "Calculated ZEC sighash" inside a sign
method will be incorrect. Bcz inside a sign we deternined scriptCode (prevOutScript) as

prevOutScript = btemplates.pubKeyHash.output.encode(bcrypto.hash160(kpPubKey)) and 
kbPubKey in our case equal "02b66ded73ed43c02a7b922eb06908164dca411f98bbe6441a868c8bbf4512124d" and 
corresponds our WIF cUPJEYuhf9SmBXbu7LbsJUozn6CSsvaKvGb3UZDfyojM4L1abfH1 and address tmPnse4WukdsLMnZYSs7u1DSZqFSXi3rS6j .

So, when we call sign method scriptCode (prevOutScript) will be equal "76a9149a6cb99bf5ffd6d4df5ce5832c33440eea4eb1f688ac",
but of course in zip-243 test vector 3 example it should be 1976a914507173527b4c3318a2aecd793bf1cfed705950cf88ac .

That's why to ensure that sighash in this example is corrent we just call hashForZcashSignature with
needed params above.

*/

// vin, keyPair, redeemScript, hashType, witnessValue, witnessScript
tx.sign(0, keyPair, '', hashType, 50000000); 

//const hex = tx.build().toHex(); 
const hex = tx.buildIncomplete().toHex();
console.log(hex);


