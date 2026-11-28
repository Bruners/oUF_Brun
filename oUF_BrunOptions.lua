--[[-------------------------------------------------------------------------
  Copyright (c) Lasse G. Brun. All rights reserved.
  Licensed under the MIT License. See LICENSE in the project root.
---------------------------------------------------------------------------]]

local addonName, ns = ...
local oUF = ns.oUF or _G.oUF
assert(oUF, "oUF_Brun requires oUF to be loaded.")

--===================================================--
-- Default Options & SavedVariables Accessors
--===================================================--

local DEFAULT_OPTIONS = {
	enableFader = true,
	fadeOutAlpha = 0.35,
	firstNameOnly = false,
	shortRaceNames = true,
	desaturateOtherDebuffs = true,
	enableHealthPrediction = true,
	enableThreatHighlight = true,
	threatStyle = "backdrop",
	showTargetThreat = false,
	targetThreatRawPct = false,
	hideSelfInfo = true,
	hidePartyInRaid = false,
	partySpacing = 32,
	partyDebuffPosition = "right",
	showPartyPets = true,
	partyPetPosition = "below",
	rangeAlpha = 0.45,
	showRaidFrames = true,
	enableClickCast = false,
	showPortraits = false,
	use2DPortraits = false,
	showBossFrames = true,
	bossSpacing = 48,
	showTargetTarget = true,
	showTargetTargetTarget = true,
	enableTotemBar = true,
	hideCompactRaidManager = true,
	oUFRuneBar = false,
	removeBuffs = false,
	playerCastBar = true,
	targetCastBar = true,
	focusCastBar = true,
	partyCastBar = false,
	petCastBar = true,
	playerShowBuffs = true,
	playerShowDebuffs = true,
	targetShowBuffs = true,
	targetShowDebuffs = true,
	focusShowBuffs = true,
	focusShowDebuffs = true,
	partyShowBuffs = true,
	partyShowDebuffs = true,
	petShowAura = true,
	petShowDebuffs = false,
	auraSizeOffset = 0,
	highlightExpiringAuras = true,
	highlightDispellableDebuffs = true,
	enableSwingBar = true,
	enableClassPower = true,
	useComboDots = false,
	playerWidth = 252,
	playerHeight = 35,
	targetWidth = 252,
	targetHeight = 35,
	partyWidth = 206,
	partyHeight = 35,
	partyPetWidth = 95,
	partyPetHeight = 15,
	raidWidth = 85,
	raidHeight = 24,
	focusWidth = 200,
	focusHeight = 30,
	totWidth = 167,
	totHeight = 25,
	petWidth = 152,
	petHeight = 15,
	bossWidth = 206,
	bossHeight = 35,
	swingWidth = 180,
	swingHeight = 10,
	playerAuraSize = 23,
	targetAuraSize = 23,
	focusAuraSize = 20,
	partyAuraSize = 19,
	healthColorMode = "class",
	healthColorPlayerOnly = false,
	statusBarTexture = "oUF_Brun",
	fontName = "oUF_Brun",
	fontOutline = "OUTLINE",
	fontSizeOffset = 0,
	barAlpha = 0.8,
	borderSize = 2,
	smoothBars = true,
	showMinimapIcon = true,
}

ns.DEFAULT_OPTIONS = DEFAULT_OPTIONS

function ns.GetPositionsDB()
	if type(oUF_BrunDB) ~= "table" then oUF_BrunDB = {} end
	if type(oUF_BrunDB.Positions) ~= "table" then oUF_BrunDB.Positions = {} end
	return oUF_BrunDB.Positions
end

function ns.GetClassColorsDB()
	if type(oUF_BrunDB) ~= "table" then oUF_BrunDB = {} end
	if type(oUF_BrunDB.ClassColors) ~= "table" then oUF_BrunDB.ClassColors = {} end
	return oUF_BrunDB.ClassColors
end

function ns.GetClickCastDB()
	if type(oUF_BrunDB) ~= "table" then oUF_BrunDB = {} end
	if type(oUF_BrunDB.ClickCast) ~= "table" then oUF_BrunDB.ClickCast = {} end
	return oUF_BrunDB.ClickCast
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

--===================================================--
-- LibSharedMedia-3.0 Integration & Live Media Engine
--===================================================--

local DEFAULT_TEXTURE = "Interface\\Addons\\oUF_Brun\\textures\\Statusbar"
local DEFAULT_FONT = "Interface\\Addons\\oUF_Brun\\textures\\Font.ttf"

local BUILTIN_STATUSBARS = {
	["oUF_Brun"] = DEFAULT_TEXTURE,
	["Flat"] = "Interface\\Buttons\\WHITE8X8",
	["Blizzard"] = "Interface\\TargetingFrame\\UI-StatusBar",
	["Blizzard Raid"] = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill",
	["Blizzard Smooth"] = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar",
}

local BUILTIN_FONTS = {
	["oUF_Brun"] = DEFAULT_FONT,
	["Friz Quadrata"] = "Fonts\\FRIZQT__.TTF",
	["Arial Narrow"] = "Fonts\\ARIALN.TTF",
	["Morpheus"] = "Fonts\\MORPHEUS.TTF",
	["Skurri"] = "Fonts\\SKURRI.TTF",
}

local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
if LSM then
	if LSM.Register then
		LSM:Register("statusbar", "oUF_Brun", DEFAULT_TEXTURE)
		LSM:Register("font", "oUF_Brun", DEFAULT_FONT)
	end
	if LSM.RegisterCallback then
		LSM.RegisterCallback(ns, "LibSharedMedia_Registered", function(_, mediatype, key)
			if mediatype == "statusbar" or mediatype == "font" then
				local opts = ns.GetOptionsDB()
				if (mediatype == "statusbar" and key == opts.statusBarTexture) or (mediatype == "font" and key == opts.fontName) then
					if ns.ApplyMedia then ns.ApplyMedia() end
				end
			end
		end)
	end
end

local trackedStatusBars = setmetatable({}, { __mode = "k" })
local trackedBarTextures = setmetatable({}, { __mode = "k" })
local trackedFontStrings = setmetatable({}, { __mode = "k" })
local trackedHealthBars = setmetatable({}, { __mode = "k" })
local trackedBackdrops = setmetatable({}, { __mode = "k" })

function ns.IsLSMAvailable()
	return LSM ~= nil
end

function ns.GetMediaList(mediaType)
	if LSM and LSM.List then
		local list = LSM:List(mediaType)
		if type(list) == "table" and #list > 0 then
			return list
		end
	end
	local src = (mediaType == "font") and BUILTIN_FONTS or BUILTIN_STATUSBARS
	local out = {}
	for k in pairs(src) do
		table.insert(out, k)
	end
	table.sort(out)
	return out
end

function ns.FetchMedia(mediaType, key)
	if LSM and LSM.Fetch and key then
		local path = LSM:Fetch(mediaType, key, true)
		if path and path ~= "" then
			return path
		end
	end
	local src = (mediaType == "font") and BUILTIN_FONTS or BUILTIN_STATUSBARS
	if key and src[key] then
		return src[key]
	end
	return (mediaType == "font") and DEFAULT_FONT or DEFAULT_TEXTURE
end

function ns.GetStatusBarTexture()
	local opts = ns.GetOptionsDB()
	return ns.FetchMedia("statusbar", opts.statusBarTexture)
end

function ns.GetFontPath()
	local opts = ns.GetOptionsDB()
	return ns.FetchMedia("font", opts.fontName)
end

function ns.GetFontFlags()
	local flag = ns.GetOptionsDB().fontOutline
	if flag == "" or flag == "OUTLINE" or flag == "THICKOUTLINE" or flag == "MONOCHROME, OUTLINE" then
		return flag
	end
	return "OUTLINE"
end

function ns.GetFontSizeOffset()
	local off = tonumber(ns.GetOptionsDB().fontSizeOffset) or 0
	return math.max(-3, math.min(4, math.floor(off + 0.5)))
end

function ns.GetBarAlpha()
	local a = tonumber(ns.GetOptionsDB().barAlpha)
	if not a then return 0.8 end
	return math.max(0.5, math.min(1.0, a))
end

function ns.GetBorderSize()
	local b = tonumber(ns.GetOptionsDB().borderSize)
	if b == 1 or b == 2 or b == 3 then
		return b
	end
	return 2
end

function ns.GetPartySpacing()
	local spacing = tonumber(ns.GetOptionsDB().partySpacing)
	if not spacing then return 32 end
	return math.max(0, math.min(120, math.floor(spacing + 0.5)))
end

function ns.GetPartyDebuffPosition()
	return (ns.GetOptionsDB().partyDebuffPosition == "below") and "below" or "right"
end

function ns.GetPartyPetPosition()
	local pos = ns.GetOptionsDB().partyPetPosition
	if pos == "right" or pos == "left" then return pos end
	return "below"
end

function ns.GetFadeOutAlpha()
	local a = tonumber(ns.GetOptionsDB().fadeOutAlpha)
	if not a then return 0.35 end
	return math.max(0.0, math.min(0.90, math.floor(a * 20 + 0.5) / 20))
end

function ns.GetBossSpacing()
	local spacing = tonumber(ns.GetOptionsDB().bossSpacing)
	if not spacing then return 48 end
	return math.max(0, math.min(120, math.floor(spacing + 0.5)))
end

function ns.GetRangeAlpha()
	local a = tonumber(ns.GetOptionsDB().rangeAlpha)
	if not a then return 0.45 end
	return math.max(0.20, math.min(0.90, math.floor(a * 20 + 0.5) / 20))
end

function ns.GetAuraSizeOffset()
	local off = tonumber(ns.GetOptionsDB().auraSizeOffset)
	if not off then return 0 end
	return math.max(-6, math.min(8, math.floor(off + 0.5)))
end

function ns.GetSmoothBars()
	return ns.GetOptionsDB().smoothBars ~= false
end

local SIZE_LIMITS = {
	playerWidth = { min = 140, max = 420, def = 252 },
	playerHeight = { min = 20, max = 70, def = 35 },
	targetWidth = { min = 140, max = 420, def = 252 },
	targetHeight = { min = 20, max = 70, def = 35 },
	partyWidth = { min = 120, max = 360, def = 206 },
	partyHeight = { min = 20, max = 70, def = 35 },
	partyPetWidth = { min = 60, max = 240, def = 95 },
	partyPetHeight = { min = 10, max = 40, def = 15 },
	raidWidth = { min = 50, max = 160, def = 85 },
	raidHeight = { min = 16, max = 50, def = 24 },
	focusWidth = { min = 110, max = 360, def = 200 },
	focusHeight = { min = 18, max = 60, def = 30 },
	totWidth = { min = 90, max = 300, def = 167 },
	totHeight = { min = 16, max = 50, def = 25 },
	petWidth = { min = 90, max = 300, def = 152 },
	petHeight = { min = 12, max = 40, def = 15 },
	bossWidth = { min = 120, max = 360, def = 206 },
	bossHeight = { min = 20, max = 70, def = 35 },
	swingWidth = { min = 80, max = 360, def = 180 },
	swingHeight = { min = 4, max = 24, def = 10 },
	playerAuraSize = { min = 12, max = 40, def = 23 },
	targetAuraSize = { min = 12, max = 40, def = 23 },
	focusAuraSize = { min = 12, max = 40, def = 20 },
	partyAuraSize = { min = 12, max = 40, def = 19 },
}

function ns.GetSize(key)
	local info = SIZE_LIMITS[key]
	if not info then return 0 end
	local val = tonumber(ns.GetOptionsDB()[key])
	if not val then return info.def end
	return math.max(info.min, math.min(info.max, math.floor(val + 0.5)))
end

function ns.GetSizeLimits(key)
	return SIZE_LIMITS[key]
end

function ns.TrackStatusBar(bar)
	if bar then
		trackedStatusBars[bar] = true
	end
	return bar
end

function ns.TrackBarTexture(tex)
	if tex then
		trackedBarTextures[tex] = true
	end
	return tex
end

function ns.TrackFontString(fs, baseSize)
	if fs then
		trackedFontStrings[fs] = baseSize or 12
	end
	return fs
end

function ns.TrackHealthBar(hp)
	if hp then
		trackedHealthBars[hp] = true
	end
	return hp
end

function ns.TrackBackdropFrame(frame)
	if frame then
		trackedBackdrops[frame] = true
	end
	return frame
end

function ns.GetTrackedBackdrops()
	return trackedBackdrops
end

function ns.ApplyMedia()
	local texPath = ns.GetStatusBarTexture()
	local fontPath = ns.GetFontPath()
	local flags = ns.GetFontFlags()
	local offset = ns.GetFontSizeOffset()
	local alpha = ns.GetBarAlpha()
	local borderSize = ns.GetBorderSize()

	ns.TEXTURE = texPath
	ns.FONT = fontPath

	for bar in pairs(trackedStatusBars) do
		if bar.SetStatusBarTexture then
			bar:SetStatusBarTexture(texPath)
		end
	end
	for tex in pairs(trackedBarTextures) do
		if tex.SetTexture then
			tex:SetTexture(texPath)
		end
	end
	for hp in pairs(trackedHealthBars) do
		if hp.SetAlpha then
			hp:SetAlpha(alpha)
		end
	end
	for fs, baseSize in pairs(trackedFontStrings) do
		if fs.SetFont then
			local sz = math.max(7, (baseSize or 12) + offset)
			if not fs:SetFont(fontPath, sz, flags) then
				fs:SetFont(DEFAULT_FONT, sz, flags)
			end
		end
	end

	if ns.ApplyBackdropBorderSize then
		ns.ApplyBackdropBorderSize(borderSize)
	end
	if ns.ApplyHealthColors then
		ns.ApplyHealthColors()
	end
	if oUF and oUF.objects then
		for _, obj in ipairs(oUF.objects) do
			if obj.Power and obj.Power.ForceUpdate then
				obj.Power:ForceUpdate()
			end
		end
	end
	if ns.ApplyThreatSettings then
		ns.ApplyThreatSettings()
	end
end

local LIVE_OPTIONS = {
	enableFader = true,
	fadeOutAlpha = true,
	firstNameOnly = true,
	shortRaceNames = true,
	showMinimapIcon = true,
	enableClickCast = true,
	enableThreatHighlight = true,
	threatStyle = true,
	showTargetThreat = true,
	targetThreatRawPct = true,
	desaturateOtherDebuffs = true,
	highlightExpiringAuras = true,
	highlightDispellableDebuffs = true,
	healthColorMode = true,
	healthColorPlayerOnly = true,
	statusBarTexture = true,
	fontName = true,
	fontOutline = true,
	fontSizeOffset = true,
	barAlpha = true,
	borderSize = true,
	smoothBars = true,
	partySpacing = true,
	partyDebuffPosition = true,
	partyPetPosition = true,
	bossSpacing = true,
	rangeAlpha = true,
}

local TAB_OPTION_KEYS = {
	general = {
		"firstNameOnly", "shortRaceNames", "hideSelfInfo", "enableHealthPrediction",
		"enableFader", "fadeOutAlpha", "removeBuffs", "showMinimapIcon",
	},
	frames = {
		"showPortraits", "use2DPortraits", "showTargetTarget", "showTargetTargetTarget",
		"showBossFrames", "bossSpacing", "enableClassPower", "useComboDots", "enableSwingBar",
		"enableTotemBar", "oUFRuneBar",
	},
	sizing = {
		"playerWidth", "playerHeight", "targetWidth", "targetHeight",
		"partyWidth", "partyHeight", "partyPetWidth", "partyPetHeight",
		"raidWidth", "raidHeight",
		"focusWidth", "focusHeight", "totWidth", "totHeight",
		"petWidth", "petHeight", "bossWidth", "bossHeight",
		"swingWidth", "swingHeight",
		"playerAuraSize", "targetAuraSize", "focusAuraSize", "partyAuraSize",
	},
	auras = {
		"playerShowBuffs", "playerShowDebuffs", "playerCastBar",
		"targetShowBuffs", "targetShowDebuffs", "targetCastBar",
		"focusShowBuffs", "focusShowDebuffs", "focusCastBar",
		"partyShowBuffs", "partyShowDebuffs", "partyCastBar",
		"petShowAura", "petShowDebuffs", "petCastBar", "auraSizeOffset",
		"desaturateOtherDebuffs", "highlightDispellableDebuffs", "highlightExpiringAuras",
	},
	group = {
		"showRaidFrames", "hidePartyInRaid", "hideCompactRaidManager", "showPartyPets",
		"partyPetPosition", "partyDebuffPosition", "partySpacing", "rangeAlpha",
	},
	clickcast = {
		"enableClickCast",
	},
	colors = {
		"healthColorMode", "healthColorPlayerOnly",
	},
	threat = {
		"enableThreatHighlight", "threatStyle", "showTargetThreat", "targetThreatRawPct",
	},
	appearance = {
		"statusBarTexture", "fontName", "fontOutline", "fontSizeOffset", "barAlpha", "borderSize", "smoothBars",
	},
}

local configFrame
local pendingCustomSpellCallback
local pendingCustomSpellInitial

local function GetStaticPopupEditBox(dialog)
	return dialog.editBox or (dialog.GetEditBox and dialog:GetEditBox()) or _G[dialog:GetName() .. "EditBox"]
end

if StaticPopupDialogs then
	StaticPopupDialogs["OUF_BRUN_RESET_ALL"] = {
		text = "|cffff8000oUF_Brun|r\n\nReset ALL settings across every tab, custom class colors, click-cast bindings, and frame positions back to defaults?",
		button1 = YES or "Yes",
		button2 = CANCEL or "Cancel",
		OnAccept = function()
			if InCombatLockdown() or not ns.ResetDefaults then return end
			local freshOpts = ns.ResetDefaults()
			if configFrame and configFrame.SyncAllControls then
				configFrame.SyncAllControls(freshOpts, true)
			end
		end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
	}

	StaticPopupDialogs["OUF_BRUN_CLICKCAST_SPELL"] = {
		text = "|cffff8000oUF_Brun|r\n\nEnter exact spell or macro spell name for this click binding:",
		button1 = ACCEPT or "Accept",
		button2 = CANCEL or "Cancel",
		hasEditBox = true,
		maxLetters = 80,
		OnShow = function(self)
			local eb = GetStaticPopupEditBox(self)
			if eb then
				eb:SetText(pendingCustomSpellInitial or "")
				eb:SetFocus()
				eb:HighlightText()
			end
		end,
		OnAccept = function(self)
			local eb = GetStaticPopupEditBox(self)
			local text = eb and eb:GetText() or ""
			local trimmed = text:match("^%s*(.-)%s*$") or ""
			if pendingCustomSpellCallback then
				local cb = pendingCustomSpellCallback
				pendingCustomSpellCallback = nil
				pendingCustomSpellInitial = nil
				cb(trimmed)
			end
		end,
		OnCancel = function()
			pendingCustomSpellCallback = nil
			pendingCustomSpellInitial = nil
		end,
		EditBoxOnEnterPressed = function(self)
			local parent = self:GetParent()
			local eb = GetStaticPopupEditBox(parent)
			local text = eb and eb:GetText() or ""
			local trimmed = text:match("^%s*(.-)%s*$") or ""
			if pendingCustomSpellCallback then
				local cb = pendingCustomSpellCallback
				pendingCustomSpellCallback = nil
				pendingCustomSpellInitial = nil
				cb(trimmed)
			end
			parent:Hide()
		end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
	}
end

local function OpenCustomSpellPopup(initialText, onAccept)
	if not StaticPopup_Show then return end
	pendingCustomSpellInitial = initialText or ""
	pendingCustomSpellCallback = onAccept
	local popup = StaticPopup_Show("OUF_BRUN_CLICKCAST_SPELL")
	if popup then popup:Raise() end
end

local FLAT_BACKDROP = {
	bgFile = "Interface\\Buttons\\WHITE8X8",
	edgeFile = "Interface\\Buttons\\WHITE8X8",
	edgeSize = 1,
}

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

	local FONT = ns.FONT
	local TEXTURE = ns.TEXTURE
	local FONT_SIZE = ns.FONT_SIZE or 14
	local SMALL_FONT_SIZE = ns.SMALL_FONT_SIZE or 12

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

	local function CreateFlatSlider(parent, cfg)
		local yOff = cfg.yOffset or 0
		local minVal = cfg.minVal or 0
		local maxVal = cfg.maxVal or 100
		local step = cfg.step or 1
		local showLive = (cfg.live ~= false)

		if cfg.divider ~= false then
			local div = parent:CreateTexture(nil, "BORDER")
			div:SetPoint("TOPLEFT", 12, -yOff)
			div:SetPoint("TOPRIGHT", -12, -yOff)
			div:SetHeight(1)
			div:SetColorTexture(1, 1, 1, 0.06)
		end

		local lbl = parent:CreateFontString(nil, "OVERLAY")
		lbl:SetFont(FONT, SMALL_FONT_SIZE, "OUTLINE")
		lbl:SetPoint("TOPLEFT", 14, -(yOff + 8))
		lbl:SetTextColor(0.92, 0.92, 0.95)
		lbl:SetText(cfg.label or "")

		local liveBadge
		if showLive then
			liveBadge = parent:CreateFontString(nil, "OVERLAY")
			liveBadge:SetFont(FONT, SMALL_FONT_SIZE - 2, "OUTLINE")
			liveBadge:SetPoint("TOPRIGHT", -14, -(yOff + 9))
			liveBadge:SetTextColor(0.35, 0.78, 0.45)
			liveBadge:SetText("LIVE")
		end

		local valText = parent:CreateFontString(nil, "OVERLAY")
		valText:SetFont(FONT, SMALL_FONT_SIZE, "OUTLINE")
		if liveBadge then
			valText:SetPoint("RIGHT", liveBadge, "LEFT", -10, 0)
		else
			valText:SetPoint("TOPRIGHT", -14, -(yOff + 8))
		end
		valText:SetJustifyH("RIGHT")
		valText:SetTextColor(1, 0.84, 0.45)

		local slider = CreateFrame("Slider", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
		slider:SetPoint("TOPLEFT", 14, -(yOff + 28))
		slider:SetPoint("TOPRIGHT", -14, -(yOff + 28))
		slider:SetHeight(14)
		slider:SetOrientation("HORIZONTAL")
		slider:SetMinMaxValues(minVal, maxVal)
		slider:SetValueStep(step)
		if slider.SetObeyStepOnDrag then
			slider:SetObeyStepOnDrag(true)
		end
		slider:EnableMouseWheel(true)

		local track = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
		track:SetPoint("LEFT", slider, "LEFT", 0, 0)
		track:SetPoint("RIGHT", slider, "RIGHT", 0, 0)
		track:SetHeight(6)
		StyleFlatBox(track, 0.05, 0.05, 0.07, 1, 0.28, 0.28, 0.34, 1)
		slider:SetFrameLevel(track:GetFrameLevel() + 2)

		local thumb = slider:CreateTexture(nil, "OVERLAY")
		thumb:SetSize(10, 14)
		thumb:SetColorTexture(1, 0.56, 0.12, 1)
		slider:SetThumbTexture(thumb)

		local fill = track:CreateTexture(nil, "ARTWORK")
		fill:SetPoint("TOPLEFT", track, "TOPLEFT", 1, -1)
		fill:SetPoint("BOTTOM", track, "BOTTOM", 0, 1)
		fill:SetPoint("RIGHT", thumb, "CENTER", 0, 0)
		fill:SetColorTexture(0.85, 0.45, 0.08, 0.95)

		local minLbl = parent:CreateFontString(nil, "OVERLAY")
		minLbl:SetFont(FONT, SMALL_FONT_SIZE - 2, "OUTLINE")
		minLbl:SetPoint("TOPLEFT", 14, -(yOff + 45))
		minLbl:SetTextColor(0.55, 0.55, 0.62)
		minLbl:SetText(cfg.minText or tostring(minVal))

		local maxLbl = parent:CreateFontString(nil, "OVERLAY")
		maxLbl:SetFont(FONT, SMALL_FONT_SIZE - 2, "OUTLINE")
		maxLbl:SetPoint("TOPRIGHT", -14, -(yOff + 45))
		maxLbl:SetTextColor(0.55, 0.55, 0.62)
		maxLbl:SetText(cfg.maxText or tostring(maxVal))

		local function SnapValue(v)
			local snapped = math.floor(((v - minVal) / step) + 0.5) * step + minVal
			return math.max(minVal, math.min(maxVal, snapped))
		end

		local function FormatText(v)
			return cfg.formatVal and cfg.formatVal(v) or tostring(v)
		end

		function slider:SetValueSilent(v)
			local snapped = SnapValue(tonumber(v) or minVal)
			self._updating = true
			self:SetValue(snapped)
			self._updating = nil
			valText:SetText(FormatText(snapped))
			fill:SetShown(snapped > minVal)
		end

		function slider:SetEnabledState(enabled)
			local en = (enabled ~= false)
			self._disabled = not en
			self:EnableMouse(en)
			self:EnableMouseWheel(en)
			local a = en and 1 or 0.42
			lbl:SetAlpha(a)
			valText:SetAlpha(a)
			minLbl:SetAlpha(a)
			maxLbl:SetAlpha(a)
			track:SetAlpha(a)
			thumb:SetAlpha(a)
			if liveBadge then
				liveBadge:SetAlpha(a)
			end
		end

		slider:SetScript("OnEnter", function(self)
			if not self._disabled then
				track:SetBackdropBorderColor(1, 0.56, 0.12, 1)
			end
			if cfg.tip then
				GameTooltip:SetOwner(self, "ANCHOR_TOP")
				GameTooltip:AddLine(cfg.label or "", 1, 0.82, 0)
				GameTooltip:AddLine(cfg.tip, 0.85, 0.85, 0.9, true)
				if self._disabled and cfg.disabledTip then
					GameTooltip:AddLine(cfg.disabledTip, 1, 0.45, 0.35, true)
				end
				GameTooltip:Show()
			end
		end)
		slider:SetScript("OnLeave", function()
			track:SetBackdropBorderColor(0.28, 0.28, 0.34, 1)
			GameTooltip:Hide()
		end)
		slider:SetScript("OnMouseWheel", function(self, delta)
			if self._disabled then return end
			local cur = SnapValue(self:GetValue())
			self:SetValue(SnapValue(cur + (delta > 0 and step or -step)))
		end)
		slider:SetScript("OnValueChanged", function(self, value)
			if self._updating or self._disabled then return end
			local snapped = SnapValue(value)
			if math.abs(value - snapped) > 0.0001 then
				self._updating = true
				self:SetValue(snapped)
				self._updating = nil
			end
			valText:SetText(FormatText(snapped))
			fill:SetShown(snapped > minVal)
			if cfg.onChanged then
				cfg.onChanged(snapped)
			end
		end)

		return slider
	end

	local function OpenColorPicker(r, g, b, onChanged, onCancel)
		if ColorPickerFrame.SetupColorPickerAndShow then
			ColorPickerFrame:SetupColorPickerAndShow({
				swatchFunc = function()
					local nr, ng, nb = ColorPickerFrame:GetColorRGB()
					onChanged(nr, ng, nb)
				end,
				cancelFunc = function()
					onCancel()
				end,
				r = r,
				g = g,
				b = b,
				hasOpacity = false,
			})
		else
			ColorPickerFrame:Hide()
			ColorPickerFrame.hasOpacity = false
			ColorPickerFrame.previousValues = { r, g, b }
			ColorPickerFrame.func = function()
				local nr, ng, nb = ColorPickerFrame:GetColorRGB()
				onChanged(nr, ng, nb)
			end
			ColorPickerFrame.cancelFunc = function()
				onCancel()
			end
			ColorPickerFrame:SetColorRGB(r, g, b)
			ColorPickerFrame:Show()
		end
	end

	-- Virtualized dropdown picker for LibSharedMedia statusbars & fonts
	local dropdownCloseOverlay = CreateFrame("Button", nil, UIParent)
	dropdownCloseOverlay:SetAllPoints(UIParent)
	dropdownCloseOverlay:SetFrameStrata("FULLSCREEN_DIALOG")
	dropdownCloseOverlay:EnableMouse(true)
	dropdownCloseOverlay:Hide()

	local mediaDropdown = CreateFrame("Frame", nil, dropdownCloseOverlay, BackdropTemplateMixin and "BackdropTemplate" or nil)
	mediaDropdown:SetSize(244, 208)
	mediaDropdown:SetFrameLevel(dropdownCloseOverlay:GetFrameLevel() + 2)
	mediaDropdown:EnableMouse(true)
	mediaDropdown:EnableMouseWheel(true)
	mediaDropdown:SetClampedToScreen(true)
	StyleFlatBox(mediaDropdown, 0.05, 0.05, 0.07, 0.98, 0.34, 0.34, 0.42, 1)

	local VISIBLE_ROWS = 9
	local dropdownItems = {}
	local dropdownOffset = 0
	local dropdownMediaType = "statusbar"
	local dropdownSelectedKey = nil
	local dropdownOnSelect = nil
	local dropdownAnchor = nil
	local dropdownRows = {}
	local choiceDropdown

	local scrollTrack = mediaDropdown:CreateTexture(nil, "BORDER")
	scrollTrack:SetPoint("TOPRIGHT", -4, -6)
	scrollTrack:SetPoint("BOTTOMRIGHT", -4, 6)
	scrollTrack:SetWidth(3)
	scrollTrack:SetColorTexture(1, 1, 1, 0.08)

	local scrollThumb = mediaDropdown:CreateTexture(nil, "ARTWORK")
	scrollThumb:SetWidth(3)
	scrollThumb:SetColorTexture(1, 0.55, 0.1, 0.85)

	local function CloseMediaDropdown()
		mediaDropdown:Hide()
		if choiceDropdown then
			choiceDropdown:Hide()
		end
		dropdownCloseOverlay:Hide()
		dropdownAnchor = nil
	end

	dropdownCloseOverlay:SetScript("OnClick", CloseMediaDropdown)

	local function RefreshMediaDropdownRows()
		local total = #dropdownItems
		local maxOff = math.max(0, total - VISIBLE_ROWS)
		dropdownOffset = math.max(0, math.min(dropdownOffset, maxOff))

		local showScroll = (total > VISIBLE_ROWS)
		scrollTrack:SetShown(showScroll)
		scrollThumb:SetShown(showScroll)
		if showScroll then
			local trackH = 196
			local thumbH = math.max(18, math.floor(trackH * (VISIBLE_ROWS / total)))
			local travel = trackH - thumbH
			local ratio = (maxOff > 0) and (dropdownOffset / maxOff) or 0
			scrollThumb:ClearAllPoints()
			scrollThumb:SetHeight(thumbH)
			scrollThumb:SetPoint("TOPRIGHT", mediaDropdown, "TOPRIGHT", -4, -(6 + ratio * travel))
		end

		for i = 1, VISIBLE_ROWS do
			local row = dropdownRows[i]
			local key = dropdownItems[dropdownOffset + i]
			if key then
				row._key = key
				local isSelected = (key == dropdownSelectedKey)
				row.activeBg:SetShown(isSelected)
				if dropdownMediaType == "statusbar" then
					row.previewBar:SetTexture(ns.FetchMedia("statusbar", key))
					row.previewBar:SetVertexColor(isSelected and 1 or 0.35, isSelected and 0.56 or 0.52, isSelected and 0.12 or 0.68, 0.55)
					row.previewBar:Show()
					row.label:SetFont(FONT, SMALL_FONT_SIZE - 1, "OUTLINE")
				else
					row.previewBar:Hide()
					if not row.label:SetFont(ns.FetchMedia("font", key), SMALL_FONT_SIZE, "OUTLINE") then
						row.label:SetFont(DEFAULT_FONT, SMALL_FONT_SIZE, "OUTLINE")
					end
				end
				row.label:SetText(key)
				row.label:SetTextColor(isSelected and 1 or 0.92, isSelected and 0.84 or 0.92, isSelected and 0.45 or 0.95)
				row:Show()
			else
				row._key = nil
				row:Hide()
			end
		end
	end

	for i = 1, VISIBLE_ROWS do
		local row = CreateFrame("Button", nil, mediaDropdown)
		row:SetPoint("TOPLEFT", 5, -(5 + (i - 1) * 22))
		row:SetPoint("TOPRIGHT", -11, -(5 + (i - 1) * 22))
		row:SetHeight(21)

		local previewBar = row:CreateTexture(nil, "BACKGROUND")
		previewBar:SetPoint("TOPLEFT", 1, -1)
		previewBar:SetPoint("BOTTOMRIGHT", -1, 1)
		previewBar:Hide()
		row.previewBar = previewBar

		local activeBg = row:CreateTexture(nil, "BORDER")
		activeBg:SetAllPoints()
		activeBg:SetColorTexture(1, 0.5, 0, 0.22)
		activeBg:Hide()
		row.activeBg = activeBg

		local hoverBg = row:CreateTexture(nil, "BORDER")
		hoverBg:SetAllPoints()
		hoverBg:SetColorTexture(1, 1, 1, 0.08)
		hoverBg:Hide()

		local label = row:CreateFontString(nil, "OVERLAY")
		label:SetPoint("LEFT", 6, 0)
		label:SetPoint("RIGHT", -6, 0)
		label:SetJustifyH("LEFT")
		label:SetWordWrap(false)
		label:SetFont(FONT, SMALL_FONT_SIZE, "OUTLINE")
		row.label = label

		row:SetScript("OnEnter", function() hoverBg:Show() end)
		row:SetScript("OnLeave", function() hoverBg:Hide() end)
		row:SetScript("OnClick", function(self)
			if self._key and dropdownOnSelect then
				local chosen = self._key
				local cb = dropdownOnSelect
				CloseMediaDropdown()
				cb(chosen)
			end
		end)
		dropdownRows[i] = row
	end

	mediaDropdown:SetScript("OnMouseWheel", function(_, delta)
		dropdownOffset = dropdownOffset - (delta > 0 and 2 or -2)
		RefreshMediaDropdownRows()
	end)

	local function OpenMediaDropdown(anchorBtn, mediaType, currentKey, onSelect)
		if dropdownCloseOverlay:IsShown() and dropdownAnchor == anchorBtn then
			CloseMediaDropdown()
			return
		end
		dropdownAnchor = anchorBtn
		dropdownMediaType = mediaType
		dropdownSelectedKey = currentKey
		dropdownOnSelect = onSelect
		dropdownItems = ns.GetMediaList(mediaType)
		dropdownOffset = 0
		for idx, itemKey in ipairs(dropdownItems) do
			if itemKey == currentKey then
				dropdownOffset = math.max(0, idx - 4)
				break
			end
		end
		local listH = math.min(VISIBLE_ROWS, math.max(1, #dropdownItems)) * 22 + 10
		mediaDropdown:SetSize(244, listH)
		mediaDropdown:ClearAllPoints()
		mediaDropdown:SetPoint("TOPLEFT", anchorBtn, "BOTTOMLEFT", 0, -2)
		RefreshMediaDropdownRows()
		if choiceDropdown then choiceDropdown:Hide() end
		mediaDropdown:Show()
		dropdownCloseOverlay:Show()
	end

	-- Generic scrollable dropdown for Click-Cast modifiers, mouse buttons & spells
	choiceDropdown = CreateFrame("Frame", nil, dropdownCloseOverlay, BackdropTemplateMixin and "BackdropTemplate" or nil)
	choiceDropdown:SetSize(200, 208)
	choiceDropdown:SetFrameLevel(dropdownCloseOverlay:GetFrameLevel() + 2)
	choiceDropdown:EnableMouse(true)
	choiceDropdown:EnableMouseWheel(true)
	choiceDropdown:SetClampedToScreen(true)
	choiceDropdown:Hide()
	StyleFlatBox(choiceDropdown, 0.05, 0.05, 0.07, 0.98, 0.34, 0.34, 0.42, 1)

	local choiceItems = {}
	local choiceOffset = 0
	local choiceSelectedVal = nil
	local choiceOnSelect = nil
	local choiceRows = {}

	local choiceScrollTrack = choiceDropdown:CreateTexture(nil, "BORDER")
	choiceScrollTrack:SetPoint("TOPRIGHT", -4, -6)
	choiceScrollTrack:SetPoint("BOTTOMRIGHT", -4, 6)
	choiceScrollTrack:SetWidth(3)
	choiceScrollTrack:SetColorTexture(1, 1, 1, 0.08)

	local choiceScrollThumb = choiceDropdown:CreateTexture(nil, "ARTWORK")
	choiceScrollThumb:SetWidth(3)
	choiceScrollThumb:SetColorTexture(1, 0.55, 0.1, 0.85)

	local function RefreshChoiceDropdownRows()
		local total = #choiceItems
		local maxOff = math.max(0, total - VISIBLE_ROWS)
		choiceOffset = math.max(0, math.min(choiceOffset, maxOff))

		local showScroll = (total > VISIBLE_ROWS)
		choiceScrollTrack:SetShown(showScroll)
		choiceScrollThumb:SetShown(showScroll)
		if showScroll then
			local trackH = 196
			local thumbH = math.max(18, math.floor(trackH * (VISIBLE_ROWS / total)))
			local travel = trackH - thumbH
			local ratio = (maxOff > 0) and (choiceOffset / maxOff) or 0
			choiceScrollThumb:ClearAllPoints()
			choiceScrollThumb:SetHeight(thumbH)
			choiceScrollThumb:SetPoint("TOPRIGHT", choiceDropdown, "TOPRIGHT", -4, -(6 + ratio * travel))
		end

		for i = 1, VISIBLE_ROWS do
			local row = choiceRows[i]
			local item = choiceItems[choiceOffset + i]
			if item then
				row._value = item.value
				local isSelected = (choiceSelectedVal ~= nil and item.value == choiceSelectedVal)
				row.activeBg:SetShown(isSelected)
				row.label:SetText(item.label or "")
				if isSelected then
					row.label:SetTextColor(1, 0.84, 0.45)
				elseif item.r and item.g and item.b then
					row.label:SetTextColor(item.r, item.g, item.b)
				else
					row.label:SetTextColor(0.92, 0.92, 0.95)
				end
				row:Show()
			else
				row._value = nil
				row:Hide()
			end
		end
	end

	for i = 1, VISIBLE_ROWS do
		local row = CreateFrame("Button", nil, choiceDropdown)
		row:SetPoint("TOPLEFT", 5, -(5 + (i - 1) * 22))
		row:SetPoint("TOPRIGHT", -11, -(5 + (i - 1) * 22))
		row:SetHeight(21)

		local activeBg = row:CreateTexture(nil, "BORDER")
		activeBg:SetAllPoints()
		activeBg:SetColorTexture(1, 0.5, 0, 0.22)
		activeBg:Hide()
		row.activeBg = activeBg

		local hoverBg = row:CreateTexture(nil, "BORDER")
		hoverBg:SetAllPoints()
		hoverBg:SetColorTexture(1, 1, 1, 0.08)
		hoverBg:Hide()

		local label = row:CreateFontString(nil, "OVERLAY")
		label:SetPoint("LEFT", 6, 0)
		label:SetPoint("RIGHT", -6, 0)
		label:SetJustifyH("LEFT")
		label:SetWordWrap(false)
		label:SetFont(FONT, SMALL_FONT_SIZE, "OUTLINE")
		row.label = label

		row:SetScript("OnEnter", function() hoverBg:Show() end)
		row:SetScript("OnLeave", function() hoverBg:Hide() end)
		row:SetScript("OnClick", function(self)
			if self._value ~= nil and choiceOnSelect then
				local val = self._value
				local cb = choiceOnSelect
				CloseMediaDropdown()
				cb(val)
			end
		end)
		choiceRows[i] = row
	end

	choiceDropdown:SetScript("OnMouseWheel", function(_, delta)
		choiceOffset = choiceOffset - (delta > 0 and 2 or -2)
		RefreshChoiceDropdownRows()
	end)

	local function OpenChoiceDropdown(anchorBtn, items, currentValue, dropWidth, onSelect)
		if dropdownCloseOverlay:IsShown() and dropdownAnchor == anchorBtn then
			CloseMediaDropdown()
			return
		end
		dropdownAnchor = anchorBtn
		choiceItems = items or {}
		choiceSelectedVal = currentValue
		choiceOnSelect = onSelect
		choiceOffset = 0
		if currentValue ~= nil then
			for idx, item in ipairs(choiceItems) do
				if item.value == currentValue then
					choiceOffset = math.max(0, idx - 4)
					break
				end
			end
		end
		local listH = math.min(VISIBLE_ROWS, math.max(1, #choiceItems)) * 22 + 10
		choiceDropdown:SetSize(dropWidth or 180, listH)
		choiceDropdown:ClearAllPoints()
		choiceDropdown:SetPoint("TOPLEFT", anchorBtn, "BOTTOMLEFT", 0, -2)
		RefreshChoiceDropdownRows()
		mediaDropdown:Hide()
		choiceDropdown:Show()
		dropdownCloseOverlay:Show()
	end

	-- Build 9 category pages
	local tabs = {
		{ id = "general", label = "General" },
		{ id = "frames", label = "Unit Frames" },
		{ id = "sizing", label = "Sizing" },
		{ id = "auras", label = "Auras & Casts" },
		{ id = "group", label = "Party & Raid" },
		{ id = "clickcast", label = "Click-Cast" },
		{ id = "colors", label = "Colors" },
		{ id = "threat", label = "Aggro & Threat" },
		{ id = "appearance", label = "Appearance" },
	}
	local pages = {}
	local tabButtons = {}
	local tabLabels = {}
	local activeTabId = "general"

	local function SelectTab(tabId)
		CloseMediaDropdown()
		activeTabId = tabId
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
		tabLabels[tab.id] = tab.label
		local page = CreateFrame("Frame", nil, contentArea)
		page:SetAllPoints()
		page:Hide()
		pages[tab.id] = page

		local tbtn = CreateFrame("Button", nil, sidebar)
		tbtn:SetPoint("TOPLEFT", 6, -(10 + (i - 1) * 30))
		tbtn:SetPoint("TOPRIGHT", -6, -(10 + (i - 1) * 30))
		tbtn:SetHeight(25)

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
	local RefreshGeneralUI
	do
		local p = pages.general
		local card1 = CreateCard(p, "Names & Visuals", 134, 12)
		local generalVisuals = {
			{ key = "firstNameOnly", label = "First Name Only (hide Forever surnames)", tip = "Show only the first name on player unit frames." },
			{ key = "shortRaceNames", label = "Shorten Long Race & Creature Names", tip = "Shorten compound race names (e.g. Windshaper Skyborne -> Skyborne)." },
			{ key = "hideSelfInfo", label = "Hide Player Name & Level at Max Level", tip = "Keep your player power bar uncluttered at max level." },
			{ key = "enableHealthPrediction", label = "Incoming Heals & Absorb Shields", tip = "Show incoming heal predictions and absorb overlays on health bars." },
		}
		for i, def in ipairs(generalVisuals) do
			CreateToggleRow(card1, def, i)
		end

		local card2 = CreateCard(p, "Behavior & Interface", 168, 158)
		local generalBehavior = {
			{ key = "enableFader", label = "Fade Player & Pet Out of Combat", tip = "Smoothly fade Player and Pet frames when idle with no target." },
			{ key = "removeBuffs", label = "Hide Default Blizzard Buff Frame", tip = "Disable Blizzard's top-right buff and weapon enchant frames." },
			{ key = "showMinimapIcon", label = "Show Minimap Quick Toggle Icon", tip = "Display the draggable 'B' button around the minimap." },
		}
		for i, def in ipairs(generalBehavior) do
			local row = CreateToggleRow(card2, def, i)
			if def.key == "enableFader" then
				row:HookScript("OnClick", function()
					if RefreshGeneralUI then RefreshGeneralUI() end
				end)
			end
		end

		local fadeSlider = CreateFlatSlider(card2, {
			label = "Idle Fade Opacity",
			yOffset = 108,
			minVal = 0,
			maxVal = 90,
			step = 5,
			minText = "0%",
			maxText = "90%",
			formatVal = function(v) return string.format("%d%%", v) end,
			tip = "Opacity of Player & Pet frames when faded out of combat with no target.",
			disabledTip = "Requires 'Fade Player & Pet Out of Combat' to be enabled.",
			onChanged = function(v)
				ns.GetOptionsDB().fadeOutAlpha = v / 100
				if ns.ApplyFaderSettings then
					ns.ApplyFaderSettings()
				end
			end,
		})

		RefreshGeneralUI = function()
			local opts = ns.GetOptionsDB()
			fadeSlider:SetValueSilent(math.floor(ns.GetFadeOutAlpha() * 100 + 0.5))
			fadeSlider:SetEnabledState(opts.enableFader ~= false)
		end
	end

	-- Page 2: Unit Frames
	local RefreshFramesUI
	do
		local p = pages.frames
		local card1 = CreateCard(p, "Frames & Portraits", 178, 8)
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
			local row = CreateToggleRow(card1, def, i)
			if def.key == "showBossFrames" then
				row:HookScript("OnClick", function()
					if RefreshFramesUI then RefreshFramesUI() end
				end)
			end
		end

		local bossLbl = card1:CreateFontString(nil, "OVERLAY")
		bossLbl:SetFont(FONT, SMALL_FONT_SIZE, "OUTLINE")
		bossLbl:SetPoint("TOPLEFT", 32, -153)
		bossLbl:SetTextColor(0.86, 0.86, 0.90)
		bossLbl:SetText("Boss Frame Spacing")

		local bossLive = card1:CreateFontString(nil, "OVERLAY")
		bossLive:SetFont(FONT, SMALL_FONT_SIZE - 2, "OUTLINE")
		bossLive:SetPoint("TOPRIGHT", -14, -154)
		bossLive:SetTextColor(0.35, 0.78, 0.45)
		bossLive:SetText("LIVE")

		local bossPlus = CreateActionButton(card1, "+", 24, 20, function()
			if not ns.GetOptionsDB().showBossFrames then return end
			ns.GetOptionsDB().bossSpacing = math.min(120, ns.GetBossSpacing() + 4)
			if ns.ApplyBossSpacing then ns.ApplyBossSpacing() end
			if RefreshFramesUI then RefreshFramesUI() end
		end)
		bossPlus:SetPoint("RIGHT", bossLive, "LEFT", -8, 0)

		local bossVal = card1:CreateFontString(nil, "OVERLAY")
		bossVal:SetFont(FONT, SMALL_FONT_SIZE, "OUTLINE")
		bossVal:SetWidth(52)
		bossVal:SetPoint("RIGHT", bossPlus, "LEFT", -4, 0)
		bossVal:SetJustifyH("CENTER")
		bossVal:SetTextColor(1, 0.84, 0.45)

		local bossMinus = CreateActionButton(card1, "-", 24, 20, function()
			if not ns.GetOptionsDB().showBossFrames then return end
			ns.GetOptionsDB().bossSpacing = math.max(0, ns.GetBossSpacing() - 4)
			if ns.ApplyBossSpacing then ns.ApplyBossSpacing() end
			if RefreshFramesUI then RefreshFramesUI() end
		end)
		bossMinus:SetPoint("RIGHT", bossVal, "LEFT", -4, 0)

		RefreshFramesUI = function()
			local enabled = (ns.GetOptionsDB().showBossFrames ~= false)
			bossVal:SetText(ns.GetBossSpacing() .. " px")
			local a = enabled and 1 or 0.42
			bossLbl:SetAlpha(a)
			bossLive:SetAlpha(a)
			bossVal:SetAlpha(a)
			bossPlus:SetAlpha(a)
			bossMinus:SetAlpha(a)
		end

		local card2 = CreateCard(p, "Class & Combat Bars", 156, 192)
		local classBars = {
			{ key = "enableClassPower", label = "Class Power, Combo Points & Stagger", tip = "Show Combo Points, Holy Power, Chi, Soul Shards, Arcane Charges, Essence, or Stagger." },
			{
				key = "useComboDots",
				label = "Use Combo Point Dots (instead of Bar)",
				tip = "Show classic combo point dots on Target's power bar instead of the segmented bar.",
				indent = true,
				dependsOn = "enableClassPower",
				dependsLabel = "Class Power, Combo Points & Stagger",
			},
			{ key = "enableSwingBar", label = "Player Swing Timer Bar", tip = "Display melee and ranged auto-attack swing timer bars." },
			{ key = "enableTotemBar", label = "Clickable Totem Bar above Player", tip = "Style and anchor Shaman/class totems above your Player frame." },
			{ key = "oUFRuneBar", label = "Use oUF Death Knight Rune Bar", tip = "Replace Blizzard's default Death Knight Rune Frame with oUF runes." },
		}
		for i, def in ipairs(classBars) do
			CreateToggleRow(card2, def, i)
		end
	end

	-- Page 3: Sizing
	local RefreshSizingUI
	do
		local p = pages.sizing
		local card1 = CreateCard(p, "Unit Frame Dimensions (Width x Height)", 250, 8)

		local reloadNote = card1:CreateFontString(nil, "OVERLAY")
		reloadNote:SetFont(FONT, SMALL_FONT_SIZE - 2, "OUTLINE")
		reloadNote:SetPoint("TOPRIGHT", -12, -11)
		reloadNote:SetTextColor(0.9, 0.65, 0.3)
		reloadNote:SetText("Reload UI")

		local sizeSteppers = {}
		local function CreateSizeStepper(parent, key, normalStep, shiftStep, onAfterChange)
			local lim = ns.GetSizeLimits and ns.GetSizeLimits(key) or { min = 10, max = 400, def = 100 }
			local wrap = CreateFrame("Frame", nil, parent)
			wrap:SetSize(90, 18)
			wrap:EnableMouseWheel(true)

			local function StepBy(delta)
				local nextVal = math.max(lim.min, math.min(lim.max, ns.GetSize(key) + delta))
				ns.GetOptionsDB()[key] = nextVal
				reloadNeeded = true
				UpdateReloadHint()
				if onAfterChange then onAfterChange(nextVal) end
				if RefreshSizingUI then RefreshSizingUI() end
			end

			local minus = CreateActionButton(wrap, "-", 20, 18, function()
				local d = IsShiftKeyDown() and shiftStep or normalStep
				StepBy(-d)
			end)
			minus:SetPoint("LEFT", 0, 0)

			local valFs = wrap:CreateFontString(nil, "OVERLAY")
			valFs:SetFont(FONT, SMALL_FONT_SIZE - 1, "OUTLINE")
			valFs:SetWidth(42)
			valFs:SetPoint("CENTER", 0, 0)
			valFs:SetJustifyH("CENTER")
			valFs:SetTextColor(1, 0.84, 0.45)

			local plus = CreateActionButton(wrap, "+", 20, 18, function()
				local d = IsShiftKeyDown() and shiftStep or normalStep
				StepBy(d)
			end)
			plus:SetPoint("RIGHT", 0, 0)

			local function ShowTip(self)
				GameTooltip:SetOwner(self, "ANCHOR_TOP")
				GameTooltip:AddLine(string.format("%d - %d px  (Default: %d px)", lim.min, lim.max, lim.def), 1, 0.82, 0)
				GameTooltip:AddLine(string.format("Click: +/-%d px  |  Shift-Click: +/-%d px  |  Scroll: +/-1 px", normalStep, shiftStep), 0.85, 0.85, 0.9, true)
				GameTooltip:AddLine("Requires Reload UI to apply frame layout.", 0.9, 0.65, 0.3)
				GameTooltip:Show()
			end
			local function HideTip() GameTooltip:Hide() end

			wrap:SetScript("OnMouseWheel", function(_, delta)
				local step = IsShiftKeyDown() and shiftStep or 1
				StepBy(delta > 0 and step or -step)
			end)
			minus:HookScript("OnEnter", ShowTip)
			minus:HookScript("OnLeave", HideTip)
			plus:HookScript("OnEnter", ShowTip)
			plus:HookScript("OnLeave", HideTip)

			sizeSteppers[key] = valFs
			return wrap
		end

		local hdrUnit = card1:CreateFontString(nil, "OVERLAY")
		hdrUnit:SetFont(FONT, SMALL_FONT_SIZE - 2, "OUTLINE")
		hdrUnit:SetPoint("TOPLEFT", 14, -30)
		hdrUnit:SetTextColor(0.58, 0.58, 0.65)
		hdrUnit:SetText("Unit / Bar")

		local hdrW = card1:CreateFontString(nil, "OVERLAY")
		hdrW:SetFont(FONT, SMALL_FONT_SIZE - 2, "OUTLINE")
		hdrW:SetPoint("TOP", card1, "TOPLEFT", 197, -30)
		hdrW:SetTextColor(0.58, 0.58, 0.65)
		hdrW:SetText("Width (px)")

		local hdrH = card1:CreateFontString(nil, "OVERLAY")
		hdrH:SetFont(FONT, SMALL_FONT_SIZE - 2, "OUTLINE")
		hdrH:SetPoint("TOP", card1, "TOPLEFT", 339, -30)
		hdrH:SetTextColor(0.58, 0.58, 0.65)
		hdrH:SetText("Height (px)")

		local sizeRows = {
			{ label = "Player", wKey = "playerWidth", hKey = "playerHeight" },
			{ label = "Target", wKey = "targetWidth", hKey = "targetHeight" },
			{ label = "Party", wKey = "partyWidth", hKey = "partyHeight" },
			{ label = "Party Pet", wKey = "partyPetWidth", hKey = "partyPetHeight" },
			{ label = "Raid", wKey = "raidWidth", hKey = "raidHeight" },
			{ label = "Focus", wKey = "focusWidth", hKey = "focusHeight" },
			{ label = "ToT / ToToT", wKey = "totWidth", hKey = "totHeight" },
			{ label = "Pet", wKey = "petWidth", hKey = "petHeight" },
			{ label = "Boss", wKey = "bossWidth", hKey = "bossHeight" },
			{ label = "Swing Bar", wKey = "swingWidth", hKey = "swingHeight" },
		}
		for idx, def in ipairs(sizeRows) do
			local rowY = 43 + (idx - 1) * 20
			if idx % 2 == 1 then
				local stripe = card1:CreateTexture(nil, "BACKGROUND")
				stripe:SetPoint("TOPLEFT", 10, -rowY + 1)
				stripe:SetPoint("TOPRIGHT", -10, -rowY + 1)
				stripe:SetHeight(19)
				stripe:SetColorTexture(1, 1, 1, 0.025)
			end

			local lbl = card1:CreateFontString(nil, "OVERLAY")
			lbl:SetFont(FONT, SMALL_FONT_SIZE - 1, "OUTLINE")
			lbl:SetPoint("TOPLEFT", 14, -(rowY + 2))
			lbl:SetTextColor(0.92, 0.92, 0.95)
			lbl:SetText(def.label)

			local wWrap = CreateSizeStepper(card1, def.wKey, 2, 10)
			wWrap:SetPoint("TOPLEFT", card1, "TOPLEFT", 152, -rowY)

			local xSep = card1:CreateFontString(nil, "OVERLAY")
			xSep:SetFont(FONT, SMALL_FONT_SIZE - 2, "OUTLINE")
			xSep:SetPoint("TOP", card1, "TOPLEFT", 268, -(rowY + 3))
			xSep:SetTextColor(0.5, 0.5, 0.56)
			xSep:SetText("x")

			local hWrap = CreateSizeStepper(card1, def.hKey, 1, 5)
			hWrap:SetPoint("TOPLEFT", card1, "TOPLEFT", 294, -rowY)
		end

		local card2 = CreateCard(p, "Aura Icon Sizes (px)", 82, 264)
		local auraGrid = {
			{ label = "Player", key = "playerAuraSize", col = 0, row = 0 },
			{ label = "Target", key = "targetAuraSize", col = 1, row = 0 },
			{ label = "Focus", key = "focusAuraSize", col = 0, row = 1 },
			{ label = "Party / Boss", key = "partyAuraSize", col = 1, row = 1 },
		}
		local function OnAuraBaseSizeChanged()
			if ns.ApplyTestDebuffs then
				ns.ApplyTestDebuffs()
			end
		end
		for _, def in ipairs(auraGrid) do
			local yPos = 33 + def.row * 23
			local xLbl = (def.col == 0) and 14 or 214
			local xRight = (def.col == 0) and -214 or -14

			local lbl = card2:CreateFontString(nil, "OVERLAY")
			lbl:SetFont(FONT, SMALL_FONT_SIZE - 1, "OUTLINE")
			lbl:SetPoint("TOPLEFT", xLbl, -(yPos + 2))
			lbl:SetTextColor(0.92, 0.92, 0.95)
			lbl:SetText(def.label)

			local aWrap = CreateSizeStepper(card2, def.key, 1, 5, OnAuraBaseSizeChanged)
			aWrap:SetPoint("TOPRIGHT", card2, "TOPRIGHT", xRight, -yPos)
		end

		RefreshSizingUI = function()
			for key, fs in pairs(sizeSteppers) do
				fs:SetText(tostring(ns.GetSize(key)))
			end
		end
	end

	-- Page 4: Auras & Casts
	local RefreshAurasUI
	do
		local p = pages.auras
		local card1 = CreateCard(p, "Unit Auras & Castbars", 186, 10)

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
				fs:SetPoint("TOPLEFT", ch.x, -33)
			else
				fs:SetPoint("TOP", card1, "TOPLEFT", ch.x, -33)
			end
			fs:SetText(ch.text)
		end

		local matrixRows = {
			{ unit = "Player", buffs = "playerShowBuffs", debuffs = "playerShowDebuffs", cast = "playerCastBar" },
			{ unit = "Target", buffs = "targetShowBuffs", debuffs = "targetShowDebuffs", cast = "targetCastBar" },
			{ unit = "Focus", buffs = "focusShowBuffs", debuffs = "focusShowDebuffs", cast = "focusCastBar" },
			{ unit = "Party", buffs = "partyShowBuffs", debuffs = "partyShowDebuffs", cast = "partyCastBar" },
			{ unit = "Pet", buffs = "petShowAura", debuffs = "petShowDebuffs", cast = "petCastBar", buffsTip = "Show Pet Buffs" },
		}
		for idx, r in ipairs(matrixRows) do
			local rowY = 52 + (idx - 1) * 26
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

			CreateMatrixCell(card1, r.buffs, r.buffsTip or ("Show " .. r.unit .. " Buffs"), colBuffsX, rowY)
			CreateMatrixCell(card1, r.debuffs, "Show " .. r.unit .. " Debuffs", colDebuffsX, rowY)
			CreateMatrixCell(card1, r.cast, "Show " .. r.unit .. " Castbar", colCastX, rowY)
		end

		local card2 = CreateCard(p, "Aura Filtering & Highlights", 138, 204)
		local auraExtras = {
			{ key = "desaturateOtherDebuffs", label = "Prioritize Player Debuffs & Desaturate Others", tip = "Sort your debuffs first on Target/Boss and grey out others' debuffs." },
			{ key = "highlightDispellableDebuffs", label = "Highlight Dispellable Debuffs (Player Class)", tip = "Border-highlight and prioritize debuffs your class can dispel." },
			{ key = "highlightExpiringAuras", label = "Highlight Expiring Timers (<=10s / <=5s)", tip = "Turn aura countdown timers yellow at <=10s and red at <=5s." },
		}
		for i, def in ipairs(auraExtras) do
			CreateToggleRow(card2, def, i)
		end

		local auraDiv = card2:CreateTexture(nil, "BORDER")
		auraDiv:SetPoint("TOPLEFT", 12, -104)
		auraDiv:SetPoint("TOPRIGHT", -12, -104)
		auraDiv:SetHeight(1)
		auraDiv:SetColorTexture(1, 1, 1, 0.06)

		local auraSizeLbl = card2:CreateFontString(nil, "OVERLAY")
		auraSizeLbl:SetFont(FONT, SMALL_FONT_SIZE, "OUTLINE")
		auraSizeLbl:SetPoint("TOPLEFT", 14, -114)
		auraSizeLbl:SetTextColor(0.92, 0.92, 0.95)
		auraSizeLbl:SetText("Aura Icon Size Adjust (Reload)")

		local auraSizePlus = CreateActionButton(card2, "+", 26, 20, function()
			ns.GetOptionsDB().auraSizeOffset = math.min(8, ns.GetAuraSizeOffset() + 1)
			reloadNeeded = true
			UpdateReloadHint()
			if ns.ApplyTestDebuffs then ns.ApplyTestDebuffs() end
			if RefreshAurasUI then RefreshAurasUI() end
		end)
		auraSizePlus:SetPoint("TOPRIGHT", -14, -110)

		local auraSizeVal = card2:CreateFontString(nil, "OVERLAY")
		auraSizeVal:SetFont(FONT, SMALL_FONT_SIZE, "OUTLINE")
		auraSizeVal:SetWidth(86)
		auraSizeVal:SetPoint("RIGHT", auraSizePlus, "LEFT", -6, 0)
		auraSizeVal:SetJustifyH("CENTER")
		auraSizeVal:SetTextColor(1, 0.84, 0.45)

		local auraSizeMinus = CreateActionButton(card2, "-", 26, 20, function()
			ns.GetOptionsDB().auraSizeOffset = math.max(-6, ns.GetAuraSizeOffset() - 1)
			reloadNeeded = true
			UpdateReloadHint()
			if ns.ApplyTestDebuffs then ns.ApplyTestDebuffs() end
			if RefreshAurasUI then RefreshAurasUI() end
		end)
		auraSizeMinus:SetPoint("RIGHT", auraSizeVal, "LEFT", -6, 0)

		RefreshAurasUI = function()
			local off = ns.GetAuraSizeOffset()
			if off == 0 then
				auraSizeVal:SetText("Default (0)")
			elseif off > 0 then
				auraSizeVal:SetText("+" .. off .. " px")
			else
				auraSizeVal:SetText(off .. " px")
			end
		end
	end

	-- Page 4: Party & Raid
	local RefreshGroupUI
	do
		local p = pages.group
		local card1 = CreateCard(p, "Group & Raid Layout", 268, 6)
		local groupToggles = {
			{ key = "showRaidFrames", label = "Enable Raid Frames (8-Group Compact Grid)", tip = "Replace Blizzard raid frames with the compact 8-group oUF_Brun grid." },
			{ key = "hidePartyInRaid", label = "Hide Party Frames when in a Raid", tip = "Hide the 4-member party stack automatically while in a raid group." },
			{ key = "hideCompactRaidManager", label = "Auto-fade Blizzard Raid Manager Tab", tip = "Fade Blizzard's collapsed raid manager side tab until mouseover." },
		}
		for i, def in ipairs(groupToggles) do
			CreateToggleRow(card1, def, i)
		end

		local petRow = CreateToggleRow(card1, {
			key = "showPartyPets",
			label = "Show Party Pets",
			tip = "Display pet health bars for party members who have an active pet.",
		}, 4)
		petRow:ClearAllPoints()
		petRow:SetPoint("TOPLEFT", 8, -104)
		petRow:SetPoint("TOPRIGHT", -200, -104)
		petRow:HookScript("OnClick", function()
			if RefreshGroupUI then RefreshGroupUI() end
		end)

		local petPosLive = card1:CreateFontString(nil, "OVERLAY")
		petPosLive:SetFont(FONT, SMALL_FONT_SIZE - 2, "OUTLINE")
		petPosLive:SetPoint("TOPRIGHT", -14, -110)
		petPosLive:SetTextColor(0.35, 0.78, 0.45)
		petPosLive:SetText("LIVE")

		local function MakePetPosBtn(id, label, w, tip)
			local b = CreateActionButton(card1, label, w, 20, function()
				ns.GetOptionsDB().partyPetPosition = id
				if ns.ApplyPartyPetPosition then ns.ApplyPartyPetPosition() end
				if ns.ApplyPartyDebuffPosition then ns.ApplyPartyDebuffPosition() end
				if RefreshGroupUI then RefreshGroupUI() end
			end)
			b:HookScript("OnEnter", function(self)
				GameTooltip:SetOwner(self, "ANCHOR_TOP")
				GameTooltip:AddLine("Party Pets: " .. label, 1, 0.82, 0)
				GameTooltip:AddLine(tip, 0.85, 0.85, 0.9, true)
				GameTooltip:AddLine("Applies immediately out of combat.", 0.35, 0.85, 0.45)
				GameTooltip:Show()
			end)
			b:HookScript("OnLeave", function() GameTooltip:Hide() end)
			return b
		end

		local petLeftBtn = MakePetPosBtn("left", "Left", 44, "Anchor party pet frames centered on the left side of each party frame.")
		petLeftBtn:SetPoint("RIGHT", petPosLive, "LEFT", -8, 0)

		local petRightBtn = MakePetPosBtn("right", "Right", 48, "Anchor party pet frames on the right side of each party frame.")
		petRightBtn:SetPoint("RIGHT", petLeftBtn, "LEFT", -4, 0)

		local petBelowBtn = MakePetPosBtn("below", "Below", 50, "Anchor party pet frames underneath each party frame.")
		petBelowBtn:SetPoint("RIGHT", petRightBtn, "LEFT", -4, 0)

		local posDiv = card1:CreateTexture(nil, "BORDER")
		posDiv:SetPoint("TOPLEFT", 12, -129)
		posDiv:SetPoint("TOPRIGHT", -12, -129)
		posDiv:SetHeight(1)
		posDiv:SetColorTexture(1, 1, 1, 0.06)

		local posLbl = card1:CreateFontString(nil, "OVERLAY")
		posLbl:SetFont(FONT, SMALL_FONT_SIZE, "OUTLINE")
		posLbl:SetPoint("TOPLEFT", 14, -137)
		posLbl:SetTextColor(0.92, 0.92, 0.95)
		posLbl:SetText("Party Debuffs Position")

		local posLive = card1:CreateFontString(nil, "OVERLAY")
		posLive:SetFont(FONT, SMALL_FONT_SIZE - 2, "OUTLINE")
		posLive:SetPoint("TOPRIGHT", -14, -138)
		posLive:SetTextColor(0.35, 0.78, 0.45)
		posLive:SetText("LIVE")

		local function MakePosBtn(id, label, tip)
			local b = CreateActionButton(card1, label, 64, 20, function()
				ns.GetOptionsDB().partyDebuffPosition = id
				if ns.ApplyPartyDebuffPosition then ns.ApplyPartyDebuffPosition() end
				if ns.ApplyPartyPetPosition then ns.ApplyPartyPetPosition() end
				if RefreshGroupUI then RefreshGroupUI() end
			end)
			b:HookScript("OnEnter", function(self)
				GameTooltip:SetOwner(self, "ANCHOR_TOP")
				GameTooltip:AddLine("Party Debuffs: " .. label, 1, 0.82, 0)
				GameTooltip:AddLine(tip, 0.85, 0.85, 0.9, true)
				GameTooltip:AddLine("Applies immediately out of combat.", 0.35, 0.85, 0.45)
				GameTooltip:Show()
			end)
			b:HookScript("OnLeave", function() GameTooltip:Hide() end)
			return b
		end

		local posBelowBtn = MakePosBtn("below", "Below", "Anchor party debuffs underneath each party frame.")
		posBelowBtn:SetPoint("RIGHT", posLive, "LEFT", -10, 0)

		local posRightBtn = MakePosBtn("right", "Right", "Anchor party debuffs vertically centered on the right of each party frame for tighter vertical spacing.")
		posRightBtn:SetPoint("RIGHT", posBelowBtn, "LEFT", -6, 0)

		local spacingSlider = CreateFlatSlider(card1, {
			label = "Party Frame Spacing",
			yOffset = 158,
			minVal = 0,
			maxVal = 120,
			step = 1,
			minText = "0 px",
			maxText = "120 px",
			formatVal = function(v) return v .. " px" end,
			tip = "Vertical gap in pixels between party frames (0-120 px). Applies live out of combat (works with Test Frames).",
			onChanged = function(v)
				ns.GetOptionsDB().partySpacing = v
				if ns.ApplyPartySpacing then
					ns.ApplyPartySpacing()
				end
			end,
		})

		local rangeSlider = CreateFlatSlider(card1, {
			label = "Out-of-Range Opacity (Party & Raid)",
			yOffset = 214,
			minVal = 20,
			maxVal = 90,
			step = 5,
			minText = "20%",
			maxText = "90%",
			formatVal = function(v) return string.format("%d%%", v) end,
			tip = "Opacity of Party and Raid frames when a unit is out of range.",
			onChanged = function(v)
				ns.GetOptionsDB().rangeAlpha = v / 100
				if ns.ApplyRangeAlpha then
					ns.ApplyRangeAlpha()
				end
			end,
		})

		local card2 = CreateCard(p, "Healing & Click-Casting", 68, 280)
		local clickCastStatusText = card2:CreateFontString(nil, "OVERLAY")
		clickCastStatusText:SetFont(FONT, SMALL_FONT_SIZE, "OUTLINE")
		clickCastStatusText:SetPoint("TOPLEFT", 14, -33)
		clickCastStatusText:SetPoint("RIGHT", -186, 0)
		clickCastStatusText:SetJustifyH("LEFT")

		local openClickCastBtn = CreateActionButton(card2, "Configure Click-Cast...", 164, 22, function()
			SelectTab("clickcast")
		end)
		openClickCastBtn:SetPoint("TOPRIGHT", -12, -29)

		local bindNote = card2:CreateFontString(nil, "OVERLAY")
		bindNote:SetFont(FONT, SMALL_FONT_SIZE - 1, "OUTLINE")
		bindNote:SetPoint("TOPLEFT", 14, -52)
		bindNote:SetPoint("TOPRIGHT", -14, -52)
		bindNote:SetJustifyH("LEFT")
		bindNote:SetTextColor(0.62, 0.62, 0.68)
		bindNote:SetText("Configure buttons, modifiers, spells & Blizzard unit menu in Click-Cast.")

		RefreshGroupUI = function()
			local opts = ns.GetOptionsDB()
			local petEnabled = opts.showPartyPets ~= false
			local petPos = ns.GetPartyPetPosition()
			petBelowBtn:SetActive(petPos == "below")
			petRightBtn:SetActive(petPos == "right")
			petLeftBtn:SetActive(petPos == "left")
			petBelowBtn:SetEnabled(petEnabled)
			petRightBtn:SetEnabled(petEnabled)
			petLeftBtn:SetEnabled(petEnabled)
			petBelowBtn:SetAlpha(petEnabled and 1 or 0.45)
			petRightBtn:SetAlpha(petEnabled and 1 or 0.45)
			petLeftBtn:SetAlpha(petEnabled and 1 or 0.45)

			local pos = ns.GetPartyDebuffPosition()
			posRightBtn:SetActive(pos == "right")
			posBelowBtn:SetActive(pos == "below")
			spacingSlider:SetValueSilent(ns.GetPartySpacing())
			rangeSlider:SetValueSilent(math.floor(ns.GetRangeAlpha() * 100 + 0.5))

			local ccEnabled = opts.enableClickCast == true
			local summary = ns.GetClickCastSummary and ns.GetClickCastSummary() or nil
			if ccEnabled then
				local cnt = summary and summary.enabledCount or 0
				local menuStr = summary and summary.menuCombo or "Right (Default)"
				clickCastStatusText:SetTextColor(0.35, 0.85, 0.45)
				clickCastStatusText:SetText(string.format("Enabled (%d active)  |  Menu: %s", cnt, menuStr))
			else
				clickCastStatusText:SetTextColor(0.68, 0.68, 0.74)
				clickCastStatusText:SetText("Click-Casting: Disabled (Blizzard defaults)")
			end
		end
	end

	-- Page 5: Click-Cast
	local RefreshClickCastUI
	do
		local p = pages.clickcast
		local card1 = CreateCard(p, "Click-Casting (Party & Raid)", 66, 10)
		local ccEnableRow = CreateToggleRow(card1, {
			key = "enableClickCast",
			label = "Enable Click-Casting on Party & Raid Frames",
			tip = "Bind spells, Blizzard Unit Menu, Target, Focus, or Assist to mouse clicks on Party & Raid frames. Applies live out of combat.",
		}, 1)
		ccEnableRow:HookScript("OnClick", function()
			if RefreshClickCastUI then RefreshClickCastUI() end
			if RefreshGroupUI then RefreshGroupUI() end
		end)

		local card2 = CreateCard(p, "Class Click Bindings", 258, 84)
		local ccOffset = 0
		local CC_VISIBLE_ROWS = 7

		local MOD_CHOICES = {
			{ value = "", label = "None" },
			{ value = "shift-", label = "Shift" },
			{ value = "ctrl-", label = "Ctrl" },
			{ value = "alt-", label = "Alt" },
		}
		local MOD_TEXT = {
			[""] = "None",
			["shift-"] = "Shift",
			["ctrl-"] = "Ctrl",
			["alt-"] = "Alt",
		}
		local BTN_CHOICES = {
			{ value = "1", label = "Left" },
			{ value = "2", label = "Right" },
			{ value = "3", label = "Middle" },
			{ value = "4", label = "Btn 4" },
			{ value = "5", label = "Btn 5" },
		}
		local BTN_TEXT = {
			["1"] = "Left",
			["2"] = "Right",
			["3"] = "Middle",
			["4"] = "Btn 4",
			["5"] = "Btn 5",
		}
		local ACTION_LABELS = {
			menu = "Unit Menu (Blizzard)",
			target = "Target Unit",
			focus = "Focus Unit",
			assist = "Assist Unit",
		}

		local function ApplyBindingChanges()
			if ns.UpdateClickCastFrames then
				ns.UpdateClickCastFrames()
			end
			if RefreshClickCastUI then RefreshClickCastUI() end
			if RefreshGroupUI then RefreshGroupUI() end
		end

		local addBtn = CreateActionButton(card2, "+ Add", 56, 18, function()
			if not ns.GetClickCastBindings then return end
			local bindings = ns.GetClickCastBindings()
			local used = {}
			for _, b in ipairs(bindings) do
				used[(b.mod or "") .. (b.button or "1")] = true
			end
			local nextMod, nextBtn = "shift-", "1"
			local found = false
			for _, m in ipairs({ "", "shift-", "ctrl-", "alt-" }) do
				for _, bt in ipairs({ "1", "2", "3", "4", "5" }) do
					if not used[m .. bt] then
						nextMod, nextBtn = m, bt
						found = true
						break
					end
				end
				if found then break end
			end
			table.insert(bindings, {
				enabled = true,
				mod = nextMod,
				button = nextBtn,
				action = "spell",
				spell = "",
			})
			ccOffset = math.max(0, #bindings - CC_VISIBLE_ROWS)
			ApplyBindingChanges()
		end)
		addBtn:SetPoint("TOPRIGHT", -100, -5)
		addBtn.label:SetFont(FONT, SMALL_FONT_SIZE - 2, "OUTLINE")
		addBtn:HookScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:AddLine("Add Click Binding", 1, 0.82, 0)
			GameTooltip:AddLine("Append a new modifier + mouse button slot for your current class.", 0.85, 0.85, 0.9, true)
			GameTooltip:Show()
		end)
		addBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)

		local resetClassBtn = CreateActionButton(card2, "Reset Class", 84, 18, function()
			if ns.ResetClassClickCastBindings then
				ns.ResetClassClickCastBindings()
			end
			ccOffset = 0
			if RefreshClickCastUI then RefreshClickCastUI() end
			if RefreshGroupUI then RefreshGroupUI() end
		end)
		resetClassBtn:SetPoint("TOPRIGHT", -10, -5)
		resetClassBtn.label:SetFont(FONT, SMALL_FONT_SIZE - 2, "OUTLINE")
		resetClassBtn:HookScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:AddLine("Reset Class Bindings", 1, 0.82, 0)
			GameTooltip:AddLine("Restore recommended click-cast defaults (keeps Right-Click as Blizzard Unit Menu).", 0.85, 0.85, 0.9, true)
			GameTooltip:Show()
		end)
		resetClassBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)

		local function AddColHeader(text, xOff)
			local h = card2:CreateFontString(nil, "OVERLAY")
			h:SetFont(FONT, SMALL_FONT_SIZE - 2, "OUTLINE")
			h:SetPoint("TOPLEFT", xOff, -31)
			h:SetTextColor(0.58, 0.58, 0.65)
			h:SetText(text)
		end
		AddColHeader("On", 12)
		AddColHeader("Modifier", 34)
		AddColHeader("Button", 102)
		AddColHeader("Action / Spell", 172)

		local ccScrollTrack = card2:CreateTexture(nil, "BORDER")
		ccScrollTrack:SetPoint("TOPRIGHT", -6, -46)
		ccScrollTrack:SetHeight(CC_VISIBLE_ROWS * 26 - 3)
		ccScrollTrack:SetWidth(3)
		ccScrollTrack:SetColorTexture(1, 1, 1, 0.08)

		local ccScrollThumb = card2:CreateTexture(nil, "ARTWORK")
		ccScrollThumb:SetWidth(3)
		ccScrollThumb:SetColorTexture(1, 0.55, 0.1, 0.85)

		local function CreatePickerButton(parent, btnW, onClick)
			local b = CreateFrame("Button", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
			b:SetSize(btnW, 20)
			StyleFlatBox(b, 0.11, 0.11, 0.14, 1, 0.28, 0.28, 0.34, 1)

			local t = b:CreateFontString(nil, "OVERLAY")
			t:SetFont(FONT, SMALL_FONT_SIZE - 1, "OUTLINE")
			t:SetPoint("LEFT", 6, 0)
			t:SetPoint("RIGHT", -16, 0)
			t:SetJustifyH("LEFT")
			t:SetWordWrap(false)
			t:SetTextColor(0.92, 0.92, 0.95)
			b.text = t

			local ar = b:CreateFontString(nil, "OVERLAY")
			ar:SetFont(FONT, SMALL_FONT_SIZE - 2, "OUTLINE")
			ar:SetPoint("RIGHT", -5, 0)
			ar:SetTextColor(0.7, 0.7, 0.76)
			ar:SetText("v")

			b:SetScript("OnEnter", function(self)
				self:SetBackdropBorderColor(1, 0.56, 0.12, 1)
			end)
			b:SetScript("OnLeave", function(self)
				self:SetBackdropBorderColor(0.28, 0.28, 0.34, 1)
			end)
			b:SetScript("OnClick", onClick)
			return b
		end

		local ccRows = {}
		card2:EnableMouseWheel(true)
		card2:SetScript("OnMouseWheel", function(_, delta)
			ccOffset = ccOffset - (delta > 0 and 1 or -1)
			if RefreshClickCastUI then RefreshClickCastUI() end
		end)

		local function BuildSpellMenuItems()
			local items = {
				{ value = "__ACT__:menu", label = "Unit Menu (Blizzard)", r = 1, g = 0.84, b = 0.45 },
				{ value = "__ACT__:target", label = "Target Unit", r = 1, g = 0.84, b = 0.45 },
				{ value = "__ACT__:focus", label = "Focus Unit", r = 1, g = 0.84, b = 0.45 },
				{ value = "__ACT__:assist", label = "Assist Unit", r = 1, g = 0.84, b = 0.45 },
				{ value = "__CUSTOM__", label = "Type Custom Spell...", r = 0.45, g = 0.82, b = 1 },
			}
			local spells = ns.GetPlayerSpellbookSpells and ns.GetPlayerSpellbookSpells() or {}
			for _, spellName in ipairs(spells) do
				table.insert(items, { value = spellName, label = spellName })
			end
			return items
		end

		for i = 1, CC_VISIBLE_ROWS do
			local row = CreateFrame("Frame", nil, card2, BackdropTemplateMixin and "BackdropTemplate" or nil)
			row:SetPoint("TOPLEFT", 8, -(46 + (i - 1) * 26))
			row:SetPoint("TOPRIGHT", -14, -(46 + (i - 1) * 26))
			row:SetHeight(23)
			StyleFlatBox(row, 0.07, 0.07, 0.095, 0.9, 1, 1, 1, 0.05)

			local cb = CreateFrame("Button", nil, row)
			cb:SetSize(20, 20)
			cb:SetPoint("LEFT", 3, 0)
			local cbBox = CreateCheckVisual(cb)
			cbBox:SetPoint("CENTER", 0, 0)
			row.cbBox = cbBox
			cb:SetScript("OnClick", function()
				local bindings = ns.GetClickCastBindings and ns.GetClickCastBindings()
				local entry = bindings and bindings[row._idx]
				if not entry then return end
				entry.enabled = (entry.enabled == false) and true or false
				ApplyBindingChanges()
			end)
			cb:SetScript("OnEnter", function(self)
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				GameTooltip:AddLine("Enable / Disable Binding", 1, 0.82, 0)
				GameTooltip:AddLine("Uncheck to temporarily turn off this button/spell without deleting it.", 0.85, 0.85, 0.9, true)
				GameTooltip:Show()
			end)
			cb:SetScript("OnLeave", function() GameTooltip:Hide() end)

			local modBtn = CreatePickerButton(row, 62, function(self)
				local bindings = ns.GetClickCastBindings and ns.GetClickCastBindings()
				local entry = bindings and bindings[row._idx]
				if not entry then return end
				OpenChoiceDropdown(self, MOD_CHOICES, entry.mod or "", 96, function(chosen)
					entry.mod = chosen
					ApplyBindingChanges()
				end)
			end)
			modBtn:SetPoint("LEFT", 26, 0)
			row.modBtn = modBtn

			local btnBtn = CreatePickerButton(row, 64, function(self)
				local bindings = ns.GetClickCastBindings and ns.GetClickCastBindings()
				local entry = bindings and bindings[row._idx]
				if not entry then return end
				OpenChoiceDropdown(self, BTN_CHOICES, entry.button or "1", 100, function(chosen)
					entry.button = chosen
					ApplyBindingChanges()
				end)
			end)
			btnBtn:SetPoint("LEFT", 94, 0)
			row.btnBtn = btnBtn

			local actBtn = CreatePickerButton(row, 196, function(self)
				local bindings = ns.GetClickCastBindings and ns.GetClickCastBindings()
				local entry = bindings and bindings[row._idx]
				if not entry then return end
				local curVal
				if (entry.action or "spell") == "spell" then
					curVal = entry.spell or ""
				else
					curVal = "__ACT__:" .. entry.action
				end
				OpenChoiceDropdown(self, BuildSpellMenuItems(), curVal, 218, function(chosen)
					if chosen == "__CUSTOM__" then
						OpenCustomSpellPopup(entry.action == "spell" and entry.spell or "", function(typedSpell)
							if typedSpell and typedSpell ~= "" then
								entry.action = "spell"
								entry.spell = typedSpell
								ApplyBindingChanges()
							end
						end)
					elseif chosen:sub(1, 8) == "__ACT__:" then
						entry.action = chosen:sub(9)
						entry.spell = ""
						ApplyBindingChanges()
					else
						entry.action = "spell"
						entry.spell = chosen
						ApplyBindingChanges()
					end
				end)
			end)
			actBtn:SetPoint("LEFT", 164, 0)
			row.actBtn = actBtn

			local delBtn = CreateActionButton(row, "x", 20, 20, function()
				local bindings = ns.GetClickCastBindings and ns.GetClickCastBindings()
				if not bindings or not row._idx then return end
				table.remove(bindings, row._idx)
				ApplyBindingChanges()
			end)
			delBtn:SetPoint("RIGHT", -3, 0)
			delBtn.label:SetFont(FONT, SMALL_FONT_SIZE - 2, "OUTLINE")
			delBtn:HookScript("OnEnter", function(self)
				GameTooltip:SetOwner(self, "ANCHOR_TOP")
				GameTooltip:AddLine("Remove Binding", 1, 0.82, 0)
				GameTooltip:AddLine("Delete this click-cast slot.", 0.85, 0.85, 0.9, true)
				GameTooltip:Show()
			end)
			delBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)

			ccRows[i] = row
		end

		local summaryLine = card2:CreateTexture(nil, "BORDER")
		summaryLine:SetPoint("BOTTOMLEFT", 12, 26)
		summaryLine:SetPoint("BOTTOMRIGHT", -12, 26)
		summaryLine:SetHeight(1)
		summaryLine:SetColorTexture(1, 1, 1, 0.06)

		local summaryText = card2:CreateFontString(nil, "OVERLAY")
		summaryText:SetFont(FONT, SMALL_FONT_SIZE - 1, "OUTLINE")
		summaryText:SetPoint("BOTTOMLEFT", 12, 9)
		summaryText:SetPoint("BOTTOMRIGHT", -12, 9)
		summaryText:SetJustifyH("LEFT")
		summaryText:SetWordWrap(false)

		RefreshClickCastUI = function()
			local ccEnabled = (ns.GetOptionsDB().enableClickCast == true)
			local bindings = ns.GetClickCastBindings and ns.GetClickCastBindings() or {}
			local total = #bindings
			local maxOff = math.max(0, total - CC_VISIBLE_ROWS)
			ccOffset = math.max(0, math.min(ccOffset, maxOff))

			local showScroll = (total > CC_VISIBLE_ROWS)
			ccScrollTrack:SetShown(showScroll)
			ccScrollThumb:SetShown(showScroll)
			if showScroll then
				local trackH = CC_VISIBLE_ROWS * 26 - 3
				local thumbH = math.max(22, math.floor(trackH * (CC_VISIBLE_ROWS / total)))
				local travel = trackH - thumbH
				local ratio = (maxOff > 0) and (ccOffset / maxOff) or 0
				ccScrollThumb:ClearAllPoints()
				ccScrollThumb:SetHeight(thumbH)
				ccScrollThumb:SetPoint("TOPRIGHT", card2, "TOPRIGHT", -6, -(46 + ratio * travel))
			end

			for i = 1, CC_VISIBLE_ROWS do
				local row = ccRows[i]
				local idx = ccOffset + i
				local entry = bindings[idx]
				if entry then
					row._idx = idx
					local slotOn = (entry.enabled ~= false)
					row.cbBox:SetCheckedVisual(slotOn, ccEnabled)

					row.modBtn.text:SetText(MOD_TEXT[entry.mod or ""] or "None")
					row.btnBtn.text:SetText(BTN_TEXT[entry.button or "1"] or "Left")

					local act = entry.action or "spell"
					if act == "spell" then
						local sp = type(entry.spell) == "string" and entry.spell ~= "" and entry.spell or nil
						if sp then
							row.actBtn.text:SetText(sp)
							row.actBtn.text:SetTextColor(0.92, 0.92, 0.95)
						else
							row.actBtn.text:SetText("Select spell...")
							row.actBtn.text:SetTextColor(0.55, 0.55, 0.62)
						end
					else
						row.actBtn.text:SetText(ACTION_LABELS[act] or act)
						row.actBtn.text:SetTextColor(1, 0.84, 0.45)
					end

					local rowAlpha = (not ccEnabled) and 0.42 or (slotOn and 1 or 0.45)
					row:SetAlpha(1)
					row.cbBox:SetAlpha(ccEnabled and 1 or 0.45)
					row.modBtn:SetAlpha(rowAlpha)
					row.btnBtn:SetAlpha(rowAlpha)
					row.actBtn:SetAlpha(rowAlpha)
					row:Show()
				else
					row._idx = nil
					row:Hide()
				end
			end

			if ccEnabled then
				local summary = ns.GetClickCastSummary and ns.GetClickCastSummary() or nil
				local menuStr = summary and summary.menuCombo or "Right (Default)"
				local tgtStr = summary and summary.targetCombo or "Left (Default)"
				if summary and summary.menuAutoFallback then
					summaryText:SetTextColor(1, 0.80, 0.35)
					summaryText:SetText(string.format("Blizzard Menu: %s  |  Target: %s", menuStr, tgtStr))
				else
					summaryText:SetTextColor(0.58, 0.80, 0.62)
					summaryText:SetText(string.format("Blizzard Menu: %s  |  Target: %s", menuStr, tgtStr))
				end
			else
				summaryText:SetTextColor(0.62, 0.62, 0.68)
				summaryText:SetText("Click-Casting disabled — default Blizzard Left/Right clicks are active.")
			end
		end
	end

	-- Page 6: Colors
	local RefreshColorUI
	do
		local p = pages.colors
		local card1 = CreateCard(p, "Health Bar Color Mode", 104, 10)

		local liveBadge = card1:CreateFontString(nil, "OVERLAY")
		liveBadge:SetFont(FONT, SMALL_FONT_SIZE - 2, "OUTLINE")
		liveBadge:SetPoint("TOPRIGHT", -12, -11)
		liveBadge:SetTextColor(0.35, 0.78, 0.45)
		liveBadge:SetText("LIVE")

		local modeButtons = {}
		local modeDefs = {
			{ id = "class", label = "Class Colors", tip = "Color player & friendly unit health bars using standard WoW class colors." },
			{ id = "blizzard", label = "Blizzard Green", tip = "Use classic Blizzard green on friendly/player health bars (no orange Druid vs aggro red clash)." },
			{ id = "custom", label = "Custom Class", tip = "Use your customized class colors from the grid below." },
		}

		local modeDesc = card1:CreateFontString(nil, "OVERLAY")
		modeDesc:SetFont(FONT, SMALL_FONT_SIZE - 1, "OUTLINE")
		modeDesc:SetPoint("TOPLEFT", 14, -63)
		modeDesc:SetPoint("TOPRIGHT", -12, -63)
		modeDesc:SetJustifyH("LEFT")
		modeDesc:SetTextColor(0.66, 0.66, 0.72)

		local MODE_DESC_TEXT = {
			class = "Standard WoW class colors on players; reaction colors on NPCs.",
			blizzard = "Classic Blizzard green on health bars instead of class colors.",
			custom = "Custom per-class colors from the palette below.",
		}

		for idx, def in ipairs(modeDefs) do
			local btn = CreateActionButton(card1, def.label, 122, 26, function()
				ns.GetOptionsDB().healthColorMode = def.id
				ns.ApplySavedOptions()
				RefreshColorUI()
			end)
			if idx == 1 then
				btn:SetPoint("TOPLEFT", 12, -33)
			else
				btn:SetPoint("LEFT", modeButtons[idx - 1], "RIGHT", 10, 0)
			end
			btn:HookScript("OnEnter", function(self)
				GameTooltip:SetOwner(self, "ANCHOR_TOP")
				GameTooltip:AddLine(def.label, 1, 0.82, 0)
				GameTooltip:AddLine(def.tip, 0.85, 0.85, 0.9, true)
				GameTooltip:AddLine("Applies immediately without reloading.", 0.35, 0.85, 0.45)
				GameTooltip:Show()
			end)
			btn:HookScript("OnLeave", function()
				GameTooltip:Hide()
			end)
			btn.modeId = def.id
			modeButtons[idx] = btn
		end

		local playerOnlyRow = CreateToggleRow(card1, {
			key = "healthColorPlayerOnly",
			label = "Keep Class Colors on Other Units (Player Only)",
			tip = "When enabled, Blizzard Green or Custom Class color applies only to your Player frame; Target, Party & Raid keep default class colors.",
		}, 3)
		playerOnlyRow:HookScript("OnClick", function()
			if RefreshColorUI then RefreshColorUI() end
		end)

		local card2 = CreateCard(p, "Custom Class Colors", 222, 122)
		local resetColorsBtn = CreateActionButton(card2, "Reset Colors", 86, 18, function()
			table.wipe(ns.GetClassColorsDB())
			ns.ApplySavedOptions()
			RefreshColorUI()
		end)
		resetColorsBtn:SetPoint("TOPRIGHT", -10, -5)
		resetColorsBtn.label:SetFont(FONT, SMALL_FONT_SIZE - 2, "OUTLINE")
		resetColorsBtn:HookScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:AddLine("Reset Custom Class Colors", 1, 0.82, 0)
			GameTooltip:AddLine("Restore all classes back to default WoW class colors.", 0.85, 0.85, 0.9, true)
			GameTooltip:Show()
		end)
		resetColorsBtn:HookScript("OnLeave", function()
			GameTooltip:Hide()
		end)

		local baseOrder = CLASS_SORT_ORDER or {
			"WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT",
			"SHAMAN", "MAGE", "WARLOCK", "MONK", "DRUID", "DEMONHUNTER", "EVOKER",
		}
		local classTokens = {}
		local seenTokens = {}
		local colorTable = oUF.colors and oUF.colors.class or {}
		for _, token in ipairs(baseOrder) do
			if colorTable[token] then
				table.insert(classTokens, token)
				seenTokens[token] = true
			end
		end
		for token in pairs(colorTable) do
			if type(token) == "string" and not seenTokens[token] then
				table.insert(classTokens, token)
			end
		end

		local classRows = {}
		for idx, token in ipairs(classTokens) do
			local col = (idx - 1) % 2
			local row = math.floor((idx - 1) / 2)
			local x = (col == 0) and 12 or 210
			local y = 33 + row * 25

			local item = CreateFrame("Button", nil, card2)
			item:SetSize(188, 22)
			item:SetPoint("TOPLEFT", x, -y)

			local hoverBg = item:CreateTexture(nil, "BACKGROUND")
			hoverBg:SetAllPoints()
			hoverBg:SetColorTexture(1, 1, 1, 0.05)
			hoverBg:Hide()

			local swatchFrame = CreateFrame("Frame", nil, item, BackdropTemplateMixin and "BackdropTemplate" or nil)
			swatchFrame:SetSize(16, 16)
			swatchFrame:SetPoint("LEFT", 4, 0)
			StyleFlatBox(swatchFrame, 0.05, 0.05, 0.07, 1, 0.34, 0.34, 0.40, 1)

			local swatchTex = swatchFrame:CreateTexture(nil, "ARTWORK")
			swatchTex:SetPoint("TOPLEFT", 2, -2)
			swatchTex:SetPoint("BOTTOMRIGHT", -2, 2)
			swatchTex:SetTexture(TEXTURE)

			local classLabel = item:CreateFontString(nil, "OVERLAY")
			classLabel:SetFont(FONT, SMALL_FONT_SIZE, "OUTLINE")
			classLabel:SetPoint("LEFT", swatchFrame, "RIGHT", 8, 0)
			classLabel:SetText(LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[token] or token)
			classLabel:SetTextColor(0.92, 0.92, 0.95)

			item:SetScript("OnEnter", function(self)
				hoverBg:Show()
				local mode = ns.GetOptionsDB().healthColorMode or "class"
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				GameTooltip:AddLine(classLabel:GetText(), 1, 0.82, 0)
				if mode ~= "custom" then
					GameTooltip:AddLine("Click to pick a custom color (switches mode to Custom Class).", 0.85, 0.85, 0.9, true)
				else
					GameTooltip:AddLine("Click to change this class color.", 0.85, 0.85, 0.9, true)
				end
				GameTooltip:Show()
			end)
			item:SetScript("OnLeave", function()
				hoverBg:Hide()
				GameTooltip:Hide()
			end)
			item:SetScript("OnClick", function()
				local opts = ns.GetOptionsDB()
				local classDB = ns.GetClassColorsDB()
				local prevMode = opts.healthColorMode or "class"
				local prevEntry = classDB[token]
				local prevColor = prevEntry and { prevEntry.r or prevEntry[1], prevEntry.g or prevEntry[2], prevEntry.b or prevEntry[3] } or nil
				local startR, startG, startB
				if prevColor and prevColor[1] and prevColor[2] and prevColor[3] then
					startR, startG, startB = prevColor[1], prevColor[2], prevColor[3]
				elseif ns.GetDefaultClassColor then
					startR, startG, startB = ns.GetDefaultClassColor(token)
				else
					startR, startG, startB = 0.5, 0.5, 0.5
				end

				OpenColorPicker(startR, startG, startB, function(nr, ng, nb)
					opts.healthColorMode = "custom"
					classDB[token] = { r = nr, g = ng, b = nb }
					ns.ApplySavedOptions()
					RefreshColorUI()
				end, function()
					opts.healthColorMode = prevMode
					if prevColor then
						classDB[token] = { r = prevColor[1], g = prevColor[2], b = prevColor[3] }
					else
						classDB[token] = nil
					end
					ns.ApplySavedOptions()
					RefreshColorUI()
				end)
			end)

			classRows[idx] = {
				token = token,
				swatchFrame = swatchFrame,
				swatchTex = swatchTex,
				label = classLabel,
			}
		end

		RefreshColorUI = function()
			local opts = ns.GetOptionsDB()
			local mode = (opts.healthColorMode == "blizzard" or opts.healthColorMode == "custom") and opts.healthColorMode or "class"
			for _, btn in ipairs(modeButtons) do
				btn:SetActive(btn.modeId == mode)
			end
			local desc = MODE_DESC_TEXT[mode] or MODE_DESC_TEXT.class
			if opts.healthColorPlayerOnly and mode ~= "class" then
				desc = desc .. " (Player Only)"
			end
			modeDesc:SetText(desc)

			local classDB = ns.GetClassColorsDB()
			local isCustom = (mode == "custom")
			for _, row in ipairs(classRows) do
				local c = classDB[row.token]
				local r, g, b
				if isCustom and type(c) == "table" and (c.r or c[1]) then
					r, g, b = c.r or c[1], c.g or c[2], c.b or c[3]
				elseif ns.GetDefaultClassColor then
					r, g, b = ns.GetDefaultClassColor(row.token)
				else
					r, g, b = 0.5, 0.5, 0.5
				end
				row.swatchTex:SetVertexColor(r, g, b, 1)
				row.swatchFrame:SetAlpha(isCustom and 1 or 0.65)
				row.label:SetAlpha(isCustom and 1 or 0.65)
			end
		end
	end

	-- Page 6: Aggro & Threat
	local RefreshThreatUI
	do
		local p = pages.threat
		local card1 = CreateCard(p, "Unit Frame Aggro Indicator", 132, 12)
		local threatToggleRow = CreateToggleRow(card1, {
			key = "enableThreatHighlight",
			label = "Enable Aggro / Threat Indicator",
			tip = "Highlight unit frames (Player, Target, Party, Raid) when a unit holds aggro or high threat.",
		}, 1)

		local styleButtons = {}
		local styleDefs = {
			{ id = "backdrop", label = "Border", width = 66, tip = "Color the frame's 2px outer border by threat level (no bar bleed)." },
			{ id = "glow", label = "Outer Glow", width = 86, tip = "Soft feathered outer glow radiating around the frame (no bar bleed)." },
			{ id = "tint", label = "Tint", width = 54, tip = "Classic red/orange/yellow backdrop tint glowing behind Health & Power bars." },
			{ id = "badge", label = "Badge", width = 62, tip = "Display an AGGRO / HIGH / THREAT pill above standard frames (or [!] on compact frames)." },
			{ id = "both", label = "Glow + Badge", width = 95, tip = "Soft feathered outer glow radiating around the frame + AGGRO / [!] badge." },
		}

		local styleDesc = card1:CreateFontString(nil, "OVERLAY")
		styleDesc:SetFont(FONT, SMALL_FONT_SIZE - 1, "OUTLINE")
		styleDesc:SetPoint("TOPLEFT", 14, -96)
		styleDesc:SetPoint("TOPRIGHT", -12, -96)
		styleDesc:SetJustifyH("LEFT")
		styleDesc:SetTextColor(0.66, 0.66, 0.72)

		local STYLE_DESC_TEXT = {
			backdrop = "Style: Hollow 2px outer frame border (yellow / orange / red).",
			glow = "Style: Soft feathered outer glow radiating around the frame.",
			tint = "Style: Classic backdrop tint glowing through Health & Power bars.",
			badge = "Style: Non-overlapping AGGRO pill above the frame (no border glow).",
			both = "Style: Soft feathered outer glow + above-frame AGGRO pill.",
		}

		for idx, def in ipairs(styleDefs) do
			local btn = CreateActionButton(card1, def.label, def.width, 24, function()
				if not ns.GetOptionsDB().enableThreatHighlight then return end
				ns.GetOptionsDB().threatStyle = def.id
				ns.ApplySavedOptions()
				RefreshThreatUI()
			end)
			if idx == 1 then
				btn:SetPoint("TOPLEFT", 12, -62)
			else
				btn:SetPoint("LEFT", styleButtons[idx - 1], "RIGHT", 6, 0)
			end
			btn:HookScript("OnEnter", function(self)
				GameTooltip:SetOwner(self, "ANCHOR_TOP")
				GameTooltip:AddLine(def.label, 1, 0.82, 0)
				GameTooltip:AddLine(def.tip, 0.85, 0.85, 0.9, true)
				if not ns.GetOptionsDB().enableThreatHighlight then
					GameTooltip:AddLine("Requires 'Enable Aggro / Threat Indicator' to be enabled.", 1, 0.45, 0.35, true)
				else
					GameTooltip:AddLine("Applies immediately without reloading.", 0.35, 0.85, 0.45)
				end
				GameTooltip:Show()
			end)
			btn:HookScript("OnLeave", function()
				GameTooltip:Hide()
			end)
			btn.styleId = def.id
			styleButtons[idx] = btn
		end

		threatToggleRow:HookScript("OnClick", function()
			if RefreshThreatUI then RefreshThreatUI() end
		end)

		local card2 = CreateCard(p, "Target Threat Percentage", 114, 156)
		CreateToggleRow(card2, {
			key = "showTargetThreat",
			label = "Show Threat % Bar on Target Frame",
			tip = "Display a compact threat % pill above Target's top-left corner in combat.",
		}, 1)
		CreateToggleRow(card2, {
			key = "targetThreatRawPct",
			label = "Show Raw Pull Threshold % (110% / 130%)",
			tip = "Use Blizzard's raw aggro threshold percentage (110% melee / 130% ranged) instead of scaled 100% tank cap.",
			indent = true,
			dependsOn = "showTargetThreat",
			dependsLabel = "Show Threat % Bar on Target Frame",
		}, 2)

		local threatNote = card2:CreateFontString(nil, "OVERLAY")
		threatNote:SetFont(FONT, SMALL_FONT_SIZE - 1, "OUTLINE")
		threatNote:SetPoint("TOPLEFT", 16, -86)
		threatNote:SetPoint("TOPRIGHT", -14, -86)
		threatNote:SetJustifyH("LEFT")
		threatNote:SetTextColor(0.62, 0.62, 0.68)
		threatNote:SetText("Displays above Target's top-left corner while on an enemy's threat table.")

		RefreshThreatUI = function()
			local opts = ns.GetOptionsDB()
			local enabled = (opts.enableThreatHighlight ~= false)
			local style = (opts.threatStyle == "glow" or opts.threatStyle == "tint" or opts.threatStyle == "badge" or opts.threatStyle == "both") and opts.threatStyle or "backdrop"
			for _, btn in ipairs(styleButtons) do
				btn:SetActive(enabled and btn.styleId == style)
				btn:SetAlpha(enabled and 1 or 0.45)
			end
			styleDesc:SetText(STYLE_DESC_TEXT[style] or STYLE_DESC_TEXT.backdrop)
			styleDesc:SetAlpha(enabled and 1 or 0.45)
		end
	end

	-- Page 7: Appearance (LibSharedMedia-3.0 + Font/Bar/Border Style)
	local RefreshAppearanceUI
	do
		local p = pages.appearance
		local card1 = CreateCard(p, "Textures & Fonts", 122, 10)

		local lsmBadge = card1:CreateFontString(nil, "OVERLAY")
		lsmBadge:SetFont(FONT, SMALL_FONT_SIZE - 2, "OUTLINE")
		lsmBadge:SetPoint("TOPRIGHT", -12, -11)
		if ns.IsLSMAvailable() then
			lsmBadge:SetTextColor(0.35, 0.78, 0.45)
			lsmBadge:SetText("LSM Active")
		else
			lsmBadge:SetTextColor(0.6, 0.6, 0.66)
			lsmBadge:SetText("Built-in Media")
		end

		local function CreateMediaSelector(yOff, labelText, mediaType, onChosen)
			local lbl = card1:CreateFontString(nil, "OVERLAY")
			lbl:SetFont(FONT, SMALL_FONT_SIZE, "OUTLINE")
			lbl:SetPoint("TOPLEFT", 14, -(yOff + 5))
			lbl:SetTextColor(0.92, 0.92, 0.95)
			lbl:SetText(labelText)

			local btn = CreateFrame("Button", nil, card1, BackdropTemplateMixin and "BackdropTemplate" or nil)
			btn:SetSize(244, 24)
			btn:SetPoint("TOPRIGHT", -14, -yOff)
			StyleFlatBox(btn, 0.11, 0.11, 0.14, 1, 0.30, 0.30, 0.36, 1)

			if mediaType == "statusbar" then
				local preview = btn:CreateTexture(nil, "BACKGROUND")
				preview:SetPoint("TOPLEFT", 2, -2)
				preview:SetPoint("BOTTOMRIGHT", -2, 2)
				preview:SetVertexColor(0.28, 0.48, 0.72, 0.55)
				btn.preview = preview
			end

			local valText = btn:CreateFontString(nil, "OVERLAY")
			valText:SetFont(FONT, SMALL_FONT_SIZE, "OUTLINE")
			valText:SetPoint("LEFT", 8, 0)
			valText:SetPoint("RIGHT", -22, 0)
			valText:SetJustifyH("LEFT")
			valText:SetWordWrap(false)
			valText:SetTextColor(1, 1, 1)
			btn.valText = valText

			local arrow = btn:CreateFontString(nil, "OVERLAY")
			arrow:SetFont(FONT, SMALL_FONT_SIZE - 1, "OUTLINE")
			arrow:SetPoint("RIGHT", -8, 0)
			arrow:SetTextColor(0.75, 0.75, 0.82)
			arrow:SetText("v")

			btn:SetScript("OnEnter", function(self)
				self:SetBackdropBorderColor(1, 0.56, 0.12, 1)
			end)
			btn:SetScript("OnLeave", function(self)
				self:SetBackdropBorderColor(0.30, 0.30, 0.36, 1)
			end)
			btn:SetScript("OnClick", function(self)
				local cur = (mediaType == "statusbar") and ns.GetOptionsDB().statusBarTexture or ns.GetOptionsDB().fontName
				OpenMediaDropdown(self, mediaType, cur, function(chosen)
					onChosen(chosen)
					ns.ApplyMedia()
					RefreshAppearanceUI()
				end)
			end)

			return btn
		end

		local texBtn = CreateMediaSelector(35, "Bar Texture", "statusbar", function(chosen)
			ns.GetOptionsDB().statusBarTexture = chosen
		end)
		local fontBtn = CreateMediaSelector(67, "Font", "font", function(chosen)
			ns.GetOptionsDB().fontName = chosen
		end)

		local lsmNote = card1:CreateFontString(nil, "OVERLAY")
		lsmNote:SetFont(FONT, SMALL_FONT_SIZE - 1, "OUTLINE")
		lsmNote:SetPoint("TOPLEFT", 14, -99)
		lsmNote:SetPoint("TOPRIGHT", -12, -99)
		lsmNote:SetJustifyH("LEFT")
		lsmNote:SetTextColor(0.62, 0.62, 0.68)
		lsmNote:SetText(ns.IsLSMAvailable()
			and "LibSharedMedia-3.0 active: shared textures & fonts apply live."
			or "Using built-in media. Add SharedMedia / LSM-3.0 addons for more.")

		local card2 = CreateCard(p, "Typography & Frame Style", 204, 140)

		local liveBadge2 = card2:CreateFontString(nil, "OVERLAY")
		liveBadge2:SetFont(FONT, SMALL_FONT_SIZE - 2, "OUTLINE")
		liveBadge2:SetPoint("TOPRIGHT", -12, -11)
		liveBadge2:SetTextColor(0.35, 0.78, 0.45)
		liveBadge2:SetText("LIVE")

		-- Row 1: Font Outline
		local outlineLbl = card2:CreateFontString(nil, "OVERLAY")
		outlineLbl:SetFont(FONT, SMALL_FONT_SIZE, "OUTLINE")
		outlineLbl:SetPoint("TOPLEFT", 14, -39)
		outlineLbl:SetTextColor(0.92, 0.92, 0.95)
		outlineLbl:SetText("Font Outline")

		local outlineBtns = {}
		local outlineDefs = {
			{ id = "", label = "None", w = 54 },
			{ id = "OUTLINE", label = "Outline", w = 62 },
			{ id = "THICKOUTLINE", label = "Thick", w = 56 },
			{ id = "MONOCHROME, OUTLINE", label = "Mono", w = 54 },
		}
		for i = #outlineDefs, 1, -1 do
			local def = outlineDefs[i]
			local b = CreateActionButton(card2, def.label, def.w, 22, function()
				ns.GetOptionsDB().fontOutline = def.id
				ns.ApplyMedia()
				RefreshAppearanceUI()
			end)
			if i == #outlineDefs then
				b:SetPoint("TOPRIGHT", -14, -34)
			else
				b:SetPoint("RIGHT", outlineBtns[i + 1], "LEFT", -6, 0)
			end
			b.outlineId = def.id
			outlineBtns[i] = b
		end

		-- Row 2: Font Size Adjust
		local sizeLbl = card2:CreateFontString(nil, "OVERLAY")
		sizeLbl:SetFont(FONT, SMALL_FONT_SIZE, "OUTLINE")
		sizeLbl:SetPoint("TOPLEFT", 14, -73)
		sizeLbl:SetTextColor(0.92, 0.92, 0.95)
		sizeLbl:SetText("Font Size Adjust")

		local sizePlus = CreateActionButton(card2, "+", 28, 22, function()
			local opts = ns.GetOptionsDB()
			opts.fontSizeOffset = math.min(4, ns.GetFontSizeOffset() + 1)
			ns.ApplyMedia()
			RefreshAppearanceUI()
		end)
		sizePlus:SetPoint("TOPRIGHT", -14, -68)

		local sizeVal = card2:CreateFontString(nil, "OVERLAY")
		sizeVal:SetFont(FONT, SMALL_FONT_SIZE, "OUTLINE")
		sizeVal:SetWidth(90)
		sizeVal:SetPoint("RIGHT", sizePlus, "LEFT", -6, 0)
		sizeVal:SetJustifyH("CENTER")
		sizeVal:SetTextColor(1, 0.84, 0.45)

		local sizeMinus = CreateActionButton(card2, "-", 28, 22, function()
			local opts = ns.GetOptionsDB()
			opts.fontSizeOffset = math.max(-3, ns.GetFontSizeOffset() - 1)
			ns.ApplyMedia()
			RefreshAppearanceUI()
		end)
		sizeMinus:SetPoint("RIGHT", sizeVal, "LEFT", -6, 0)

		-- Row 3: Health Bar Opacity
		local alphaLbl = card2:CreateFontString(nil, "OVERLAY")
		alphaLbl:SetFont(FONT, SMALL_FONT_SIZE, "OUTLINE")
		alphaLbl:SetPoint("TOPLEFT", 14, -107)
		alphaLbl:SetTextColor(0.92, 0.92, 0.95)
		alphaLbl:SetText("Health Bar Opacity")

		local alphaPlus = CreateActionButton(card2, "+", 28, 22, function()
			local opts = ns.GetOptionsDB()
			opts.barAlpha = math.min(1.0, math.floor((ns.GetBarAlpha() + 0.05) * 20 + 0.5) / 20)
			ns.ApplyMedia()
			RefreshAppearanceUI()
		end)
		alphaPlus:SetPoint("TOPRIGHT", -14, -102)

		local alphaVal = card2:CreateFontString(nil, "OVERLAY")
		alphaVal:SetFont(FONT, SMALL_FONT_SIZE, "OUTLINE")
		alphaVal:SetWidth(90)
		alphaVal:SetPoint("RIGHT", alphaPlus, "LEFT", -6, 0)
		alphaVal:SetJustifyH("CENTER")
		alphaVal:SetTextColor(1, 0.84, 0.45)

		local alphaMinus = CreateActionButton(card2, "-", 28, 22, function()
			local opts = ns.GetOptionsDB()
			opts.barAlpha = math.max(0.5, math.floor((ns.GetBarAlpha() - 0.05) * 20 + 0.5) / 20)
			ns.ApplyMedia()
			RefreshAppearanceUI()
		end)
		alphaMinus:SetPoint("RIGHT", alphaVal, "LEFT", -6, 0)

		-- Row 4: Frame Border Size
		local borderLbl = card2:CreateFontString(nil, "OVERLAY")
		borderLbl:SetFont(FONT, SMALL_FONT_SIZE, "OUTLINE")
		borderLbl:SetPoint("TOPLEFT", 14, -141)
		borderLbl:SetTextColor(0.92, 0.92, 0.95)
		borderLbl:SetText("Frame Border Size")

		local borderBtns = {}
		local borderDefs = {
			{ size = 1, label = "1px" },
			{ size = 2, label = "2px" },
			{ size = 3, label = "3px" },
		}
		for i = #borderDefs, 1, -1 do
			local def = borderDefs[i]
			local b = CreateActionButton(card2, def.label, 74, 22, function()
				ns.GetOptionsDB().borderSize = def.size
				ns.ApplyMedia()
				RefreshAppearanceUI()
			end)
			if i == #borderDefs then
				b:SetPoint("TOPRIGHT", -14, -136)
			else
				b:SetPoint("RIGHT", borderBtns[i + 1], "LEFT", -8, 0)
			end
			b.borderSize = def.size
			borderBtns[i] = b
		end

		-- Row 5: Smooth Bar Transitions
		local smoothLbl = card2:CreateFontString(nil, "OVERLAY")
		smoothLbl:SetFont(FONT, SMALL_FONT_SIZE, "OUTLINE")
		smoothLbl:SetPoint("TOPLEFT", 14, -175)
		smoothLbl:SetTextColor(0.92, 0.92, 0.95)
		smoothLbl:SetText("Smooth Bar Transitions")

		local smoothOffBtn = CreateActionButton(card2, "Off", 74, 22, function()
			ns.GetOptionsDB().smoothBars = false
			if ns.ApplySmoothBars then ns.ApplySmoothBars() end
			RefreshAppearanceUI()
		end)
		smoothOffBtn:SetPoint("TOPRIGHT", -14, -170)

		local smoothOnBtn = CreateActionButton(card2, "On", 74, 22, function()
			ns.GetOptionsDB().smoothBars = true
			if ns.ApplySmoothBars then ns.ApplySmoothBars() end
			RefreshAppearanceUI()
		end)
		smoothOnBtn:SetPoint("RIGHT", smoothOffBtn, "LEFT", -8, 0)

		RefreshAppearanceUI = function()
			local opts = ns.GetOptionsDB()
			local texKey = opts.statusBarTexture or "oUF_Brun"
			texBtn.preview:SetTexture(ns.FetchMedia("statusbar", texKey))
			texBtn.valText:SetText(texKey)

			local fKey = opts.fontName or "oUF_Brun"
			if not fontBtn.valText:SetFont(ns.FetchMedia("font", fKey), SMALL_FONT_SIZE, "OUTLINE") then
				fontBtn.valText:SetFont(DEFAULT_FONT, SMALL_FONT_SIZE, "OUTLINE")
			end
			fontBtn.valText:SetText(fKey)

			local flags = ns.GetFontFlags()
			for _, b in ipairs(outlineBtns) do
				b:SetActive(b.outlineId == flags)
			end

			local offset = ns.GetFontSizeOffset()
			if offset == 0 then
				sizeVal:SetText("Default (0)")
			elseif offset > 0 then
				sizeVal:SetText("+" .. offset .. " pt")
			else
				sizeVal:SetText(offset .. " pt")
			end

			alphaVal:SetText(string.format("%d%%", math.floor(ns.GetBarAlpha() * 100 + 0.5)))

			local bSize = ns.GetBorderSize()
			for _, b in ipairs(borderBtns) do
				b:SetActive(b.borderSize == bSize)
			end

			local isSmooth = ns.GetSmoothBars()
			smoothOnBtn:SetActive(isSmooth)
			smoothOffBtn:SetActive(not isSmooth)
		end
	end

	local function SyncAllControls(curOpts, markReload)
		for k, cb in pairs(checkboxes) do
			cb:SetChecked(curOpts[k])
		end
		RefreshDependencies()
		if RefreshGeneralUI then RefreshGeneralUI() end
		if RefreshFramesUI then RefreshFramesUI() end
		if RefreshSizingUI then RefreshSizingUI() end
		if RefreshAurasUI then RefreshAurasUI() end
		if RefreshGroupUI then RefreshGroupUI() end
		if RefreshClickCastUI then RefreshClickCastUI() end
		if RefreshColorUI then RefreshColorUI() end
		if RefreshThreatUI then RefreshThreatUI() end
		if RefreshAppearanceUI then RefreshAppearanceUI() end
		if markReload then
			reloadNeeded = true
		end
		UpdateReloadHint()
	end
	f.SyncAllControls = SyncAllControls

	local function ResetActiveTab()
		local keys = TAB_OPTION_KEYS[activeTabId]
		if not keys then return end
		local curOpts = ns.GetOptionsDB()
		local needsReload = false
		for _, k in ipairs(keys) do
			if curOpts[k] ~= DEFAULT_OPTIONS[k] and not LIVE_OPTIONS[k] then
				needsReload = true
			end
			curOpts[k] = DEFAULT_OPTIONS[k]
		end
		if activeTabId == "colors" and ns.GetClassColorsDB then
			table.wipe(ns.GetClassColorsDB())
		elseif activeTabId == "clickcast" and ns.ResetClassClickCastBindings then
			ns.ResetClassClickCastBindings()
		end
		if ns.ApplySavedOptions then
			ns.ApplySavedOptions()
		end
		if activeTabId == "general" and oUF and oUF.objects then
			for _, obj in ipairs(oUF.objects) do
				if obj.UpdateTags then obj:UpdateTags() end
			end
		end
		SyncAllControls(curOpts, needsReload)
	end

	local resetTabBtn = CreateActionButton(headerBar, "Reset Tab", 86, 24, ResetActiveTab)
	resetTabBtn:SetPoint("RIGHT", closeBtn, "LEFT", -10, 0)
	resetTabBtn:HookScript("OnEnter", function(self)
		local tabName = tabLabels[activeTabId] or activeTabId
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		GameTooltip:AddLine("Reset '" .. tabName .. "' Tab", 1, 0.82, 0)
		GameTooltip:AddLine("Restores only the settings on the active tab back to defaults.", 0.85, 0.85, 0.9, true)
		GameTooltip:Show()
	end)
	resetTabBtn:HookScript("OnLeave", function()
		GameTooltip:Hide()
	end)

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
		if StaticPopup_Show then
			local popup = StaticPopup_Show("OUF_BRUN_RESET_ALL")
			if popup then popup:Raise() end
		else
			local freshOpts = ns.ResetDefaults()
			SyncAllControls(freshOpts, true)
		end
	end)
	resetBtn:SetPoint("LEFT", testBtn, "RIGHT", 12, 0)
	resetBtn:HookScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:AddLine("Reset All Defaults", 1, 0.82, 0)
		GameTooltip:AddLine("Asks for confirmation before resetting every tab, custom class colors, and frame positions.", 0.85, 0.85, 0.9, true)
		GameTooltip:Show()
	end)
	resetBtn:HookScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	reloadBtn = CreateActionButton(footerBar, "Reload UI", 128, 26, ReloadUI)
	reloadBtn:SetPoint("RIGHT", -15, 0)

	SelectTab("general")
	SyncAllControls(ns.GetOptionsDB(), false)

	f:SetScript("OnShow", function()
		SyncAllControls(ns.GetOptionsDB(), false)
		ns.UpdateMoverBtnState()
		ns.UpdateTestBtnState()
	end)
	f:SetScript("OnHide", CloseMediaDropdown)

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

	local FONT = ns.FONT

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
