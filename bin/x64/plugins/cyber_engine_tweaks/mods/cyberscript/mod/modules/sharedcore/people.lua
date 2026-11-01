-- People: one registry of who lives in Night City, shared by every mod.
--
-- A person gets into the registry three ways:
--   generated  people.populate(place, opts) makes the people of a place (a
--              workplace, a building, a gang's crew) from the save's seed: the
--              same save always gets the same people, a new save new ones.
--   hand-made  people.register(def): characters a mod writes on purpose.
--   promoted   people.promote(def): someone another mod already half-knows
--              (a network user, a bank account's owner, a boss) becomes a full
--              person the first time they matter. Same key, same person.
--
-- Only what has CHANGED is saved (generated people can always be rebuilt from
-- the seed), so saves stay small however many people there are.
--
-- A person: { id, name, first, last, gender, pronoun, look = { record, appearance },
--   age, home, place, job, org, district, traits = { ... }, status, source }
--   status: "alive" (default), "hurt", "missing", "dead", or anything a mod uses
--
-- Each person also has relationships with other people, a history of what
-- happened to them, and an opinion of V (-100 to 100).
--
-- The game's own story characters are not people here: their lives are written
-- by the game's quests. Mods can still name them in relationships or text.

return function(Core)
	local people = { list = {}, order = {}, populated = {}, registered = {} }
	local Rng = Core.Rng

	---------------------------------------------------------------------------
	-- Word lists (Night City is everyone)
	---------------------------------------------------------------------------

	local firstNames = {
		male = { "Aaron", "Akio", "Andrés", "Bao", "Carlos", "Dante", "Dmitri", "Emeka", "Felix", "Gus", "Hiro",
			"Ilya", "Jamal", "Javier", "Jun", "Kenji", "Kofi", "Lars", "Luis", "Marcus", "Mateo", "Nikolai", "Omar",
			"Pavel", "Quinn", "Rafael", "Ravi", "Rico", "Samir", "Tomas", "Tyrone", "Victor", "Wei", "Yusuf", "Zed" },
		female = { "Aiko", "Ana", "Bianca", "Chiara", "Dalia", "Esme", "Faye", "Gloria", "Hana", "Imani", "Ines",
			"Jade", "Kat", "Keiko", "Lena", "Lupe", "Marisol", "Mei", "Nadia", "Nia", "Oksana", "Priya", "Rosa",
			"Sakura", "Sofia", "Tamsin", "Uma", "Valentina", "Wen", "Yara", "Yuki", "Zainab", "Zoe" },
		other = { "Ash", "Blue", "Cass", "Echo", "Jules", "Kai", "Lux", "Nico", "Remy", "River", "Rook", "Sage", "Sky" },
	}
	local surnames = { "Alvarez", "Ahmed", "Brandt", "Castillo", "Cho", "Doyle", "Dubois", "Estrada", "Fujita",
		"Garza", "Gupta", "Hayes", "Herrera", "Ito", "Ivanova", "Jensen", "Kim", "Kowal", "Lima", "Lin", "Mbeki",
		"Morales", "Nakamura", "Novak", "Okafor", "Okoye", "Petrov", "Reyes", "Rossi", "Sato", "Silva", "Singh",
		"Tanaka", "Tran", "Vance", "Volkov", "Wu", "Yilmaz", "Zhou" }

	-- The game's crowd characters to look like, by way of life. A spawned crowd
	-- character picks a random appearance; whoever spawns a person first should
	-- save the one it got (people.update(id, { look = ... })) so they look the same after.
	people.looks = {
		corpo     = { male = { "Character.CorpoMan", "Character.CorpoManAfterWork", "Character.CorpoManCoffee" },
		              female = { "Character.CorpoWoman", "Character.CorpoWomanAfterWork", "Character.CorpoWomanBag" },
		              other = { "Character.NonBinaryMaleBodyCorpo", "Character.NonBinaryFemaleBodyCorpo" } },
		worker    = { male = { "Character.WorkerMale", "Character.WorkerSpecialistMale", "Character.TenantMale" },
		              female = { "Character.TenantWoman", "Character.WomanChubbyTenant" },
		              other = { "Character.NonBinaryMaleBody", "Character.NonBinaryFemaleBody" } },
		vendor    = { male = { "Character.VendorMale", "Character.AsianVendorMale", "Character.CreoleVendorMale" },
		              female = { "Character.VendorFemale", "Character.AsianVendorFemale", "Character.CreoleVendorFemale" },
		              other = { "Character.NonBinaryMaleBody", "Character.NonBinaryFemaleBody" } },
		nightlife = { male = { "Character.NightlifeMale", "Character.ObeseMaleNightlife" },
		              female = { "Character.NightlifeWoman" },
		              other = { "Character.NonBinaryMaleBodyNightlife", "Character.NonBinaryFemaleBodyNightlife" } },
		young     = { male = { "Character.YoungsterMale", "Character.YoungsterMaleBig" },
		              female = { "Character.YoungsterFemale", "Character.WomanChubbyYoungster" },
		              other = { "Character.NonBinaryMaleBodyYoungster", "Character.NonBinaryFemaleBodyYoungster" } },
		rich      = { male = { "Character.CitizenRichMale", "Character.CitizenRichMaleCasual" },
		              female = { "Character.CitizenRichFemale", "Character.CitizenRichFemaleCasual" },
		              other = { "Character.NonBinaryMaleBodyPosh", "Character.NonBinaryFemaleBodyPosh" } },
		street    = { male = { "Character.CitizenBikerMale", "Character.JunkieMale", "Character.HomelessMan" },
		              female = { "Character.CitizenBikerFemale", "Character.JunkieFemale", "Character.HomelessFemale" },
		              other = { "Character.NonBinaryMaleBody", "Character.NonBinaryFemaleBody" } },
		medical   = { male = { "Character.WorkerSpecialistMale" }, female = { "Character.NurseFemale" },
		              other = { "Character.NonBinaryFemaleBody" } },
		nomad     = { male = { "Character.CitizenAldecaldosMale", "Character.CitizenAldecaldosMaleMechanic" },
		              female = { "Character.CitizenAldecaldosFemale", "Character.CitizenAldecaldosFemaleNomad" },
		              other = { "Character.CitizenAldecaldosFemale" } },
	}

	-- Personality: each person gets a couple of these.
	people.traitList = { "loyal", "greedy", "brave", "cowardly", "kind", "cruel", "honest", "liar", "ambitious",
		"lazy", "curious", "paranoid", "hot-headed", "calm", "romantic", "cynical", "religious", "chromed-out",
		"addict", "gambler", "family-first", "loner", "gossip", "vengeful", "forgiving" }

	-- Relationship kinds. Two-way ones are kept on both people.
	people.relationKinds = {
		partner = true, spouse = true, sibling = true, friend = true, rival = true, enemy = true, coworker = true,
		roommate = true, crew = true, ex = true,
		parent = "child", child = "parent", boss = "employee", employee = "boss",
	}

	---------------------------------------------------------------------------
	-- Saved state: only what changed
	---------------------------------------------------------------------------

	local rebuild -- below: makes the known people again for a newly loaded save

	local function state()
		local s = Core.state()
		if s == nil then return nil end
		s.people = s.people or {}
		local p = s.people
		if people.boundTo ~= p then
			people.boundTo = p
			rebuild(p)
		end
		p.changes = p.changes or {}     -- id -> fields changed on a generated or hand-made person
		p.made = p.made or {}           -- id -> a promoted person, whole (nothing to rebuild them from)
		p.keys = p.keys or {}           -- promotion key -> id
		p.places = p.places or {}       -- place -> opts it was populated with (to rebuild after a load)
		p.relations = p.relations or {} -- id -> { otherId -> kind } changed or added
		p.history = p.history or {}     -- id -> { { time, kind, text, by } }
		p.opinion = p.opinion or {}     -- id -> opinion of V
		p.nextId = p.nextId or 1
		return p
	end

	local function copy(t)
		if type(t) ~= "table" then return t end
		local out = {}
		for k, v in pairs(t) do out[k] = copy(v) end
		return out
	end

	local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

	local function now()
		local s = Core.state()
		return s and s.market and s.market.clock or 0
	end

	---------------------------------------------------------------------------
	-- Generation
	---------------------------------------------------------------------------

	local function seed() local s = Core.state() return s and s.seed or "0" end

	local function pickGender(rng)
		local r = rng:next()
		if r < 0.47 then return "male", "he" elseif r < 0.94 then return "female", "she" end
		return "other", "they"
	end

	-- One generated person: the same for the same seed, place and number.
	local function generate(place, n, opts)
		local rng = Rng.new(seed(), "person", place, n)
		local gender, pronoun = pickGender(rng)
		local first, last = rng:pick(firstNames[gender]), rng:pick(surnames)
		local lifestyle = opts.lifestyle or "worker"
		local looks = people.looks[lifestyle] or people.looks.worker
		local traits = {}
		while #traits < 2 do
			local t = rng:pick(people.traitList)
			if traits[1] ~= t then table.insert(traits, t) end
		end
		local jobs = opts.jobs or { opts.job or "staff" }
		return {
			id = "gen:" .. place .. ":" .. n, source = "generated",
			name = first .. " " .. last, first = first, last = last, gender = gender, pronoun = pronoun,
			look = { record = rng:pick(looks[gender] or looks.male) },
			age = rng:int(opts.minAge or 19, opts.maxAge or 64),
			place = place, home = opts.home, job = jobs[((n - 1) % #jobs) + 1], org = opts.org,
			district = opts.district, lifestyle = lifestyle, traits = traits, status = "alive",
		}
	end

	-- Relationships within a place, decided once from the seed.
	local function baseRelations(place, ids)
		local rng = Rng.new(seed(), "relations", place)
		local rel = {}
		local function link(a, b, kind)
			rel[a] = rel[a] or {}
			rel[a][b] = kind
			local back = people.relationKinds[kind]
			rel[b] = rel[b] or {}
			rel[b][a] = type(back) == "string" and back or kind
		end
		for i = 1, #ids do
			for j = i + 1, #ids do
				local r = rng:next()
				if r < 0.08 then link(ids[i], ids[j], "partner")
				elseif r < 0.14 then link(ids[i], ids[j], "sibling")
				elseif r < 0.34 then link(ids[i], ids[j], "friend")
				elseif r < 0.40 then link(ids[i], ids[j], "rival")
				end
			end
		end
		return rel
	end

	local baseRel = {} -- id -> { otherId -> kind } from generation (rebuilt, never saved)

	local function remember(p)
		if people.list[p.id] == nil then table.insert(people.order, p.id) end
		people.list[p.id] = p
	end

	-- Makes the people of a place, or gives back the ones already made.
	-- place: any string a mod picks ("rn:watson.hotel-3a", "corp:arasaka:hr").
	-- opts: { count, lifestyle, job, jobs = { ... }, org, home, district, minAge, maxAge }
	-- Returns the ids, in order. Populating the same place again returns the same people.
	function people.populate(place, opts)
		local st = state()
		if st == nil or type(place) ~= "string" then return {} end
		if people.populated[place] then return people.populated[place] end
		opts = opts or st.places[place] or {}
		st.places[place] = opts
		local ids = {}
		for n = 1, math.max(0, math.floor(opts.count or 3)) do
			local p = generate(place, n, opts)
			remember(p)
			table.insert(ids, p.id)
		end
		for a, links in pairs(baseRelations(place, ids)) do
			baseRel[a] = baseRel[a] or {}
			for b, kind in pairs(links) do baseRel[a][b] = kind end
		end
		people.populated[place] = ids
		Core.emit("people.populated", { place = place, ids = ids })
		return ids
	end

	-- Hand-made characters. def: a person's fields plus `id` (yours, prefixed with
	-- your mod's name: "mymod:fixer_rosa"). Register them again on every load,
	-- like organisations; what happens to them is saved.
	function people.register(def)
		if type(def) ~= "table" or type(def.id) ~= "string" then return nil end
		local p = copy(def)
		p.source = p.source or "registered"
		p.status = p.status or "alive"
		if p.name == nil then p.name = (((p.first or "") .. " " .. (p.last or "")):gsub("^%s+", ""):gsub("%s+$", "")) end
		people.registered[p.id] = p
		remember(p)
		Core.emit("people.added", { id = p.id, source = p.source })
		return p.id
	end

	-- Someone another mod already knows about, made a full person the first time
	-- they matter. def: { key (unique to them, e.g. "rn:watson.pc-1a2b:m.reyes"),
	-- name?, first?, last?, initial?, handle?, gender?, lifestyle?, job?, org?, place?, home?, district? }.
	-- initial: the first letter of their first name, if that's all that's known;
	-- handle: a street name, kept in quotes in the full name.
	-- Missing details are filled in from the key, so the same key always gives
	-- the same person. Returns the id (the same one every time for the same key).
	function people.promote(def)
		local st = state()
		if st == nil or type(def) ~= "table" or type(def.key) ~= "string" then return nil end
		local existing = st.keys[def.key]
		if existing then return existing end
		local rng = Rng.new(seed(), "promote", def.key)
		local gender, pronoun = def.gender, def.pronoun
		if gender == nil then gender, pronoun = pickGender(rng) end
		pronoun = pronoun or (gender == "male" and "he" or gender == "female" and "she" or "they")
		local pool = firstNames[gender] or firstNames.other
		if def.initial then
			-- a first name that fits a known initial ("k.tanaka" -> Kenji, Keiko...)
			local fits = {}
			for _, n in ipairs(pool) do if n:sub(1, 1):lower() == def.initial:lower() then table.insert(fits, n) end end
			if #fits > 0 then pool = fits end
		end
		local first = def.first or rng:pick(pool)
		local last = def.last or rng:pick(surnames)
		local looks = people.looks[def.lifestyle or "worker"] or people.looks.worker
		local id = "p:" .. st.nextId
		st.nextId = st.nextId + 1
		local p = {
			id = id, key = def.key, source = def.source or "promoted",
			name = def.name or (def.handle and (first .. " \"" .. def.handle .. "\" " .. last) or (first .. " " .. last)),
			first = first, last = last, handle = def.handle, gender = gender, pronoun = pronoun,
			look = def.look or { record = rng:pick(looks[gender] or looks.male) },
			age = def.age or rng:int(19, 64), place = def.place, home = def.home, job = def.job, org = def.org,
			district = def.district, lifestyle = def.lifestyle or "worker",
			traits = def.traits or { rng:pick(people.traitList), rng:pick(people.traitList) }, status = "alive",
		}
		st.made[id] = p
		st.keys[def.key] = id
		remember(p)
		Core.emit("people.added", { id = id, source = p.source, key = def.key })
		return id
	end

	-- A different save was loaded: start from its people. Promoted people come
	-- back from the save, populated places are made again from the seed, and
	-- hand-made characters stay registered.
	rebuild = function(st)
		st.changes = st.changes or {}
		st.made = st.made or {}
		st.keys = st.keys or {}
		st.places = st.places or {}
		st.relations = st.relations or {}
		st.history = st.history or {}
		st.opinion = st.opinion or {}
		st.nextId = st.nextId or 1
		people.list, people.order, people.populated, baseRel = {}, {}, {}, {}
		for _, p in pairs(people.registered) do remember(p) end
		local ids = {}
		for id in pairs(st.made) do table.insert(ids, id) end
		table.sort(ids)
		for _, id in ipairs(ids) do remember(st.made[id]) end
		local places = {}
		for place in pairs(st.places) do table.insert(places, place) end
		table.sort(places)
		for _, place in ipairs(places) do people.populate(place, st.places[place]) end
	end

	---------------------------------------------------------------------------
	-- Reading
	---------------------------------------------------------------------------

	-- A person as they are now (generated or hand-made details with every change on top).
	function people.get(id)
		local st = state()
		local base = people.list[id]
		if base == nil and st and st.made[id] then base = st.made[id] remember(base) end
		if base == nil then return nil end
		local p = copy(base)
		local changes = st and st.changes[id]
		if changes then for k, v in pairs(changes) do p[k] = copy(v) end end
		p.opinion = st and st.opinion[id] or 0
		return p
	end

	function people.byKey(key)
		local st = state()
		return st and st.keys[key]
	end

	-- People matching every field given: people.find({ org = "maelstrom", status = "alive" }).
	-- Only people already known (populated, registered or promoted) are searched.
	function people.find(query)
		local out = {}
		for _, id in ipairs(people.order) do
			local p = people.get(id)
			local ok = p ~= nil
			for k, v in pairs(query or {}) do
				if not ok then break end
				if k == "trait" then
					local has = false
					for _, t in ipairs(p.traits or {}) do if t == v then has = true end end
					ok = has
				elseif p[k] ~= v then ok = false end
			end
			if ok then table.insert(out, p) end
		end
		return out
	end

	function people.all() return people.find({}) end

	---------------------------------------------------------------------------
	-- Changing
	---------------------------------------------------------------------------

	-- Changes a person's details (status, job, home, org, look, anything). Saved.
	function people.update(id, fields, why)
		local st = state()
		if st == nil or type(fields) ~= "table" or people.get(id) == nil then return false end
		local before = people.get(id)
		if st.made[id] then
			for k, v in pairs(fields) do st.made[id][k] = copy(v) end
		else
			st.changes[id] = st.changes[id] or {}
			for k, v in pairs(fields) do st.changes[id][k] = copy(v) end
		end
		local changed = {}
		for k, v in pairs(fields) do changed[k] = { old = before[k], new = v } end
		Core.emit("people.changed", { id = id, changed = changed, why = why })
		return true
	end

	-- Adds to what happened to someone. kind: a short word ("robbed", "hired",
	-- "hurt", "met_v"); text: one line a person could read; by: who did it (an
	-- org id, a person id, or "player" for V). Keeps the latest 30 per person.
	function people.remember(id, kind, text, by)
		local st = state()
		if st == nil or people.get(id) == nil then return false end
		st.history[id] = st.history[id] or {}
		local h = st.history[id]
		local entry = { time = now(), kind = kind, text = text, by = by }
		table.insert(h, entry)
		while #h > 30 do table.remove(h, 1) end
		Core.emit("people.event", { id = id, kind = kind, text = text, by = by })
		return true
	end

	function people.history(id)
		local st = state()
		return copy(st and st.history[id] or {})
	end

	-- What a person thinks of V, -100 to 100.
	function people.opinion(id)
		local st = state()
		return st and st.opinion[id] or 0
	end

	function people.changeOpinion(id, amount, why)
		local st = state()
		if st == nil or people.get(id) == nil then return 0 end
		local before = st.opinion[id] or 0
		local after = clamp(math.floor(before + (tonumber(amount) or 0) + 0.5), -100, 100)
		st.opinion[id] = after
		if after ~= before then
			Core.host.setVariable("core_opinion", id, after)
			Core.emit("people.opinion", { id = id, value = after, change = after - before, why = why })
		end
		return after
	end

	---------------------------------------------------------------------------
	-- Relationships
	---------------------------------------------------------------------------

	-- Everyone a person is tied to: { otherId -> kind }.
	function people.relations(id)
		local st = state()
		local out = {}
		for other, kind in pairs(baseRel[id] or {}) do out[other] = kind end
		for other, kind in pairs(st and st.relations[id] or {}) do
			if kind == false then out[other] = nil else out[other] = kind end
		end
		return out
	end

	-- Ties two people (kind from people.relationKinds, or your own word), or
	-- unties them with kind = nil. Both sides are updated.
	function people.relate(a, b, kind, why)
		local st = state()
		if st == nil or a == b or people.get(a) == nil or people.get(b) == nil then return false end
		local back = people.relationKinds[kind]
		local backKind = kind == nil and false or (type(back) == "string" and back or kind)
		st.relations[a] = st.relations[a] or {}
		st.relations[b] = st.relations[b] or {}
		st.relations[a][b] = kind == nil and false or kind
		st.relations[b][a] = backKind
		Core.emit("people.relation", { a = a, b = b, kind = kind, why = why })
		return true
	end

	return people
end
