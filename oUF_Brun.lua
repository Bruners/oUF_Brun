--[[-------------------------------------------------------------------------
  Lasse G. Brun grants anyone the right to use this work for any purpose,
  without any conditions, unless such conditions are required by law.
---------------------------------------------------------------------------]]

local oUF_Brun = {
-- (point , frame , relativePoint , x , y)
	Player = {"RIGHT", UIParent, "CENTER", -98, -340},
	Target = {"LEFT", UIParent, "CENTER", 98, -340},
	Pet = {"RIGHT", "oUF_player", "LEFT", -25, 0},
	Focus = {"TOP", UIParent, "TOP", 250,-30},
	FocusTarget = {"TOP", "oUF_Focus", "BOTTOM", 0,-30},
	ToT = {"LEFT", "oUF_player", "RIGHT", 14, 5},
	ToToT = {"LEFT", "oUF_player", "RIGHT", 14, -28},
	Party = {"TOPLEFT", UIParent, "TOPLEFT", 20, -50},
	Runeframe = {"TOPLEFT", "oUF_player", "BOTTOMLEFT", 0, -20}, -- Coords for the blizzard runes
}

local oUFRuneBar = false							-- Enable/Disable the rune bar delivered by oUF.
local removeBuffs = false							-- Enable/Disable blizzard default buff frame.
local hideSelfInfo = true							-- Enable/Disable name and level info on playerframe when at max level.
local hidePartyInRaid = false						-- Enable/Disable party frames in raid.

local FONT_SIZE = 14								-- Largest font on frames ( most frames )
local SMALL_FONT_SIZE = 12							-- Smallest font on frames ( target's target )

local FONT = ("Interface\\Addons\\oUF_Brun\\textures\\Font.ttf")
local TEXTURE = ("Interface\\Addons\\oUF_Brun\\textures\\Statusbar")
local HIGHLIGHT = ("Interface\\QuestFrame\\UI-QuestTitleHighlight")
local COMBO = ("Interface\\Addons\\oUF_Brun\\textures\\pb4combo")

local height, width = 35, 252						-- Default frame height and width used by several frames.

local playerShowBuffs = true						-- Enable/disable uffs on player.
local playerShowDebuffs = true						-- Enable/disable debuffs on player.
local playerBuffsSize = 23							-- Size of players buffs.
local playerDebuffSize = 23							-- Size of players debuffs.
local playerBuffSpacing = 2							-- Buff spacing
local playerDebuffSpacing = 2						-- Debuff spacing
local playerCastBar = true							-- Enable/Disable castbar on player.

local targetShowBuffs = true						-- Enable/disable buffs on target.
local targetShowDebuffs = true						-- Enable/disable debuffs on target.
local targetBuffSize = 23							-- Size of targets buffs.
local targetDebuffSize = 23							-- Size of targets debuffs.
local targetBuffSpacing = 2							-- Buff spacing
local targetDebuffSpacing = 2						-- Debuff spacing
local targetCastBar = true							-- Enable/Disable castbar on target.

local targetTargetHeight = height-10				-- Target's target height.
local targetTargetWidth = width-85 					-- Target's target width.

local petHeight, petWidth = 15, 152					-- Player pet height and width.
local petShowAura = true							-- Enable/disable aura on pet.
local petCastBar = true								-- Enable/disable castbar on pet.

local focusHeight, focusWidth = 20, 200				-- Foucs height and width.
local focusShowBuffs = true							-- Enable/disable buffs on focus.
local focusShowDebuffs = true						-- Enable/disable debuffs on focus.
local focusBuffSize = 20							-- Size of focus buffs.
local focusDebuffSize = 20							-- Size of focus debuffs.
local focusBuffSpacing = 2							-- Buff spacing
local focusDebuffSpacing = 2						-- Debuff spacing
local focusCastBar = true							-- Enable/Disable castbar on focus.

local partyHeight, partyWidth = height, width-50	-- Party height and width.
local partyShowBuffs = true							-- Enable/disable buffs on party.
local partyShowDebuffs = true						-- Enable/disable debuffs on party.
local partyBuffSize = 17							-- Size of party buffs.
local partyDebuffSize = 17							-- Size of party debuffs.
local partyBuffSpacing = 2							-- Debuff spacing
local partyDebuffSpacing = 2						-- Debuff spacing

local partyPetAndTargetHeight = 15					-- Party target and party pet height.
local partyPetAndTargetWidth = 95					-- Party target and party pet width.

local substr = string.sub
local _, playerClass = UnitClass("player")
local RUNEBARGAP = 0
local EXPREPBARGAP = 21
local backdrop = {
	bgFile="Interface\\Tooltips\\UI-Tooltip-Background",
	tile = true, 
	insets ={left = -2, right = -2, top = -2, bottom = -2}
}

oUF.colors.power["MANA"] = {48/255, 113/255, 191/255}
oUF.colors.power["RAGE"] = {226/255, 45/255, 75/255}
oUF.colors.power["FOCUS"] = {1, 210/255, 0}
oUF.colors.power["ENERGY"] = {1, 220/255, 25/255}
oUF.colors.power["RUNIC_POWER"] = {48/255, 113/255, 191/255}
oUF.colors.tapped = {.55,.57,.61}
oUF.colors.disconnected = {0.7, 0.7, 0.7}
oUF.colors.runes = {
	[1] = {1, 0, 0},
	[2] = {0, 0.5, 0},
	[3] = {0, 0.4, 0.7},
	[4] = {0.8, 0.1, 1},
}

if(removeBuffs == true) then
	BuffFrame:Hide()
	TemporaryEnchantFrame:Hide()
end

local menu = function(self)
	local unit = self.unit:sub(1, -2)
	local cunit = self.unit:gsub("(.)", string.upper, 1)

	if(unit == "party" or unit == "partypet") then
		ToggleDropDownMenu(1, nil, _G["PartyMemberFrame"..self.id.."DropDown"], "cursor", 0, 0)
	elseif(_G[cunit.."FrameDropDown"]) then
		ToggleDropDownMenu(1, nil, _G[cunit.."FrameDropDown"], "cursor", 0, 0)
	end
end

local function GetCurrentAspect()
	return UnitBuff("player", "Aspect of the Hawk") or UnitBuff("player", "Aspect of the Viper") or "Unknown"
end

local function GetManaPercent()
	return ((UnitMana("player") / UnitManaMax("player")) * 100)
end

local function PostUpdateReputation(self, event, unit, bar)
	local _, id = GetWatchedFactionInfo()
	bar:SetStatusBarColor(FACTION_BAR_COLORS[id].r, FACTION_BAR_COLORS[id].g, FACTION_BAR_COLORS[id].b)
end

local function updateCPoints(self, event, unit)
	if unit == PlayerFrame.unit and unit ~= self.CPoints.unit then
		self.CPoints.unit = unit
	end
end

local function PostCreateAuraIcon(self, button, icons)
	icons.showDebuffType = true
	icons.gap = 1
	button.cd:SetReverse()
	button.icon:SetTexCoord(.07, .93, .07, .93)

	self.ButtonOverlay = button:CreateTexture(nil, "OVERLAY")
	self.ButtonOverlay:SetPoint("TOPLEFT", -2.5, 2.5)
	self.ButtonOverlay:SetPoint("BOTTOMRIGHT", 2.5, -2.5)
	self.ButtonOverlay:SetTexture("Interface\\Addons\\oUF_Brun\\textures\\border")
	self.ButtonOverlay:SetVertexColor(.31,.45,.63)
	self.ButtonOverlay:SetBlendMode("BLEND")

	self.ButtonGloss = button:CreateTexture(nil, "OVERLAY")
	self.ButtonGloss:SetPoint("TOPLEFT", -3, 3)
	self.ButtonGloss:SetPoint("BOTTOMRIGHT", 3, -3)
	self.ButtonGloss:SetTexture("Interface\\Addons\\oUF_Brun\\textures\\gloss")
	self.ButtonGloss:SetVertexColor(.84,.75,.65)
	self.ButtonGloss:SetBlendMode("ADD")
end

local PostUpdateAuraIcon
do
	local playerUnits = {
		player = true,
		pet = true,
		vehicle = true,
	}

	PostUpdateAuraIcon = function(self, icons, unit, icon, index, offset, filter, isDebuff)
		local texture = icon.icon
		if(playerUnits[icon.owner]) then
			texture:SetDesaturated(false)
		else
			texture:SetDesaturated(true)
		end
	end
end

local function castbarStyle(cb)
	local cbsp = cb:CreateTexture(nil, "OVERLAY")
	cbsp:SetHeight(30)
	cbsp:SetBlendMode("ADD")
	cbsp:SetWidth(10)
	cbsp:SetTexCoord(0, 0, 0, 1, 1, 0, 1, 1)

	cb.Spark = cbsp

	local cbtime = cb:CreateFontString(nil, "OVERLAY")
	cbtime:SetPoint("RIGHT", cb, -5, 1)
	cbtime:SetTextColor(1, 1, 1)
	cbtime:SetJustifyH("RIGHT")
	cbtime:SetShadowOffset(1, -1)
	cbtime:SetFont(FONT, SMALL_FONT_SIZE, "OUTLINE")

	cb.Time = cbtime

	local cbtext = cb:CreateFontString(nil, "OVERLAY")
	cbtext:SetPoint("LEFT", cb, 15, 1)
	cbtext:SetWidth(240)
	cbtext:SetTextColor(1, 1, 1)
	cbtext:SetShadowOffset(1, -1)
	cbtext:SetJustifyH("LEFT")
	cbtext:SetFont(FONT, SMALL_FONT_SIZE, "OUTLINE")

	cb.Text = cbtext

	local cbicon = cb:CreateTexture(nil, "OVERLAY")
	cbicon:SetHeight(cb:GetHeight()+1)
	cbicon:SetWidth(cb:GetHeight()+1)
	cbicon:SetTexCoord(0.07, .93, .07, .93)
	cbicon:SetPoint("TOPLEFT", cb, "TOPLEFT", -2, 0)

	cb.Icon = cbicon

	cb.CustomTimeText = function(self, duration)
		if self.casting then
			self.Time:SetFormattedText("%.1f", self.max - duration)
		elseif self.channeling then
			self.Time:SetFormattedText("%.1f", duration)
		end
	end
end

local UnitSpecific = {
	player = function(self)
		local hp, pp = self.Health, self.Power
		local combat = pp:CreateTexture(nil, "OVERLAY")
		combat:SetHeight(17)
		combat:SetWidth(17)
		combat:SetPoint("BOTTOMLEFT", pp, -8,-5)
		combat:SetTexCoord(0.58, 0.90, 0.08, 0.41)

		self.Combat = combat

		if (playerClass == "DEATHKNIGHT") then
			if oUFRuneBar == true then
				self:SetAttribute("initial-height", height-7)
				pp:SetHeight(height*0.4 -7)
				pp.value:SetFont(FONT, SMALL_FONT_SIZE , "OUTLINE")
				
				local runes = CreateFrame("Frame", nil, self)
				runes:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -5)
				runes:SetHeight(7)
				runes:SetWidth(width)
				runes:SetBackdrop(backdrop)
				runes:SetBackdropColor(0, 0, 0, .9)
				runes.order = { 1, 2, 5, 6, 3, 4}
				runes.height = 7
				runes.width = width / 6 - 0.75

				for i = 1, 6 do
					local bar = CreateFrame("StatusBar", nil, runes)
					bar:SetStatusBarTexture(TEXTURE)
					
					runes[i] = bar
				end
				
				self.Runes = runes
				RUNEBARGAP = 11
			end
		end

		if(playerClass == "DRUID") then
			self.DruidPower = CreateFrame("StatusBar", nil, self)
			self.DruidPower:SetPoint("TOP", self.Castbar, "BOTTOM")
			self.DruidPower:SetStatusBarTexture(TEXTURE)
			self.DruidPower:SetHeight(1)
			self.DruidPower:SetWidth(width)
			self.DruidPower.colors = self.colors
			self.DruidPower:SetScript("OnEvent", UpdateDruidPower)
			self.DruidPower:RegisterEvent("UNIT_MANA")
			self.DruidPower:RegisterEvent("UNIT_ENERGY")
			self.DruidPower:RegisterEvent("PLAYER_LOGIN")
			self.DruidPower.Text = self.DruidPower:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
			self.DruidPower.Text:SetPoint("CENTER", self.DruidPower)
			self.DruidPower.Text:SetTextColor(oUF.colors.power["MANA"])
		end

		if UnitLevel("player") ~= MAX_PLAYER_LEVEL then
			local resting = pp:CreateTexture(nil, "OVERLAY")
			resting:SetHeight(20)
			resting:SetWidth(25)
			resting:SetPoint("BOTTOMLEFT", -15, -10)
			self.Resting = resting
		else
			if (hideSelfInfo == true) then
				self.Info:Hide()
				self:Tag(self.Name, "[afkdnd]")
			end
		end	

		if(IsAddOnLoaded"oUF_CombatFeedback") then
			self.CombatFeedbackText = self.Infoliner
			self.CombatFeedbackText.maxAlpha = .8
		end

		if(IsAddOnLoaded"oUF_Experience" and UnitLevel("player") ~= MAX_PLAYER_LEVEL) then
			self.Experience = CreateFrame("StatusBar", nil, self)
			self.Experience:SetPoint("TOPLEFT", pp, "BOTTOMLEFT", 0,-2-RUNEBARGAP)
			self.Experience:SetPoint("TOPRIGHT", pp, "BOTTOMRIGHT",0,-2-RUNEBARGAP)
			self.Experience:SetHeight(13)
			self.Experience:SetStatusBarTexture(TEXTURE)
			self.Experience:SetStatusBarColor(0, 0.4, 1, 1)
			self.Experience.Tooltip = true

			self.Experience.Rested = CreateFrame("StatusBar", nil, self)
			self.Experience.Rested:SetAllPoints(self.Experience)
			self.Experience.Rested:SetStatusBarTexture(TEXTURE)
			self.Experience.Rested:SetStatusBarColor(0, 0.4, 1, 0.7)

			self.Experience.Text = self.Experience:CreateFontString(nil, "OVERLAY")
			self.Experience.Text:SetFont(FONT, SMALL_FONT_SIZE , "OUTLINE")
			self.Experience.Text:SetPoint("CENTER", self.Experience)
			self.Experience:SetBackdrop(backdrop)
			self.Experience:SetBackdropColor(0, 0, 0, .9)
			self.Experience:SetAlpha(0.8)
			EXPREPBARGAP = 21
		elseif (IsAddOnLoaded"oUF_Reputation" and UnitLevel("player") == MAX_PLAYER_LEVEL) then
			self.Reputation = CreateFrame("StatusBar", nil, self)
			self.Reputation:SetPoint("TOPLEFT", pp, "BOTTOMLEFT", 0,-2-RUNEBARGAP)
			self.Reputation:SetPoint("TOPRIGHT", pp, "BOTTOMRIGHT",0,-2-RUNEBARGAP)
			self.Reputation:SetHeight(13)
			self.Reputation:SetStatusBarTexture(TEXTURE)
			self.Reputation.PostUpdate = PostUpdateReputation
			self.Reputation:SetFrameStrata("LOW")
			self.Reputation.Tooltip = true
			self.Reputation.Text = self.Reputation:CreateFontString(nil, "OVERLAY")
			self.Reputation.Text:SetFont(FONT, SMALL_FONT_SIZE , "OUTLINE")
			self.Reputation.Text:SetPoint("CENTER", self.Reputation)
			self.Reputation:SetBackdrop(backdrop)
			self.Reputation:SetBackdropColor(0, 0, 0, .9)
			self.Reputation:SetAlpha(0.8)
			EXPREPBARGAP = 21
		end
		if (playerShowBuffs) then
			local buffs = CreateFrame("Frame", nil, self)
			buffs:SetPoint("BOTTOMRIGHT", hp, "TOPRIGHT",0,1)
			buffs:SetHeight(playerBuffsSize)
			buffs:SetWidth(width)
			buffs.size = math.floor(buffs:GetHeight())
			buffs.num = math.floor(width / buffs.size + .5)
			buffs.spacing = playerBuffSpacing
			buffs.initialAnchor = ("TOPRIGHT")
			buffs["growth-y"] = ("UP")
			buffs["growth-x"] = ("LEFT")

			self.Buffs = buffs
		end
		if (playerShowDebuffs) then
			local debuffs = CreateFrame("Frame", nil, self)
			debuffs:SetPoint("TOPLEFT", pp, "BOTTOMLEFT", 0,-EXPREPBARGAP-RUNEBARGAP)
			debuffs:SetPoint("TOPRIGHT", pp, "BOTTOMRIGHT",0,-EXPREPBARGAP-RUNEBARGAP)
			debuffs:SetHeight(playerDebuffSize)
			debuffs:SetWidth(width)
			debuffs.size = math.floor(debuffs:GetHeight())
			debuffs.num = math.floor(width / debuffs.size + .5)
			debuffs.spacing = playerDebuffSpacing
			debuffs.initialAnchor = ("BOTTOMRIGHT")
			debuffs["growth-y"] = ("DOWN")
			debuffs["growth-x"] = ("LEFT")

			self.Debuffs = debuffs
		end
		if playerCastBar then
			local cb = CreateFrame("StatusBar", nil, self)
			cb:SetPoint("TOPLEFT", pp, "BOTTOMLEFT", 0, -2-RUNEBARGAP)
			cb:SetPoint("TOPRIGHT", pp, "BOTTOMRIGHT", 0, -2-RUNEBARGAP)
			cb:SetBackdrop(backdrop)
			cb:SetBackdropColor(0, 0, 0, .9)
			cb:SetToplevel(true)
			cb:SetStatusBarTexture(TEXTURE)
			cb:SetStatusBarColor(1.0, 0.7, 0.0)
			cb:SetHeight(14)

			self.Castbar = cb
			castbarStyle(cb)
		end
	end,

	pet = function(self)
		self:SetAttribute("initial-height", petHeight)
		self:SetAttribute("initial-width", petWidth)

		self.Health.colorHappiness = true
		self.Health:SetHeight(self:GetAttribute("initial-height")*0.8)
		self.Power:SetHeight(self:GetAttribute("initial-height")*0.2)
		self:Tag(self.Health.value, "[brunhppp]")
		self.Info:Hide()
		self.Power.value:Hide()
		local hp, pp = self.Health, self.Power
		if (petShowAura) then
			self.Auras = CreateFrame("Frame", nil, self)
			self.Auras:SetPoint("TOPRIGHT", self, "TOPLEFT", -3, 0)
			self.Auras:SetHeight(hp:GetHeight() + pp:GetHeight())
			self.Auras:SetWidth(self:GetAttribute("initial-width"))
			self.Auras.size = self:GetAttribute("initial-height")
			self.Auras.spacing = 2
			self.Auras.initialAnchor = "TOPRIGHT"
			self.Auras["growth-x"] = "LEFT"
		end

		if petCastBar then
			local cb = CreateFrame("StatusBar", nil, self)
			cb:SetStatusBarTexture(TEXTURE)
			cb:SetStatusBarColor(1, .25, .35, .5)
			cb:SetAllPoints(self.Health)
			cb:SetToplevel(true)

			self.Castbar = cb
		end

		if(playerClass == "HUNTER") then
			self:Tag(self.Name, "[happiness]")
		end
	end,

	target = function(self)
		local hp, pp = self.Health, self.Power
		self.CPoints = {}
		self.CPoints.unit = "player"
		for i = 1, 5 do
			self.CPoints[i] = pp:CreateTexture(nil, "OVERLAY")
			self.CPoints[i]:SetHeight(10)
			self.CPoints[i]:SetWidth(10)
			self.CPoints[i]:SetTexture(COMBO)
			if(i==1) then
				self.CPoints[i]:SetPoint("CENTER", pp, "CENTER", 30, -1)
				self.CPoints[i]:SetVertexColor(1,84/255,0)
			else
				self.CPoints[i]:SetPoint("RIGHT", self.CPoints[i-1], "LEFT", -2, 0)
				self.CPoints[i]:SetWidth(10+(i*0.5))
				self.CPoints[i]:SetHeight(10+(i*0.5))
			end
		end
		self.CPoints[2]:SetVertexColor(1,162/255,0)
		self.CPoints[3]:SetVertexColor(1,246/255,0)
		self.CPoints[4]:SetVertexColor(204/255,1,0)
		self.CPoints[5]:SetVertexColor(76/255,236/255,0)

		self:RegisterEvent("UNIT_COMBO_POINTS", updateCPoints)

		if targetCastBar then
			local cb = CreateFrame("StatusBar", nil, self)
			cb:SetPoint("TOPLEFT", pp, "BOTTOMLEFT", 0, -2)
			cb:SetPoint("TOPRIGHT", pp, "BOTTOMRIGHT", 0, -2)
			cb:SetBackdrop(backdrop)
			cb:SetBackdropColor(0, 0, 0, .9)
			cb:SetToplevel(true)
			cb:SetStatusBarTexture(TEXTURE)
			cb:SetStatusBarColor(1.0, 0.7, 0.0)
			cb:SetHeight(14)

			self.Castbar = cb
			castbarStyle(cb)
		end
		if (targetShowBuffs) then
			local buffs = CreateFrame("Frame", nil, self)
			buffs:SetPoint("BOTTOMRIGHT", self, "TOPRIGHT",0,1)
			buffs:SetHeight(targetBuffSize)
			buffs:SetWidth(width)
			buffs.size = math.floor(buffs:GetHeight())
			buffs.num = math.floor(width / buffs.size + .5)
			buffs.spacing = targetBuffSpacing
			buffs.initialAnchor = ("TOPRIGHT")
			buffs["growth-y"] = ("UP")
			buffs["growth-x"] = ("LEFT")

			self.Buffs = buffs
		end
		if (targetShowDebuffs) then
			local debuffs = CreateFrame("Frame", nil, self)
			debuffs:SetPoint("TOPLEFT", self, "BOTTOMLEFT",0,-EXPREPBARGAP)
			debuffs:SetHeight(targetDebuffSize)
			debuffs:SetWidth(width)
			debuffs.size = math.floor(debuffs:GetHeight())
			debuffs.num = math.floor(width / debuffs.size + .5)
			debuffs.spacing = targetDebuffSpacing
			debuffs.initialAnchor = ("BOTTOMLEFT")
			debuffs["growth-y"] = ("DOWN")
			debuffs["growth-x"] = ("RIGHT")

			self.Debuffs = debuffs
		end
	end,
	targettarget = function(self)
		local hp, pp = self.Health, self.Power
		self:SetAttribute("initial-height", targetTargetHeight)
		self:SetAttribute("initial-width", targetTargetWidth)
		self.Name:SetFont(FONT, SMALL_FONT_SIZE , "OUTLINE")
		hp.value:SetFont(FONT, SMALL_FONT_SIZE , "OUTLINE")
		pp.value:SetFont(FONT, SMALL_FONT_SIZE , "OUTLINE")
		self.Info:SetFont(FONT, SMALL_FONT_SIZE , "OUTLINE")
		self.Health:SetHeight(self:GetAttribute("initial-height")*0.6)
		self.Power:SetHeight(self:GetAttribute("initial-height")*0.4)
	end,
	party = function(self)
		local hp, pp = self.Health, self.Power
		if(self:GetAttribute"unitsuffix" == "pet") or (self:GetAttribute"unitsuffix" == "target") then
			self.Power:Hide()
			self.PvP:SetHeight(15)
			self.PvP:SetWidth(15)
			self.PvP:SetPoint("TOPRIGHT", 10, 10)
			self:Tag(self.Name, "[ShortName]")
			self:Tag(hp.value, "[brunminushp]")
			self:SetAttribute("initial-height", partyPetAndTargetHeight)
			self:SetAttribute("initial-width", partyPetAndTargetWidth)
			self.Health:SetHeight(self:GetAttribute("initial-height"))
		else
			if (partyShowBuffs) then
				self.Buffs = CreateFrame("Frame", nil, self)
				self.Buffs:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 0, 2)
				self.Buffs:SetHeight(partyBuffSize)
				self.Buffs:SetWidth(partyWidth)
				self.Buffs.spacing = partyBuffSpacing
				self.Buffs.size = math.floor(self.Buffs:GetHeight() + .8)
				self.Buffs.num = math.floor(partyWidth / self.Buffs.size + .5)
				self.Buffs.initialAnchor = "BOTTOMLEFT"
				self.Buffs["growth-y"] = "UP"
				self.Buffs["growth-x"] = "RIGHT"
			end
			if (partyShowBuffs) then
				self.Debuffs = CreateFrame("Frame", nil, self)
				self.Debuffs:SetPoint("TOPLEFT", self, "BOTTOMLEFT",0,-4)
				self.Debuffs:SetHeight(partyDebuffSize)
				self.Debuffs:SetWidth(partyWidth)
				self.Debuffs.spacing = partyDebuffSpacing
				self.Debuffs.size = math.floor(self.Debuffs:GetHeight() + .5)
				self.Debuffs.num = math.floor(partyWidth / self.Debuffs.size + .5)
				self.Debuffs.initialAnchor = "BOTTOMLEFT"
				self.Debuffs["growth-x"] = "RIGHT"
				self.Debuffs["growth-y"] = "DOWN"
				self.Debuffs.filter = false
			end
			self:SetAttribute("initial-height", partyHeight)
			self:SetAttribute("initial-width", partyWidth)
			hp:SetHeight(self:GetAttribute("initial-height")*0.6)
			pp:SetHeight(self:GetAttribute("initial-height")*0.4)
		end
		self.Range = true
		self.inRangeAlpha = 1
		self.outsideRangeAlpha = .5
	end,
	focus = function(self)
		local hp, pp = self.Health, self.Power
		self:SetAttribute("initial-height", focusHeight)
		self:SetAttribute("initial-width", focusWidth)
		hp:SetHeight(self:GetAttribute("initial-height")*0.6)
		pp:SetHeight(self:GetAttribute("initial-height")*0.4)
		if focusCastBar then
			local cb = CreateFrame("StatusBar", nil, self)
			cb:SetStatusBarTexture(TEXTURE)
			cb:SetStatusBarColor(1, .25, .35, .5)
			cb:SetAllPoints(self.Health)
			cb:SetToplevel(true)

			self.Castbar = cb
		end
		if (focusShowBuffs) then
			local buffs = CreateFrame("Frame", nil, self)
			buffs:SetPoint("BOTTOMRIGHT", self, "TOPRIGHT",0,3)
			buffs:SetHeight(focusBuffSize)
			buffs:SetWidth(focusWidth)
			buffs.size = math.floor(buffs:GetHeight())
			buffs.num = math.floor(focusWidth / buffs.size + .5)
			buffs.spacing = focusBuffSpacing
			buffs.initialAnchor = ("TOPRIGHT")
			buffs["growth-y"] = ("UP")
			buffs["growth-x"] = ("LEFT")

			self.Buffs = buffs
			self.Power:Hide()
		end
		if (focusShowDebuffs) then
			local debuffs = CreateFrame("Frame", nil, self)
			debuffs:SetPoint("TOPLEFT", self, "BOTTOMLEFT",0,-5)
			debuffs:SetHeight(focusDebuffSize)
			debuffs:SetWidth(focusWidth)
			debuffs.size = math.floor(debuffs:GetHeight())
			debuffs.num = math.floor(focusWidth / debuffs.size + .5)
			debuffs.spacing = focusDebuffSpacing
			debuffs.initialAnchor = ("BOTTOMLEFT")
			debuffs["growth-y"] = ("DOWN")
			debuffs["growth-x"] = ("RIGHT")

			self.Debuffs = debuffs
		end
	end,
}
UnitSpecific.targettargettarget = UnitSpecific.targettarget
UnitSpecific.focustarget = UnitSpecific.focus

local Shared = function(self, unit)
	self.colors = colors
	self.menu = menu
	self.BarFade = true
	self.MoveableFrames = true
	self.DebuffHighlightBackdrop = true

	self:SetScript("OnEnter", UnitFrame_OnEnter)
	self:SetScript("OnLeave", UnitFrame_OnLeave)

	self:RegisterForClicks"anyup"
	self:SetAttribute("*type2", "menu")

	self:SetBackdrop(backdrop)
	self:SetBackdropColor(0, 0, 0, .9)

	self:SetAttribute("initial-height", height)
	self:SetAttribute("initial-width", width)

	local hp = CreateFrame("StatusBar", nil, self)
	hp:SetPoint("TOPRIGHT", self)
	hp:SetPoint("TOPLEFT", self)
	hp:SetStatusBarTexture(TEXTURE)
	hp:SetHeight(self:GetAttribute("initial-height")*0.6)
	hp:SetAlpha(0.8)
	hp.frequentUpdates = true
	hp.colorDisconnected = true
	hp.colorTapping = true
	hp.colorClass = true
	hp.colorReaction = true
	hp.Smooth = true

	self.Health = hp

	local hpbg = hp:CreateTexture(nil, "BORDER")
	hpbg:SetAllPoints(self)
	hpbg:SetTexture(TEXTURE)
	hpbg:SetAlpha(0.3)

	hp.bg = hpbg

	local hpp = hp:CreateFontString(nil, "OVERLAY")
	hpp:SetFont(FONT, FONT_SIZE , "OUTLINE")
	hpp:SetPoint("RIGHT", -1, 0)
	hpp:SetTextColor(1, 1, 1)

	hp.value = hpp
	self:Tag(hpp, "[brunhp]")

	local pp = CreateFrame("StatusBar", nil, self)
	pp:SetPoint("TOPRIGHT", hp, "BOTTOMRIGHT", 0, -1)
	pp:SetPoint("TOPLEFT", hp, "BOTTOMLEFT", 0, -1)
	pp:SetStatusBarTexture(TEXTURE)
	pp:SetHeight(self:GetAttribute("initial-height")*0.4)
	pp.frequentUpdates = true
	pp.colorDisconnected = true
	pp.colorTapping = true
	pp.colorClass = false
	pp.colorPower = true
	pp.Smooth = true

	self.Power = pp

	local infoliner = hp:CreateFontString(nil, "OVERLAY")
	infoliner:SetFont(FONT, FONT_SIZE , "OUTLINE")
	infoliner:SetJustifyH"LEFT"
	infoliner:SetPoint("TOP", hp, "CENTER")
		
	self.Infoliner = infoliner
	
	local ppbg = pp:CreateTexture(nil, "BORDER")
	ppbg:SetAllPoints(pp)
	ppbg:SetTexture(TEXTURE)
	ppbg:SetAlpha(0.3)

	pp.bg = ppbg

	local ppp = pp:CreateFontString(nil, "OVERLAY")
	ppp:SetFont(FONT, FONT_SIZE , "OUTLINE")
	ppp:SetPoint("RIGHT", -1, 0)
	ppp:SetTextColor(1, 1, 1)

	pp.value = ppp
	self:Tag(ppp, "[brunpp]")

	local leader = hp:CreateTexture(nil, "OVERLAY")
	leader:SetHeight(16)
	leader:SetWidth(16)
	leader:SetPoint("TOP", hp, "TOP")

	self.Leader = leader

	local masterlooter = hp:CreateTexture(nil, "OVERLAY")
	masterlooter:SetHeight(16)
	masterlooter:SetWidth(16)
	masterlooter:SetPoint("LEFT", leader, "RIGHT")

	self.MasterLooter = masterlooter

	local assistant = hp:CreateTexture(nil, "OVERLAY")
	assistant:SetHeight(16)
	assistant:SetWidth(16)
	assistant:SetPoint("TOP", hp, "TOP")
	
	self.Assistant = assistant

	local ricon = hp:CreateTexture(nil, "OVERLAY")
	ricon:SetHeight(13)
	ricon:SetWidth(13)
	ricon:SetPoint("RIGHT", leader, "LEFT")

	self.RaidIcon = ricon

	local pvp = hp:CreateTexture(nil, "OVERLAY")
	pvp:SetHeight(35)
	pvp:SetWidth(35)
	pvp:SetPoint("TOPLEFT", hp, "TOPRIGHT", -5, 3)

	self.PvP = pvp

	local name = hp:CreateFontString(nil, "OVERLAY")
	name:SetPoint("LEFT", 2, 0)
	name:SetJustifyH"LEFT"
	name:SetFont(FONT, FONT_SIZE , "OUTLINE")
	name:SetHeight(12)

	self.Name = name
	self:Tag(name, "[NormalName] [afkdnd]")

	local info = pp:CreateFontString(nil, "OVERLAY")
	info:SetPoint("LEFT", 2, 0)
	info:SetPoint("RIGHT", -2, 0)
	info:SetJustifyH"LEFT"
	info:SetFont(FONT, FONT_SIZE , "OUTLINE")
	info:SetTextColor(1, 1, 1)

	self.Info = info
	self:Tag(info, "L[difficulty][level]|cffffffff[shortclassification] [smarterrace]|r")

	local hl = self:CreateTexture(nil, "HIGHLIGHT")
	hl:SetPoint("TOP", 0, -1)
	hl:SetPoint("LEFT")
	hl:SetPoint("RIGHT")
	hl:SetPoint("BOTTOM", 0, -1)
	hl:SetBlendMode("ADD")
	hl:SetHeight("50")
	hl:SetTexture(HIGHLIGHT)

	self.Highlight = hl

	self.PostCreateAuraIcon = PostCreateAuraIcon
	self.PostUpdateAuraIcon = PostUpdateAuraIcon
	
	-- Small hacks are always allowed...
	local unit = unit or "party"
	if(UnitSpecific[unit]) then
		return UnitSpecific[unit](self)
	end
end

oUF:RegisterStyle("Brun", Shared)
oUF:SetActiveStyle"Brun"

-- :Spawn(unit, frame_name, isPet) --isPet is only used on headers.
oUF:Spawn("player", "oUF_player"):SetPoint(unpack(oUF_Brun.Player))
oUF:Spawn("target", "oUF_target"):SetPoint(unpack(oUF_Brun.Target))
oUF:Spawn("targettarget", "oUF_TargetTarget"):SetPoint(unpack(oUF_Brun.ToT))
oUF:Spawn("targettargettarget", "oUF_ToToT"):SetPoint(unpack(oUF_Brun.ToToT))
oUF:Spawn("focus", "oUF_Focus"):SetPoint(unpack(oUF_Brun.Focus))
--oUF:Spawn("focustarget"):SetPoint(unpack(oUF_Brun.FocusTarget))
oUF:Spawn("pet", "oUF_Pet"):SetPoint(unpack(oUF_Brun.Pet))

if(oUFRuneBar == false and playerClass == "DEATHKNIGHT") then
	RuneFrame:ClearAllPoints()
	RuneFrame:SetPoint(unpack(oUF_Brun.Runeframe))
end

local party = oUF:Spawn("header", "oUF_Party")
party:SetPoint(unpack(oUF_Brun.Party))
party:SetManyAttributes(
	"showParty", true,
	"yOffset", -79,
	"xOffset", -40,
	"maxColumns", 2,
	"unitsPerColumn", 2,
	"columnAnchorPoint", "LEFT",
	"columnSpacing", 40,
	"template", "oUF_BrunPartyTemplate"
)
local partyToggle = CreateFrame("Frame")
partyToggle:RegisterEvent("PLAYER_LOGIN")
partyToggle:RegisterEvent("RAID_ROSTER_UPDATE")
partyToggle:RegisterEvent("PARTY_LEADER_CHANGED")
partyToggle:RegisterEvent("PARTY_MEMBERS_CHANGED")
partyToggle:SetScript("OnEvent", function(self)
	if(InCombatLockdown()) then
		self:RegisterEvent("PLAYER_REGEN_ENABLED")
	else
		self:UnregisterEvent("PLAYER_REGEN_ENABLED")
		local numraid = GetNumRaidMembers()
		if hidePartyInRaid then
			if numraid > 0 then
				party:Hide()
			else
				party:Show()
			end
		else
			party:Show()
		end
	end
end)
