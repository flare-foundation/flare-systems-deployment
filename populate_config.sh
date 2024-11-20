#!/usr/bin/env bash

set -eu

source <(grep -v '^#' "./.env" | sed -E 's|^(.+)=(.*)$|: ${\1=\2}; export \1|g')

declare -A NODES=( 
    ["flare"]="https://flare-api.flare.network/ext/C/rpc"
    ["songbird"]="https://songbird-api.flare.network/ext/C/rpc"
    ["coston"]="https://coston-api.flare.network/ext/C/rpc"
    ["coston2"]="https://coston2-api.flare.network/ext/C/rpc"
)
ROOT_DIR="$(pwd)"
CONFIG_DIR="${ROOT_DIR}/config/${NETWORK}"

CHAIN_CONFIG="${CONFIG_DIR}/config.json"
DEPLOYED_CONTRACTS="${CONFIG_DIR}/contracts.json"
INITIAL_REWARD_EPOCH="${CONFIG_DIR}/initial_reward_epoch.txt"
CHAIN_ID_FILE="${CONFIG_DIR}/chain_id.txt"

get_address_by_name() {
    name="$1"
    echo $(jq -r ".[] | select(.name == \"$name\") | .address" "$DEPLOYED_CONTRACTS")
}

write_attestation_source() {
    attestation_type=$1; shift
    source=$1; shift
    lut_limit=$1; shift

    url_env_name="${source^^}_${attestation_type^^}_URL"
    api_key_env_name="${source^^}_${attestation_type^^}_API_KEY"

    if [[ ${!url_env_name:+x} != "x" ]]; then
        echo "warning: $attestation_type for $source source config wasn't generated: $url_env_name env variable is not set" >&2
        return
    fi

    url="${!url_env_name}"
    api_key="${!url_env_name:-""}"

    cat <<EOF

## $source
[types.$attestation_type.Sources.$source]
url = "$url"
api_key = "$api_key"
lut_limit = "$lut_limit"
queue = "$source"
EOF
}

write_attestation_type() {
    name=$1;

    cat <<EOF

# $name
[types.$name]
abi_path = "configs/abis/$name.json"
EOF

}

write_attestation_queue() {
    name=$1; shift
cat <<EOF

[queues.$name]
size = 10
max_dequeues_per_second = 0
max_workers = 0
max_attempts = 3
time_off = 2
EOF

}

write_fdc_attestation_types() {
    config_file=$1; shift
    (
        # queues
        write_attestation_queue "sgb"
        write_attestation_queue "flr"
        write_attestation_queue "eth"
        write_attestation_queue "btc"
        write_attestation_queue "doge"
        write_attestation_queue "xrp"
        # evm transaction
        write_attestation_type "EVMTransaction"
        write_attestation_source "EVMTransaction" "sgb" 18446744073709551615
        write_attestation_source "EVMTransaction" "flr" 18446744073709551615
        write_attestation_source "EVMTransaction" "eth" 18446744073709551615
        # payment
        write_attestation_type "Payment"
        write_attestation_source "Payment" "btc" 1209600
        write_attestation_source "Payment" "doge" 1209600
        write_attestation_source "Payment" "xrp" 1209600
        # balance decreasing transaction
        write_attestation_type "BalanceDecreasingTransaction"
        write_attestation_source "BalanceDecreasingTransaction" "btc" 1209600
        write_attestation_source "BalanceDecreasingTransaction" "doge" 1209600
        write_attestation_source "BalanceDecreasingTransaction" "xrp" 1209600
        # confirmed block height exists
        write_attestation_type "ConfirmedBlockHeightExists"
        write_attestation_source "ConfirmedBlockHeightExists" "btc" 1209600
        write_attestation_source "ConfirmedBlockHeightExists" "doge" 1209600
        write_attestation_source "ConfirmedBlockHeightExists" "xrp" 1209600
        # referenced payment nonexistence
        write_attestation_type "ReferencedPaymentNonexistence"
        write_attestation_source "ReferencedPaymentNonexistence" "btc" 1209600
        write_attestation_source "ReferencedPaymentNonexistence" "doge" 1209600
        write_attestation_source "ReferencedPaymentNonexistence" "xrp" 1209600
        # address validity
        write_attestation_type "AddressValidity"
        write_attestation_source "AddressValidity" "btc" 18446744073709551615
        write_attestation_source "AddressValidity" "doge" 18446744073709551615
        write_attestation_source "AddressValidity" "xrp" 18446744073709551615
    ) >>$config_file
}

main() {

    if [ -d "mounts" ] || [ -f "mounts" ]; then
        echo "cleaning configs from previous runs:"
        echo "rm -r mounts"
        rm -r "mounts"
    fi
    echo ""

    mount_dirs=(
        "mounts/system-client/"
        "mounts/c-chain-indexer/"
        "mounts/ftso-client/"
        "mounts/fdc-client/"
        "mounts/fast-updates/"
    )

    echo "preparing mount dirs:"
    for dest in "${mount_dirs[@]}"; do
        echo "mkdir -p $dest"
        mkdir -p "$dest"
    done
    echo ""

    echo "writing configs for c-chain-indexer, system-client, ftso-client, fdc-client and fast-updates"

    # read contract adresses
    export SUBMISSION=$(get_address_by_name "Submission")
    export RELAY=$(get_address_by_name "Relay")
    export FLARE_SYSTEMS_MANAGER=$(get_address_by_name "FlareSystemsManager")
    export VOTER_REGISTRY=$(get_address_by_name "VoterRegistry")
    export FLARE_SYSTEMS_CALCULATOR=$(get_address_by_name "FlareSystemsCalculator")
    export FTSO_REWARD_OFFERS_MANAGER=$(get_address_by_name "FtsoRewardOffersManager")
    export REWARD_MANAGER=$(get_address_by_name "RewardManager")
    export FAST_UPDATER=$(get_address_by_name "FastUpdater")
    export FAST_UPDATES_CONFIGURATION=$(get_address_by_name "FastUpdatesConfiguration")
    export FAST_UPDATE_INCENTIVE_MANAGER=$(get_address_by_name "FastUpdateIncentiveManager")

    # read config parameters
    export FIRST_VOTING_EPOCH_START_SEC=$(jq -r .firstVotingRoundStartTs "$CHAIN_CONFIG")
    export VOTING_EPOCH_DURATION_SEC=$(jq -r .votingEpochDurationSeconds "$CHAIN_CONFIG")
    export FIRST_REWARD_EPOCH_START_VOTING_ID=$(jq -r .firstRewardEpochStartVotingRoundId "$CHAIN_CONFIG")
    export REWARD_EPOCH_DURATION_IN_VOTING_EPOCHS=$(jq -r .rewardEpochDurationInVotingEpochs "$CHAIN_CONFIG")
    export INITIAL_REWARD_EPOCH_ID=$(cat "$INITIAL_REWARD_EPOCH")

    # chain id
    export CHAIN_ID=$(cat "$CHAIN_ID_FILE")

    # block height
    block_hex=$(curl -s "${NODES["$NETWORK"]}" \
        -X POST \
        -H "Content-Type: application/json" \
        --data '{"method":"eth_blockNumber","params":[],"id":1,"jsonrpc":"2.0"}' \
        | jq -r '.result')
    export INDEXER_START_BLOCK=$((16#${block_hex/0x/} - 1000000))

    # write configs

    # c chain indexer
    mkdir -p "mounts/c-chain-indexer/"
    CONFIG_FILE="mounts/c-chain-indexer/config.toml"
    envsubst < "template-configs/c-chain-indexer.template.toml" > "$CONFIG_FILE"

    # system client
    mkdir -p "mounts/system-client"
    CONFIG_FILE="mounts/system-client/config.toml"
    envsubst < "template-configs/system-client.template.toml" > "$CONFIG_FILE"

    # ftso client
    mkdir -p "mounts/ftso-client"
    CONFIG_FILE="mounts/ftso-client/.env"
    envsubst < "template-configs/ftso-client.template.env" > "$CONFIG_FILE"

    # fdc client
    mkdir -p "mounts/fdc-client"
    CONFIG_FILE="mounts/fdc-client/config.toml"
    envsubst < "template-configs/fdc-client.template.toml" > "$CONFIG_FILE"
    write_fdc_attestation_types $CONFIG_FILE
    
    # fast updates
    mkdir -p "mounts/fast-updates"
    CONFIG_FILE="mounts/fast-updates/config.toml"
    envsubst < "template-configs/fast-updates.template.toml" > "$CONFIG_FILE"
}

main
