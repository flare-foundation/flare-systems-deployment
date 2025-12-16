# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

# \[[v1.1.2]()\] - Upcoming

### Changed

- bumped fdc-client image to v1.2.2

### Added

- generate fdc client config for Web2Json attestation type

# \[[v1.1.1](https://github.com/flare-foundation/flare-systems-deployment/tree/v1.0.8)\] - 2025-11-06

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
