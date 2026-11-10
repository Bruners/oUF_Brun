--[[-------------------------------------------------------------------------
  Lasse G. Brun grants anyone the right to use this work for any purpose,
  without any conditions, unless such conditions are required by law.
---------------------------------------------------------------------------]]

local addonName, ns = ...
local oUF = ns.oUF or _G.oUF
assert(oUF, "oUF_Brun requires oUF to be loaded.")

local issecretvalue = _G.issecretvalue
local nop = _G.nop or function() end
local smoothInterpolation = Enum.StatusBarInterpolation.ExponentialEaseOut
local playerClass = UnitClassBase("player")
local isMaxLevel = (UnitLevel("player") == GetMaxLevelForPlayerExpansion())

local oUF_Brun = {
	-- { point, frame, relativePoint, x, y }
	Player = { "RIGHT", UIParent, "CENTER", -98, -340 },
	Target = { "LEFT", UIParent, "CENTER", 98, -340 },
	Pet = { "RIGHT", "oUF_player", "LEFT", -25, 0 },
	Focus = { "TOP", UIParent, "TOP", 250, -30 },
	FocusTarget = { "LEFT", "oUF_Focus", "RIGHT", 8, 0 },
	ToT = { "LEFT", "oUF_player", "RIGHT", 14, 5 },
	ToToT = { "LEFT", "oUF_player", "RIGHT", 14, -28 },
	Party = { "TOPLEFT", UIParent, "TOPLEFT", 20, -50 },
	Boss = { "RIGHT", UIParent, "RIGHT", -50, 150 },
	Runeframe = { "TOPLEFT", "oUF_player", "BOTTOMLEFT", 0, -20 },
}

local oUFRuneBar = false				-- Enable/Disable the rune bar delivered by oUF.
local removeBuffs = false				-- Enable/Disable blizzard default buff frame.
local hideSelfInfo = true				-- Enable/Disable name and level info on playerframe when at max level.
local hidePartyInRaid = false			-- Enable/Disable party frames in raid.
local enableHealthPrediction = true		-- Enable/Disable incoming heal and absorb shields on health bars.
local enableThreatHighlight = true		-- Enable/Disable backdrop aggro highlight on threat.
local desaturateOtherDebuffs = true		-- Desaturate non-player debuffs on Target/Boss and sort player debuffs first.
local firstNameOnly = false				-- Show only first name (hide WoW Forever surname) on all player unit frames.
local enableFader = true				-- Fade out Player and Pet frames when out of combat with no target.
local fadeOutAlpha = 0.35				-- Alpha value for faded Player/Pet frames when idle.
local showBossFrames = true				-- Spawn Boss1..MAX_BOSS_FRAMES frames.
local enableTotemBar = true				-- Style and anchor clickable TotemFrame icons above Player/Pet.
local hideCompactRaidManager = true		-- Auto-fade the collapsed Blizzard Raid Manager tab until mouseover.

ns.firstNameOnly = firstNameOnly

local FONT_SIZE = 14					-- Largest font on frames (most frames)
local SMALL_FONT_SIZE = 12				-- Smallest font on frames (target's target)

local FONT = "Interface\\Addons\\oUF_Brun\\textures\\Font.ttf"
local TEXTURE = "Interface\\Addons\\oUF_Brun\\textures\\Statusbar"
local BORDER_TEXTURE = "Interface\\Addons\\oUF_Brun\\textures\\border"
local GLOSS_TEXTURE = "Interface\\Addons\\oUF_Brun\\textures\\gloss"
local HIGHLIGHT = "Interface\\QuestFrame\\UI-QuestTitleHighlight"
local COMBO = "Interface\\Addons\\oUF_Brun\\textures\\pb4combo"

local height, width = 35, 252			-- Default frame height and width used by several frames.

local playerShowBuffs = false
local playerShowDebuffs = true
local playerBuffsSize = 23
local playerDebuffSize = 23
local playerBuffSpacing = 2
local playerDebuffSpacing = 2
local playerCastBar = true

local targetShowBuffs = true
local targetShowDebuffs = true
local targetBuffSize = 23
local targetDebuffSize = 23
local targetBuffSpacing = 2
local targetDebuffSpacing = 2
local targetCastBar = true

local targetTargetHeight = height - 10
local targetTargetWidth = width - 85

local petHeight, petWidth = 15, 152
local petShowAura = true
local petCastBar = true

local focusHeight, focusWidth = 20, 200
local focusShowBuffs = true
local focusShowDebuffs = true
local focusBuffSize = 20
local focusDebuffSize = 20
local focusBuffSpacing = 2
local focusDebuffSpacing = 2
local focusCastBar = true

local partyHeight, partyWidth = height, width - 46
local partyShowBuffs = true
local partyShowDebuffs = true
local partyBuffSize = 19
local partyDebuffSize = 19
local partyBuffSpacing = 2
local partyDebuffSpacing = 2

local partyPetAndTargetHeight = 15
local partyPetAndTargetWidth = 95

local MODULEGAP = 0
local EXPREPBARGAP = 21
local backdrop = {
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
	tile = true,
	insets = { left = -2, right = -2, top = -2, bottom = -2 },
}

-- Mixin BackdropTemplate dynamically because WoW decoupled SetBackdrop from native Frame/StatusBar widgets.
local function ApplyBackdrop(frame)
	if not frame.SetBackdrop and BackdropTemplateMixin then
		Mixin(frame, BackdropTemplateMixin)
		if frame.OnBackdropLoaded then
			frame:OnBackdropLoaded()
		end
	end
	if frame.SetBackdrop then
		frame:SetBackdrop(backdrop)
		frame:SetBackdropColor(0, 0, 0, 0.9)
	end
end

oUF.colors.power.MANA:SetRGB(48 / 255, 113 / 255, 191 / 255)
oUF.colors.power.RAGE:SetRGB(226 / 255, 45 / 255, 75 / 255)
oUF.colors.power.FOCUS:SetRGB(1, 210 / 255, 0)
oUF.colors.power.ENERGY:SetRGB(1, 220 / 255, 25 / 255)
oUF.colors.power.RUNIC_POWER:SetRGB(48 / 255, 113 / 255, 191 / 255)
oUF.colors.tapped:SetRGB(0.55, 0.57, 0.61)
oUF.colors.disconnected:SetRGB(0.7, 0.7, 0.7)

if removeBuffs then
	if BuffFrame then
		BuffFrame:UnregisterAllEvents()
		BuffFrame:Hide()
	end
	if TemporaryEnchantFrame then
		TemporaryEnchantFrame:UnregisterAllEvents()
		TemporaryEnchantFrame:Hide()
	end
end

--===================================================--
-- C++ Duration & Time Formatters
--===================================================--

local auraDurationFormatter
if C_StringUtil and C_StringUtil.CreateNumericRuleFormatter and Enum.NumericRuleFormatRounding then
	local roundDown = Enum.NumericRuleFormatRounding.Down
	auraDurationFormatter = C_StringUtil.CreateNumericRuleFormatter()
	auraDurationFormatter:SetBreakpoints({
		{ threshold = 0, step = 1, rounding = roundDown, format = "%d" },
		{ threshold = 60, format = "%d:%02d", components = {
			{ div = 60, step = 1, rounding = roundDown },
			{ mod = 60, step = 1, rounding = roundDown },
		}},
		{ threshold = 300, format = "%dm", components = {{ div = 60, step = 1, rounding = roundDown }} },
		{ threshold = 3600, format = "%dh", components = {{ div = 3600, step = 1, rounding = roundDown }} },
		{ threshold = 86400, format = "%dd", components = {{ div = 86400, step = 1, rounding = roundDown }} },
	})
end

local castTimeFormatter
if C_StringUtil and C_StringUtil.CreateNumericRuleFormatter then
	castTimeFormatter = C_StringUtil.CreateNumericRuleFormatter()
	castTimeFormatter:SetBreakpoints({ { threshold = 0, format = "%.1f" } })
end

-- Resolve the unit token from oUF 14's self.__unit before invoking GameTooltip:SetUnit.
local function UnitFrameOnEnter(self)
	local unit = self.__unit or self:GetAttribute("unit")
	if not unit or not UnitExists(unit) then return end
	GameTooltip_SetDefaultAnchor(GameTooltip, self)
	GameTooltip:SetUnit(unit)
end

local function UnitFrameOnLeave()
	GameTooltip:FadeOut()
end

-- Sync background texture tint with the parent Health/Power statusbar color.
local function PostUpdateBarColor(element, _, color, altR, altG, altB)
	local bg = element.bg
	if not bg then return end
	if color then
		bg:SetVertexColor(color:GetRGB())
	elseif altB then
		bg:SetVertexColor(altR, altG, altB)
	end
end

local function UpdateTargetComboPoints(self, event, _, powerType)
	if event == "UNIT_POWER_UPDATE" and powerType ~= "COMBO_POINTS" then
		return
	end

	local cp = 0
	if UnitExists("target") then
		if GetComboPoints then
			cp = GetComboPoints("player", "target") or 0
		else
			cp = UnitPower("player", Enum.PowerType.ComboPoints) or 0
		end
	end

	if issecretvalue(cp) then
		cp = 0
	end

	local cpoints = self.CPoints
	for i = 1, 5 do
		cpoints[i]:SetShown(i <= cp)
	end
end

--===================================================--
-- Auras (CreateAuras + Player Debuff Priority)
--===================================================--

local function StyleAuraButton(element, button, options)
	local fontSize = math.max(8, math.floor((element.size or 20) * 0.45))

	if button.Icon then
		button.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		if options and options.desaturateIcon then
			button.Icon:SetDesaturated(true)
		end
	end

	if button.Cooldown then
		button.Cooldown:SetReverse(true)
		if auraDurationFormatter and button.Time then
			button.Cooldown:SetHideCountdownNumbers(true)
		else
			for i = 1, button.Cooldown:GetNumRegions() do
				local region = select(i, button.Cooldown:GetRegions())
				if region and region.IsObjectType and region:IsObjectType("FontString") then
					region:SetFont(FONT, fontSize, "OUTLINE")
				end
			end
		end
	end

	if button.Time then
		button.Time:SetFont(FONT, fontSize, "OUTLINE")
		button.Time:ClearAllPoints()
		button.Time:SetPoint("TOP", button, "TOP", 0, 2)
		button.Time:SetTextColor(1, 1, 1)
	end

	if button.Count then
		button.Count:SetFont(FONT, fontSize, "OUTLINE")
		button.Count:ClearAllPoints()
		button.Count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, -1)
	end

	local overlay = button:CreateTexture(nil, "OVERLAY")
	overlay:SetPoint("TOPLEFT", -2.5, 2.5)
	overlay:SetPoint("BOTTOMRIGHT", 2.5, -2.5)
	overlay:SetTexture(BORDER_TEXTURE)
	overlay:SetVertexColor(0.31, 0.45, 0.63)
	overlay:SetBlendMode("BLEND")
	button.ButtonOverlay = overlay

	local gloss = button:CreateTexture(nil, "OVERLAY")
	gloss:SetPoint("TOPLEFT", -3, 3)
	gloss:SetPoint("BOTTOMRIGHT", 3, -3)
	gloss:SetTexture(GLOSS_TEXTURE)
	gloss:SetVertexColor(0.84, 0.75, 0.65)
	gloss:SetBlendMode("ADD")
	button.ButtonGloss = gloss
end

-- Create an oUF 14 intrinsic AuraContainer with the requested filter and layout geometry.
local function CreateAuraWidget(self, filter, frameWidth, iconSize, spacing, growthX, growthY)
	local initialAnchor = (growthY == "UP" and "BOTTOM" or "TOP") .. (growthX == "LEFT" and "RIGHT" or "LEFT")
	local element = self:CreateAuras({
		initialAnchor = initialAnchor,
		growthX = growthX,
		growthY = growthY,
		layoutLimit = frameWidth,
	})
	element:SetSize(frameWidth, iconSize)
	element.size = iconSize
	element.maxFrameCount = math.floor(frameWidth / iconSize + 0.5)
	element.elementSpacing = spacing
	element.lineSpacing = spacing
	element.groupSpacing = spacing
	element.groupLineSpacing = spacing
	element.forceNewLine = false
	element.showCount = true
	if auraDurationFormatter then
		element.showDuration = true
		element.durationFormatter = auraDurationFormatter
	end
	element.showDebuffBorder = (filter ~= "HELPFUL")
	if filter == "HELPFUL" then
		element.cancelButton = "RightButtonUp"
		element.showStealableBorder = true
	end
	element.PostCreateButton = StyleAuraButton

	if filter == "BOTH" then
		element:AddGroup("HELPFUL")
		element:AddGroup("HARMFUL")
	elseif filter == "TARGET_DEBUFFS" then
		element:AddGroup("HARMFUL|PLAYER")
		element:AddGroup("HARMFUL|!PLAYER", {
			desaturateIcon = desaturateOtherDebuffs,
		})
	else
		element:AddGroup(filter)
	end

	return element
end

--===================================================--
-- Castbar (Interrupt Attribution, Hold & Boolean Color)
--===================================================--

local castNormalColor = CreateColor(1.0, 0.7, 0.0)
local castShieldColor = CreateColor(0.65, 0.65, 0.65)
local castFailedColor = CreateColor(0.85, 0.2, 0.2)

local function UpdateCastbarColor(element, _, _, notInterruptible)
	if element.isPlayerCastbar then
		element:SetStatusBarColor(castNormalColor:GetRGB())
	else
		local tex = element:GetStatusBarTexture()
		if tex and tex.SetVertexColorFromBoolean then
			tex:SetVertexColorFromBoolean(notInterruptible, castShieldColor, castNormalColor)
		end
	end
end

local function PostCastStart(element, unit, spellID, notInterruptible)
	UpdateCastbarColor(element, unit, spellID, notInterruptible)
	if element.Time and element.Time.binding then
		element.Time.binding:SetEnabled(true)
	end
	if element.SafeZone then
		local showLatency = (unit == "player")
		element.SafeZone:SetShown(showLatency)
		if element.Latency then
			element.Latency:SetShown(showLatency)
			if showLatency then
				element.Latency:SetFormattedText("%dms", select(4, GetNetStats()))
			end
		end
	end
end

local function PostCastFail(element)
	local tex = element:GetStatusBarTexture()
	if tex then
		tex:SetVertexColor(castFailedColor:GetRGB())
	else
		element:SetStatusBarColor(castFailedColor:GetRGB())
	end
	if element.Time and element.Time.binding then
		element.Time.binding:SetEnabled(false)
		element.Time:SetText("")
	end
	if element.Delay then
		element.Delay:SetText("")
	end
	if element.SafeZone then
		element.SafeZone:Hide()
	end
	if element.Latency then
		element.Latency:Hide()
	end
end

local function PostCastInterrupted(element, _, _, interruptedBy)
	PostCastFail(element)
	if not interruptedBy or not UnitNameFromGUID then return end

	local ok, name = pcall(UnitNameFromGUID, interruptedBy)
	if not ok or not name then return end

	if UnitClassFromGUID then
		local okClass, _, class = pcall(UnitClassFromGUID, interruptedBy)
		if okClass and class and not issecretvalue(class) and C_ClassColor then
			local color = C_ClassColor.GetClassColor(class)
			if color and C_ColorUtil and C_ColorUtil.WrapTextInColor then
				name = C_ColorUtil.WrapTextInColor(name, color)
			end
		end
	end

	if element.Text and SPELL_INTERRUPTED_BY then
		element.Text:SetFormattedText(SPELL_INTERRUPTED_BY, name)
	end
end

local function CreateCastbar(self, anchor, yOffset, isPlayer)
	local cb = CreateFrame("StatusBar", nil, self)
	cb:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOffset)
	cb:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, yOffset)
	ApplyBackdrop(cb)
	cb:SetToplevel(true)
	cb:SetStatusBarTexture(TEXTURE)
	cb:SetStatusBarColor(castNormalColor:GetRGB())
	cb:SetHeight(14)
	cb.smoothing = smoothInterpolation
	cb.timeToHold = 0.5
	cb.isPlayerCastbar = isPlayer

	local cbsp = cb:CreateTexture(nil, "OVERLAY")
	cbsp:SetSize(10, 30)
	cbsp:SetBlendMode("ADD")
	cbsp:SetTexCoord(0, 0, 0, 1, 1, 0, 1, 1)
	cbsp:SetPoint("CENTER", cb:GetStatusBarTexture(), "RIGHT", 0, 0)
	cb.Spark = cbsp

	if isPlayer then
		local safezone = cb:CreateTexture(nil, "BORDER")
		safezone:SetTexture(TEXTURE)
		safezone:SetVertexColor(0.85, 0.15, 0.15, 0.65)
		cb.SafeZone = safezone

		local latency = cb:CreateFontString(nil, "OVERLAY")
		latency:SetFont(FONT, math.max(8, SMALL_FONT_SIZE - 3), "OUTLINE")
		latency:SetPoint("BOTTOMRIGHT", safezone, "BOTTOMRIGHT", -1, 0)
		latency:SetTextColor(0.8, 0.8, 0.8, 0.85)
		cb.Latency = latency
	end

	local cbtime = cb:CreateFontString(nil, "OVERLAY")
	cbtime:SetPoint("RIGHT", -5, 1)
	cbtime:SetTextColor(1, 1, 1)
	cbtime:SetJustifyH("RIGHT")
	cbtime:SetShadowOffset(1, -1)
	cbtime:SetFont(FONT, SMALL_FONT_SIZE, "OUTLINE")
	if C_DurationUtil and C_DurationUtil.CreateDurationTextBinding and castTimeFormatter and Enum.DurationTextBindingProperty then
		cbtime.binding = C_DurationUtil.CreateDurationTextBinding()
		cbtime.binding:SetTextFormat("{} / {}", {
			{ property = Enum.DurationTextBindingProperty.RemainingDuration, formatter = castTimeFormatter },
			{ property = Enum.DurationTextBindingProperty.TotalDuration, formatter = castTimeFormatter },
		})
	end
	cb.Time = cbtime

	local cbdelay = cb:CreateFontString(nil, "OVERLAY")
	cbdelay:SetPoint("RIGHT", cbtime, "LEFT", -3, 0)
	cbdelay:SetTextColor(1, 0.35, 0.35)
	cbdelay:SetJustifyH("RIGHT")
	cbdelay:SetShadowOffset(1, -1)
	cbdelay:SetFont(FONT, SMALL_FONT_SIZE, "OUTLINE")
	cb.Delay = cbdelay

	local cbtext = cb:CreateFontString(nil, "OVERLAY")
	cbtext:SetPoint("LEFT", 15, 1)
	cbtext:SetPoint("RIGHT", cbdelay, "LEFT", -4, 0)
	cbtext:SetWordWrap(false)
	cbtext:SetTextColor(1, 1, 1)
	cbtext:SetShadowOffset(1, -1)
	cbtext:SetJustifyH("LEFT")
	cbtext:SetFont(FONT, SMALL_FONT_SIZE, "OUTLINE")
	cb.Text = cbtext

	local cbicon = cb:CreateTexture(nil, "OVERLAY")
	cbicon:SetSize(15, 15)
	cbicon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	cbicon:SetPoint("TOPLEFT", -2, 0)
	cb.Icon = cbicon

	cb.PostCastStart = PostCastStart
	cb.PostCastInterruptible = UpdateCastbarColor
	cb.PostCastFail = PostCastFail
	cb.PostCastInterrupted = PostCastInterrupted

	self.Castbar = cb
end

local function CreatePredictionBar(hp, anchorTexture, r, g, b, a, reverse)
	local bar = CreateFrame("StatusBar", nil, hp)
	bar:SetPoint("TOP")
	bar:SetPoint("BOTTOM")
	bar:SetPoint(reverse and "RIGHT" or "LEFT", anchorTexture, "RIGHT")
	bar:SetStatusBarTexture(TEXTURE)
	bar:SetStatusBarColor(r, g, b, a)
	if reverse then
		bar:SetReverseFill(true)
	end
	return bar
end

local function CreateHealthPrediction(self)
	local hp = self.Health
	local hpTex = hp:GetStatusBarTexture()

	local myBar = CreatePredictionBar(hp, hpTex, 0.1, 0.8, 0.2, 0.5, false)
	local otherBar = CreatePredictionBar(hp, myBar:GetStatusBarTexture(), 0.1, 0.6, 0.2, 0.5, false)
	local absorbBar = CreatePredictionBar(hp, otherBar:GetStatusBarTexture(), 0.4, 0.8, 1.0, 0.55, false)
	local healAbsorbBar = CreatePredictionBar(hp, hpTex, 0.8, 0.2, 0.2, 0.6, true)

	local overAbsorb = hp:CreateTexture(nil, "OVERLAY")
	overAbsorb:SetPoint("TOP")
	overAbsorb:SetPoint("BOTTOM")
	overAbsorb:SetPoint("LEFT", hp, "RIGHT", -4, 0)
	overAbsorb:SetWidth(10)

	local overHealAbsorb = hp:CreateTexture(nil, "OVERLAY")
	overHealAbsorb:SetPoint("TOP")
	overHealAbsorb:SetPoint("BOTTOM")
	overHealAbsorb:SetPoint("RIGHT", hp, "LEFT", 4, 0)
	overHealAbsorb:SetWidth(10)

	local overHeal = hp:CreateTexture(nil, "OVERLAY")
	overHeal:SetPoint("TOP")
	overHeal:SetPoint("BOTTOM")
	overHeal:SetPoint("LEFT", hp, "RIGHT", -4, 0)
	overHeal:SetWidth(10)

	hp.HealingPlayer = myBar
	hp.HealingOther = otherBar
	hp.DamageAbsorb = absorbBar
	hp.HealAbsorb = healAbsorbBar
	hp.OverDamageAbsorbIndicator = overAbsorb
	hp.OverHealAbsorbIndicator = overHealAbsorb
	hp.OverHealIndicator = overHeal
	hp.incomingHealOverflow = 1.0
end

local function CreateCostPrediction(bar, barWidth)
	local cost = CreateFrame("StatusBar", nil, bar)
	cost:SetReverseFill(true)
	cost:SetPoint("TOP")
	cost:SetPoint("BOTTOM")
	cost:SetPoint("RIGHT", bar:GetStatusBarTexture(), "RIGHT")
	cost:SetStatusBarTexture(TEXTURE)
	cost:SetStatusBarColor(1, 1, 1, 0.45)
	cost:SetWidth(barWidth)
	bar.CostPrediction = cost
end

local function PostUpdateThreat(element, _, status, color)
	local frame = element.__owner
	if not frame or not frame.SetBackdropColor then return end
	if status and not issecretvalue(status) and status > 0 and color then
		local r, g, b = color:GetRGB()
		frame:SetBackdropColor(r * 0.75, g * 0.15, b * 0.15, 0.95)
	else
		frame:SetBackdropColor(0, 0, 0, 0.9)
	end
end

--===================================================--
-- Rare / Elite Classification Indicator Element
--===================================================--

local function UpdateClassificationIndicator(self, _, unit)
	if unit and unit ~= self.__unit then return end
	unit = unit or self.__unit
	local element = self.ClassificationIndicator
	local c = unit and UnitClassification(unit)
	if not c or issecretvalue(c) then
		element:Hide()
		return
	end

	local atlas, tex
	if c == "elite" or c == "worldboss" then
		atlas = "nameplates-icon-elite-gold"
		tex = "Interface\\TargetingFrame\\UI-TargetingFrame-Elite"
	elseif c == "rare" or c == "rareelite" then
		atlas = "nameplates-icon-elite-silver"
		tex = "Interface\\TargetingFrame\\UI-TargetingFrame-Rare"
	else
		element:Hide()
		return
	end

	if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then
		element:SetTexCoord(0, 1, 0, 1)
		element:SetAtlas(atlas, false)
	else
		element:SetTexture(tex)
		element:SetTexCoord(0, 0.22, 0, 0.62)
	end

	local ok, isPVP = pcall(UnitIsPVP, unit)
	local hasPvP = ok and not issecretvalue(isPVP) and isPVP
	element:ClearAllPoints()
	if element.isSmall then
		element:SetPoint("CENTER", self.Health, "TOPRIGHT", 1, hasPvP and -12 or -2)
	else
		element:SetPoint("CENTER", self.Health, "TOPRIGHT", 1, hasPvP and -20 or -6)
	end
	element:Show()
end

oUF:AddElement("ClassificationIndicator", UpdateClassificationIndicator, function(self)
	local element = self.ClassificationIndicator
	if element then
		element.__owner = self
		self:RegisterEvent("UNIT_CLASSIFICATION_CHANGED", UpdateClassificationIndicator)
		self:RegisterEvent("UNIT_FACTION", UpdateClassificationIndicator)
		return true
	end
end, function(self)
	local element = self.ClassificationIndicator
	if element then
		element:Hide()
		self:UnregisterEvent("UNIT_CLASSIFICATION_CHANGED", UpdateClassificationIndicator)
		self:UnregisterEvent("UNIT_FACTION", UpdateClassificationIndicator)
	end
end)

--===================================================--
-- Out-of-Combat Frame Fader Element
--===================================================--

do
	local fadeManager = CreateFrame("Frame")
	local fadeFrames = {}
	local activeFrames = {}
	local FADE_IN_TIME = 0.3
	local FADE_OUT_TIME = 1.2

	local function FadeOnUpdate(self, elapsed)
		local count = 0
		for frame, info in pairs(fadeFrames) do
			info.timer = info.timer + elapsed
			if info.timer >= info.duration then
				frame:SetAlpha(info.endAlpha)
				fadeFrames[frame] = nil
			else
				local progress = info.timer / info.duration
				frame:SetAlpha(info.startAlpha + (info.endAlpha - info.startAlpha) * progress)
				count = count + 1
			end
		end
		if count == 0 then
			self:SetScript("OnUpdate", nil)
		end
	end

	local function FadeFrameTo(frame, duration, endAlpha)
		local pending = fadeFrames[frame]
		if pending and pending.endAlpha == endAlpha then return end
		fadeFrames[frame] = nil

		local startAlpha = frame:GetAlpha()
		if startAlpha == endAlpha then return end

		fadeFrames[frame] = {
			timer = 0,
			duration = duration,
			startAlpha = startAlpha,
			endAlpha = endAlpha,
		}
		fadeManager:SetScript("OnUpdate", FadeOnUpdate)
	end

	local function ShouldFrameShow(self)
		if self:IsMouseOver() then return true end
		if UnitAffectingCombat("player") then return true end
		if UnitExists("target") then return true end
		if C_Secrets and C_Secrets.ShouldUnitSpellCastingBeSecret and C_Secrets.ShouldUnitSpellCastingBeSecret("player") then
			return true
		end
		if UnitCastingInfo("player") or UnitChannelInfo("player") then return true end
		return false
	end

	local function UpdateFader(self)
		if not activeFrames[self] then return end
		local show = ShouldFrameShow(self)
		FadeFrameTo(self, show and FADE_IN_TIME or FADE_OUT_TIME, show and 1 or fadeOutAlpha)
	end

	local function UpdateAllFaders()
		for frame in pairs(activeFrames) do
			UpdateFader(frame)
		end
	end

	local castEvents = {
		"UNIT_SPELLCAST_START",
		"UNIT_SPELLCAST_STOP",
		"UNIT_SPELLCAST_FAILED",
		"UNIT_SPELLCAST_FAILED_QUIET",
		"UNIT_SPELLCAST_INTERRUPTED",
		"UNIT_SPELLCAST_CHANNEL_START",
		"UNIT_SPELLCAST_CHANNEL_STOP",
	}

	oUF:AddElement("BrunFader", UpdateFader, function(self, unit)
		if not self.fade or (unit ~= "player" and unit ~= "pet") then return end
		activeFrames[self] = true
		if not self.__brunFaderHooked then
			self:HookScript("OnEnter", UpdateFader)
			self:HookScript("OnLeave", UpdateFader)
			self.__brunFaderHooked = true
		end
		if not fadeManager.registered then
			fadeManager:RegisterEvent("PLAYER_ENTERING_WORLD")
			fadeManager:RegisterEvent("PLAYER_REGEN_ENABLED")
			fadeManager:RegisterEvent("PLAYER_REGEN_DISABLED")
			fadeManager:RegisterEvent("PLAYER_TARGET_CHANGED")
			for _, ev in ipairs(castEvents) do
				fadeManager:RegisterUnitEvent(ev, "player")
			end
			fadeManager:SetScript("OnEvent", UpdateAllFaders)
			fadeManager.registered = true
		end
		UpdateFader(self)
		return true
	end, function(self)
		activeFrames[self] = nil
		fadeFrames[self] = nil
		self:SetAlpha(1)
		if not next(activeFrames) and fadeManager.registered then
			fadeManager:UnregisterAllEvents()
			fadeManager:SetScript("OnEvent", nil)
			fadeManager.registered = nil
		end
	end)
end

--===================================================--
-- Saved Options, Edit Mode Movers & /brun Config GUI
--===================================================--

local movers = {}
local manualMoversUnlocked = false

local DEFAULT_OPTIONS = {
	enableFader = enableFader,
	firstNameOnly = firstNameOnly,
	desaturateOtherDebuffs = desaturateOtherDebuffs,
	enableHealthPrediction = enableHealthPrediction,
	enableThreatHighlight = enableThreatHighlight,
	hideSelfInfo = hideSelfInfo,
	hidePartyInRaid = hidePartyInRaid,
	showBossFrames = showBossFrames,
	enableTotemBar = enableTotemBar,
	hideCompactRaidManager = hideCompactRaidManager,
	oUFRuneBar = oUFRuneBar,
	removeBuffs = removeBuffs,
	playerCastBar = playerCastBar,
	targetCastBar = targetCastBar,
	focusCastBar = focusCastBar,
	playerShowBuffs = playerShowBuffs,
	playerShowDebuffs = playerShowDebuffs,
	targetShowBuffs = targetShowBuffs,
	targetShowDebuffs = targetShowDebuffs,
	focusShowBuffs = focusShowBuffs,
	focusShowDebuffs = focusShowDebuffs,
	partyShowBuffs = partyShowBuffs,
	partyShowDebuffs = partyShowDebuffs,
	showMinimapIcon = true,
}

local function GetPositionsDB()
	if type(oUF_BrunDB) ~= "table" then oUF_BrunDB = {} end
	if type(oUF_BrunDB.Positions) ~= "table" then oUF_BrunDB.Positions = {} end
	return oUF_BrunDB.Positions
end

local function GetOptionsDB()
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

local minimapButton

local function ApplySavedOptions()
	local opts = GetOptionsDB()
	enableFader = opts.enableFader
	firstNameOnly = opts.firstNameOnly
	ns.firstNameOnly = firstNameOnly
	desaturateOtherDebuffs = opts.desaturateOtherDebuffs
	enableHealthPrediction = opts.enableHealthPrediction
	enableThreatHighlight = opts.enableThreatHighlight
	hideSelfInfo = opts.hideSelfInfo
	hidePartyInRaid = opts.hidePartyInRaid
	showBossFrames = opts.showBossFrames
	enableTotemBar = opts.enableTotemBar
	hideCompactRaidManager = opts.hideCompactRaidManager
	oUFRuneBar = opts.oUFRuneBar
	removeBuffs = opts.removeBuffs
	playerCastBar = opts.playerCastBar
	targetCastBar = opts.targetCastBar
	focusCastBar = opts.focusCastBar
	playerShowBuffs = opts.playerShowBuffs
	playerShowDebuffs = opts.playerShowDebuffs
	targetShowBuffs = opts.targetShowBuffs
	targetShowDebuffs = opts.targetShowDebuffs
	focusShowBuffs = opts.focusShowBuffs
	focusShowDebuffs = opts.focusShowDebuffs
	partyShowBuffs = opts.partyShowBuffs
	partyShowDebuffs = opts.partyShowDebuffs

	if minimapButton then
		minimapButton:SetShown(opts.showMinimapIcon ~= false)
	end

	if removeBuffs then
		if BuffFrame then
			BuffFrame:UnregisterAllEvents()
			BuffFrame:Hide()
		end
		if TemporaryEnchantFrame then
			TemporaryEnchantFrame:UnregisterAllEvents()
			TemporaryEnchantFrame:Hide()
		end
	end
end

local function FinishMoverDrag(mover)
	if not mover.dragging or InCombatLockdown() then return end
	local anchor = mover.anchor
	anchor:StopMovingOrSizing()
	mover.dragging = nil
	local point, _, relativePoint, x, y = anchor:GetPoint()
	GetPositionsDB()[mover.key] = { point = point, relativePoint = relativePoint, x = x, y = y }
end

local function IsMoverModeActive()
	if InCombatLockdown() then return false end
	if manualMoversUnlocked then return true end
	return EditModeManagerFrame and EditModeManagerFrame:IsShown() or false
end

local function UpdateEditModeMovers()
	if InCombatLockdown() then
		manualMoversUnlocked = false
	end
	local editing = IsMoverModeActive()
	for _, mover in pairs(movers) do
		FinishMoverDrag(mover)
		mover:SetShown(editing)
	end
end

do
	local editCombat = CreateFrame("Frame")
	editCombat:RegisterEvent("PLAYER_REGEN_DISABLED")
	editCombat:RegisterEvent("PLAYER_REGEN_ENABLED")
	editCombat:SetScript("OnEvent", UpdateEditModeMovers)
	if EditModeManagerFrame then
		EditModeManagerFrame:HookScript("OnShow", UpdateEditModeMovers)
		EditModeManagerFrame:HookScript("OnHide", UpdateEditModeMovers)
	end
end

local function CreatePositionAnchor(key, w, h, defaultPoint)
	local anchor = CreateFrame("Frame", "oUF_Brun" .. key .. "Anchor", UIParent)
	anchor:SetSize(w, h)
	anchor:SetMovable(true)
	anchor:SetClampedToScreen(true)
	anchor:SetDontSavePosition(true)

	local saved = GetPositionsDB()[key]
	if saved then
		anchor:SetPoint(saved.point, UIParent, saved.relativePoint or saved.point, saved.x, saved.y)
	else
		anchor:SetPoint(unpack(defaultPoint))
	end

	local mover = CreateFrame("Frame", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	mover:SetAllPoints(anchor)
	mover:SetFrameStrata("DIALOG")
	if mover.SetBackdrop then
		mover:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8X8",
			edgeFile = "Interface\\Buttons\\WHITE8X8",
			edgeSize = 1,
		})
		mover:SetBackdropColor(0.1, 0.1, 0.1, 0.65)
		mover:SetBackdropBorderColor(1, 0.5, 0, 1)
	end
	mover.anchor = anchor
	mover.key = key
	mover.defaultPoint = defaultPoint
	mover:EnableMouse(true)
	mover:RegisterForDrag("LeftButton")

	local label = mover:CreateFontString(nil, "OVERLAY")
	label:SetFont(FONT, SMALL_FONT_SIZE, "OUTLINE")
	label:SetPoint("CENTER")
	label:SetText(key)

	mover:SetScript("OnDragStart", function()
		if InCombatLockdown() then return end
		anchor:StartMoving()
		mover.dragging = true
	end)
	mover:SetScript("OnDragStop", function() FinishMoverDrag(mover) end)
	mover:SetScript("OnHide", FinishMoverDrag)
	mover:SetScript("OnMouseUp", function(_, button)
		if button ~= "RightButton" or InCombatLockdown() then return end
		FinishMoverDrag(mover)
		anchor:ClearAllPoints()
		anchor:SetPoint(unpack(defaultPoint))
		GetPositionsDB()[key] = nil
	end)
	mover:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:AddLine("oUF_Brun: " .. key)
		GameTooltip:AddLine("Left-drag to move | Right-click to reset", 0.8, 0.8, 0.8)
		GameTooltip:Show()
	end)
	mover:SetScript("OnLeave", function() GameTooltip:Hide() end)
	mover:SetShown(IsMoverModeActive())
	movers[key] = mover

	return anchor
end

local configFrame
local function ToggleConfigGUI()
	if configFrame then
		configFrame:SetShown(not configFrame:IsShown())
		return
	end

	local f = CreateFrame("Frame", "oUF_BrunConfigFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	f:SetSize(420, 560)
	f:SetPoint("CENTER")
	f:SetFrameStrata("DIALOG")
	f:SetMovable(true)
	f:EnableMouse(true)
	f:SetClampedToScreen(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	ApplyBackdrop(f)
	tinsert(UISpecialFrames, "oUF_BrunConfigFrame")

	local title = f:CreateFontString(nil, "OVERLAY")
	title:SetFont(FONT, FONT_SIZE + 2, "OUTLINE")
	title:SetPoint("TOPLEFT", 16, -12)
	title:SetText("|cffff8000oUF_Brun|r Quick Settings")

	local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	closeBtn:SetPoint("TOPRIGHT", -2, -2)

	local scrollFrame = CreateFrame("ScrollFrame", "oUF_BrunConfigScrollFrame", f, "UIPanelScrollFrameTemplate")
	scrollFrame:SetPoint("TOPLEFT", 14, -38)
	scrollFrame:SetPoint("BOTTOMRIGHT", -32, 46)

	local content = CreateFrame("Frame", nil, scrollFrame)
	content:SetSize(360, 680)
	scrollFrame:SetScrollChild(content)

	local optionSections = {
		{
			title = "General Settings",
			options = {
				{ key = "enableFader", label = "Fade Player & Pet out of combat" },
				{ key = "firstNameOnly", label = "First Name Only (hide Forever surnames)" },
				{ key = "enableHealthPrediction", label = "Incoming Heal & Absorb Shields" },
				{ key = "enableThreatHighlight", label = "Aggro / Threat Backdrop Highlight" },
				{ key = "hideSelfInfo", label = "Hide Player Name & Level at Max Level" },
				{ key = "showMinimapIcon", label = "Show Minimap Quick Toggle Icon" },
			},
		},
		{
			title = "Party, Raid & Encounters",
			options = {
				{ key = "hidePartyInRaid", label = "Hide Party Frames when in a Raid" },
				{ key = "showBossFrames", label = "Enable Boss Frames (Boss 1-5)" },
				{ key = "enableTotemBar", label = "Enable Clickable Totem Bar above Player" },
				{ key = "hideCompactRaidManager", label = "Auto-fade Blizzard Raid Manager Tab" },
				{ key = "oUFRuneBar", label = "Use oUF Death Knight Rune Bar" },
				{ key = "removeBuffs", label = "Hide Default Blizzard Buff Frame" },
			},
		},
		{
			title = "Castbars & Auras",
			options = {
				{ key = "desaturateOtherDebuffs", label = "Prioritize Player Debuffs & desaturate others" },
				{ key = "playerCastBar", label = "Show Player Castbar" },
				{ key = "targetCastBar", label = "Show Target Castbar" },
				{ key = "focusCastBar", label = "Show Focus Castbar" },
				{ key = "playerShowBuffs", label = "Show Player Buffs" },
				{ key = "playerShowDebuffs", label = "Show Player Debuffs" },
				{ key = "targetShowBuffs", label = "Show Target Buffs" },
				{ key = "targetShowDebuffs", label = "Show Target Debuffs" },
				{ key = "focusShowBuffs", label = "Show Focus Buffs" },
				{ key = "focusShowDebuffs", label = "Show Focus Debuffs" },
				{ key = "partyShowBuffs", label = "Show Party Buffs" },
				{ key = "partyShowDebuffs", label = "Show Party Debuffs" },
			},
		},
	}

	local checkboxes = {}
	local opts = GetOptionsDB()
	local curY = 0

	for _, section in ipairs(optionSections) do
		local header = content:CreateFontString(nil, "OVERLAY")
		header:SetFont(FONT, SMALL_FONT_SIZE + 1, "OUTLINE")
		header:SetTextColor(1, 0.82, 0)
		header:SetPoint("TOPLEFT", 6, -curY)
		header:SetText(section.title)
		curY = curY + 20

		for _, def in ipairs(section.options) do
			local cb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
			cb:SetSize(22, 22)
			cb:SetPoint("TOPLEFT", 10, -curY)
			cb:SetChecked(opts[def.key])

			local text = cb.Text or cb:CreateFontString(nil, "OVERLAY")
			text:SetFont(FONT, SMALL_FONT_SIZE, "OUTLINE")
			text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
			text:SetTextColor(1, 1, 1)
			text:SetText(def.label)

			cb:SetScript("OnClick", function(self)
				local checked = self:GetChecked() and true or false
				GetOptionsDB()[def.key] = checked
				ApplySavedOptions()
				if def.key == "firstNameOnly" then
					for _, obj in ipairs(oUF.objects) do
						if obj.UpdateTags then obj:UpdateTags() end
					end
				end
			end)
			checkboxes[def.key] = cb
			curY = curY + 24
		end
		curY = curY + 8
	end
	content:SetHeight(curY + 10)

	local moverBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	moverBtn:SetSize(120, 24)
	moverBtn:SetPoint("BOTTOMLEFT", 14, 12)
	local function UpdateMoverBtnText()
		moverBtn:SetText(manualMoversUnlocked and "Lock Movers" or "Unlock Movers")
	end
	UpdateMoverBtnText()
	moverBtn:SetScript("OnClick", function()
		if InCombatLockdown() then return end
		manualMoversUnlocked = not manualMoversUnlocked
		UpdateEditModeMovers()
		UpdateMoverBtnText()
	end)

	local resetBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	resetBtn:SetSize(110, 24)
	resetBtn:SetPoint("BOTTOM", 0, 12)
	resetBtn:SetText("Reset Defaults")
	resetBtn:SetScript("OnClick", function()
		if InCombatLockdown() then return end
		table.wipe(GetOptionsDB())
		table.wipe(GetPositionsDB())
		local freshOpts = GetOptionsDB()
		for k, cb in pairs(checkboxes) do
			cb:SetChecked(freshOpts[k])
		end
		for _, mover in pairs(movers) do
			mover.anchor:ClearAllPoints()
			mover.anchor:SetPoint(unpack(mover.defaultPoint))
		end
		ApplySavedOptions()
	end)

	local reloadBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	reloadBtn:SetSize(110, 24)
	reloadBtn:SetPoint("BOTTOMRIGHT", -14, 12)
	reloadBtn:SetText("Reload UI")
	reloadBtn:SetScript("OnClick", ReloadUI)

	f:SetScript("OnShow", function()
		local curOpts = GetOptionsDB()
		for k, cb in pairs(checkboxes) do
			cb:SetChecked(curOpts[k])
		end
		UpdateMoverBtnText()
	end)

	configFrame = f
end

--===================================================--
-- Minimap Button
--===================================================--

local function CreateMinimapButton()
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
		local q = 1
		if x < 0 then q = q + 1 end
		if y > 0 then q = q + 2 end

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
			if InCombatLockdown() then return end
			manualMoversUnlocked = not manualMoversUnlocked
			UpdateEditModeMovers()
		else
			ToggleConfigGUI()
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
	local opts = GetOptionsDB()
	btn:SetShown(opts.showMinimapIcon ~= false)
end

SLASH_OUFBRUN1 = "/brun"
SLASH_OUFBRUN2 = "/oufbrun"
SlashCmdList["OUFBRUN"] = function(msg)
	msg = (msg or ""):lower():match("^%s*(.-)%s*$")
	if msg == "move" or msg == "unlock" or msg == "lock" then
		if InCombatLockdown() then return end
		manualMoversUnlocked = not manualMoversUnlocked
		UpdateEditModeMovers()
	else
		ToggleConfigGUI()
	end
end

--===================================================--
-- Clickable Totem Bar & Raid Manager Auto-Fade
--===================================================--

local function SortTotemButtons(a, b)
	return (a.layoutIndex or 0) < (b.layoutIndex or 0)
end

local function CreateTotemBar(self)
	if not enableTotemBar then return end
	local nativeFrame = _G.TotemFrame
	if not nativeFrame or not nativeFrame.totemPool then return end

	local size, spacing = 22, 3
	local maxTotems = _G.MAX_TOTEMS or 4
	local bar = CreateFrame("Frame", nil, self)
	bar:SetSize(size * maxTotems + spacing * (maxTotems - 1), size)
	bar:SetPoint("BOTTOMLEFT", self.Health, "TOPLEFT", 0, 4)
	bar:Hide()
	self.BrunTotems = bar

	for i = 1, maxTotems do
		local totem = CreateFrame("Frame", nil, bar)
		totem:SetSize(size, size)
		if i == 1 then
			totem:SetPoint("LEFT", bar, "LEFT", 0, 0)
		else
			totem:SetPoint("LEFT", bar[i - 1], "RIGHT", spacing, 0)
		end

		local icon = totem:CreateTexture(nil, "BORDER")
		icon:SetAllPoints(totem)
		icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		totem.Icon = icon

		local overlay = totem:CreateTexture(nil, "OVERLAY")
		overlay:SetPoint("TOPLEFT", -2.5, 2.5)
		overlay:SetPoint("BOTTOMRIGHT", 2.5, -2.5)
		overlay:SetTexture(BORDER_TEXTURE)
		overlay:SetVertexColor(0.31, 0.45, 0.63)

		local gloss = totem:CreateTexture(nil, "OVERLAY")
		gloss:SetPoint("TOPLEFT", -3, 3)
		gloss:SetPoint("BOTTOMRIGHT", 3, -3)
		gloss:SetTexture(GLOSS_TEXTURE)
		gloss:SetVertexColor(0.84, 0.75, 0.65)
		gloss:SetBlendMode("ADD")

		local text = totem:CreateFontString(nil, "OVERLAY")
		text:SetFont(FONT, 10, "OUTLINE")
		text:SetPoint("TOP", totem, "TOP", 0, 2)
		text:SetTextColor(1, 1, 1)
		if C_DurationUtil and C_DurationUtil.CreateDurationTextBinding and auraDurationFormatter then
			text.binding = C_DurationUtil.CreateDurationTextBinding()
			text.binding:SetFontString(text)
			text.binding:SetFormatter(auraDurationFormatter)
			text.binding:SetExpiredText("")
			text.binding:SetZeroDurationText("")
			text.binding:SetEnabled(false)
		end
		totem.Time = text
		totem:Hide()
		bar[i] = totem
	end

	local active = {}
	local function UpdateTotemBar()
		table.wipe(active)
		for button in nativeFrame.totemPool:EnumerateActive() do
			if button:IsShown() then
				active[#active + 1] = button
			end
		end
		table.sort(active, SortTotemButtons)

		for i = 1, maxTotems do
			local totem, button = bar[i], active[i]
			if button then
				if button.Icon and button.Icon.Texture then
					totem.Icon:SetTexture(button.Icon.Texture:GetTexture())
				end
				if totem.Time.binding and GetTotemDuration and button.slot then
					totem.Time.binding:SetDuration(GetTotemDuration(button.slot))
					totem.Time.binding:SetEnabled(true)
				end
				totem:Show()

				button:ClearAllPoints()
				button:SetParent(totem)
				button:SetAllPoints(totem)
				button:SetAlpha(0)
				button:SetFrameLevel(totem:GetFrameLevel() + 3)
				button:EnableMouse(true)
			else
				totem.Icon:SetTexture(nil)
				if totem.Time.binding then
					totem.Time.binding:SetEnabled(false)
				end
				totem.Time:SetText("")
				totem:Hide()
			end
		end
		bar:SetShown(#active > 0)
	end

	hooksecurefunc(nativeFrame, "Update", UpdateTotemBar)
	UpdateTotemBar()
end

do
	local rmLoader = CreateFrame("Frame")
	rmLoader:RegisterEvent("PLAYER_ENTERING_WORLD")
	rmLoader:SetScript("OnEvent", function(self)
		self:UnregisterAllEvents()
		ApplySavedOptions()
		CreateMinimapButton()
		if not hideCompactRaidManager then return end
		local manager = _G.CompactRaidFrameManager
		if not manager then return end
		local function RefreshAlpha()
			if manager.collapsed and not manager:IsMouseOver() then
				manager:SetAlpha(0)
			else
				manager:SetAlpha(1)
			end
		end
		manager:HookScript("OnEnter", function() manager:SetAlpha(1) end)
		manager:HookScript("OnLeave", function()
			C_Timer.After(0.8, RefreshAlpha)
		end)
		manager:HookScript("OnShow", RefreshAlpha)
		RefreshAlpha()
	end)
end

--===================================================--
-- Unit-Specific Configurations
--===================================================--

local UnitSpecific = {
	player = function(self)
		local hp, pp = self.Health, self.Power
		self.fade = enableFader
		CreateCostPrediction(pp, width)

		local altPower = CreateFrame("StatusBar", nil, self)
		altPower:SetPoint("BOTTOMLEFT", hp, "TOPLEFT", 0, 28)
		altPower:SetStatusBarTexture(TEXTURE)
		altPower:SetSize(width, 9)
		ApplyBackdrop(altPower)
		altPower:EnableMouse(true)
		altPower.colorPower = true
		altPower.smoothing = smoothInterpolation

		local altBg = altPower:CreateTexture(nil, "BORDER")
		altBg:SetAllPoints()
		altBg:SetTexture(TEXTURE)
		altBg:SetAlpha(0.3)
		altPower.bg = altBg
		altPower.PostUpdateColor = PostUpdateBarColor

		local altText = altPower:CreateFontString(nil, "OVERLAY")
		altText:SetFont(FONT, SMALL_FONT_SIZE, "OUTLINE")
		altText:SetPoint("CENTER")
		altText:SetTextColor(1, 1, 1)
		altPower.Text = altText
		altPower.PostUpdate = function(element, _, cur, _, max)
			if not cur or not max then
				element.Text:SetText("")
				return
			end
			element.Text:SetFormattedText("%s/%s", ns.siValue(cur), ns.siValue(max))
		end
		self.AlternativePower = altPower

		local combat = pp:CreateTexture(nil, "OVERLAY")
		combat:SetSize(16, 16)
		combat:SetPoint("CENTER", pp, "BOTTOMLEFT", -5, -2)
		self.CombatIndicator = combat

		if playerClass == "DEATHKNIGHT" and oUFRuneBar then
			local runes = CreateFrame("Frame", nil, self)
			runes:SetPoint("TOPLEFT", pp, "BOTTOMLEFT", 0, -3)
			runes:SetSize(width, 7)
			ApplyBackdrop(runes)
			runes.colorSpec = true
			runes.sortOrder = "asc"

			local runeWidth = width / 6 - 0.2
			for i = 1, 6 do
				local bar = CreateFrame("StatusBar", nil, runes)
				bar:SetStatusBarTexture(TEXTURE)
				bar:SetSize(runeWidth, 7)
				if i == 1 then
					bar:SetPoint("TOPLEFT")
				else
					bar:SetPoint("LEFT", runes[i - 1], "RIGHT", 0.2, 0)
				end
				runes[i] = bar
			end

			self.Runes = runes
			MODULEGAP = 11
		end

		if playerClass == "DRUID" or playerClass == "PRIEST" or playerClass == "SHAMAN" then
			local addPower = CreateFrame("StatusBar", nil, self)
			addPower:SetPoint("TOPLEFT", pp, "BOTTOMLEFT", 0, -3)
			addPower:SetStatusBarTexture(TEXTURE)
			addPower:SetSize(width, 7)
			ApplyBackdrop(addPower)
			addPower:SetAlpha(0.85)
			addPower.frequentUpdates = true
			addPower.colorPower = true
			addPower.smoothing = smoothInterpolation

			local addBg = addPower:CreateTexture(nil, "BORDER")
			addBg:SetAllPoints()
			addBg:SetTexture(TEXTURE)
			addBg:SetAlpha(0.3)
			addPower.bg = addBg
			addPower.PostUpdateColor = PostUpdateBarColor

			if ALT_POWER_BAR_PAIR_DISPLAY_INFO then
				addPower.displayPairs = CopyTable(ALT_POWER_BAR_PAIR_DISPLAY_INFO)
				if playerClass == "DRUID" then
					addPower.displayPairs.DRUID = addPower.displayPairs.DRUID or {}
					addPower.displayPairs.DRUID[Enum.PowerType.Energy] = true
					addPower.displayPairs.DRUID[Enum.PowerType.Rage] = true
				end
			end

			local addText = addPower:CreateFontString(nil, "OVERLAY")
			addText:SetFont(FONT, SMALL_FONT_SIZE, "OUTLINE")
			addText:SetPoint("CENTER")
			addText:SetTextColor(1, 1, 1)
			addPower.Text = addText

			addPower.PostUpdate = function(element, cur, max)
				if not element:IsShown() then
					element.Text:SetText("")
					return
				end
				if issecretvalue(cur) or issecretvalue(max) then
					element.Text:SetFormattedText("%s", ns.FormatZero(cur, string.format("%s/%s", ns.siValue(cur), ns.siValue(max))))
				elseif max and max > 0 and cur ~= max then
					element.Text:SetFormattedText("%s - %d%%", ns.siValue(cur), math.floor(cur / max * 100))
				else
					element.Text:SetText("")
				end
			end

			addPower.PostVisibility = function(_, isVisible)
				local gap = isVisible and 11 or 0
				if self.Castbar then
					self.Castbar:SetPoint("TOPLEFT", pp, "BOTTOMLEFT", 0, -2 - gap)
					self.Castbar:SetPoint("TOPRIGHT", pp, "BOTTOMRIGHT", 0, -2 - gap)
				end
				if self.PlayerDebuffs then
					self.PlayerDebuffs:SetPoint("TOPLEFT", pp, "BOTTOMLEFT", 0, -EXPREPBARGAP - gap + 2)
					self.PlayerDebuffs:SetPoint("TOPRIGHT", pp, "BOTTOMRIGHT", 0, -EXPREPBARGAP - gap + 2)
				end
			end

			self.AdditionalPower = addPower
		end

		if not isMaxLevel then
			local resting = pp:CreateTexture(nil, "OVERLAY")
			resting:SetSize(25, 20)
			resting:SetPoint("BOTTOMLEFT", -15, -10)
			self.RestingIndicator = resting
		end

		if playerShowBuffs then
			local buffs = CreateAuraWidget(self, "HELPFUL", width, playerBuffsSize, playerBuffSpacing, "LEFT", "UP")
			buffs:SetPoint("BOTTOMRIGHT", hp, "TOPRIGHT", 0, 4)
		end
		if playerShowDebuffs then
			local debuffs = CreateAuraWidget(self, "HARMFUL", width, playerDebuffSize, playerDebuffSpacing, "LEFT", "DOWN")
			debuffs:SetPoint("TOPLEFT", pp, "BOTTOMLEFT", 0, -EXPREPBARGAP - MODULEGAP + 2)
			debuffs:SetPoint("TOPRIGHT", pp, "BOTTOMRIGHT", 0, -EXPREPBARGAP - MODULEGAP + 2)
			self.PlayerDebuffs = debuffs
		end
		if playerCastBar then
			CreateCastbar(self, pp, -2 - MODULEGAP, true)
		end
		CreateTotemBar(self)
	end,

	pet = function(self)
		self.fade = enableFader
		self.Health.colorHappiness = true

		if petShowAura then
			local auras = CreateAuraWidget(self, "BOTH", petWidth, petHeight, 2, "LEFT", "DOWN")
			auras:SetPoint("TOPRIGHT", self, "TOPLEFT", -3, 0)
		end

		if petCastBar then
			local cb = CreateFrame("StatusBar", nil, self)
			cb:SetStatusBarTexture(TEXTURE)
			cb:SetStatusBarColor(1, 0.25, 0.35, 0.5)
			cb:SetAllPoints(self.Health)
			cb:SetToplevel(true)
			cb.smoothing = smoothInterpolation
			self.Castbar = cb
		end
	end,

	target = function(self)
		local hp, pp = self.Health, self.Power
		if playerClass == "ROGUE" or playerClass == "DRUID" then
			self.CPoints = {}
			for i = 1, 5 do
				local dot = pp:CreateTexture(nil, "OVERLAY")
				dot:SetTexture(COMBO)
				dot:Hide()
				if i == 1 then
					dot:SetSize(10, 10)
					dot:SetPoint("CENTER", pp, "CENTER", 30, -1)
					dot:SetVertexColor(1, 84 / 255, 0)
				else
					local sz = 10 + (i * 0.5)
					dot:SetSize(sz, sz)
					dot:SetPoint("RIGHT", self.CPoints[i - 1], "LEFT", -2, 0)
				end
				self.CPoints[i] = dot
			end
			self.CPoints[2]:SetVertexColor(1, 162 / 255, 0)
			self.CPoints[3]:SetVertexColor(1, 246 / 255, 0)
			self.CPoints[4]:SetVertexColor(204 / 255, 1, 0)
			self.CPoints[5]:SetVertexColor(76 / 255, 236 / 255, 0)

			local cpWatcher = CreateFrame("Frame", nil, self)
			cpWatcher.CPoints = self.CPoints
			cpWatcher:RegisterUnitEvent("UNIT_POWER_UPDATE", "player", "vehicle")
			cpWatcher:RegisterEvent("PLAYER_TARGET_CHANGED")
			cpWatcher:SetScript("OnEvent", UpdateTargetComboPoints)
		end

		if targetCastBar then
			CreateCastbar(self, pp, -2, false)
		end
		if targetShowBuffs then
			local buffs = CreateAuraWidget(self, "HELPFUL", width, targetBuffSize, targetBuffSpacing, "LEFT", "UP")
			buffs:SetPoint("BOTTOMRIGHT", hp, "TOPRIGHT", 0, 4)
		end
		if targetShowDebuffs then
			local debuffs = CreateAuraWidget(self, "TARGET_DEBUFFS", width, targetDebuffSize, targetDebuffSpacing, "RIGHT", "DOWN")
			debuffs:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -EXPREPBARGAP)
		end
	end,

	party = function(self)
		local hp = self.Health
		if partyShowBuffs then
			local buffs = CreateAuraWidget(self, "HELPFUL", partyWidth, partyBuffSize, partyBuffSpacing, "RIGHT", "UP")
			buffs:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 0, 4)
		end
		if partyShowDebuffs then
			local debuffs = CreateAuraWidget(self, "HARMFUL", partyWidth, partyDebuffSize, partyDebuffSpacing, "LEFT", "DOWN")
			debuffs:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -4)
		end

		local lfdrole = hp:CreateTexture(nil, "OVERLAY")
		lfdrole:SetSize(14, 14)
		lfdrole:SetPoint("CENTER", self, "BOTTOMRIGHT", 1, 2)
		self.GroupRoleIndicator = lfdrole

		local readycheck = hp:CreateTexture(nil, "OVERLAY")
		readycheck:SetSize(18, 18)
		readycheck:SetPoint("CENTER")
		self.ReadyCheckIndicator = readycheck

		local resurrect = hp:CreateTexture(nil, "OVERLAY")
		resurrect:SetSize(20, 20)
		resurrect:SetPoint("CENTER")
		self.ResurrectIndicator = resurrect

		local summon = hp:CreateTexture(nil, "OVERLAY")
		summon:SetSize(22, 22)
		summon:SetPoint("CENTER")
		self.SummonIndicator = summon
	end,

	focus = function(self)
		if focusCastBar then
			CreateCastbar(self, self.Health, -2, false)
		end
		if focusShowBuffs then
			local buffs = CreateAuraWidget(self, "HELPFUL", focusWidth, focusBuffSize, focusBuffSpacing, "LEFT", "UP")
			buffs:SetPoint("BOTTOMRIGHT", self, "TOPRIGHT", 0, 4)
		end
		if focusShowDebuffs then
			local debuffs = CreateAuraWidget(self, "TARGET_DEBUFFS", focusWidth, focusDebuffSize, focusDebuffSpacing, "RIGHT", "DOWN")
			debuffs:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -EXPREPBARGAP)
		end
	end,

	boss = function(self)
		CreateCastbar(self, self.Power, -2, false)
		local buffs = CreateAuraWidget(self, "HELPFUL", partyWidth, partyBuffSize, partyBuffSpacing, "LEFT", "UP")
		buffs:SetPoint("BOTTOMRIGHT", self.Health, "TOPRIGHT", 0, 4)
		local debuffs = CreateAuraWidget(self, "TARGET_DEBUFFS", partyWidth, partyDebuffSize, partyDebuffSpacing, "RIGHT", "DOWN")
		debuffs:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -18)
	end,
}

local function Shared(self, unit, isSingle)
	unit = unit and unit:gsub("%d+$", "") or unit
	local isPartySubUnit = (unit == "partypet" or unit == "partytarget")
	local isTargetTarget = (unit == "targettarget" or unit == "targettargettarget" or unit == "focustarget")
	local hasPowerBar = (unit ~= "focus" and unit ~= "focustarget" and not isPartySubUnit)
	local fontSize = isTargetTarget and SMALL_FONT_SIZE or FONT_SIZE

	local frameWidth, frameHeight = width, height
	local hpHeight, ppHeight = height * 0.6, height * 0.4
	if unit == "focustarget" then
		frameWidth, frameHeight = partyPetAndTargetWidth + 30, focusHeight
		hpHeight = focusHeight
	elseif isTargetTarget then
		frameWidth, frameHeight = targetTargetWidth, targetTargetHeight
		hpHeight, ppHeight = targetTargetHeight * 0.6, targetTargetHeight * 0.4
	elseif unit == "pet" then
		frameWidth, frameHeight = petWidth, petHeight
		hpHeight, ppHeight = petHeight * 0.8, petHeight * 0.2
	elseif unit == "focus" then
		frameWidth, frameHeight = focusWidth, focusHeight
		hpHeight = focusHeight
	elseif isPartySubUnit then
		hpHeight = partyPetAndTargetHeight
	elseif unit == "party" or unit == "boss" then
		frameWidth, frameHeight = partyWidth, partyHeight
		hpHeight, ppHeight = partyHeight * 0.6, partyHeight * 0.4
	end

	self:SetScript("OnEnter", UnitFrameOnEnter)
	self:SetScript("OnLeave", UnitFrameOnLeave)
	self:RegisterForClicks("AnyUp")

	ApplyBackdrop(self)
	self:SetSize(frameWidth, frameHeight)
	if not isSingle and unit ~= "partytarget" then
		self.Range = {
			insideAlpha = 1,
			outsideAlpha = 0.5,
		}
	end

	local hp = CreateFrame("StatusBar", nil, self)
	hp:SetPoint("TOPRIGHT")
	hp:SetPoint("TOPLEFT")
	hp:SetStatusBarTexture(TEXTURE)
	hp:SetHeight(hpHeight)
	hp:SetAlpha(0.8)
	hp.colorDisconnected = true
	hp.colorTapping = true
	hp.colorClass = true
	hp.colorReaction = true
	hp.smoothing = smoothInterpolation
	hp.PostUpdateColor = PostUpdateBarColor
	self.Health = hp

	if enableHealthPrediction and not isPartySubUnit and not isTargetTarget then
		CreateHealthPrediction(self)
	end

	if enableThreatHighlight and not isPartySubUnit and not isTargetTarget then
		self.ThreatIndicator = {
			IsObjectType = nop,
			Show = nop,
			Hide = nop,
			PostUpdate = PostUpdateThreat,
		}
	end

	local hpbg = hp:CreateTexture(nil, "BORDER")
	hpbg:SetAllPoints(self)
	hpbg:SetTexture(TEXTURE)
	hpbg:SetAlpha(0.3)
	hp.bg = hpbg

	local hpp = hp:CreateFontString(nil, "OVERLAY")
	hpp:SetFont(FONT, fontSize, "OUTLINE")
	hpp:SetPoint("RIGHT", -1, 0)
	hpp:SetTextColor(1, 1, 1)
	hp.value = hpp
	self:Tag(hpp, unit == "pet" and "[brunhppp]" or (isPartySubUnit and "[brunminushp]" or "[brunhp]"))

	if hasPowerBar then
		local pp = CreateFrame("StatusBar", nil, self)
		pp:SetPoint("TOPRIGHT", hp, "BOTTOMRIGHT", 0, -1)
		pp:SetPoint("TOPLEFT", hp, "BOTTOMLEFT", 0, -1)
		pp:SetStatusBarTexture(TEXTURE)
		pp:SetHeight(ppHeight)
		pp.frequentUpdates = true
		pp.colorDisconnected = true
		pp.colorTapping = true
		pp.colorPower = true
		pp.smoothing = smoothInterpolation
		pp.PostUpdateColor = PostUpdateBarColor
		self.Power = pp

		local ppbg = pp:CreateTexture(nil, "BORDER")
		ppbg:SetAllPoints()
		ppbg:SetTexture(TEXTURE)
		ppbg:SetAlpha(0.3)
		pp.bg = ppbg

		if unit ~= "pet" then
			local ppp = pp:CreateFontString(nil, "OVERLAY")
			ppp:SetFont(FONT, fontSize, "OUTLINE")
			ppp:SetPoint("RIGHT", -1, 0)
			ppp:SetTextColor(1, 1, 1)
			pp.value = ppp
			self:Tag(ppp, "[brunpp]")

			if not (unit == "player" and hideSelfInfo and isMaxLevel) then
				local info = pp:CreateFontString(nil, "OVERLAY")
				info:SetPoint("LEFT", 2, 0)
				info:SetPoint("RIGHT", ppp, "LEFT", -4, 0)
				info:SetWordWrap(false)
				info:SetJustifyH("LEFT")
				info:SetFont(FONT, fontSize, "OUTLINE")
				info:SetTextColor(1, 1, 1)
				self.Info = info
				self:Tag(info, "L[difficulty][level]|cffffffff[shortclassification] [smarterrace]|r")
			end
		end
	end

	if unit == "player" or unit == "target" or unit == "party" then
		local leader = hp:CreateTexture(nil, "OVERLAY")
		leader:SetSize(14, 14)
		leader:SetPoint("CENTER", hp, "TOP", 0, 1)
		self.LeaderIndicator = leader

		local masterlooter = hp:CreateTexture(nil, "OVERLAY")
		masterlooter:SetSize(14, 14)
		masterlooter:SetPoint("CENTER", hp, "TOP", 14, 1)
		self.MasterLooterIndicator = masterlooter

		local assistant = hp:CreateTexture(nil, "OVERLAY")
		assistant:SetSize(14, 14)
		assistant:SetPoint("CENTER", hp, "TOP", 0, 1)
		self.AssistantIndicator = assistant
	end

	local ricon = hp:CreateTexture(nil, "OVERLAY")
	ricon:SetSize(14, 14)
	ricon:SetPoint("CENTER", hp, "TOP", -14, 1)
	self.RaidTargetIndicator = ricon

	local pvp = hp:CreateTexture(nil, "OVERLAY")
	if isPartySubUnit then
		pvp:SetSize(18, 18)
		pvp:SetPoint("TOPLEFT", hp, "TOPRIGHT", -5, 2)
	else
		pvp:SetSize(30, 30)
		pvp:SetPoint("TOPLEFT", hp, "TOPRIGHT", -8, 3)
	end
	self.PvPIndicator = pvp

	if unit ~= "player" and unit ~= "pet" and unit ~= "party" then
		local classification = hp:CreateTexture(nil, "OVERLAY")
		local isSmall = isPartySubUnit or isTargetTarget
		classification:SetSize(isSmall and 14 or 20, isSmall and 14 or 20)
		classification.isSmall = isSmall
		self.ClassificationIndicator = classification

		local quest = hp:CreateTexture(nil, "OVERLAY")
		quest:SetSize(isSmall and 14 or 18, isSmall and 14 or 18)
		quest:SetPoint("CENTER", hp, "TOPLEFT", 0, 0)
		self.QuestIndicator = quest
	end

	if unit == "party" or unit == "target" or unit == "focus" then
		local phase = CreateFrame("Frame", nil, hp)
		phase:SetSize(16, 16)
		phase:SetPoint("CENTER", hp, "TOP", 28, 1)
		phase:EnableMouse(true)
		local phaseIcon = phase:CreateTexture(nil, "OVERLAY")
		phaseIcon:SetAllPoints()
		phase.Icon = phaseIcon
		self.PhaseIndicator = phase
	end

	local name = hp:CreateFontString(nil, "OVERLAY")
	name:SetPoint("LEFT", 2, 0)
	name:SetPoint("RIGHT", hpp, "LEFT", -4, 0)
	name:SetWordWrap(false)
	name:SetJustifyH("LEFT")
	name:SetFont(FONT, fontSize, "OUTLINE")
	self.Name = name
	local nameTag = "[NormalName] [afkdnd]"
	if isPartySubUnit then
		nameTag = "[ShortName]"
	elseif unit == "player" and hideSelfInfo and isMaxLevel then
		nameTag = "[afkdnd]"
	elseif unit == "pet" and playerClass == "HUNTER" and C_PetInfo and C_PetInfo.GetPetHappiness then
		nameTag = "[happiness]"
	end
	self:Tag(name, nameTag)

	local hl = self:CreateTexture(nil, "HIGHLIGHT")
	hl:SetPoint("TOPLEFT", 0, -1)
	hl:SetPoint("BOTTOMRIGHT", 0, -1)
	hl:SetBlendMode("ADD")
	hl:SetTexture(HIGHLIGHT)
	self.Highlight = hl

	if UnitSpecific[unit] then
		return UnitSpecific[unit](self)
	end
end

oUF:RegisterStyle("Brun", Shared)

local function SpawnFrames(self)
	if InCombatLockdown() then
		local defer = CreateFrame("Frame")
		defer:RegisterEvent("PLAYER_REGEN_ENABLED")
		defer:SetScript("OnEvent", function(f)
			f:UnregisterAllEvents()
			SpawnFrames(self)
		end)
		return
	end

	ApplySavedOptions()
	self:SetActiveStyle("Brun")

	local playerAnchor = CreatePositionAnchor("Player", width, height, oUF_Brun.Player)
	self:Spawn("player", "oUF_player"):SetPoint("CENTER", playerAnchor, "CENTER", 0, 0)

	local targetAnchor = CreatePositionAnchor("Target", width, height, oUF_Brun.Target)
	self:Spawn("target", "oUF_target"):SetPoint("CENTER", targetAnchor, "CENTER", 0, 0)

	local totAnchor = CreatePositionAnchor("ToT", targetTargetWidth, targetTargetHeight, oUF_Brun.ToT)
	self:Spawn("targettarget", "oUF_TargetTarget"):SetPoint("CENTER", totAnchor, "CENTER", 0, 0)

	local tototAnchor = CreatePositionAnchor("ToToT", targetTargetWidth, targetTargetHeight, oUF_Brun.ToToT)
	self:Spawn("targettargettarget", "oUF_ToToT"):SetPoint("CENTER", tototAnchor, "CENTER", 0, 0)

	local focusAnchor = CreatePositionAnchor("Focus", focusWidth, focusHeight, oUF_Brun.Focus)
	self:Spawn("focus", "oUF_Focus"):SetPoint("CENTER", focusAnchor, "CENTER", 0, 0)

	local focusTargetAnchor = CreatePositionAnchor("FocusTarget", partyPetAndTargetWidth + 30, focusHeight, oUF_Brun.FocusTarget)
	self:Spawn("focustarget", "oUF_FocusTarget"):SetPoint("CENTER", focusTargetAnchor, "CENTER", 0, 0)

	local petAnchor = CreatePositionAnchor("Pet", petWidth, petHeight, oUF_Brun.Pet)
	self:Spawn("pet", "oUF_Pet"):SetPoint("CENTER", petAnchor, "CENTER", 0, 0)

	if showBossFrames and MAX_BOSS_FRAMES then
		local bossGroupHeight = MAX_BOSS_FRAMES * partyHeight + (MAX_BOSS_FRAMES - 1) * 48
		local bossAnchor = CreatePositionAnchor("Boss", partyWidth, bossGroupHeight, oUF_Brun.Boss)
		local prevBoss
		for i = 1, MAX_BOSS_FRAMES do
			local boss = self:Spawn("boss" .. i, "oUF_Boss" .. i)
			if prevBoss then
				boss:SetPoint("TOPRIGHT", prevBoss, "BOTTOMRIGHT", 0, -48)
			else
				boss:SetPoint("TOPRIGHT", bossAnchor, "TOPRIGHT", 0, 0)
			end
			prevBoss = boss
		end
	end

	if not oUFRuneBar and playerClass == "DEATHKNIGHT" and RuneFrame then
		if RuneFrame:GetParent() == PlayerFrame then
			RuneFrame:SetParent(UIParent)
		end
		RuneFrame:ClearAllPoints()
		RuneFrame:SetPoint(unpack(oUF_Brun.Runeframe))
		RuneFrame:Show()
	end

	local partySpacing = 48
	local partyGroupHeight = partyHeight * 4 + partySpacing * 3
	local partyGroup = CreateFrame("Frame", "oUF_BrunPartyGroup", UIParent, "SecureHandlerStateTemplate")
	local partyAnchor = CreatePositionAnchor("Party", partyWidth, partyGroupHeight, oUF_Brun.Party)
	partyGroup:SetPoint("TOPLEFT", partyAnchor, "TOPLEFT", 0, 0)
	partyGroup:SetSize(partyWidth, partyGroupHeight)

	local prevParty
	for i = 1, 4 do
		local partyFrame = self:Spawn("party" .. i, "oUF_Party" .. i)
		partyFrame:SetParent(partyGroup)
		partyFrame:ClearAllPoints()
		if prevParty then
			partyFrame:SetPoint("TOPLEFT", prevParty, "BOTTOMLEFT", 0, -partySpacing)
		else
			partyFrame:SetPoint("TOPLEFT", partyGroup, "TOPLEFT", 0, 0)
		end
		prevParty = partyFrame

		partyFrame:RegisterEvent("GROUP_ROSTER_UPDATE", function(frame)
			if UnitExists(frame.__unit) then
				frame:UpdateAllElements("GROUP_ROSTER_UPDATE")
			end
		end, true)
		partyFrame:RegisterEvent("UNIT_CONNECTION", function(frame)
			if UnitExists(frame.__unit) then
				frame:UpdateAllElements("UNIT_CONNECTION")
			end
		end, true)
	end

	RegisterStateDriver(partyGroup, "visibility", hidePartyInRaid and "[group:raid] hide; [group:party] show; hide" or "[group:party] show; hide")
end

oUF:Factory(SpawnFrames)
