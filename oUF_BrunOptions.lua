--[[-------------------------------------------------------------------------
  Copyright (c) Lasse G. Brun. All rights reserved.
  Licensed under the MIT License. See LICENSE in the project root.
---------------------------------------------------------------------------]]

local addonName, ns = ...
local oUF = ns.oUF or _G.oUF
assert(oUF, "oUF_Brun requires oUF to be loaded.")

local FONT = ns.FONT
local TEXTURE = ns.TEXTURE
local FONT_SIZE = ns.FONT_SIZE or 14
local SMALL_FONT_SIZE = ns.SMALL_FONT_SIZE or 12

--===================================================--
-- Default Options & SavedVariables Accessors
--===================================================--

local DEFAULT_OPTIONS = {
	enableFader = true,
	firstNameOnly = false,
	shortRaceNames = true,
	desaturateOtherDebuffs = true,
	enableHealthPrediction = true,
	enableThreatHighlight = true,
	hideSelfInfo = true,
	hidePartyInRaid = false,
	showRaidFrames = true,
	enableClickCast = false,
	showPortraits = false,
	use2DPortraits = false,
	showBossFrames = true,
	showTargetTarget = true,
	showTargetTargetTarget = true,
	enableTotemBar = true,
	hideCompactRaidManager = true,
	oUFRuneBar = false,
	removeBuffs = false,
	playerCastBar = true,
	targetCastBar = true,
	focusCastBar = true,
	playerShowBuffs = true,
	playerShowDebuffs = true,
	targetShowBuffs = true,
	targetShowDebuffs = true,
	focusShowBuffs = true,
	focusShowDebuffs = true,
	partyShowBuffs = true,
	partyShowDebuffs = true,
	highlightExpiringAuras = true,
	highlightDispellableDebuffs = true,
	enableSwingBar = true,
	enableClassPower = true,
	showMinimapIcon = true,
}

ns.DEFAULT_OPTIONS = DEFAULT_OPTIONS

function ns.GetPositionsDB()
	if type(oUF_BrunDB) ~= "table" then oUF_BrunDB = {} end
	if type(oUF_BrunDB.Positions) ~= "table" then oUF_BrunDB.Positions = {} end
	return oUF_BrunDB.Positions
end

function ns.GetOptionsDB()
	if type(oUF_BrunDB) ~= "table" then oUF_BrunDB = {} end
	if type(oUF_BrunDB.Options) ~= "table" then oUF_BrunDB.Options = {} end
	local opts = oUF_BrunDB.Options
	for k, v in pairs(DEFAULT_OPTIONS) do
		if opts[k] == nil then
			opts[k] = v
		end
	end
	return opts
end

local LIVE_OPTIONS = {
	firstNameOnly = true,
	shortRaceNames = true,
	showMinimapIcon = true,
	enableClickCast = true,
	desaturateOtherDebuffs = true,
	highlightExpiringAuras = true,
	highlightDispellableDebuffs = true,
}

local FLAT_BACKDROP = {
	bgFile = "Interface\\Buttons\\WHITE8X8",
	edgeFile = "Interface\\Buttons\\WHITE8X8",
	edgeSize = 1,
}

local configFrame
local moverBtnRef
local testBtnRef

local function StyleFlatBox(frame, bgR, bgG, bgB, bgA, brR, brG, brB, brA)
	if not frame.SetBackdrop and BackdropTemplateMixin then
		Mixin(frame, BackdropTemplateMixin)
		if frame.OnBackdropLoaded then frame:OnBackdropLoaded() end
	end
	if frame.SetBackdrop then
		frame:SetBackdrop(FLAT_BACKDROP)
		frame:SetBackdropColor(bgR, bgG, bgB, bgA)
		frame:SetBackdropBorderColor(brR, brG, brB, brA)
	end
end

function ns.UpdateMoverBtnState()
	if not moverBtnRef then return end
	local unlocked = ns.IsMoversUnlocked and ns.IsMoversUnlocked() or false
	moverBtnRef:SetLabel(unlocked and "Lock Movers" or "Unlock Movers")
	if moverBtnRef.SetActive then
		moverBtnRef:SetActive(unlocked)
	end
end

function ns.UpdateTestBtnState()
	if not testBtnRef then return end
	local active = ns.IsTestModeActive and ns.IsTestModeActive() or false
	testBtnRef:SetLabel(active and "Stop Test" or "Test Frames")
	if testBtnRef.SetActive then
		testBtnRef:SetActive(active)
	end
end

function ns.ToggleConfigGUI()
	if configFrame then
		configFrame:SetShown(not configFrame:IsShown())
		return
	end

	local f = CreateFrame("Frame", "oUF_BrunConfigFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	f:SetSize(580, 444)
	f:SetPoint("CENTER")
	f:SetFrameStrata("DIALOG")
	f:SetMovable(true)
	f:EnableMouse(true)
	f:SetClampedToScreen(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	StyleFlatBox(f, 0.06, 0.06, 0.08, 0.96, 0.22, 0.22, 0.26, 1)
	tinsert(UISpecialFrames, "oUF_BrunConfigFrame")

	-- Header bar
	local headerBar = CreateFrame("Frame", nil, f)
	headerBar:SetPoint("TOPLEFT", 1, -1)
	headerBar:SetPoint("TOPRIGHT", -1, -1)
	headerBar:SetHeight(40)

	local headerBg = headerBar:CreateTexture(nil, "BACKGROUND")
	headerBg:SetAllPoints()
	headerBg:SetColorTexture(0.09, 0.09, 0.12, 1)

	local headerAccent = headerBar:CreateTexture(nil, "ARTWORK")
	headerAccent:SetPoint("TOPLEFT", 0, 0)
	headerAccent:SetPoint("TOPRIGHT", 0, 0)
	headerAccent:SetHeight(2)
	headerAccent:SetColorTexture(1, 0.5, 0, 0.9)

	local headerLine = f:CreateTexture(nil, "BORDER")
	headerLine:SetPoint("TOPLEFT", headerBar, "BOTTOMLEFT", 0, 0)
	headerLine:SetPoint("TOPRIGHT", headerBar, "BOTTOMRIGHT", 0, 0)
	headerLine:SetHeight(1)
	headerLine:SetColorTexture(1, 1, 1, 0.08)

	local title = headerBar:CreateFontString(nil, "OVERLAY")
	title:SetFont(FONT, FONT_SIZE + 2, "OUTLINE")
	title:SetPoint("LEFT", 16, 0)
	title:SetText("|cffff8000oUF_Brun|r  |cffe6e6e6Settings|r")

	local version = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(addonName, "Version"))
		or (GetAddOnMetadata and GetAddOnMetadata(addonName, "Version"))
	if version and version ~= "" then
		local verText = headerBar:CreateFontString(nil, "OVERLAY")
		verText:SetFont(FONT, SMALL_FONT_SIZE - 1, "OUTLINE")
		verText:SetPoint("LEFT", title, "RIGHT", 8, -1)
		verText:SetTextColor(0.55, 0.55, 0.6)
		verText:SetText("v" .. version)
	end

	local closeBtn = CreateFrame("Button", nil, headerBar, BackdropTemplateMixin and "BackdropTemplate" or nil)
	closeBtn:SetSize(24, 24)
	closeBtn:SetPoint("RIGHT", -10, 0)
	StyleFlatBox(closeBtn, 0.14, 0.14, 0.17, 1, 0.25, 0.25, 0.3, 1)
	local closeTxt = closeBtn:CreateFontString(nil, "OVERLAY")
	closeTxt:SetFont(FONT, FONT_SIZE, "OUTLINE")
	closeTxt:SetPoint("CENTER", 0, 0)
	closeTxt:SetText("X")
	closeTxt:SetTextColor(0.8, 0.8, 0.85)
	closeBtn:SetScript("OnEnter", function(self)
		self:SetBackdropColor(0.65, 0.16, 0.16, 1)
		self:SetBackdropBorderColor(0.9, 0.3, 0.3, 1)
		closeTxt:SetTextColor(1, 1, 1)
	end)
	closeBtn:SetScript("OnLeave", function(self)
		self:SetBackdropColor(0.14, 0.14, 0.17, 1)
		self:SetBackdropBorderColor(0.25, 0.25, 0.3, 1)
		closeTxt:SetTextColor(0.8, 0.8, 0.85)
	end)
	closeBtn:SetScript("OnClick", function() f:Hide() end)

	-- Footer bar
	local footerBar = CreateFrame("Frame", nil, f)
	footerBar:SetPoint("BOTTOMLEFT", 1, 1)
	footerBar:SetPoint("BOTTOMRIGHT", -1, 1)
	footerBar:SetHeight(48)

	local footerBg = footerBar:CreateTexture(nil, "BACKGROUND")
	footerBg:SetAllPoints()
	footerBg:SetColorTexture(0.08, 0.08, 0.10, 1)

	local footerLine = f:CreateTexture(nil, "BORDER")
	footerLine:SetPoint("BOTTOMLEFT", footerBar, "TOPLEFT", 0, 0)
	footerLine:SetPoint("BOTTOMRIGHT", footerBar, "TOPRIGHT", 0, 0)
	footerLine:SetHeight(1)
	footerLine:SetColorTexture(1, 1, 1, 0.08)

	-- Left navigation sidebar
	local sidebar = CreateFrame("Frame", nil, f)
	sidebar:SetPoint("TOPLEFT", headerBar, "BOTTOMLEFT", 0, -1)
	sidebar:SetPoint("BOTTOMLEFT", footerBar, "TOPLEFT", 0, 1)
	sidebar:SetWidth(138)

	local sidebarBg = sidebar:CreateTexture(nil, "BACKGROUND")
	sidebarBg:SetAllPoints()
	sidebarBg:SetColorTexture(0.045, 0.045, 0.06, 0.95)

	local sidebarLine = f:CreateTexture(nil, "BORDER")
	sidebarLine:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 0, 0)
	sidebarLine:SetPoint("BOTTOMLEFT", sidebar, "BOTTOMRIGHT", 0, 0)
	sidebarLine:SetWidth(1)
	sidebarLine:SetColorTexture(1, 1, 1, 0.08)

	local statusHint = sidebar:CreateFontString(nil, "OVERLAY")
	statusHint:SetFont(FONT, SMALL_FONT_SIZE - 1, "OUTLINE")
	statusHint:SetPoint("BOTTOMLEFT", 12, 12)
	statusHint:SetPoint("BOTTOMRIGHT", -10, 12)
	statusHint:SetJustifyH("LEFT")
	statusHint:SetTextColor(0.5, 0.5, 0.56)
	statusHint:SetText("Live options apply\ninstantly.")

	-- Right content host
	local contentArea = CreateFrame("Frame", nil, f)
	contentArea:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 1, 0)
	contentArea:SetPoint("BOTTOMRIGHT", footerBar, "TOPRIGHT", 0, 1)

	-- Shared state & helpers
	local checkboxes = {}
	local dependentControls = {}
	local reloadNeeded = false
	local reloadBtn

	local function UpdateReloadHint()
		if reloadNeeded then
			statusHint:SetTextColor(1, 0.62, 0.2)
			statusHint:SetText("Reload UI to apply\nstructural changes.")
		else
			statusHint:SetTextColor(0.5, 0.5, 0.56)
			statusHint:SetText("Live options apply\ninstantly.")
		end
		if reloadBtn and reloadBtn.SetAccent then
			reloadBtn:SetAccent(reloadNeeded)
		end
	end

	local function RefreshDependencies()
		local curOpts = ns.GetOptionsDB()
		for _, item in ipairs(dependentControls) do
			local enabled = curOpts[item.dependsOn] and true or false
			item.setEnabled(enabled)
		end
	end

	local function OnOptionChanged(key, checked)
		ns.GetOptionsDB()[key] = checked
		ns.ApplySavedOptions()
		if key == "firstNameOnly" or key == "shortRaceNames" then
			for _, obj in ipairs(oUF.objects) do
				if obj.UpdateTags then obj:UpdateTags() end
			end
		end
		if not LIVE_OPTIONS[key] then
			reloadNeeded = true
			UpdateReloadHint()
		end
		RefreshDependencies()
	end

	local function CreateActionButton(parent, label, btnW, btnH, onClick)
		local btn = CreateFrame("Button", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
		btn:SetSize(btnW, btnH)
		StyleFlatBox(btn, 0.13, 0.13, 0.16, 1, 0.28, 0.28, 0.34, 1)

		local txt = btn:CreateFontString(nil, "OVERLAY")
		txt:SetFont(FONT, SMALL_FONT_SIZE, "OUTLINE")
		txt:SetPoint("CENTER", 0, 0)
		txt:SetText(label)
		txt:SetTextColor(0.92, 0.92, 0.95)
		btn.label = txt
		btn._active = false
		btn._accent = false
		btn._hovered = false

		local function RefreshStyle()
			if btn._active or btn._accent then
				if btn._hovered then
					btn:SetBackdropColor(0.75, 0.38, 0.05, 1)
				else
					btn:SetBackdropColor(0.58, 0.28, 0.04, 0.95)
				end
				btn:SetBackdropBorderColor(1, 0.56, 0.12, 1)
				txt:SetTextColor(1, 1, 1)
			elseif btn._hovered then
				btn:SetBackdropColor(0.20, 0.20, 0.25, 1)
				btn:SetBackdropBorderColor(0.48, 0.48, 0.56, 1)
				txt:SetTextColor(1, 1, 1)
			else
				btn:SetBackdropColor(0.13, 0.13, 0.16, 1)
				btn:SetBackdropBorderColor(0.28, 0.28, 0.34, 1)
				txt:SetTextColor(0.92, 0.92, 0.95)
			end
		end

		function btn:SetLabel(text)
			txt:SetText(text)
		end
		function btn:SetActive(state)
			btn._active = state and true or false
			RefreshStyle()
		end
		function btn:SetAccent(state)
			btn._accent = state and true or false
			RefreshStyle()
		end

		btn:SetScript("OnEnter", function()
			btn._hovered = true
			RefreshStyle()
		end)
		btn:SetScript("OnLeave", function()
			btn._hovered = false
			RefreshStyle()
		end)
		btn:SetScript("OnClick", onClick)
		return btn
	end

	local function CreateCard(parent, cardTitle, cardHeight, yOffset)
		local card = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
		card:SetPoint("TOPLEFT", 14, -yOffset)
		card:SetPoint("TOPRIGHT", -14, -yOffset)
		card:SetHeight(cardHeight)
		StyleFlatBox(card, 0.09, 0.09, 0.12, 0.9, 1, 1, 1, 0.07)

		local hdr = card:CreateFontString(nil, "OVERLAY")
		hdr:SetFont(FONT, SMALL_FONT_SIZE + 1, "OUTLINE")
		hdr:SetPoint("TOPLEFT", 12, -10)
		hdr:SetTextColor(1, 0.72, 0.18)
		hdr:SetText(cardTitle)

		local line = card:CreateTexture(nil, "BORDER")
		line:SetPoint("TOPLEFT", 12, -26)
		line:SetPoint("TOPRIGHT", -12, -26)
		line:SetHeight(1)
		line:SetColorTexture(1, 1, 1, 0.06)

		return card
	end

	local function CreateCheckVisual(parent)
		local box = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
		box:SetSize(15, 15)
		StyleFlatBox(box, 0.05, 0.05, 0.07, 1, 0.34, 0.34, 0.40, 1)

		local fill = box:CreateTexture(nil, "ARTWORK")
		fill:SetPoint("TOPLEFT", 3, -3)
		fill:SetPoint("BOTTOMRIGHT", -3, 3)
		fill:SetTexture(TEXTURE)
		fill:SetVertexColor(1, 0.55, 0.08, 1)
		box.fill = fill

		function box:SetCheckedVisual(checked, enabled)
			fill:SetShown(checked)
			if not enabled then
				box:SetBackdropBorderColor(0.24, 0.24, 0.28, 0.6)
				fill:SetVertexColor(0.55, 0.42, 0.25, 0.55)
			elseif checked then
				box:SetBackdropBorderColor(1, 0.56, 0.12, 1)
				fill:SetVertexColor(1, 0.55, 0.08, 1)
			else
				box:SetBackdropBorderColor(0.36, 0.36, 0.42, 1)
			end
		end

		return box
	end

	local function CreateToggleRow(card, def, rowIndex)
		local opts = ns.GetOptionsDB()
		local y = 32 + (rowIndex - 1) * 24
		local indent = def.indent and 18 or 0

		local row = CreateFrame("Button", nil, card)
		row:SetPoint("TOPLEFT", 8 + indent, -y)
		row:SetPoint("TOPRIGHT", -8, -y)
		row:SetHeight(22)

		local hoverBg = row:CreateTexture(nil, "BACKGROUND")
		hoverBg:SetAllPoints()
		hoverBg:SetColorTexture(1, 1, 1, 0.045)
		hoverBg:Hide()

		local box = CreateCheckVisual(row)
		box:SetPoint("LEFT", 6, 0)

		local label = row:CreateFontString(nil, "OVERLAY")
		label:SetFont(FONT, SMALL_FONT_SIZE, "OUTLINE")
		label:SetPoint("LEFT", box, "RIGHT", 8, 0)
		label:SetJustifyH("LEFT")
		label:SetText(def.label)
		label:SetTextColor(0.92, 0.92, 0.95)

		if LIVE_OPTIONS[def.key] then
			local liveTag = row:CreateFontString(nil, "OVERLAY")
			liveTag:SetFont(FONT, SMALL_FONT_SIZE - 2, "OUTLINE")
			liveTag:SetPoint("RIGHT", -6, 0)
			liveTag:SetTextColor(0.35, 0.78, 0.45)
			liveTag:SetText("LIVE")
			row.liveTag = liveTag
			label:SetPoint("RIGHT", liveTag, "LEFT", -8, 0)
		else
			label:SetPoint("RIGHT", -8, 0)
		end

		local isChecked = opts[def.key] and true or false
		local isEnabled = true

		local function Refresh()
			box:SetCheckedVisual(isChecked, isEnabled)
			if isEnabled then
				label:SetTextColor(0.92, 0.92, 0.95)
			else
				label:SetTextColor(0.45, 0.45, 0.50)
			end
			if row.liveTag then
				row.liveTag:SetAlpha(isEnabled and 1 or 0.35)
			end
		end

		local control = {
			SetChecked = function(_, val)
				isChecked = val and true or false
				Refresh()
			end,
		}
		checkboxes[def.key] = control

		if def.dependsOn then
			table.insert(dependentControls, {
				dependsOn = def.dependsOn,
				setEnabled = function(enabled)
					isEnabled = enabled
					Refresh()
				end,
			})
		end

		row:SetScript("OnEnter", function(self)
			if isEnabled then hoverBg:Show() end
			if def.tip or (not isEnabled and def.dependsLabel) then
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				GameTooltip:AddLine(def.label, 1, 0.82, 0)
				if def.tip then
					GameTooltip:AddLine(def.tip, 0.85, 0.85, 0.9, true)
				end
				if not isEnabled and def.dependsLabel then
					GameTooltip:AddLine("Requires '" .. def.dependsLabel .. "' to be enabled.", 1, 0.45, 0.35, true)
				elseif LIVE_OPTIONS[def.key] then
					GameTooltip:AddLine("Applies immediately without reloading.", 0.35, 0.85, 0.45)
				else
					GameTooltip:AddLine("Requires Reload UI to apply.", 0.65, 0.65, 0.7)
				end
				GameTooltip:Show()
			end
		end)
		row:SetScript("OnLeave", function()
			hoverBg:Hide()
			GameTooltip:Hide()
		end)
		row:SetScript("OnClick", function()
			if not isEnabled then return end
			isChecked = not isChecked
			Refresh()
			OnOptionChanged(def.key, isChecked)
		end)

		Refresh()
		return row
	end

	local function CreateMatrixCell(parent, key, tipLabel, xCenter, yTop)
		local opts = ns.GetOptionsDB()
		local btn = CreateFrame("Button", nil, parent)
		btn:SetSize(28, 22)
		btn:SetPoint("TOP", parent, "TOPLEFT", xCenter, -yTop)

		local hoverBg = btn:CreateTexture(nil, "BACKGROUND")
		hoverBg:SetAllPoints()
		hoverBg:SetColorTexture(1, 1, 1, 0.06)
		hoverBg:Hide()

		local box = CreateCheckVisual(btn)
		box:SetPoint("CENTER")

		local isChecked = opts[key] and true or false
		local function Refresh()
			box:SetCheckedVisual(isChecked, true)
		end

		checkboxes[key] = {
			SetChecked = function(_, val)
				isChecked = val and true or false
				Refresh()
			end,
		}

		btn:SetScript("OnEnter", function(self)
			hoverBg:Show()
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:AddLine(tipLabel, 1, 0.82, 0)
			GameTooltip:AddLine("Requires Reload UI to apply.", 0.65, 0.65, 0.7)
			GameTooltip:Show()
		end)
		btn:SetScript("OnLeave", function()
			hoverBg:Hide()
			GameTooltip:Hide()
		end)
		btn:SetScript("OnClick", function()
			isChecked = not isChecked
			Refresh()
			OnOptionChanged(key, isChecked)
		end)

		Refresh()
		return btn
	end

	-- Build 4 category pages
	local tabs = {
		{ id = "general", label = "General" },
		{ id = "frames", label = "Unit Frames" },
		{ id = "auras", label = "Auras & Casts" },
		{ id = "group", label = "Party & Raid" },
	}
	local pages = {}
	local tabButtons = {}

	local function SelectTab(tabId)
		for id, page in pairs(pages) do
			page:SetShown(id == tabId)
		end
		for id, btn in pairs(tabButtons) do
			local active = (id == tabId)
			btn._active = active
			btn.accent:SetShown(active)
			if active then
				btn.bg:SetColorTexture(1, 0.5, 0, 0.14)
				btn.label:SetTextColor(1, 0.84, 0.45)
			else
				btn.bg:SetColorTexture(0, 0, 0, 0)
				btn.label:SetTextColor(0.76, 0.76, 0.82)
			end
		end
	end

	for i, tab in ipairs(tabs) do
		local page = CreateFrame("Frame", nil, contentArea)
		page:SetAllPoints()
		page:Hide()
		pages[tab.id] = page

		local tbtn = CreateFrame("Button", nil, sidebar)
		tbtn:SetPoint("TOPLEFT", 6, -(12 + (i - 1) * 34))
		tbtn:SetPoint("TOPRIGHT", -6, -(12 + (i - 1) * 34))
		tbtn:SetHeight(28)

		local bg = tbtn:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints()
		bg:SetColorTexture(0, 0, 0, 0)
		tbtn.bg = bg

		local accent = tbtn:CreateTexture(nil, "ARTWORK")
		accent:SetPoint("TOPLEFT", 0, -2)
		accent:SetPoint("BOTTOMLEFT", 0, 2)
		accent:SetWidth(3)
		accent:SetColorTexture(1, 0.5, 0, 1)
		accent:Hide()
		tbtn.accent = accent

		local lbl = tbtn:CreateFontString(nil, "OVERLAY")
		lbl:SetFont(FONT, SMALL_FONT_SIZE + 1, "OUTLINE")
		lbl:SetPoint("LEFT", 12, 0)
		lbl:SetText(tab.label)
		lbl:SetTextColor(0.76, 0.76, 0.82)
		tbtn.label = lbl

		tbtn:SetScript("OnEnter", function(self)
			if not self._active then
				self.bg:SetColorTexture(1, 1, 1, 0.05)
				self.label:SetTextColor(1, 1, 1)
			end
		end)
		tbtn:SetScript("OnLeave", function(self)
			if not self._active then
				self.bg:SetColorTexture(0, 0, 0, 0)
				self.label:SetTextColor(0.76, 0.76, 0.82)
			end
		end)
		tbtn:SetScript("OnClick", function()
			SelectTab(tab.id)
		end)
		tabButtons[tab.id] = tbtn
	end

	-- Page 1: General
	do
		local p = pages.general
		local card1 = CreateCard(p, "Names & Visuals", 158, 12)
		local generalVisuals = {
			{ key = "firstNameOnly", label = "First Name Only (hide Forever surnames)", tip = "Show only the first name on player unit frames." },
			{ key = "shortRaceNames", label = "Shorten Long Race & Creature Names", tip = "Shorten compound race names (e.g. Windshaper Skyborne -> Skyborne)." },
			{ key = "hideSelfInfo", label = "Hide Player Name & Level at Max Level", tip = "Keep your player power bar uncluttered at max level." },
			{ key = "enableHealthPrediction", label = "Incoming Heals & Absorb Shields", tip = "Show incoming heal predictions and absorb overlays on health bars." },
			{ key = "enableThreatHighlight", label = "Aggro / Threat Backdrop Highlight", tip = "Highlight unit frame borders when a unit holds aggro or high threat." },
		}
		for i, def in ipairs(generalVisuals) do
			CreateToggleRow(card1, def, i)
		end

		local card2 = CreateCard(p, "Behavior & Interface", 110, 182)
		local generalBehavior = {
			{ key = "enableFader", label = "Fade Player & Pet Out of Combat", tip = "Smoothly fade Player and Pet frames when idle with no target." },
			{ key = "removeBuffs", label = "Hide Default Blizzard Buff Frame", tip = "Disable Blizzard's top-right buff and weapon enchant frames." },
			{ key = "showMinimapIcon", label = "Show Minimap Quick Toggle Icon", tip = "Display the draggable 'B' button around the minimap." },
		}
		for i, def in ipairs(generalBehavior) do
			CreateToggleRow(card2, def, i)
		end
	end

	-- Page 2: Unit Frames
	do
		local p = pages.frames
		local card1 = CreateCard(p, "Frames & Portraits", 158, 12)
		local frameToggles = {
			{ key = "showPortraits", label = "Show Portraits (Player & Target)", tip = "Display framed portrait boxes beside Player and Target frames." },
			{
				key = "use2DPortraits",
				label = "Use 2D Portraits (instead of 3D Models)",
				tip = "Render cropped square 2D portraits instead of animated 3D models.",
				indent = true,
				dependsOn = "showPortraits",
				dependsLabel = "Show Portraits (Player & Target)",
			},
			{ key = "showTargetTarget", label = "Show Target of Target (ToT)", tip = "Display your target's current target." },
			{ key = "showTargetTargetTarget", label = "Show Target of Target's Target (ToToT)", tip = "Display your target's target's target below ToT." },
			{ key = "showBossFrames", label = "Enable Boss Frames (Boss 1-5)", tip = "Spawn dedicated encounter boss frames on the right." },
		}
		for i, def in ipairs(frameToggles) do
			CreateToggleRow(card1, def, i)
		end

		local card2 = CreateCard(p, "Class & Combat Bars", 134, 182)
		local classBars = {
			{ key = "enableClassPower", label = "Player Class Power & Monk Stagger Bar", tip = "Show Holy Power, Chi, Soul Shards, Arcane Charges, Essence, or Stagger." },
			{ key = "enableSwingBar", label = "Player Swing Timer Bar", tip = "Display melee and ranged auto-attack swing timer bars." },
			{ key = "enableTotemBar", label = "Clickable Totem Bar above Player", tip = "Style and anchor Shaman/class totems above your Player frame." },
			{ key = "oUFRuneBar", label = "Use oUF Death Knight Rune Bar", tip = "Replace Blizzard's default Death Knight Rune Frame with oUF runes." },
		}
		for i, def in ipairs(classBars) do
			CreateToggleRow(card2, def, i)
		end
	end

	-- Page 3: Auras & Casts
	do
		local p = pages.auras
		local card1 = CreateCard(p, "Unit Auras & Castbars", 168, 12)

		local colBuffsX, colDebuffsX, colCastX = 205, 285, 365
		local colHeaders = {
			{ text = "Unit", x = 14, align = "LEFT" },
			{ text = "Buffs", x = colBuffsX, align = "CENTER" },
			{ text = "Debuffs", x = colDebuffsX, align = "CENTER" },
			{ text = "Castbar", x = colCastX, align = "CENTER" },
		}
		for _, ch in ipairs(colHeaders) do
			local fs = card1:CreateFontString(nil, "OVERLAY")
			fs:SetFont(FONT, SMALL_FONT_SIZE - 1, "OUTLINE")
			fs:SetTextColor(0.65, 0.65, 0.72)
			if ch.align == "LEFT" then
				fs:SetPoint("TOPLEFT", ch.x, -34)
			else
				fs:SetPoint("TOP", card1, "TOPLEFT", ch.x, -34)
			end
			fs:SetText(ch.text)
		end

		local matrixRows = {
			{ unit = "Player", buffs = "playerShowBuffs", debuffs = "playerShowDebuffs", cast = "playerCastBar" },
			{ unit = "Target", buffs = "targetShowBuffs", debuffs = "targetShowDebuffs", cast = "targetCastBar" },
			{ unit = "Focus", buffs = "focusShowBuffs", debuffs = "focusShowDebuffs", cast = "focusCastBar" },
			{ unit = "Party", buffs = "partyShowBuffs", debuffs = "partyShowDebuffs", cast = nil },
		}
		for idx, r in ipairs(matrixRows) do
			local rowY = 54 + (idx - 1) * 27
			if idx % 2 == 1 then
				local stripe = card1:CreateTexture(nil, "BACKGROUND")
				stripe:SetPoint("TOPLEFT", 10, -rowY + 2)
				stripe:SetPoint("TOPRIGHT", -10, -rowY + 2)
				stripe:SetHeight(24)
				stripe:SetColorTexture(1, 1, 1, 0.025)
			end

			local unitLabel = card1:CreateFontString(nil, "OVERLAY")
			unitLabel:SetFont(FONT, SMALL_FONT_SIZE, "OUTLINE")
			unitLabel:SetPoint("TOPLEFT", 14, -(rowY + 4))
			unitLabel:SetTextColor(0.92, 0.92, 0.95)
			unitLabel:SetText(r.unit)

			CreateMatrixCell(card1, r.buffs, "Show " .. r.unit .. " Buffs", colBuffsX, rowY)
			CreateMatrixCell(card1, r.debuffs, "Show " .. r.unit .. " Debuffs", colDebuffsX, rowY)
			if r.cast then
				CreateMatrixCell(card1, r.cast, "Show " .. r.unit .. " Castbar", colCastX, rowY)
			else
				local dash = card1:CreateFontString(nil, "OVERLAY")
				dash:SetFont(FONT, SMALL_FONT_SIZE, "OUTLINE")
				dash:SetPoint("TOP", card1, "TOPLEFT", colCastX, -(rowY + 4))
				dash:SetTextColor(0.4, 0.4, 0.45)
				dash:SetText("-")
			end
		end

		local card2 = CreateCard(p, "Aura Filtering & Highlights", 110, 192)
		local auraExtras = {
			{ key = "desaturateOtherDebuffs", label = "Prioritize Player Debuffs & Desaturate Others", tip = "Sort your debuffs first on Target/Boss and grey out others' debuffs." },
			{ key = "highlightDispellableDebuffs", label = "Highlight Dispellable Debuffs (Player Class)", tip = "Border-highlight and prioritize debuffs your class can dispel." },
			{ key = "highlightExpiringAuras", label = "Highlight Expiring Timers (<=10s / <=5s)", tip = "Turn aura countdown timers yellow at <=10s and red at <=5s." },
		}
		for i, def in ipairs(auraExtras) do
			CreateToggleRow(card2, def, i)
		end
	end

	-- Page 4: Party & Raid
	do
		local p = pages.group
		local card1 = CreateCard(p, "Group & Raid Layout", 110, 12)
		local groupToggles = {
			{ key = "showRaidFrames", label = "Enable Raid Frames (8-Group Compact Grid)", tip = "Replace Blizzard raid frames with the compact 8-group oUF_Brun grid." },
			{ key = "hidePartyInRaid", label = "Hide Party Frames when in a Raid", tip = "Hide the 4-member party stack automatically while in a raid group." },
			{ key = "hideCompactRaidManager", label = "Auto-fade Blizzard Raid Manager Tab", tip = "Fade Blizzard's collapsed raid manager side tab until mouseover." },
		}
		for i, def in ipairs(groupToggles) do
			CreateToggleRow(card1, def, i)
		end

		local card2 = CreateCard(p, "Healing & Click-Casting", 98, 134)
		CreateToggleRow(card2, {
			key = "enableClickCast",
			label = "HealKit Smart Click-Casting (Party & Raid)",
			tip = "Bind class-aware heals and dispels directly on Party & Raid frames.",
		}, 1)

		local bindNote = card2:CreateFontString(nil, "OVERLAY")
		bindNote:SetFont(FONT, SMALL_FONT_SIZE - 1, "OUTLINE")
		bindNote:SetPoint("TOPLEFT", 16, -62)
		bindNote:SetPoint("TOPRIGHT", -14, -62)
		bindNote:SetJustifyH("LEFT")
		bindNote:SetTextColor(0.62, 0.62, 0.68)
		bindNote:SetText("M1: Quick Heal   |   M2: Big / HoT Heal   |   M3: Dispel   |   Shift-Click: Target")
	end

	-- Footer action buttons (4 equal-width 128px buttons, zero text overflow)
	local moverBtn = CreateActionButton(footerBar, "Unlock Movers", 128, 26, function()
		if ns.ToggleMovers then
			ns.ToggleMovers()
		end
	end)
	moverBtn:SetPoint("LEFT", 15, 0)
	moverBtnRef = moverBtn
	ns.UpdateMoverBtnState()

	local testBtn = CreateActionButton(footerBar, "Test Frames", 128, 26, function()
		if ns.ToggleTestFrames then
			ns.ToggleTestFrames()
		end
	end)
	testBtn:SetPoint("LEFT", moverBtn, "RIGHT", 12, 0)
	testBtnRef = testBtn
	ns.UpdateTestBtnState()

	local resetBtn = CreateActionButton(footerBar, "Reset Defaults", 128, 26, function()
		if InCombatLockdown() or not ns.ResetDefaults then return end
		local freshOpts = ns.ResetDefaults()
		for k, cb in pairs(checkboxes) do
			cb:SetChecked(freshOpts[k])
		end
		RefreshDependencies()
		reloadNeeded = true
		UpdateReloadHint()
	end)
	resetBtn:SetPoint("LEFT", testBtn, "RIGHT", 12, 0)

	reloadBtn = CreateActionButton(footerBar, "Reload UI", 128, 26, ReloadUI)
	reloadBtn:SetPoint("RIGHT", -15, 0)

	SelectTab("general")
	RefreshDependencies()
	UpdateReloadHint()

	f:SetScript("OnShow", function()
		local curOpts = ns.GetOptionsDB()
		for k, cb in pairs(checkboxes) do
			cb:SetChecked(curOpts[k])
		end
		RefreshDependencies()
		ns.UpdateMoverBtnState()
		ns.UpdateTestBtnState()
		UpdateReloadHint()
	end)

	configFrame = f
end

--===================================================--
-- Minimap Button & /brun Slash Commands
--===================================================--

local minimapButton

function ns.SetMinimapButtonShown(shown)
	if minimapButton then
		minimapButton:SetShown(shown)
	end
end

function ns.CreateMinimapButton()
	if minimapButton or not Minimap then return end

	local btn = CreateFrame("Button", "oUF_BrunMinimapButton", Minimap)
	btn:SetSize(31, 31)
	btn:SetFrameStrata("MEDIUM")
	btn:SetToplevel(true)
	btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

	local overlay = btn:CreateTexture(nil, "OVERLAY")
	overlay:SetSize(53, 53)
	overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	overlay:SetPoint("TOPLEFT", 0, 0)

	local background = btn:CreateTexture(nil, "BACKGROUND")
	background:SetSize(20, 20)
	background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	background:SetVertexColor(0.12, 0.12, 0.14, 1.0)
	background:SetPoint("TOPLEFT", 7, -5)

	local iconText = btn:CreateFontString(nil, "ARTWORK")
	iconText:SetFont(FONT, 15, "OUTLINE")
	iconText:SetPoint("CENTER", background, "CENTER", 0.5, 0.5)
	iconText:SetText("|cffff8000B|r")
	iconText:SetShadowOffset(1, -1)
	iconText:SetShadowColor(0, 0, 0, 1)

	local function UpdatePosition()
		local pos = (oUF_BrunDB and oUF_BrunDB.minimapPos) or 210
		local angle = math.rad(pos)
		local x, y = math.cos(angle), math.sin(angle)

		local minimapShape = GetMinimapShape and GetMinimapShape() or "ROUND"
		local isRound = (minimapShape == "ROUND")
		local w = (Minimap:GetWidth() / 2) + 10
		local h = (Minimap:GetHeight() / 2) + 10

		if isRound then
			x, y = x * w, y * h
		else
			local diagRadiusW = math.sqrt(2 * (w ^ 2)) - 10
			local diagRadiusH = math.sqrt(2 * (h ^ 2)) - 10
			x = math.max(-w, math.min(x * diagRadiusW, w))
			y = math.max(-h, math.min(y * diagRadiusH, h))
		end

		btn:ClearAllPoints()
		btn:SetPoint("CENTER", Minimap, "CENTER", x, y)
	end
	UpdatePosition()

	btn:EnableMouse(true)
	btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	btn:RegisterForDrag("LeftButton")

	btn:SetScript("OnDragStart", function(self)
		self.dragging = true
		self:SetScript("OnUpdate", function()
			local mx, my = Minimap:GetCenter()
			local cx, cy = GetCursorPosition()
			local scale = Minimap:GetEffectiveScale()
			cx, cy = cx / scale, cy / scale
			local angle = math.deg(math.atan2(cy - my, cx - mx))
			if angle < 0 then angle = angle + 360 end
			if type(oUF_BrunDB) ~= "table" then oUF_BrunDB = {} end
			oUF_BrunDB.minimapPos = angle
			UpdatePosition()
		end)
	end)

	btn:SetScript("OnDragStop", function(self)
		self.dragging = false
		self:SetScript("OnUpdate", nil)
	end)

	btn:SetScript("OnClick", function(_, button)
		if button == "RightButton" then
			if ns.ToggleMovers then
				ns.ToggleMovers()
			end
		else
			ns.ToggleConfigGUI()
		end
	end)

	btn:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:AddLine("|cffff8000oUF_Brun|r")
		GameTooltip:AddLine("Left-Click: |cffffffffToggle Settings Frame|r", 0.9, 0.9, 0.9)
		GameTooltip:AddLine("Right-Click: |cffffffffUnlock / Lock Movers|r", 0.9, 0.9, 0.9)
		GameTooltip:AddLine("Drag: |cffffffffMove Minimap Icon|r", 0.7, 0.7, 0.7)
		GameTooltip:Show()
	end)
	btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

	minimapButton = btn
	local opts = ns.GetOptionsDB()
	btn:SetShown(opts.showMinimapIcon ~= false)
end

SLASH_OUFBRUN1 = "/brun"
SLASH_OUFBRUN2 = "/oufbrun"
SlashCmdList["OUFBRUN"] = function(msg)
	msg = (msg or ""):lower():match("^%s*(.-)%s*$")
	if msg == "move" or msg == "unlock" or msg == "lock" then
		if ns.ToggleMovers then
			ns.ToggleMovers()
		end
	elseif msg == "test" then
		if ns.ToggleTestFrames then
			ns.ToggleTestFrames()
		end
	else
		ns.ToggleConfigGUI()
	end
end
