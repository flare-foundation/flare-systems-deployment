# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

# \[[v1.7.0](https://github.com/flare-foundation/flare-systems-deployment/tree/v1.7.0)\] - 2026-08-19

### Changed

- **the indexer database is renamed from `flare_ftso_indexer` to `fsp_indexer`.**
  Every service in the stack takes the name from `docker-compose.yaml`, so the
  stack needs no changes from you — but **anything of your own that reads the
  indexer database directly must be repointed**: backups, dashboards, reward
  calculation, ad-hoc queries.
- bumped c-chain-indexer image to v2.0.0 and switched it to `mode = "fsp"` with
  `history_epochs = 0`. The indexer now only collects what the FSP stack needs
  and resolves the contracts by name itself, so the config template no longer
  lists any `collect_transactions` / `collect_logs` entries and no longer sets
  `db.history_drop`, which fsp mode ignores. A fresh sync takes well under a
  minute instead of hours: it fully indexes only the last hour or so of blocks,
  and backfills the FSP events behind that. Retention is no longer a fixed
  42-day window either — history drop now deletes below two reward epochs before
  the current epoch's start, so the indexed range grows as the indexer runs and
  settles at roughly 7 to 10 days on Flare and Songbird, sliding forward with
  each epoch.
- the indexer database moved to a new `indexer_data_v2` volume. The old
  `indexer_data` volume is left untouched as a rollback point.
- the services that read the indexer database — system-client, ftso-client,
  fdc-client and tee-relay-client — now wait for the indexer's `/health` to report
  200 before they start, via a compose healthcheck. Previously they came up
  against an empty database and worked through their own retry and backoff paths
  until data appeared. If you raise `indexer.history_epochs`, raise the
  healthcheck's `start_period` to match: the first backfill then takes
  proportionally longer, and compose will not start the dependent services once
  it marks the indexer unhealthy.
- `populate_config.sh` no longer appends a `FlareTeeManager` log filter to the
  indexer config. v2 collects the `TeeInstructionsSent` events tee-relay-client
  reads on every network where the contract is deployed, so the generated filter
  only duplicated a built-in one. `FlareTeeManager` is still resolved for the
  tee-relay-client config.

### Upgrading

```bash
docker compose down
git fetch --tags
git checkout v1.7.0
./populate_config.sh
docker compose pull
docker compose up -d
```

- `./populate_config.sh` is **required**: the indexer config template changed.
- the indexer starts from an empty database and resyncs in under a minute.
  `/health` reports 503 until it has, and the services that read the database wait
  for it, so expect them to start a minute or so after `docker compose up -d`.
- do **not** run `docker compose down -v`, `docker volume prune -a` or
  `docker system prune --volumes` during the upgrade: all three delete the old
  `indexer_data` volume you are keeping in order to roll back.
- once v2 runs fine, reclaim the space with
  `docker volume rm <project>_indexer_data`, where `<project>` is this
  directory's name. List the volumes first with `docker volume ls`.

### Rolling back

```bash
docker compose down
git checkout v1.6.1
./populate_config.sh
docker compose pull
docker compose up -d
```

- the v1 indexer picks up the old `indexer_data` volume and resumes from where
  it stopped, then re-indexes the blocks produced while v2 was running. Allow
  catchup time in proportion to how long v2 ran.

# \[[v1.6.1](https://github.com/flare-foundation/flare-systems-deployment/tree/v1.6.1)\] - 2026-08-19

### Changed

- bumped fast-updates image to v1.1.0
- updated the fast-updates config template for EIP-1559 (type 2) submissions:
  `gas_price_multiplier` replaced by `base_fee_multiplier`,
  `max_priority_fee_multiplier`, `minimal_max_priority_fee`, and
  `maximal_max_priority_fee`
- bumped flare-system-client image to v1.1.2, and dropped `logger.file` and
  `logger.max_file_size` from its config template: the container already logs to
  stdout, so the file only grew inside it, unrotated by anything outside
- dropped `logger.file` from the fast-updates config template too, for the same
  reason

# \[[v1.6.0](https://github.com/flare-foundation/flare-systems-deployment/tree/v1.6.0)\] - 2026-08-04

### Added

- added tee-relay-client image v0.0.2 under the new `tee` compose profile, with
  config generation for the FlareTeeManager address, signer, and FDC2 verifiers
- indexing of FlareTeeManager logs, on the networks where it is deployed

### Changed

- bumped flare-system-client image to v1.1.1
- bumped ftso-scaling image to v1.1.1
- configured the new FlareSystemsCalculator addresses for the Coston2 and Coston
- added the `tee` profile to c-chain-indexer and its database

# \[[v1.5.4](https://github.com/flare-foundation/flare-systems-deployment/tree/v1.5.4)\] - 2026-07-14

### Changed

- bumped flare-system-client image to v1.1.0
- bumped ftso-scaling image to v1.1.0
- bumped fdc-client image to v1.3.0
- configured the new VoterRegistry, VoterPreRegistry, and FlareSystemsCalculator
  addresses for the Flare and Songbird reward epoch 417 contract upgrades
- retained indexing of the legacy contract addresses for historical reward epochs

# \[[v1.5.3](https://github.com/flare-foundation/flare-systems-deployment/tree/v1.5.3)\] - 2026-07-01

### Changed

- bumped flare-system-c-chain-indexer image to v1.1.3

### Added

- pinned all images to their manifest digests in `docker-compose.yaml` so pulls
  resolve to immutable content even if a tag is moved

# \[[v1.5.2](https://github.com/flare-foundation/flare-systems-deployment/tree/v1.5.2)\] - 2026-05-13

### Changed

- bumped flare-system-client image to v1.0.15
- bumped fdc-client image to v1.2.10

# \[[v1.5.1](https://github.com/flare-foundation/flare-systems-deployment/tree/v1.5.1)\] - 2026-05-12

### Changed

- bumped flare-system-client image to v1.0.14

# \[[v1.5.0](https://github.com/flare-foundation/flare-systems-deployment/tree/v1.5.0)\] - 2026-04-18

### Changed

- bumped flare-system-client image to v1.0.12
- bumped ftso-scaling image to v1.0.9
- bumped fdc-client image to v1.2.9

### Added

- fdc-client config generation for XRPPayment and XRPPaymentNonexistence

# \[[v1.4.2](https://github.com/flare-foundation/flare-systems-deployment/tree/v1.4.2)\] - 2026-03-26

### Changed

- bumped flare-system-client image to v1.0.11
- bumped fdc-client image to v1.2.8
- bumped ftso-scaling image to v1.0.8

# \[[v1.4.1](https://github.com/flare-foundation/flare-systems-deployment/tree/v1.4.1)\] - 2026-03-10

### Changed

- bumped fdc-client image to v1.2.7

# \[[v1.4.0](https://github.com/flare-foundation/flare-systems-deployment/tree/v1.4.0)\] - 2026-03-10

### Changed

- new relay contract addresses for all 4 chains
- bumped flare-system-client image to v1.0.10
- bumped fdc-client image to v1.2.6
- bumped ftso-scaling image to v1.0.6

### Added

- release github job

### Removed

- command argument from ftso-client service as it is now setup in the docker image

# \[[v1.3.1](https://github.com/flare-foundation/flare-systems-deployment/tree/v1.3.1)\] - 2026-02-20

### Changed

- bumped flare-system-client image to v1.0.9

# \[[v1.3.0](https://github.com/flare-foundation/flare-systems-deployment/tree/v1.3.0)\] - 2026-02-19

### Changed

- bumped flare-system-client image to v1.0.8
- bumped fdc-client image to v1.2.5
- bumped ftso-scaling image to v1.0.5
- changed template configuration for flare-system-c-chain-indexer for relay change
- changed template configuration for flare-system-client for gas optimizations

# \[[v1.2.2](https://github.com/flare-foundation/flare-systems-deployment/tree/v1.2.2)\] - 2026-01-26

### Changed

- bumped fdc-client image to v1.2.4

# \[[v1.2.1](https://github.com/flare-foundation/flare-systems-deployment/tree/v1.2.1)\] - 2026-01-23

### Changed

- bumped fdc-client image to v1.2.3

# \[[v1.2.0](https://github.com/flare-foundation/flare-systems-deployment/tree/v1.2.0)\] - 2025-12-18

### Changed

- bumped fdc-client image to v1.2.2

### Added

- generate fdc-client config for Web2Json attestation type

# \[[v1.1.1](https://github.com/flare-foundation/flare-systems-deployment/tree/v1.1.1)\] - 2025-11-06

### Changed

- bumped flare-system-c-chain-indexer image to v1.1.2
- bumped fast-updates image to v1.0.2
- bumped fdc-client image to v1.1.0

### Added

- pass secret values for flare-system-c-chain-indexer via env
- pass secret values for system-client via env
- pass secret values for fdc-client via env
- pass secret values for ftso-client via env
- pass secret values for fast-updates via env

# \[[v1.1.0](https://github.com/flare-foundation/flare-systems-deployment/tree/v1.0.8)\] - 2025-10-22

### Changed

- bumped flare-system-c-chain-indexer image to v1.1.1
- bumped flare-system-client image to v1.0.5
- bumped fdc-client image to v1.0.6
- bumped ftso-scaling image to v1.0.4
- bumped fast-updates image to v1.0.1
- bump max_priority_fee_per_gas config in system client from 20Gwei to 100Gwei
  for better performance during gas spikes

### Added

- add image tag for mysql (9.5.0)
- pass secret values for flare-system-c-chain-indexer via env
- added `fast-updates` to example value for `COMPOSE_PROFILES` as entities are
  expected to run fast updates

# \[[v1.0.8](https://github.com/flare-foundation/flare-systems-deployment/tree/v1.0.8)\] - 2025-06-11
