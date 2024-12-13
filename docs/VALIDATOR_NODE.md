# Validator node registration values

## Setup
You will need to generate three values to register the node with the system:
- 20-byte node id bytes in hex
- raw certificate bytes in hex
- signature bytes in hex

On your validator node locate the certificate (`.crt`) and private key (`.key`) file. The usual locations are:
- `~/.avalanchego/staking/staker.key`
- `~/.avalanchego/staking/staker.crt`

The combination of following values will be needed for all three steps. You can set them for your current shell process by copy pasting the following snippet into your terminal.
```bash
PATH_TO_CRT=~/.avalanchego/staking/staker.crt
ZERO_PREFIX=0000000000000000000000000000000000000000000000000000000000000000
PATH_TO_KEY=~/.avalanchego/staking/staker.key
IDENTITY_ADDRESS=youridentityaddresswithout0xprefix
```

### 20-byte node id bytes in hex
**NOTE: If you have older version of `openssl`, try without `-provider legacy`.**
```bash
cat $PATH_TO_CRT | \
  tail -n +2 | \
  head -n -1 | \
  base64 -d | \
  openssl dgst -sha256 -binary | \
  openssl rmd160 -provider legacy -binary | \
  xxd -p | \
  sed -e 's/^/0x/;'
```

### Raw certificate bytes in hex
```bash
cat $PATH_TO_CRT | \
  tail -n +2 | \
  head -n -1 | \
  base64 -d | \
  xxd -p | \
  tr -d \\n | \
  sed -e 's/^/0x/;' && echo
```

### Signature bytes in hex
```bash
echo -n $ZERO_PREFIX$IDENTITY_ADDRESS | \
  xxd -r -p | \
  openssl dgst -sha256 -sign $PATH_TO_KEY | \
  xxd -p | \
  tr -d \\n | \
  sed -e 's/^/0x/;' && echo
```

