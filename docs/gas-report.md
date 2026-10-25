# Gas report

Baseline: `forge snapshot` (optimizer on, 200 runs, solc 0.8.24).
Figures below are full **test-scenario** gas from `.gas-snapshot` — each
scenario includes contract deployment and setup, so they are upper
bounds on the individual calls, not isolated call costs. They are useful
for spotting regressions run to run, not for quoting a user a mint price.

## Contract size

| Contract | Runtime size | Initcode size | Runtime margin to the 24,576-byte limit |
|---|---|---|---|
| `CommunityGate` | 6,157 B | 6,444 B | 18,419 B |
| `GatedToken` | 1,944 B | 2,789 B | 22,632 B |

Both contracts are dependency-free (no OpenZeppelin): the gate only ever
needs `balanceOf`, so the token stays a minimal ERC-20 and deployment
stays small.

## Test-scenario gas (from `.gas-snapshot`)

| Scenario | Gas |
|---|---|
| Mint + transfer | 93,890 |
| Approve + transferFrom | 98,789 |
| Burn reduces supply | 66,951 |
| Highest tier wins regardless of order | 273,535 |
| Deactivated tier skipped | 192,489 |
| Update tier changes eligibility | 125,817 |
| Post at threshold + list by channel | 425,045 |
| Pause blocks posts but not reads | 243,709 |
| Non-member cannot post | 112,591 |
| Deactivated channel blocks posts | 112,696 |

## Invariant fuzz

`forge test` invariant profile: 256 runs, depth 100, `fail_on_revert`.
Each invariant ran 25,600 handler calls with 0 reverts across the suite —
every handler action is guarded, so a revert would mean a real bug, not a
fuzzer artefact. The four invariants (supply accounting, tierOf highest
qualified, channel posts partition the post log, checkAccess matches the
balance comparison) all held.
