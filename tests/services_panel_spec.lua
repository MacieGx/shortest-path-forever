-- UI/ServicesPanel.lua against a stub quest log and client: the tab registers once with its order, selecting the tab
-- shows the panel, a refresh keeps the ScrollFrame's offset and only a new search query scrolls back to the top.
local created, tickers = {}, {}
local panel

local function region()
	local r = { points = {}, shown = true }
	function r:SetPoint(...)
		self.points[#self.points + 1] = { ... }
	end
	function r:ClearAllPoints()
		self.points = {}
	end
	function r:SetText(text)
		self.text = text
	end
	function r:GetText()
		return self.text
	end
	function r.SetTextColor() end
	function r.SetJustifyH() end
	function r.SetWordWrap() end
	function r.SetMaxLines() end
	function r:SetAtlas(atlas)
		self.atlas = atlas
	end
	function r:SetTexture(file)
		self.file = file
	end
	function r:SetSize(width, height)
		self.width, self.height = width, height
	end
	function r.SetScale() end
	function r.SetBlendMode() end
	function r.SetAlpha() end
	function r:SetShown(shown)
		self.shown = shown
	end
	function r:Show()
		self.shown = true
	end
	function r:Hide()
		self.shown = false
	end
	function r:IsShown()
		return self.shown
	end
	function r.SetAllPoints() end
	function r.SetTexCoord() end
	return r
end

local function frame(frameType, name, parent, template)
	local f = {
		frameType = frameType,
		name = name,
		parent = parent,
		template = template,
		scripts = {},
		points = {},
		shown = true,
		width = 300,
		height = 40,
		events = {},
	}
	function f:SetScript(event, callback)
		self.scripts[event] = callback
	end
	function f:HookScript(event, callback)
		self.scripts[event] = callback
	end
	function f:GetScript(event)
		return self.scripts[event]
	end
	function f:Show()
		self.shown = true
		if self.scripts.OnShow then
			self.scripts.OnShow(self)
		end
	end
	function f:Hide()
		self.shown = false
		if self.scripts.OnHide then
			self.scripts.OnHide(self)
		end
	end
	function f:SetShown(shown)
		if shown then
			self:Show()
		else
			self:Hide()
		end
	end
	function f:IsShown()
		return self.shown
	end
	function f:SetPoint(...)
		self.points[#self.points + 1] = { ... }
	end
	function f:ClearAllPoints()
		self.points = {}
	end
	function f:SetSize(width, height)
		self.width, self.height = width, height
	end
	function f:GetSize()
		return self.width, self.height
	end
	function f:SetWidth(width)
		self.width = width
	end
	function f:GetWidth()
		return self.width
	end
	function f:SetHeight(height)
		self.height = height
	end
	function f:GetHeight()
		return self.height
	end
	function f.SetAllPoints() end
	function f:SetFrameLevel(level)
		self.level = level
	end
	function f.GetFrameLevel()
		return 1
	end
	function f.EnableMouse() end
	function f:RegisterEvent(event)
		self.events[event] = true
	end
	function f.CreateTexture()
		return region()
	end
	function f.CreateFontString()
		return region()
	end
	if template == "SearchBoxTemplate" then
		f.Instructions = region()
		f.text = ""
		function f:SetText(text)
			self.text = text
			if self.scripts.OnTextChanged then
				self.scripts.OnTextChanged(self)
			end
		end
		function f:GetText()
			return self.text
		end
		function f.SetMaxLetters() end
	elseif template == "ScrollFrameTemplate" then
		f.ScrollBar = frame("Slider", nil, f)
		f.scroll = 0
		function f:SetScrollChild(child)
			self.child = child
		end
		function f:SetVerticalScroll(value)
			self.scroll = value
		end
		function f:GetVerticalScroll()
			return self.scroll
		end
	elseif template == "CollapseButtonTemplate" then
		function f:UpdateCollapsedState(collapsed)
			self.collapsed = collapsed
		end
	end
	created[#created + 1] = f
	return f
end

local function byTemplate(template)
	for _, f in ipairs(created) do
		if f.template == template then
			return f
		end
	end
end

local ns = {
	Init = function() end,
	L = setmetatable({}, {
		__index = function(_, key)
			return key
		end,
	}),
}
ns.FormatCountdown = function(ms)
	local seconds = math.ceil(ms / 1000)
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end
local groups = {
	{ section = "vendors", key = "arrows", label = "Arrows", icon = 2512 },
	{ section = "vendors", key = "bank", label = "Bank", icon = 4496 },
	{ section = "trainers", key = "class", label = "Class trainer", icon = "Class" },
}
local places = {
	arrows = { { id = 1, name = "Dalmond", title = "General Goods", map = 100, x = 0.1, y = 0.1 } },
	bank = { { id = 2, name = "Karus", title = "Banker", map = 100, x = 0.2, y = 0.2 } },
	class = { { id = 3, name = "Mage trainer", title = "Mage Trainer", map = 100, x = 0.3, y = 0.3 } },
}
local navigated
ns.Art = {
	Icon = function(texture)
		texture.icon = true
	end,
	Fit = function() end,
	RowArt = function() end,
	Band = function() end,
	CoverFrame = function() end,
}
ns.NearbyServices = {
	State = function()
		return "ready"
	end,
	PlayerWorld = function()
		return { map = 1, x = 0, y = 0 }
	end,
	PlayerUi = function()
		return 100, 0.1, 0.1
	end,
	Sections = function(_, query)
		local list = {}
		for _, section in ipairs({ "vendors", "trainers" }) do
			local rows = {}
			for _, group in ipairs(groups) do
				local place = places[group.key][1]
				local match = query == "" or group.label:lower():find(query:lower(), 1, true) ~= nil
				if group.section == section and match then
					rows[#rows + 1] = { group = group, npc = place }
				end
			end
			if #rows > 0 then
				list[#list + 1] = { section = section, label = section, count = #rows, collapsed = false, rows = rows }
			end
		end
		return list
	end,
	Shortlist = function()
		return {}
	end,
	Rank = function()
		return {
			Step = function()
				return nil, nil, false
			end,
		}
	end,
	Detail = function(_, place)
		return place.name
	end,
	Navigate = function(key, place)
		navigated = { key = key, place = place }
	end,
	OnReady = function() end,
}
ns.QuestLogTabs = {
	Register = function(key, spec)
		ns.registered = { key = key, spec = spec }
		return { Icon = region() }
	end,
	Select = function(key)
		if ns.registered and ns.registered.key == key then
			ns.registered.spec.panel:Show()
		end
	end,
}
local map = frame("Frame", "QuestMapFrame")
map.ContentsAnchor = frame("Frame", "ContentsAnchor", map)
local loaded
local env = setmetatable({
	QuestMapFrame = map,
	CreateFrame = frame,
	C_Item = {
		GetItemIconByID = function()
			return "Interface\\Icons\\INV_Misc_Bag_08"
		end,
	},
	C_Timer = {
		NewTicker = function(seconds, callback)
			local ticker = { seconds = seconds, callback = callback, cancelled = false }
			function ticker:Cancel()
				self.cancelled = true
			end
			tickers[#tickers + 1] = ticker
			return ticker
		end,
		After = function() end,
	},
	EventUtil = {
		ContinueOnAddOnLoaded = function(name, callback)
			assert(name == "Blizzard_WorldMap", name)
			loaded = callback
		end,
	},
	GetZoneText = function()
		return "Darkshore"
	end,
	GetSubZoneText = function()
		return "Auberdine"
	end,
	NORMAL_FONT_COLOR = { r = 1, g = 0.82, b = 0 },
	ShortestPathForever = {
		API = {
			Estimate = function()
				return 10
			end,
			Navigate = function() end,
		},
	},
	InCombatLockdown = function()
		return false
	end,
}, { __index = _G })
env._G = env
setfenv(assert(loadfile("UI/ServicesPanel.lua")), env)("ShortestPathForever", ns)
assert(loaded, "the panel waits for Blizzard_WorldMap")
loaded()
panel = ns.registered and ns.registered.spec.panel
assert(ns.registered.key == "services", "registered under its own key")
assert(ns.registered.spec.order == 20, "its tab order")
assert(ns.registered.spec.name == "ShortestPathForeverServicesTab", "its tab name")
assert(ns.registered.spec.tooltip == "Nearby services", "its tooltip")
assert(panel and not panel:IsShown(), "the panel starts hidden")

local search = assert(byTemplate("SearchBoxTemplate"), "a search box")
local scroll = assert(byTemplate("ScrollFrameTemplate"), "a scroll frame")
assert(search.Instructions.text == "Search services and goods", "the search placeholder")
ns.QuestLogTabs.Select("services")
assert(panel:IsShown(), "selecting the tab shows the panel")
assert(#created > 4, "the panel built its frames")
assert(#tickers == 1 and tickers[1].seconds == 10, "a ten second ticker starts while shown")

-- A refresh while open, from a zone change, leaves the player's scroll offset alone.
scroll:SetVerticalScroll(42)
assert(panel.scripts.OnEvent, "zone changes are registered")
panel.scripts.OnEvent(panel, "ZONE_CHANGED")
assert(scroll:GetVerticalScroll() == 42, "a refresh keeps the scroll offset")

-- Only a change of the search query scrolls back to the top.
search:SetText("bank")
assert(scroll:GetVerticalScroll() == 0, "a new query scrolls back to the top")
assert(panel:IsShown(), "searching keeps the panel open")
assert(tickers[1].cancelled == false, "the ticker still runs while shown")
panel:Hide()
assert(tickers[1].cancelled, "hiding the panel cancels the ticker")
assert(ns.registered.spec.panel == panel, "the tab keeps the one panel")
assert(not navigated, "a build never navigates by itself")
print("services_panel: tab registration, show, scroll preservation and query reset: ok")
