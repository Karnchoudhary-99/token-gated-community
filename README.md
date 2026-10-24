# Token-Gated Community Platform

On-chain membership for communities: hold the token, unlock the room.
A Solidity platform where communities define membership tiers by token
balance, gate content and perks behind those tiers, and verify
membership on-chain — no off-chain allowlist to trust.

## Roadmap

- [x] Project scaffold (Foundry, src/test/script layout, CI)
- [ ] Membership token + tier registry (tiers by minimum balance)
- [ ] Gated access checks (content/perk eligibility, expiry)
- [ ] Community admin (tier management, pausing, delegation)
- [ ] Invariant fuzz tests + gas report, then self-review checklist, then public

## Quick start

```bash
forge build
forge test
```

## License

MIT
