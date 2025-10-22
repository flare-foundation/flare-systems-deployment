# Registration tasks

If you do have a safe environment to work with you can register your entity
addresses with the
[`register-entities`](https://github.com/flare-foundation/flare-smart-contracts-v2/blob/main/deployment/tasks/register-entities.ts)
script and your sortition public key with the
[`register-public-keys`](https://github.com/flare-foundation/flare-smart-contracts-v2/blob/main/deployment/tasks/register-public-keys.ts)
script.

Fill out and store below snippet to a file named `accounts.json`.

```json
[
  {
    "identity": {
      "address": "<address>",
      "privateKey": "<private key hex>"
    },
    "submit": {
      "address": "<address>",
      "privateKey": "<private key hex>"
    },
    "submitSignatures": {
      "address": "<address>",
      "privateKey": "<private key hex>"
    },
    "signingPolicy": {
      "address": "<address>",
      "privateKey": "<private key hex>"
    },
    "delegation": {
      "address": "<address>",
      "privateKey": "<private key hex>"
    },
    "sortitionPrivateKey": "<private key hex>"
  }
]
```

Create `.env` file using this template (eg.: for Flare network)

```bash
FLARE_RPC=rpcurl
CHAIN_CONFIG=flare
ENTITIES_FILE_PATH=accounts.json
```

Finally run the scripts (eg.: for Flare network)

```bash
# initialize repository
yarn
# compile contracts
yarn c
# run entity registration
yarn hardhat --network flare register-entities
# run public key registration
yarn hardhat --network flare register-public-keys
```
