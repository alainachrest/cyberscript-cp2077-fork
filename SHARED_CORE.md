# CyberScript shared core

The parts of Night City that several mods share, kept in CyberScript so they all agree: what one mod does, the others see. Real Netrunning runs on it, and so will the property, corporation and corporate-career mods.

It's saved with each CyberScript save (`currentSave.core`), so every save has its own world, and nothing in it moves while the game is paused.

## For CET mods

```lua
local cs = GetMod("cyberscript")
local core = cs and cs.api and (cs.api.apiVersion or 0) >= 2 and cs.api.core
```

| Part | What it does |
| --- | --- |
| `core.orgs` | Corporations, gangs and other organisations, and world regions. `get(id)`, `all(kind)`, `register({ id, name, kind, region, ... })` to add your own (or add fields to an existing one), `region(id)`. Register yours again on every load. |
| `core.market` | The stock exchange. `get(ticker)`, `forOrg(org)`, `price`, `change`, `history`, `held`, `buy(ticker, qty)`, `sell(ticker, qty or "all")`, `portfolio()`, `shock(ticker, pct, why)`, `addTip(ticker, pct, steps, headline)`, `listCompany({ ticker, name, org, price, vol, rivals })`, `delist(ticker)`. Prices step every 30 seconds of play. |
| `core.news` | One news feed. `add(text, { source, org })`, `list(n)`, `texts(n)`. Keeps the latest 60 stories. |
| `core.heat` | Attention V is drawing, 0 to 100, per channel (`"netwatch"`, `"ncpd"`, anything). `get`, `add`, `set`, `all`, `setDecay(channel, perMinute)`. |
| `core.standing` | How each organisation feels about V, -100 to 100. `get`, `change`, `set`, `all`, `describe(value)`. |
| `core.money` | V's eddies: `get()`, `give(n)`, `take(n)` (false if V can't afford it). |

### Events

`core.on(name, fn)` returns an id for `core.off(id)`. The same events reach `cs.api.on("core.<name>", fn)`.

- `news` `{ text, source, org, time }`
- `heat` `{ channel, value, change, why }`
- `standing` `{ org, value, change, why }`
- `market.shock` `{ ticker, pct, why }`, `market.trade` `{ side, ticker, qty, price, tipped }`, `market.step` `{ clock }`, `market.listed`, `market.delisted`
- `org.registered` `{ id }`

## For datapacks

Actions:

```json
{ "name": "core:add_news", "text": "Arasaka stock slides", "org": "arasaka" }
{ "name": "core:add_heat", "channel": "ncpd", "value": 10 }
{ "name": "core:set_heat", "channel": "ncpd", "value": 0 }
{ "name": "core:change_standing", "org": "militech", "value": -15 }
{ "name": "core:set_standing", "org": "militech", "value": 50 }
{ "name": "core:market_shock", "ticker": "ARA", "value": -0.08 }
{ "name": "core:give_shares", "ticker": "MIL", "value": 10 }
```

Triggers (the usual `expected` works):

```json
{ "name": "core:heat_above", "channel": "netwatch", "value": 50 }
{ "name": "core:standing_above", "org": "arasaka", "value": 20 }
{ "name": "core:standing_below", "org": "arasaka", "value": -20 }
{ "name": "core:share_price_above", "ticker": "ARA", "value": 900 }
{ "name": "core:owns_shares", "ticker": "ARA", "value": 1 }
```

Variables kept in step: tag `core_heat` (key = channel) and tag `core_standing` (key = organisation).

The code is in `mod/modules/sharedcore/`.
