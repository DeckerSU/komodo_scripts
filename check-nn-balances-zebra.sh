#!/usr/bin/env bash
# (c) Decker 2022

# This script check NN address balances between zebrad getaddressbalance RPC and main KMD explorer.
# Just a PoC.

# Requirements:
# sudo apt install base58
#
# For modern OpenSSL 3.x you should use -provider=legacy , for older versions - don't,
# so if you are receive error message like dgst: Unrecognized flag provider, just remove
# -provider=legacy in openssl call.

# --------------------------------------------------------------------------
declare -A notaries
notaries[blackice_DEV]="02ca882f153e715091a2dbc5409096f8c109d9fe6506ca7a918056dd37162b6f6e"
notaries[blackice_AR]="02909c79a198179c193fb85bbd4ba09b875a5a9bd481fec284658188b96ed43519"
notaries[alien_EU]="03bb749e337b9074465fa28e757b5aa92cb1f0fea1a39589bca91a602834d443cd"
notaries[alien_NA]="03bea1ac333b95c8669ec091907ea8713cae26f74b9e886e13593400e21c4d30a8"
notaries[alien_SH]="03911a60395801082194b6834244fa78a3c30ff3e888667498e157b4aa80b0a65f"
notaries[alienx_EU]="026afe5b112d1b39e0edafd5e051e261a676104460581f3673f26ceff7f1e6c56c"
notaries[alienx_NA]="02f0b3ef87629509441b1ae95f28108f258a81910e483b90e0496205e24e7069b8"
notaries[artem_pikulin_AR]="026a8ed1e4eeeb023cfb8e003e1c1de6a2b771f37e112745ffb8b6e375a9cbfdec"
notaries[artem_pikulin_DEV]="036b9848396ddcdb9bb58ddab2c24b710b8e4e9b0ee084a00518505ecd9e9fe174"
notaries[blackice_EU]="02668f5f723584f97f5e6f9196fc31018f36a6cf824c60328ad0c097a785df4745"
notaries[chmex_AR]="036c856ea778ea105b93c0be187004d4e51161eda32888aa307b8f72d490884005"
notaries[chmex_EU]="025b7209ba37df8d9695a23ea706ea2594863ab09055ca6bf485855937f3321d1d"
notaries[chmex_NA]="030c2528c29d5328243c910277e3d74aa77c9b4e145308007d2b11550731591dbe"
notaries[chmex_SH]="02698305eb3c27a2c724efd2152f9250739355116f201656c34b83aac2d3aebd19"
notaries[chmex1_SH]="02d27ed1cddfbaff9e47865e7df0165457e8f075f70bbea8c0498598ccf494555d"
notaries[cipi_1_EU]="03d6e1f3a693b5d69049791005d7cb64c259a1ad85833f5a9c545d4fee29905009"
notaries[cipi_2_EU]="0202e430157486503f4bde3d3ca770c8f1e2447cf480a6b273b5265b9620f585e3"
notaries[cipi_AR]="033ae024cdb748e083406a2e20037017a1292079ad6a8161ae5b43f398724fea74"
notaries[cipi_NA]="036cc1d7476e4260601927be0fc8b748ae68d8fec8f5c498f71569a01bd92046c5"
notaries[computergenie_EU]="03a8c071036228e0900e0171f616ce1a58f0a761193551d68c4c20e70534f2e183"
notaries[computergenie_NA]="03a78ae070a5e9e935112cf7ea8293f18950f1011694ea0260799e8762c8a6f0a4"
notaries[dimxy_AR]="02689d0b77b1e8e8c93a102d8b689fd08179164d70e2dd585543c3896a0916e6a1"
notaries[dimxy_DEV]="039a01cd626d5efbe7fd05a59d8e5fced53bacac589192278f9b00ad31654b6956"
notaries[dragonhound_NA]="02e650819f4d1cabeaad6bc5ec8c0722a89e63059a10f8b5e97c983c321608329b"
notaries[fediakash_AR]="027dfe5403f8870fb0e1b94a2b4204373b31ea73179ba500a88dd56d22855cd03b"
notaries[gcharang_DEV]="033b82b5791c65477dd11095cf33332013df6d2bcb7aa06a6dae5f7b22b6959b0b"
notaries[gcharang_SH]="02cb445948bf0d89f8d61102e12a5ee6e98be61ac7c2cb9ba435219ea9db967117"
notaries[goldenman_AR]="02c11f651df6a03f1a17b9ea0b1a73c0acca7aeacd4081e09bd7dd939690af8ae1"
notaries[kolo_AR]="028431645f923a9e383a4e37cbb7168fa34988da23d43097124fe882bdac6d175f"
notaries[kolo_EU]="03e1287d4c14ad73ce9ddd31361a7de8df4eeeefe9460a1ff9a6b2a1242ad3b7c2"
notaries[kolox_AR]="0289f5f64f4bb18d014c4e9f4c888f4da2b6518e88fd5b7768728c38177b66d305"
notaries[komodopioneers_EU]="0351f7f2a6ecce863e4e774bfafe2e59e151c08bf8f350286763a6b8ed97274b82"
notaries[madmax_DEV]="027100e6b3db2028034db651946ecde90e45be3799ebc310d39af4496772a850ad"
notaries[marmarachain_EU]="0234e40800500370d43979586ee2cec2e777a0368d10c682e78bca30fd1630c18d"
notaries[mcrypt_AR]="029bdb33b08f96524082490f4373bc6026b92bcaef9bc521a840a799c73b75ed80"
notaries[mcrypt_SH]="025faab3cc2e83bf7dad6a9463cbff86c08800e937942126f258cf219bc2320043"
notaries[metaphilibert_SH]="0284af1a5ef01503e6316a2ca4abf8423a794e9fc17ac6846f042b6f4adedc3309"
notaries[mylo_NA]="0365a778014c216401b6ba9c28eec88f116a9a9912e145ba2dbbd065d98b493af5"
notaries[mylo_SH]="03458dca36e800d5bc121d8c0d35f9fc6282880a79fee2d7e050f887b797bc7d6e"
notaries[nodeone_NA]="03f9dd0484e81174fd50775cb9099691c7d140ff00c0f088847e38dc87da67eb9b"
notaries[nutellalicka_AR]="0285be2518bf8d65fceaa5f4d8485002f90d3b7ff274b23bb925fd167128e19589"
notaries[nutellalicka_SH]="03a8b10c1f74af429fc43ab4eb722f6c2a88087f2d71703e7f0e8001207a966fb5"
notaries[ocean_AR]="03c2bc8c57a001a788851fedc33ce72797ee8fe26eaa3abb1b807727e4867a3105"
notaries[pbca26_NA]="03d8b25536da157d931b159a72c0eeaedb1bf7bb3eb2d02647fa41b2422a2b064e"
notaries[pbca26_SH]="039a55787b742c3725323f0bd81c90a484fbdbf276a16317883bb03eedd9d6aa7c"
notaries[phit_SH]="02a9cef2141fb2af24349c1eea20f5fa8f5dba2835723778d19b23353ddcd877b1"
notaries[ptyx_NA]="0395640e81359526ecbc140716ddd5c9a1ce2a697fb547ca896e17cad3c65e78db"
notaries[ptyx2_NA]="0225ff37e49e443065018736fbcad175ab5993b51b99b846e8de0b8b9abbed2ef2"
notaries[sheeba_SH]="03e6578015b7f0ab78a486070435031fff7bae11256ca6a9f3d358ab03029737cb"
notaries[smdmitry_AR]="022a2a45979a6631a25e4c96469423de720a2f4c849548957c35a35c91041ee7ac"
notaries[smdmitry_EU]="02eb3aad81778f8d6f7e5295c44ca224e5c812f5e43fc1e9ce4ebafc23324183c9"
notaries[smdmitry_SH]="02d01cd6b87cbf5a9795c06968f0d169168c1be0d82cfeb79958b11ae2c30316c1"
notaries[strob_SH]="025ceac4256cef83ca4b110f837a71d70a5a977ecfdf807335e00bc78b560d451a"
notaries[strobnidan_SH]="02b967fde3686d45056343e488997d4c53f25cd7ad38548cd12b136010a09295ae"
notaries[tokel_NA]="02b472713e87fb2560569857051ea0811c65d668a6fe73df165afe152417f774a0"
notaries[tonyl_AR]="029ad03929ec295e9164e2bfb9f0e0102c280d5e5212503d079d2d99ab492a9106"
notaries[tonyl_DEV]="02342ec82b31a016b71cd1eb2f482a74f63172e1029ba2fb18f0def3bd4fc0668a"
notaries[van_EU]="03af7f8c82f20671ca1978116353839d3e501523e379bfb52b1e05d7816bb5812f"
notaries[webworker01_EU]="0321d523645caffd8e762764ba56f7874a61b9bf534837a2cb6e7da219fab15eef"
notaries[webworker01_NA]="0287883ddd8da366401893ebcc1ff7e52d2ad3736984120a0ab01603e02c21dc98"
notaries[who-biz_NA]="02f91a6772fe1a376e2bbe4b190008e3f878d40a8eaf92c65f1a7680b6b42ea47b"
notaries[yurii-khi_DEV]="03e57c7341d2c8a3be62e1caaa28978d76a8277dea7bb484fdd8c55dc05e4e4e93"
notaries[ca333_EU]="021d6fbe67d12f492a01306c70ab096f8b8581eb5f958d3f5fe3588ae8c7797f42"
notaries[dragonhound_DEV]="038e010c33c56b61389409eea5597fe17967398731e23185c84c472a16fc5d34ab"

# --------------------------------------------------------------------------
function init_colors() {
    RESET="\033[0m"
    BLACK="\033[30m"
    RED="\033[31m"
    GREEN="\033[32m"
    YELLOW="\033[33m"
    BLUE="\033[34m"
    MAGENTA="\033[35m"
    CYAN="\033[36m"
    WHITE="\033[37m"
    BRIGHT="\033[1m"
    DARKGREY="\033[90m"
}

init_colors

for i in "${!notaries[@]}" # access the keys with ${!array[@]}
do
    # key - $i, value - ${notaries[$i]}
    pubkey_hex=${notaries[$i]}
    if [ "${#pubkey_hex}" -ne "66" ]; then
    echo "Error obtaining pubkey ..." 1>&2
    exit
    fi

    # echo " Pubkey (hex): ${pubkey_hex} (${#pubkey_hex})"

    network_byte_hex="3c" #  60 (dec) KMD (Komodo)
    secret_key_hex="bc"   # 188 (dec) KMD (Komodo)

    hash160_hex=$(echo -n "${pubkey_hex}" | xxd -r -p | openssl dgst -sha256 -binary | openssl dgst -provider=legacy -rmd160 -binary | xxd -p -c 20)
    if [ "${#hash160_hex}" -ne "40" ]; then
        echo "Error obtaining rmd-160 ..." 1>&2
        exit
    fi

    # echo "rmd-160 (hex): $hash160_hex (${#hash160_hex})"
    checksum_hex=$(echo -n "${network_byte_hex}${hash160_hex}" | xxd -r -p | openssl dgst -sha256 -binary | openssl dgst -sha256 -binary | xxd -p -c 32)
    address=$(echo -n "${network_byte_hex}${hash160_hex}${checksum_hex:0:8}" | xxd -r -p | base58)
    # echo "      Address: ${address}"

    echo -e "${DARKGREY}${address}${RESET} ${YELLOW}$i${RESET}"
    balance_zebra=$(curl -s --data-binary '{"jsonrpc": "1.0", "id":"curltest", "method": "getaddressbalance", "params": [{"addresses": ["'$address'"]}] }' -H 'Content-type: application/json' http://127.0.0.1:8232/ | jq .result.balance)
    balance_explorer=$(curl -s https://kmdexplorer.io/insight-api-komodo/addr/$address/balance)

    if [ "$balance_zebra" = "$balance_explorer" ]; then
        msg="${GREEN}OK${RESET}"
    else
        msg="${RED}FAIL${RESET}"
    fi

    echo -e "\"${balance_zebra}\" vs. \"${balance_explorer}\" \x5b${msg}\x5d"

done