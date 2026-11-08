local function noop() end
local timers, initializers, frames, navigated = {}, {}, {}, {}
local clock, busy, combat = 0, false, false
local function region()
	return {
		SetText = function(self, t)
			self.text = t
		end,
	}
end
local function frame(_, name, parent, template)
	local f = { name = name, parent = parent, template = template, scripts = {}, shown = false }
	function f:SetScript(event, fn)
		self.scripts[event] = fn
	end
	function f:SetPoint(...)
		self.point = { ... }
	end
	function f:Show()
		self.shown = true
	end
	function f:Hide()
		self.shown = false
	end
	function f:IsShown()
		return self.shown
	end
	function f:SetText(text)
		self.text = text
	end
	function f:SetEnabled(enabled)
		self.enabled = enabled
	end
	function f:SetPropagateKeyboardInput(v)
		self.propagate = v
	end
	function f:SetScrollChild(child)
		self.child = child
	end
	f.SetSize, f.SetFrameStrata, f.SetClampedToScreen, f.EnableKeyboard, f.SetWidth, f.SetHeight, f.SetVerticalScroll =
		noop, noop, noop, noop, noop, noop, noop
	if template == "BasicFrameTemplateWithInset" then
		f.TitleText = region()
	end
	frames[#frames + 1] = f
	return f
end
local data = {
	[1] = { "Near vendor", { [10] = { { 10, 10 } } }, "A", 4, n = 4 },
	[2] = { "Far vendor", { [10] = { { 80, 80 } } }, "A", 4, n = 4 },
	[3] = { "Horde vendor", { [10] = { { 11, 11 } } }, "H", 4, n = 4 },
	[4] = { "Hostile vendor", { [10] = { { 12, 12 } } }, nil, 4, n = 4 },
	[5] = { "No coordinates", nil, "A", 4, n = 4 },
	[6] = { "Mage trainer", { [10] = { { 30, 30 } } }, "A", 16, n = 4 },
	[7] = { "Warrior trainer", { [10] = { { 1, 1 } } }, "A", 16, n = 4 },
	[9] = { "Bad position", { [10] = { { -1, -1 }, { 101, 1 } } }, "A", 4, n = 4 },
	[10] = { "Neutral repairs", { [11] = { { 20, 20 } } }, "AH", 16384, n = 4 },
	[11] = { "Fishing supplier", { [10] = { { 50, 50 } } }, "A", 4, n = 4 },
	[12] = { "Mining supplier", { [10] = { { 60, 60 } } }, "A", 4, n = 4 },
	[13] = { "Both vendor", { [10] = { { 70, 70 } } }, "A", 4, n = 4 },
	[1215] = { "Alchemy trainer", { [10] = { { 40, 40 } } }, "A", 16, n = 4 },
}
-- QuestieDB's item fields for the fixture vendors: the NPCs that sell it, its class and its subclass.
local items = {
	[2512] = { { 1, 2 }, 6, 2 }, -- Rough Arrow
	[2516] = { { 1 }, 6, 3 }, -- Light Shot
	[4540] = { { 1 }, 0, 0 }, -- Tough Hunk of Bread, in ns.Food
	[159] = { { 1 }, 0, 0 }, -- Refreshing Spring Water, in ns.Drink
	[4498] = { { 1 }, 1, 0 }, -- Brown Leather Satchel
	[2320] = { { 1 }, 7, 0 }, -- Coarse Thread
	[4470] = { { 1 }, 5, 0 }, -- Simple Wood
	[851] = { { 1 }, 2, 7 }, -- Cutlass
	[6256] = { { 11 }, 2, 20 }, -- Fishing Pole
	[2901] = { { 12 }, 2, 14 }, -- Mining Pick
	[3448] = { { 13 }, 0, 0 }, -- in both ns.Food and ns.Drink
}
local itemIDs = {}
for id in pairs(items) do
	itemIDs[#itemIDs + 1] = id
end
table.sort(itemIDs)
local flags = {
	VENDOR = 4,
	TRAINER = 16,
	REPAIR = 16384,
	INNKEEPER = 128,
	BANKER = 256,
	AUCTIONEER = 4096,
	FLIGHT_MASTER = 8,
	STABLEMASTER = 8192,
}
local calls = 0

local menuEntries, releaseMenu, trackingMenus = {}, nil, {}
local mapOpens = 0
local function menuNode()
	local node = {}
	function node.CreateTitle(_self, text)
		menuEntries[#menuEntries + 1] = { text = text, title = true }
	end
	function node.SetScrollMode(self, extent)
		self.scrollExtent = extent
	end
	function node.CreateButton(_self, text, callback)
		local entry = { text = text, callback = callback, children = {} }
		function entry.CreateButton(_entry, childText, childCallback)
			local child = {
				text = childText,
				callback = childCallback,
				children = {},
				SetEnabled = function() end,
				SetScrollMode = function(c, extent)
					c.scrollExtent = extent
				end,
			}
			function child.CreateButton(c, childText2, childCallback2)
				local grandchild = { text = childText2, callback = childCallback2, SetEnabled = function() end }
				c.children[#c.children + 1] = grandchild
				return grandchild
			end
			entry.children[#entry.children + 1] = child
			return child
		end
		function entry.SetEnabled(_entry, enabled)
			entry.enabled = enabled
		end
		function entry.SetScrollMode(_entry, extent)
			entry.scrollExtent = extent
		end
		function entry.CreateTitle(_entry, titleText)
			entry.children[#entry.children + 1] = { text = titleText, title = true }
		end
		menuEntries[#menuEntries + 1] = entry
		return entry
	end
	return node
end
local lib = {
	RequireContract = function(v)
		assert(v == 2)
		return true
	end,
	Enum = { byExpansion = { Classic = { npcFlags = flags } } },
	Support = {
		Get = function(name)
			assert(name == "ZoneDB")
			return { private = { areaIdToUiMapId = "return {[10]=100}", subZoneToParentZone = "return {[11]=10}" } }
		end,
	},
	Npc = {
		GetAllIds = function(...)
			assert(select("#", ...) == 0, "installed DB APIs use dot calls")
			return { 1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 1215 }
		end,
		GetAll = function(id, fields)
			assert(type(id) == "number" and #fields == 4, "packed GetAll actual contract")
			calls = calls + 1
			return data[id]
		end,
	},
	Item = {
		GetAllIds = function(...)
			assert(select("#", ...) == 0, "installed DB APIs use dot calls")
			return itemIDs
		end,
		GetAll = function(id, fields)
			assert(type(id) == "number" and #fields == 3, "item fields: vendors, class, subClass")
			local row = items[id]
			return row and { row[1], row[2], row[3], n = 3 }
		end,
	},
}
local env = setmetatable({
	LibQuestieDB = lib,
	TweaksForever = {
		API = {
			version = 2,
			Trainers = function()
				return { { npc = 6, map = 100, x = 0.3, y = 0.3 } }
			end,
		},
	},
	CreateFrame = frame,
	Menu = {
		ModifyMenu = function(tag, callback)
			trackingMenus[tag] = callback
		end,
	},
	MenuUtil = {
		CreateContextMenu = function(_, callback)
			menuEntries = {}
			local root = menuNode()
			root.AddMenuReleasedCallback = function(_, callbackFn)
				releaseMenu = callbackFn
			end
			callback(nil, root)
		end,
	},
	-- The Forever client's MenuUtil has no CloseAllMenus: a button closes its menu through its response (#161).
	MenuResponse = { Open = 1, Refresh = 2, Close = 3, CloseAll = 4 },
	UIParent = {},
	UnitFactionGroup = function()
		return "Alliance"
	end,
	UnitClass = function()
		return "Warrior", "WARRIOR", 1
	end,
	C_TradeSkillUI = {
		GetTradeSkillDisplayName = function(skill)
			if skill == 171 then
				return "Alchemy"
			end
			return "Profession " .. skill
		end,
	},
	C_Map = {
		OpenWorldMap = function(uiMapID)
			assert(uiMapID == nil, "the menu opens the map where the player is")
			mapOpens = mapOpens + 1
		end,
		GetBestMapForUnit = function()
			return 100
		end,
		GetPlayerMapPosition = function()
			return {
				GetXY = function()
					return 0.1, 0.1
				end,
			}
		end,
	},
	C_Timer = {
		After = function(_, fn)
			timers[#timers + 1] = fn
		end,
	},
	debugprofilestop = function()
		clock = clock + 0.4
		return clock
	end,
	InCombatLockdown = function()
		return combat
	end,
	geterrorhandler = function()
		return function(err)
			error(err)
		end
	end,
	SlashCmdList = {},
	ShortestPathForever = {
		API = {
			Navigate = function(owner, map, x, y, title, kind)
				assert(
					type(owner) == "string" and map == 100 and x >= 0 and x <= 1 and y >= 0 and y <= 1,
					"public API receives UI coordinates"
				)
				navigated[#navigated + 1] = { owner, map, x, y, title, kind }
				return true
			end,
		},
	},
}, { __index = _G })
env._G = env
local ns = {
	Init = function(fn)
		initializers[#initializers + 1] = fn
	end,
	WorldPoint = function(map, x, y)
		assert(map == 100)
		return { map = 1, x = x * 1000, y = y * 1000 }
	end,
	Path = {
		Busy = function()
			return busy
		end,
	},
}
-- Core.lua's map opener and gamepad check: the game opens the map and menus under the gamepad interface (#158).
local gamepad, printed = false, {}
ns.GamepadUI = function()
	return gamepad
end
ns.Print = function(text)
	printed[#printed + 1] = text
end
ns.OpenWorldMap = function(uiMap)
	if gamepad then
		return env.WorldMapFrame ~= nil and env.WorldMapFrame:IsShown()
	end
	env.C_Map.OpenWorldMap(uiMap)
	return true
end
-- UI/MenuModifier.lua's guard, with errors left to surface here rather than reported.
ns.db = {}
ns.SafeCall = function(_, fn, ...)
	return true, fn(...)
end
setfenv(assert(loadfile("Locales/enUS.lua")), env)("ShortestPathForever", ns)
setfenv(assert(loadfile("Data/Services.lua")), env)("ShortestPathForever", ns)
-- The fixture class trainers for the player's class, beside the companion addon's own list.
ns.ClassTrainers = { [7] = 1 }
setfenv(assert(loadfile("UI/MenuModifier.lua")), env)("ShortestPathForever", ns)
setfenv(assert(loadfile("UI/Nearby.lua")), env)("ShortestPathForever", ns)
for _, fn in ipairs(initializers) do
	fn()
end
env.SlashCmdList.SPFNEAR("")
assert(mapOpens == 1, "opening the menu asks the game to open the map")
assert(ns.NearbyServices.State() == "building" and calls == 0, "index does not block click")
local trackingMenu = assert(trackingMenus.MENU_WORLD_MAP_TRACKING, "registers the native world-map tracking dropdown")
local minimapMenu = assert(trackingMenus.MENU_MINIMAP_TRACKING, "registers the native minimap tracking dropdown")
trackingMenu(nil, menuNode())
local loadingEntry
for _, item in ipairs(menuEntries) do
	if item.text == "Nearby services" then
		loadingEntry = item
	end
end
assert(
	loadingEntry and loadingEntry.children and loadingEntry.children[1].text == "Loading QuestieDB…",
	"tracking menu reports loading"
)
env.SlashCmdList.SPFNEAR("")
assert(#menuEntries > 0 and menuEntries[1].title, "nearby opens an addon-owned map menu")
local dismissedMenuCount = #menuEntries
assert(releaseMenu, "native menu release callback is registered")
releaseMenu()
local function pump()
	local fn = table.remove(timers, 1)
	assert(fn)
	fn()
end
busy = true
pump()
assert(calls == 0, "index shares idle budget with path jobs")
busy = false
combat = true
pump()
assert(calls == 0, "combat defers index work")
combat = false
while #timers > 0 do
	pump()
end
assert(ns.NearbyServices.State() == "ready")
assert(#menuEntries == dismissedMenuCount, "dismissed menu does not reopen after async loading")
menuEntries = {}
trackingMenu(nil, menuNode())
local tracking = menuEntries[1]
assert(tracking.text == "Nearby services" and #tracking.children > 0, "tracking menu exposes the groups")
local function menuEntry(entries, text)
	for _, item in ipairs(entries) do
		if item.text == text then
			return item
		end
	end
end
menuEntry(tracking.children, "Repair").callback()
assert(navigated[#navigated][5] == "Neutral repairs", "tracking repair action routes nearest")
menuEntries = {}
local opensBefore = mapOpens
minimapMenu(nil, menuNode())
local minimap = menuEntries[1]
local groups = ns.NearbyServices.Groups()
assert(#minimap.children == #groups + 3, "the minimap's tracking menu carries the same groups, one section title each")
menuEntry(minimap.children, "Class trainer").callback()
assert(navigated[#navigated][5] == "Warrior trainer", "a service chosen from the minimap routes to the nearest")
assert(mapOpens == opensBefore, "the minimap's menu routes without opening the world map")
local places = ns.NearbyServices.Index()
local function group(key)
	for _, item in ipairs(groups) do
		if item.key == key then
			return item
		end
	end
	error("no group: " .. key)
end
local function npcs(key)
	local seen, list = {}, {}
	for _, place in ipairs(places[key] or {}) do
		if not seen[place.id] then
			seen[place.id] = true
			list[#list + 1] = place.id
		end
	end
	table.sort(list)
	return list
end
local function same(actual, expected)
	if #actual ~= #expected then
		return false
	end
	for at, value in ipairs(actual) do
		if value ~= expected[at] then
			return false
		end
	end
	return true
end
assert(same(npcs("arrows"), { 1, 2 }), "arrows: both vendors, by item class 6 and subclass 2")
assert(same(npcs("bullets"), { 1 }), "bullets: item class 6 and subclass 3")
assert(same(npcs("food"), { 1, 13 }), "food: exact item IDs from Data/Services.lua")
assert(same(npcs("drink"), { 1, 13 }), "drink: exact item IDs, and an item can be both")
assert(same(npcs("bags"), { 1 }), "bags: item class 1")
assert(same(npcs("trade"), { 1 }), "trade supplies: item class 7")
assert(same(npcs("reagents"), { 1 }), "reagents: item class 5 or class 15 subclass 1")
assert(same(npcs("gear"), { 1 }), "gear: weapons and armour, not tools or fishing poles")
assert(same(npcs("class"), { 6, 7 }), "class trainers: the companion list merged with the player's own class")
assert(
	group("profession:171").label == "Alchemy" and same(npcs("profession:171"), { 1215 }),
	"a profession trainer is labelled by the spell that names its skill line"
)
for _, item in ipairs(groups) do
	if item.section == "trainers" and item.key ~= "class" then
		for _, id in ipairs(item.npcs) do
			assert(id ~= 6, "the mage trainer is in no profession group")
		end
	end
end
assert(ns.NearbyServices.Items("arrows", 1)[1] == 2512, "Items names what put the NPC in the group")
assert(ns.NearbyServices.Items("arrows", 2)[1] == 2512, "an item lists every NPC that sells it")
assert(ns.NearbyServices.Items("food", 1)[1] == 4540, "Items is exact, not a range")
assert(ns.NearbyServices.Items("drink", 13)[1] == 3448, "an item in both groups names both")
assert(ns.NearbyServices.Items("gear", 11) == nil, "a fishing pole is not a weapon")
assert(ns.NearbyServices.Items("gear", 12) == nil, "a mining pick is not a weapon")
local here = { map = 1, x = 100, y = 100 }
assert(ns.NearbyServices.Nearest("arrows", here).id == 1)
assert(ns.NearbyServices.Nearest("profession:171", here).id == 1215)
assert(ns.NearbyServices.Nearest("repair", { map = 2, x = 100, y = 100 }) == nil)
assert(places.repair[1].map == 100, "subzone uses parent map")
env.SlashCmdList.SPFNEAR("")
assert(menuEntry(menuEntries, "Class trainer").callback() == env.MenuResponse.CloseAll, "class action closes the menu")
assert(navigated[#navigated][5] == "Warrior trainer", "class action routes nearest class trainer")
env.SlashCmdList.SPFNEAR("")
local profession = menuEntry(menuEntries, "Alchemy")
assert(profession and profession.text == "Alchemy", "a profession group is listed by its client skill line name")
profession.callback()
assert(navigated[#navigated][5] == "Alchemy trainer", "profession picker sends the trainer of that skill")
env.SlashCmdList.SPFNEAR("")
assert(
	menuEntry(menuEntries, "Reagents").callback() == env.MenuResponse.CloseAll,
	"a service that starts a journey closes every menu"
)
assert(navigated[#navigated][5] == "Near vendor", "reagents route to the vendor selling the reagent")
local before = calls
local beforeMenus = #menuEntries
for _ = 1, 20 do
	env.SlashCmdList.SPFNEAR("")
end
assert(#menuEntries == beforeMenus, "menu rebuilds without creating frames")
assert(calls == before, "opening does not rebuild DB")
env.SlashCmdList.SPFNEAR("repair")
assert(navigated[#navigated][5] == "Neutral repairs")

-- A fresh copy of the menu over another QuestieDB, read to the end, then opened here or on another continent.
local function fresh(questie, away, L)
	local elsewhere = false
	env.LibQuestieDB = questie
	local starts = {}
	local copy = {
		L = L or ns.L,
		Path = ns.Path,
		Food = ns.Food,
		Drink = ns.Drink,
		ProfessionTrainers = ns.ProfessionTrainers,
		ClassTrainers = ns.ClassTrainers,
		Init = function(fn)
			starts[#starts + 1] = fn
		end,
		WorldPoint = function(_, x, y)
			return { map = elsewhere and 2 or 1, x = x * 1000, y = y * 1000 }
		end,
		OpenWorldMap = ns.OpenWorldMap,
		GamepadUI = ns.GamepadUI,
		Print = ns.Print,
		ModifyMenu = ns.ModifyMenu,
	}
	setfenv(assert(loadfile("UI/Nearby.lua")), env)("ShortestPathForever", copy)
	for _, fn in ipairs(starts) do
		fn()
	end
	while #timers > 0 do
		pump()
	end
	elsewhere = away
	env.SlashCmdList.SPFNEAR("")
	return copy
end
-- A zone QuestieDB has nothing for: every group, the services too, reads as unavailable here.
local away = fresh(lib, true)
assert(away.NearbyServices.State() == "ready")
local awayGroups = away.NearbyServices.Groups()
assert(#menuEntries == #awayGroups + 4, "a heading, three sections and every group")
for position = 2, #menuEntries do
	local item = menuEntries[position]
	if not item.title then
		assert(item.text:find("unavailable here", 1, true) and item.enabled == false and #item.children == 0, item.text)
	end
end
-- No QuestieDB, and one whose zone tables do not read, each say so in a line of their own.
assert(fresh(nil).NearbyServices.State() == "missing")
assert(#menuEntries == 2 and menuEntries[2].text == "Nearby services need the QuestieDB addon.")
local broken = setmetatable({}, { __index = lib })
for _, private in ipairs({
	{ areaIdToUiMapId = { [10] = 100 }, subZoneToParentZone = "return {[11]=10}" },
	{ areaIdToUiMapId = "return {[10]=100}", subZoneToParentZone = "return {" },
	{ areaIdToUiMapId = "error('gone')", subZoneToParentZone = "return {[11]=10}" },
}) do
	broken.Support = {
		Get = function()
			return { private = private }
		end,
	}
	assert(fresh(broken).NearbyServices.State() == "failed")
	assert(#menuEntries == 2 and menuEntries[2].text == "Nearby services could not read QuestieDB.")
end
env.LibQuestieDB = lib
-- Under the gamepad interface the services menu never opens the world map or a menu itself, even over a map the game
-- opened: the player is pointed at the map's own tracking menu, which lists the services.
gamepad = true
local opens, entries = mapOpens, menuEntries
env.SlashCmdList.SPFNEAR("")
assert(mapOpens == opens and menuEntries == entries, "no map or menu opened by us under the gamepad interface")
env.WorldMapFrame = {
	IsShown = function()
		return true
	end,
}
env.SlashCmdList.SPFNEAR("")
assert(mapOpens == opens and menuEntries == entries, "over an open map no menu of ours opens either")
assert(printed[#printed]:find("tracking menu", 1, true), "it points at the map's tracking menu")
gamepad, env.WorldMapFrame = false, nil
-- The planner's own travel cost chooses between the shortlist: an Alliance hunter in Auberdine takes the Teldrassil
-- boat to Darnassus rather than walk to Kaerbrus, though Kaerbrus is the closest by straight line.
do
	local driver = assert(loadfile("tests/journey_driver.lua"))()
	local travelEnv, worldNs = driver.env, driver.ns
	travelEnv._G = travelEnv
	driver.load("Core/SafeCall.lua")
	driver.load("UI/Looks.lua")
	driver.load("Core/API.lua")
	for _, file in ipairs({
		"Data/Routes.lua",
		"Data/Transports.lua",
		"Data/Taxi.lua",
		"Data/Portals.lua",
		"Data/Walks.lua",
	}) do
		driver.load(file)
	end
	local project = travelEnv.C_Map.GetWorldPosFromMapPos
	local kalimdor = { [1438] = true, [1439] = true, [1448] = true, [1457] = true }
	travelEnv.C_Map.GetWorldPosFromMapPos = function(map, point)
		local _, world = project(map, point)
		return kalimdor[map] and 1 or (map == 2 and 0 or map), world
	end
	local function ui(point)
		return 0.5 - point.y / 50000, 0.5 - point.x / 50000
	end
	-- Auberdine, Kaerbrus on the Felwood border, Dolanaar and Darnassus, at the issue's straight-line distances.
	local auberdine = { x = 6341.38, y = 557.68 }
	local playerX, playerY = ui(auberdine)
	travelEnv.C_Map.GetBestMapForUnit = function()
		return 1439
	end
	travelEnv.C_Map.GetPlayerMapPosition = function()
		return {
			GetXY = function()
				return playerX, playerY
			end,
		}
	end
	driver.move({ map = 1, x = auberdine.x, y = auberdine.y, z = 0 })
	-- The Teldrassil boat is at Auberdine's dock: one boat ride away is what the planner should see.
	worldNs.serverTime = 0
	assert(worldNs.Timetable.Sighted(293, { epoch = -206368, seen = 0, source = "you" }))
	local travelTimers = {}
	travelEnv.C_Timer = {
		After = function(_, fn)
			travelTimers[#travelTimers + 1] = fn
		end,
	}
	travelEnv.debugprofilestop = function()
		return 0
	end
	travelEnv.MenuResponse = { Open = 1, CloseAll = 4 }
	travelEnv.SlashCmdList = {}
	local travelTracking = {}
	travelEnv.Menu.ModifyMenu = function(tag, callback)
		travelTracking[tag] = callback
	end
	local function spawn(zone, point)
		local x, y = ui(point)
		return zone, { x * 100, y * 100 }
	end
	local function place(zone, point)
		local key, spot = spawn(zone, point)
		return { [key] = { spot } }
	end
	local travelNpcs = {
		[5501] = { "Kaerbrus", place(1448, { x = 6341.38, y = -1885 }), "A", 16, n = 4 },
		[5502] = { "Dazalar", place(1438, { x = 9347, y = 2200 }), "A", 16, n = 4 },
		[5503] = {
			"Darnassus hunter trainer",
			place(1457, { x = 9946.25, y = 2612.97 }),
			"A",
			16,
			n = 4,
		},
	}
	local npcIds = { 5501, 5502, 5503 }
	travelEnv.TweaksForever = {
		API = {
			version = 2,
			Trainers = function()
				local trainerList = {}
				for _, id in ipairs(npcIds) do
					trainerList[#trainerList + 1] = { npc = id }
				end
				return trainerList
			end,
		},
	}
	travelEnv.LibQuestieDB = {
		RequireContract = function(version)
			return version == 2
		end,
		Enum = { byExpansion = { Classic = { npcFlags = flags } } },
		Support = {
			Get = function(name)
				assert(name == "ZoneDB")
				return {
					private = {
						areaIdToUiMapId = "return {[1438]=1438,[1439]=1439,[1448]=1448,[1457]=1457}",
						subZoneToParentZone = "return {}",
					},
				}
			end,
		},
		Npc = {
			GetAllIds = function()
				return npcIds
			end,
			GetAll = function(id)
				return travelNpcs[id]
			end,
		},
	}
	local routed
	local api = travelEnv.ShortestPathForever.API
	api.Navigate = function(_, map, x, y, title)
		routed = { map = map, x = x, y = y, title = title }
		return true
	end
	local estimates = 0
	local estimate = api.Estimate
	api.Estimate = function(...)
		estimates = estimates + 1
		return estimate(...)
	end
	driver.load("UI/MenuModifier.lua")
	driver.load("UI/Nearby.lua")
	local guard = 0
	while #travelTimers > 0 do
		guard = guard + 1
		assert(guard < 1000, "the QuestieDB index settles")
		table.remove(travelTimers, 1)()
	end
	assert(worldNs.NearbyServices.State() == "ready")
	local nearest = worldNs.NearbyServices.Nearest("class", { map = 1, x = auberdine.x, y = auberdine.y })
	assert(nearest.id == 5501, "Kaerbrus is the closest by straight line")
	local function travelMenu()
		local root = { children = {} }
		function root.CreateTitle(_root) end
		function root.SetScrollMode(self, extent)
			self.scrollExtent = extent
		end
		function root.CreateButton(_root, text, callback)
			local button = { text = text, callback = callback, children = {} }
			function button.CreateTitle(_button) end
			function button.CreateButton(_button, childText, childCallback)
				local child = {
					text = childText,
					callback = childCallback,
					children = {},
					SetEnabled = function() end,
					SetScrollMode = function() end,
				}
				function child.CreateButton(_child) end
				function child.CreateTitle(_child) end
				button.children[#button.children + 1] = child
				return child
			end
			button.SetEnabled = function() end
			button.SetScrollMode = function() end
			root.children[#root.children + 1] = button
			return button
		end
		return root
	end
	local function build()
		local root = travelMenu()
		travelTracking.MENU_WORLD_MAP_TRACKING(nil, root)
		local services = root.children[1]
		assert(services and services.text == "Nearby services")
		for _, child in ipairs(services.children) do
			if child.text == "Class trainer" then
				return child
			end
		end
		error("no class trainer entry")
	end
	build()
	build()
	assert(estimates == 0, "building or refreshing the menu plans nothing")
	assert(build().callback() == travelEnv.MenuResponse.CloseAll)
	assert(routed.title == "Darnassus hunter trainer", "the boat's Teldrassil trainer beats the short walk to Kaerbrus")
	assert(estimates == 3, "only the clicked service's shortlist is planned")
	local detail = api.EstimateDetail(1439, playerX, playerY, routed.map, routed.x, routed.y)
	local boat = false
	for _, leg in ipairs(detail.legs) do
		boat = boat or leg.mode == "boat"
	end
	assert(boat, "the chosen trainer is reached by boat")
end
print(
	"nearby: installed QuestieDB contract, sliced loading, faction/class/profession grouping, "
		.. "real map-menu callbacks, UI-coordinate dispatch and travel-cost choice: ok"
)
