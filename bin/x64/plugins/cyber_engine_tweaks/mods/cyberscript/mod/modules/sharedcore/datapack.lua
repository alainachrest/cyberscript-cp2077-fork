-- The shared core for CyberScript datapacks: actions, triggers and variables.
--
-- Actions (in an action list):
--   { "name": "core:add_news",        "text": "Arasaka stock slides", "org": "arasaka" }
--   { "name": "core:add_heat",        "channel": "ncpd", "value": 10 }
--   { "name": "core:set_heat",        "channel": "ncpd", "value": 0 }
--   { "name": "core:change_standing", "org": "militech", "value": -15 }
--   { "name": "core:set_standing",    "org": "militech", "value": 50 }
--   { "name": "core:market_shock",    "ticker": "ARA", "value": -0.08 }
--   { "name": "core:give_shares",     "ticker": "MIL", "value": 10 }
--
-- Triggers (in requirements; "expected" works as usual):
--   { "name": "core:heat_above",       "channel": "netwatch", "value": 50 }
--   { "name": "core:standing_above",   "org": "arasaka", "value": 20 }
--   { "name": "core:standing_below",   "org": "arasaka", "value": -20 }
--   { "name": "core:share_price_above", "ticker": "ARA", "value": 900 }
--   { "name": "core:owns_shares",      "ticker": "ARA", "value": 1 }
--
-- Variables (kept in step automatically):
--   tag "core_heat", key = channel          tag "core_standing", key = organisation

return function(Core)
	local datapack = {}
	local owner = "CyberScript shared core"

	local function num(v, default) return tonumber(v) or default or 0 end

	datapack.actions = {
		["core:add_news"] = function(a) Core.news.add(a.text or a.value, { source = "datapack", org = a.org }) end,
		["core:add_heat"] = function(a) Core.heat.add(a.channel or "netwatch", num(a.value), a.why or "datapack") end,
		["core:set_heat"] = function(a) Core.heat.set(a.channel or "netwatch", num(a.value), a.why or "datapack") end,
		["core:change_standing"] = function(a) Core.standing.change(a.org, num(a.value), a.why or "datapack") end,
		["core:set_standing"] = function(a) Core.standing.set(a.org, num(a.value), a.why or "datapack") end,
		["core:market_shock"] = function(a) Core.market.shock(tostring(a.ticker or ""):upper(), num(a.value), a.why or "datapack") end,
		["core:give_shares"] = function(a)
			local s = Core.market.state()
			local c = Core.market.get(a.ticker)
			if s == nil or c == nil or num(a.value) <= 0 then return end
			local held = s.holdings[c.ticker] or 0
			s.cost[c.ticker] = ((s.cost[c.ticker] or 0) * held) / (held + num(a.value))
			s.holdings[c.ticker] = held + math.floor(num(a.value))
		end,
	}

	datapack.triggers = {
		["core:heat_above"] = function(t) return Core.heat.get(t.channel or "netwatch") > num(t.value) end,
		["core:standing_above"] = function(t) return Core.standing.get(t.org) > num(t.value) end,
		["core:standing_below"] = function(t) return Core.standing.get(t.org) < num(t.value) end,
		["core:share_price_above"] = function(t) return Core.market.price(tostring(t.ticker or ""):upper()) > num(t.value) end,
		["core:owns_shares"] = function(t) return Core.market.held(tostring(t.ticker or ""):upper()) >= num(t.value, 1) end,
	}

	-- Called once CyberScript's extension layer is loaded.
	function datapack.register(extensions)
		if extensions == nil then return false end
		for name, fn in pairs(datapack.actions) do extensions.registerAction(name, function(a) fn(a) end, owner) end
		for name, fn in pairs(datapack.triggers) do extensions.registerTrigger(name, fn, owner) end
		return true
	end

	return datapack
end
