# Token-Gated Community Platform

On-chain membership for communities: hold the token, unlock the room.
A Solidity platform where communities define membership tiers by token
balance, gate content and perks behind those tiers, and verify
membership on-chain — no off-chain allowlist to trust.

## Roadmap

- [x] Project scaffold (Foundry, src/test/script layout, CI)
- [x] Membership token + tier registry (tiers by minimum balance)
- [x] Gated access checks (content/perk eligibility) + tier management + pausing
- [x] Invariant fuzz tests + gas report (256 runs, 0 reverts, see `docs/gas-report.md`)
- [x] Self-review checklist, then public

## How it works

- `GatedToken` — a minimal ERC-20 membership token (`COMM`). The community
  admin mints it; holders can transfer or burn it.
- `CommunityGate` — holds the token address and two registries:
  - **Tiers**: each tier has a name and a minimum balance. `tierOf(user)`
    returns the highest *active* tier the user qualifies for, judged by
    threshold, not by the order tiers were added. Deactivated tiers are
    skipped, and `updateTier` can re-threshold a tier without redeploying.
  - **Channels**: each channel has a minimum balance to post. Posting
    requires holding tokens and meeting the channel's threshold; anyone can
    read via `checkAccess(user, amount)` and `postsInChannel(id)`.
- Pausing blocks new posts but never blocks reads, so a paused community
  stays auditable.

## Quick start

```bash
forge build
forge test
```

## Deploy (local Anvil demo)

```bash
anvil &  # in another terminal
forge script script/Deploy.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
```

The deploy script seeds Bronze (1 COMM), Silver (10 COMM) and Gold
(100 COMM) tiers, plus `general` (1 COMM) and `supporters` (10 COMM)
channels. The deployer owns both contracts, so it can mint tokens and
manage tiers/channels from the same account.

## API reference

### GatedToken

- `mint(to, amount)` — owner only.
- `transfer(to, amount)`, `approve(spender, amount)`, `transferFrom(from, to, amount)`
- `burn(amount)` — burn your own tokens.
- `balanceOf(account)`, `totalSupply()`, `name()`, `symbol()`, `decimals()` (= 18)

### CommunityGate

- `addTier(name, minBalance) -> tierId`, `updateTier(id, name, minBalance)`,
  `setTierActive(id, active)`
- `tierOf(user) -> (hasTier, tierId, name)` — highest active tier met.
- `isMember(user)`, `checkAccess(user, requiredMinBalance)`
- `createChannel(name, requiredMinBalance) -> channelId`,
  `setChannelActive(id, active)`
- `postMessage(channelId, content) -> postId` — reverts for non-members,
  below-threshold posters, empty posts, inactive channels, and while paused.
- `postsInChannel(channelId)`, `postCount()`, `pause()`, `unpause()`

## Tests

25 Foundry tests: token mint/transfer/approve/burn and revert cases,
tier resolution (including out-of-order tiers, deactivation, re-thresholding),
and channel gating (threshold posts, non-members, empty posts, deactivated
channels, pause behaviour). Plus 4 invariant fuzz tests (256 runs, depth 100,
0 reverts): token supply always equals actor balances, `tierOf` always returns
the highest active qualified tier, channel listings always partition the post
log, and `checkAccess` always matches the balance comparison.

## License

MIT
