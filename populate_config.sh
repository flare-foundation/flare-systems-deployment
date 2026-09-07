#!/usr/bin/env bash

set -eu

# shellcheck source=/dev/null
source <(grep -v '^#' "./.env" | sed -E 's|^(.+)=(.*)$|: ${\1=\2}; export \1|g')

ROOT_DIR="$(pwd)"
CONFIG_DIR="${ROOT_DIR}/config/${NETWORK}"

CHAIN_CONFIG="${CONFIG_DIR}/config.json"
DEPLOYED_CONTRACTS="${CONFIG_DIR}/contracts.json"
INITIAL_REWARD_EPOCH="${CONFIG_DIR}/initial_reward_epoch.txt"
CHAIN_ID_FILE="${CONFIG_DIR}/chain_id.txt"
# only present on networks whose switch to the source-chain-id-bound Relay is scheduled
RELAY_CUTOVER="${CONFIG_DIR}/relay_cutover.json"

get_address_by_name() {
    name="$1"
    jq -r ".[] | select(.name == \"$name\") | .address" "$DEPLOYED_CONTRACTS"
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
    api_key="${!api_key_env_name:-""}"

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
size = 1000
max_dequeues_per_second = 100
max_workers = 10
max_attempts = 3
time_off = "2s"
EOF

}

write_fdc_attestation_types() {
    config_file=$1; shift
    (
        # queues
        write_attestation_queue "SGB"
        write_attestation_queue "FLR"
        write_attestation_queue "ETH"
        write_attestation_queue "BTC"
        write_attestation_queue "DOGE"
        write_attestation_queue "XRP"
        write_attestation_queue "Ignite"
        # evm transaction
        write_attestation_type "EVMTransaction"
        write_attestation_source "EVMTransaction" "SGB" 18446744073709551615
        write_attestation_source "EVMTransaction" "FLR" 18446744073709551615
        write_attestation_source "EVMTransaction" "ETH" 26400000
        # payment
        write_attestation_type "Payment"
        write_attestation_source "Payment" "BTC" 1209600
        write_attestation_source "Payment" "DOGE" 1209600
        write_attestation_source "Payment" "XRP" 1209600
        # balance decreasing transaction
        write_attestation_type "BalanceDecreasingTransaction"
        write_attestation_source "BalanceDecreasingTransaction" "BTC" 1209600
        write_attestation_source "BalanceDecreasingTransaction" "DOGE" 1209600
        write_attestation_source "BalanceDecreasingTransaction" "XRP" 1209600
        # confirmed block height exists
        write_attestation_type "ConfirmedBlockHeightExists"
        write_attestation_source "ConfirmedBlockHeightExists" "BTC" 1209600
        write_attestation_source "ConfirmedBlockHeightExists" "DOGE" 1209600
        write_attestation_source "ConfirmedBlockHeightExists" "XRP" 1209600
        # referenced payment nonexistence
        write_attestation_type "ReferencedPaymentNonexistence"
        write_attestation_source "ReferencedPaymentNonexistence" "BTC" 1209600
        write_attestation_source "ReferencedPaymentNonexistence" "DOGE" 1209600
        write_attestation_source "ReferencedPaymentNonexistence" "XRP" 1209600
        # address validity
        write_attestation_type "AddressValidity"
        write_attestation_source "AddressValidity" "BTC" 18446744073709551615
        write_attestation_source "AddressValidity" "DOGE" 18446744073709551615
        write_attestation_source "AddressValidity" "XRP" 18446744073709551615
        # web2json
        write_attestation_type "Web2Json"
        write_attestation_source "Web2Json" "Ignite" 18446744073709551615
        # xrp payment
        write_attestation_type "XRPPayment"
        write_attestation_source "XRPPayment" "XRP" 1209600
        # xrp referenced payment nonexistence
        write_attestation_type "XRPPaymentNonexistence"
        write_attestation_source "XRPPaymentNonexistence" "XRP" 1209600
    ) >>"$config_file"
}

write_tee_queue() {
    name=$1; shift

    cat <<EOF

[fdc.queues.$name]
max_dequeues_per_second = 100 # zero for unlimited
max_workers = 50              # zero for unlimited
max_attempts = 3
time_off = "2s"
EOF

}

write_tee_verifier() {
    name=$1; shift
    attestation_type=$1; shift
    source=$1; shift
    queue=$1; shift

    url_env_name="${source^^}_${attestation_type^^}_URL"
    api_key_env_name="${source^^}_${attestation_type^^}_API_KEY"

    if [[ ${!url_env_name:+x} != "x" ]]; then
        echo "warning: $attestation_type for $source source config wasn't generated: $url_env_name env variable is not set" >&2
        return
    fi

    url="${!url_env_name}"
    api_key="${!api_key_env_name:-""}"

    cat <<EOF

# $attestation_type for $source
[fdc.verifiers.$name]
type = "$attestation_type"
source = "$source"
queue = "$queue"
server.url = "$url"
server.key_name = "X-API-KEY"
server.key = "$api_key"
EOF
}

write_tee_verifiers() {
    config_file=$1; shift
    (
        # queues
        write_tee_queue "availability"
        write_tee_queue "pmw"
        # verifiers
        write_tee_verifier "availability" "TeeAvailabilityCheck" "TEE" "availability"
        write_tee_verifier "payment" "PMWPaymentStatus" "XRP" "pmw"
        write_tee_verifier "account" "PMWMultisigAccountConfigured" "XRP" "pmw"
        write_tee_verifier "fee" "PMWFeeProof" "XRP" "pmw"
    ) >>"$config_file"
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
        "mounts/tee-relay-client/"
    )

    echo "preparing mount dirs:"
    for dest in "${mount_dirs[@]}"; do
        echo "mkdir -p $dest"
        mkdir -p "$dest"
    done
    echo ""

    echo "writing configs for c-chain-indexer, system-client, ftso-client, fdc-client, fast-updates and tee-relay-client"

    # read contract adresses
    SUBMISSION=$(get_address_by_name "Submission")
    export SUBMISSION
    RELAY=$(get_address_by_name "Relay")
    export RELAY
    FLARE_SYSTEMS_MANAGER=$(get_address_by_name "FlareSystemsManager")
    export FLARE_SYSTEMS_MANAGER
    VOTER_REGISTRY=$(get_address_by_name "VoterRegistry")
    export VOTER_REGISTRY
    VOTER_PRE_REGISTRY=$(get_address_by_name "VoterPreRegistry")
    export VOTER_PRE_REGISTRY
    FLARE_SYSTEMS_CALCULATOR=$(get_address_by_name "FlareSystemsCalculator")
    export FLARE_SYSTEMS_CALCULATOR
    FTSO_REWARD_OFFERS_MANAGER=$(get_address_by_name "FtsoRewardOffersManager")
    export FTSO_REWARD_OFFERS_MANAGER
    REWARD_MANAGER=$(get_address_by_name "RewardManager")
    export REWARD_MANAGER
    FAST_UPDATER=$(get_address_by_name "FastUpdater")
    export FAST_UPDATER
    FAST_UPDATES_CONFIGURATION=$(get_address_by_name "FastUpdatesConfiguration")
    export FAST_UPDATES_CONFIGURATION
    FAST_UPDATE_INCENTIVE_MANAGER=$(get_address_by_name "FastUpdateIncentiveManager")
    export FAST_UPDATE_INCENTIVE_MANAGER
    FDC_HUB=$(get_address_by_name "FdcHub")
    export FDC_HUB
    # not deployed on every network, log collection is skipped when empty
    FLARE_TEE_MANAGER=$(get_address_by_name "FlareTeeManager")
    export FLARE_TEE_MANAGER

    # read config parameters
    FIRST_VOTING_EPOCH_START_SEC=$(jq -r .firstVotingRoundStartTs "$CHAIN_CONFIG")
    export FIRST_VOTING_EPOCH_START_SEC
    VOTING_EPOCH_DURATION_SEC=$(jq -r .votingEpochDurationSeconds "$CHAIN_CONFIG")
    export VOTING_EPOCH_DURATION_SEC
    FIRST_REWARD_EPOCH_START_VOTING_ID=$(jq -r .firstRewardEpochStartVotingRoundId "$CHAIN_CONFIG")
    export FIRST_REWARD_EPOCH_START_VOTING_ID
    REWARD_EPOCH_DURATION_IN_VOTING_EPOCHS=$(jq -r .rewardEpochDurationInVotingEpochs "$CHAIN_CONFIG")
    export REWARD_EPOCH_DURATION_IN_VOTING_EPOCHS
    INITIAL_REWARD_EPOCH_ID=$(cat "$INITIAL_REWARD_EPOCH")
    export INITIAL_REWARD_EPOCH_ID

    # chain id
    CHAIN_ID=$(cat "$CHAIN_ID_FILE")
    export CHAIN_ID

    # relay cutover: rendered into the system-client config only where it is scheduled,
    # so that a network without a date gets no [relay_cutover] section at all
    if [[ -f "$RELAY_CUTOVER" ]]; then
        # a literal string, not $(...), so the surrounding blank lines survive
        RELAY_CUTOVER_SECTION="
[relay_cutover]
address = \"$(jq -r .address "$RELAY_CUTOVER")\"
starting_reward_epoch = $(jq -r .startingRewardEpoch "$RELAY_CUTOVER")
"
    else
        RELAY_CUTOVER_SECTION=""
    fi
    export RELAY_CUTOVER_SECTION

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
    if [[ -n "${ADDITIONAL_PROTOCOL_X_API_KEY_100:-}" ]]; then
        export ADDITIONAL_PROTOCOL_X_API_KEY_100=",${ADDITIONAL_PROTOCOL_X_API_KEY_100}"
    else
        export ADDITIONAL_PROTOCOL_X_API_KEY_100=""
    fi
    mkdir -p "mounts/ftso-client"
    CONFIG_FILE="mounts/ftso-client/.env"
    envsubst < "template-configs/ftso-client.template.env" > "$CONFIG_FILE"

    # fdc client
    if [[ -n "${ADDITIONAL_PROTOCOL_X_API_KEY_200:-}" ]]; then
        export ADDITIONAL_PROTOCOL_X_API_KEY_200=",${ADDITIONAL_PROTOCOL_X_API_KEY_200}"
    else
        export ADDITIONAL_PROTOCOL_X_API_KEY_200=""
    fi
    FDC_KEYS=$(jq -Rc 'split(",")' <<< "$PROTOCOL_X_API_KEY_200$ADDITIONAL_PROTOCOL_X_API_KEY_200")
    export FDC_KEYS
    mkdir -p "mounts/fdc-client"
    CONFIG_FILE="mounts/fdc-client/config.toml"
    envsubst < "template-configs/fdc-client.template.toml" > "$CONFIG_FILE"
    write_fdc_attestation_types "$CONFIG_FILE"
    
    # fast updates
    mkdir -p "mounts/fast-updates"
    CONFIG_FILE="mounts/fast-updates/config.toml"
    envsubst < "template-configs/fast-updates.template.toml" > "$CONFIG_FILE"

    # tee relay client
    mkdir -p "mounts/tee-relay-client"
    CONFIG_FILE="mounts/tee-relay-client/config.toml"
    envsubst < "template-configs/tee-relay-client.template.toml" > "$CONFIG_FILE"
    write_tee_verifiers "$CONFIG_FILE"
}

main
