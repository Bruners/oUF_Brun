local oufbrun
if oUF then
oufbrun = {
-- (point , frame , relativePoint , x , y)
	Player = {"RIGHT", UIParent, "CENTER", -98, -340},
	Target = {"LEFT", "oUF_player", "RIGHT", 198, 0},
	Pet = {"RIGHT", "oUF_player", "LEFT", -25, 0},
	Focus = {"TOP", UIParent, "TOP", 300,-20},
	FocusTarget = {"TOP", "oUF_Focus", "BOTTOM", 0,-30},
	ToT = {"LEFT", "oUF_player", "RIGHT", 17, 5},
	ToToT = {"LEFT", "oUF_player", "RIGHT", 17, -28},
	Party = {"TOPLEFT", UIParent, "TOPLEFT", 20, -50},
	Runeframe = {"TOPLEFT", "oUF_player", "BOTTOMLEFT", 0, -20}, -- Coords for the blizzard runes
	}
else
	return
end

local oUFRuneBar = false -- Enable/Disable the runebars in oUF
local removeBuffs = false -- Removes blizzard buffs
local hideselfinfo = true -- Hides name and level info on playerframe
local oUFBcastBar = true -- Enable/Disable castbar on all frames.

local PlayerShowBuffs = false  -- Enable/disable uffs on player
local PlayerShowDebuffs = true  -- Enable/disable debuffs on player

local TargetShowBuffs = true  -- Enable/disable buffs on target
local TargetShowDebuffs = true  -- Enable/disable debuffs on target

local ShowPetAura = true  -- Enable/disable aura on pet

local FocusShowBuffs = true  -- Enable/disable buffs on focus
local FocusShowDebuffs = true  -- Enable/disable debuffs on focus

local FONT, FONT_SIZE, SMALL_FONT_SIZE = ("Interface\\Addons\\oUF_Brun\\textures\\Font.ttf"), 14, 13
local texture = ("Interface\\Addons\\oUF_Brun\\textures\\Statusbar")
local textureV = ("Interface\\Addons\\oUF_Brun\\textures\\StatusbarV")
local highlight = ("Interface\\QuestFrame\\UI-QuestTitleHighlight")
local combo = ("Interface\\Addons\\oUF_Brun\\textures\\pb4combo")
local height, width = 35, 252
local substr = string.sub
local _, playerClass = UnitClass("player")

local backdrop = {
	bgFile="Interface\\Tooltips\\UI-Tooltip-Background",
	tile = true, 
	insets ={left = -2, right = -2, top = -2, bottom = -3}
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
local function Print(text)
	ChatFrame1:AddMessage(string.format("|cff33ff99oUF|r: %s", text))
end
local function GetCurrentAspect()
	return UnitBuff("player", "Aspect of the Hawk") or UnitBuff("player", "Aspect of the Viper") or "Unknown"
end
local function GetManaPercent()
	return ((UnitMana("player") / UnitManaMax("player")) * 100)
end

local manamin, manamax, ptype
local function UpdateDruidPower(self)
	ptype = UnitPowerType("player")
	if(ptype ~= 0) then
		manamin = UnitPower("player", 0)
		manamax = UnitPowerMax("player", 0)

		self:SetMinMaxValues(0, manamax)
		self:SetValue(manamin)
		self:SetStatusBarColor(unpack(self.colors.power["MANA"]))

		if(manamin ~= manamax) then
			self.Text:SetFormattedText("%d - %d%%", manamin, math.floor(manamin / manamax * 100))
		else
			self.Text:SetText()
		end

		self:SetAlpha(1)
	else
		manamin = UnitPower("player", 3)
		manamax = UnitPowerMax("player", 3)

		self:SetStatusBarColor(unpack(self.colors.power["ENERGY"]))
		self.Text:SetText()

		if(manamin ~= manamax) then
			self:SetMinMaxValues(0, manamax)
			self:SetValue(manamin)
		else
			self:SetAlpha(0)
		end
	end
end
local function PostUpdateReputation(self, event, unit, bar)
	local _, id = GetWatchedFactionInfo()
	bar:SetStatusBarColor(FACTION_BAR_COLORS[id].r, FACTION_BAR_COLORS[id].g, FACTION_BAR_COLORS[id].b)
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

local function CreateStyle(self, unit)
	self.colors = colors
	self.menu = menu
	self.BarFade = true
	self.MoveableFrames = true

	self:RegisterForClicks("AnyUp")
	self:SetAttribute("type2", "menu")
	self:SetScript("OnEnter", UnitFrame_OnEnter)
	self:SetScript("OnLeave", UnitFrame_OnLeave)
	
	self:SetBackdrop(backdrop)
	self:SetBackdropColor(0, 0, 0, .9)
	
	self:SetAttribute("initial-height", height)
	self:SetAttribute("initial-width", width)

	self.Health = CreateFrame("StatusBar", nil, self)
	self.Health:SetPoint("TOPRIGHT", self)
	self.Health:SetPoint("TOPLEFT", self)
	self.Health:SetStatusBarTexture(texture)
	self.Health:SetHeight(self:GetAttribute("initial-height")*0.6)
	self.Health:SetAlpha(0.8)

	self.Health.frequentUpdates = true
	self.Health.colorDisconnected = true
	self.Health.colorTapping = true
	self.Health.colorClass = true
	self.Health.colorReaction = true
	self.Health.Smooth = true

	self.Health.Text = self.Health:CreateFontString(nil, "OVERLAY")
	self.Health.Text:SetFont(FONT, FONT_SIZE , "OUTLINE")
	self.Health.Text:SetPoint("RIGHT", -1, 0)
	self.Health.Text:SetTextColor(1, 1, 1)
	self:Tag(self.Health.Text, "[brunhp]")
	
	self.Health.bg = self.Health:CreateTexture(nil, "BORDER")
	self.Health.bg:SetAllPoints(self.Health)
	self.Health.bg:SetTexture(texture)
	self.Health.bg:SetAlpha(0.3)
	
	self.Name = self.Health:CreateFontString(nil, "OVERLAY")
	self.Name:SetPoint("LEFT", 2, 0)
	self.Name:SetJustifyH"LEFT"
	self.Name:SetFont(FONT, FONT_SIZE , "OUTLINE")
	self.Name:SetWidth(150)
	self.Name:SetHeight(12)
	if(unit == "pet") or (self:GetAttribute"unitsuffix" == "pet") or (self:GetAttribute"unitsuffix" == "target") then
		self:Tag(self.Name, "[ShortName]")
	else
		self:Tag(self.Name, "[NormalName] [afkdnd]")
	end
	self.Power = CreateFrame("StatusBar", nil, self)
	self.Power:SetPoint("TOPRIGHT", self.Health, "BOTTOMRIGHT", 0, -1)
	self.Power:SetPoint("TOPLEFT", self.Health, "BOTTOMLEFT", 0, -1)
	self.Power:SetStatusBarTexture(texture)
	self.Power:SetStatusBarColor(.25, .25, .35)
	self.Power:SetHeight(self:GetAttribute("initial-height")*0.4)
	
	self.Power.frequentUpdates = true
	self.Power.colorDisconnected = true
	self.Power.colorTapping = true
	self.Power.colorClass = false
	self.Power.colorPower = true
	self.Power.Smooth = true
	
	self.Power.bg = self.Power:CreateTexture(nil, "BORDER")
	self.Power.bg:SetAllPoints(self.Power)
	self.Power.bg:SetTexture(texture)
	self.Power.bg:SetAlpha(0.3)
	
	self.Power.Text = self.Power:CreateFontString(nil, "OVERLAY")
	self.Power.Text:SetFont(FONT, FONT_SIZE , "OUTLINE")
	self.Power.Text:SetPoint("RIGHT", -1, 0)
	self.Power.Text:SetTextColor(1, 1, 1)
	self:Tag(self.Power.Text, "[brunpp]")
	
	local ccs = CreateFrame("FRAME")
	ccs:SetHeight(11)
	ccs:SetWidth(self:GetAttribute("initial-width"))
	ccs:SetParent(self)
	ccs:SetFrameStrata("BACKGROUND")
	ccs:SetPoint("TOP", self, "BOTTOM", 0, -2)
	ccs:SetBackdrop(backdrop)
	ccs:SetBackdropColor(0, 0, 0, .9)
	ccs:SetAlpha(0)
	local ccsbg = ccs:CreateTexture(nil, "BORDER")
	ccsbg:SetAllPoints(ccs)
	ccsbg:SetTexture(texture)
	ccsbg:SetAlpha(ccs:GetAlpha() or 0.3)
	
	local infoliner = self.Power:CreateFontString(nil, "OVERLAY")
	infoliner:SetFont(FONT, FONT_SIZE , "OUTLINE")
	infoliner:SetJustifyH"LEFT"
	infoliner:SetPoint("TOP", self.Health, "CENTER")
	
	self.Info = self.Power:CreateFontString(nil, "OVERLAY")
	self.Info:SetPoint("LEFT", 2, 0)
	self.Info:SetPoint("RIGHT", -2, 0)
	self.Info:SetJustifyH"LEFT"
	self.Info:SetFont(FONT, FONT_SIZE , "OUTLINE")
	self.Info:SetTextColor(1, 1, 1)
	self:Tag(self.Info, "L[difficulty][level]|cffffffff[shortclassification] [smrtrace]|r")
	
	self.Leader = self.Health:CreateTexture(nil, "OVERLAY")
	self.Leader:SetPoint("TOP", -16, 5)
	self.Leader:SetTexture("Interface\GroupFrame\UI-Group-LeaderIcon")
	self.Leader:SetHeight(16)
	self.Leader:SetWidth(16)

	self.RaidIcon = self.Health:CreateTexture(nil, "OVERLAY")
	if self:GetParent():GetName() ~= "oUF_Party" then
		self.RaidIcon:SetPoint("TOP", 0, 3)
	else
		self.RaidIcon:SetPoint("CENTER")
	end
	self.RaidIcon:SetHeight(16)
	self.RaidIcon:SetWidth(16)

	self.Highlight = self:CreateTexture(nil, "HIGHLIGHT")
	self.Highlight:SetPoint("TOP", 0, -1)
	self.Highlight:SetPoint("LEFT")
	self.Highlight:SetPoint("RIGHT")
	self.Highlight:SetPoint("BOTTOM", 0, -1)
	self.Highlight:SetBlendMode("ADD")
	self.Highlight:SetHeight("50")
	self.Highlight:SetTexture(highlight)

	self.PvP = self.Health:CreateTexture(nil, "OVERLAY")
	self.PvP:SetTexCoord(0.08, 0.58, 0.045, 0.545)
	self.PvP:SetHeight(22)
	self.PvP:SetWidth(22)
	self.PvP:SetPoint("TOPRIGHT", 15, 10)

	if(unit == "player") then
		if (PlayerShowBuffs) then
			self.Buffs = CreateFrame("Frame", nil, self)
			self.Buffs:SetPoint("BOTTOMRIGHT", self.Health, "TOPRIGHT",0,3)
			self.Buffs:SetHeight(24)
			self.Buffs:SetWidth(width)
			self.Buffs.num = 20
			self.Buffs.size = 24
			self.Buffs.spacing = 1
			self.Buffs.initialAnchor = ("TOPRIGHT")
			self.Buffs["growth-y"] = ("UP")
			self.Buffs["growth-x"] = ("LEFT")
		end
		if (PlayerShowDebuffs) then
			self.Debuffs = CreateFrame("Frame", nil, self)
			self.Debuffs:SetPoint("TOPRIGHT", self, "BOTTOMRIGHT",0,-20)
			self.Debuffs:SetHeight(24)
			self.Debuffs:SetWidth(width)
			self.Debuffs.size = math.floor(self.Debuffs:GetHeight())
			self.Debuffs.num = math.floor(width / self.Debuffs.size + .5)
			self.Debuffs.spacing = 2
			self.Debuffs.initialAnchor = ("BOTTOMRIGHT")
			self.Debuffs["growth-y"] = ("DOWN")
			self.Debuffs["growth-x"] = ("LEFT")
		end
		-- Modules
		if(IsAddOnLoaded"oUF_CombatFeedback") then
			self.CombatFeedbackText = infoliner
			self.CombatFeedbackText.maxAlpha = .8
		end
		if(IsAddOnLoaded"oUF_Experience" and UnitLevel(unit) ~= MAX_PLAYER_LEVEL) then
			ccs:SetAlpha(0.6)
			ccsbg:SetAlpha(ccs:GetAlpha() or 0.3)
			self.Experience = CreateFrame("StatusBar", nil, self)
			self.Experience:SetPoint("BOTTOMRIGHT", ccs, "BOTTOMRIGHT")
			self.Experience:SetPoint("TOPLEFT", ccs, "TOPLEFT")
			self.Experience:SetStatusBarTexture(texture)
			self.Experience:SetFrameStrata("LOW")
			self.Experience.Tooltip = true
			self.Experience.Text = self.Experience:CreateFontString(nil, "OVERLAY")
			self.Experience.Text:SetFont(FONT, SMALL_FONT_SIZE , "OUTLINE")
			self.Experience.Text:SetPoint("CENTER", self.Experience)
			self.Debuffs:SetPoint("TOPRIGHT", self.Experience, "BOTTOMRIGHT",0,-2)
		elseif (IsAddOnLoaded"oUF_Reputation" and UnitLevel(unit) == MAX_PLAYER_LEVEL) then
			ccs:SetAlpha(0.6)
			ccsbg:SetAlpha(ccs:GetAlpha() or 0.3)
			self.Reputation = CreateFrame("StatusBar", nil, self)
			self.Reputation:SetPoint("TOPLEFT", ccs, "TOPLEFT", 0,-1)
			self.Reputation:SetPoint("BOTTOMRIGHT", ccs, "BOTTOMRIGHT",0,-1)
			self.Reputation:SetStatusBarTexture(texture)
			self.Reputation.PostUpdate = PostUpdateReputation
			self.Reputation:SetFrameStrata("LOW")
			self.Reputation.Tooltip = true
			self.Reputation.Text = self.Reputation:CreateFontString(nil, "OVERLAY")
			self.Reputation.Text:SetFont(FONT, SMALL_FONT_SIZE , "OUTLINE")
			self.Reputation.Text:SetPoint("CENTER", self.Reputation)
			self.Debuffs:SetPoint("TOPRIGHT", self.Reputation, "BOTTOMRIGHT",0,-2)
		end
		if(IsAddOnLoaded("oUF_Swing")) then
			self.Swing = CreateFrame("StatusBar", nil, self)
			self.Swing:SetPoint("TOP", ccs, "BOTTOM", 0, -2)
			self.Swing:SetStatusBarTexture(texture)
			self.Swing:SetStatusBarColor(1, 0.7, 0)
			self.Swing:SetHeight(6)
			self.Swing:SetWidth(self:GetAttribute("initial-width"))
			self.Swing:SetBackdrop(backdrop)
			self.Swing:SetBackdropColor(0, 0, 0)
			self.Swing.Text = self.Swing:CreateFontString(nil, "OVERLAY")
			self.Swing.Text:SetFont(FONT, SMALL_FONT_SIZE , "OUTLINE")
			self.Swing.Text:SetPoint("CENTER", self.Swing)
			self.Swing.bg = self.Swing:CreateTexture(nil, "BORDER")
			self.Swing.bg:SetAllPoints(self.Swing)
			self.Swing.bg:SetTexture(0.3, 0.3, 0.3)
		end
		self.Combat = self.Health:CreateTexture(nil, "OVERLAY")
		self.Combat:SetHeight(17)
		self.Combat:SetWidth(17)
		self.Combat:SetPoint("BOTTOMLEFT", self.Power, -8,-5)
		self.Combat:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
		self.Combat:SetTexCoord(0.58, 0.90, 0.08, 0.41)

		if UnitLevel("player") ~= MAX_PLAYER_LEVEL then
			self.Resting = self.Power:CreateTexture(nil, "OVERLAY")
			self.Resting:SetHeight(20)
			self.Resting:SetWidth(25)
			self.Resting:SetPoint("BOTTOMLEFT", -15, -10)
			self.Resting:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
			self.Resting:SetTexCoord(0, 0.5, 0, 0.42)
		else
			if (hideselfinfo == true) then
				self.Info:Hide()
				self:Tag(self.Name, "[afkdnd]")
			end
		end	
		
		-- Class spesifics
		if (playerClass == "DEATHKNIGHT") then
			if oUFRuneBar == true then
				self:SetAttribute("initial-height", height-7)
				self.Power:SetHeight(height*0.4 -7)
				self.Power.Text:SetFont(FONT, SMALL_FONT_SIZE , "OUTLINE")
				
				local runes = CreateFrame('Frame', nil, self)
				runes:SetPoint('TOPLEFT', self, 'BOTTOMLEFT', 0, -5)
				runes:SetHeight(7)
				runes:SetWidth(width)
				runes:SetBackdrop(backdrop)
				runes:SetBackdropColor(0, 0, 0, .9)
				runes.order = { 1, 2, 5, 6, 3, 4}
				runes.height = 7
				runes.width = width / 6 - 0.75

				for i = 1, 6 do
					local bar = CreateFrame('StatusBar', nil, runes)
					bar:SetStatusBarTexture(texture)
					
					runes[i] = bar
				end
				
				self.Runes = runes
				ccs:SetPoint("TOP", self.Runes, "BOTTOM", 0, -2)
			end
		end
		
		if (playerClass == "HUNTER") then
			infoliner:SetPoint("TOP", self.Health, "CENTER")
			local aspect = CreateFrame"Frame"
			aspect:RegisterEvent"UNIT_MANA"
			aspect:SetScript("OnEvent", function(self, event)
				local manaAspect, manaValue = GetCurrentAspect(), GetManaPercent()
				local manaLowPercent, manaHighPercent = 30, 85
				local textHawk = ("MANA GOOD!  |cffff4545GO HAWK!|r")
				local textViper = ("LOW MANA!  |cffff4545POT OR GO VIPER!|r")
				if not UnitIsDeadOrGhost"player" then
					if (manaValue >= manaHighPercent and manaAspect == "Aspect of the Viper") then
						infoliner:SetText(textHawk)
					elseif (manaValue <= manaLowPercent and manaAspect ~= "Aspect of the Viper") then
						infoliner:SetText(textViper)
					else
						infoliner:SetText("")
					end
				end
			end)
		end

		if(playerClass == "DRUID") then
			self.DruidPower = CreateFrame("StatusBar", nil, self)
			self.DruidPower:SetPoint("TOP", self.Castbar, "BOTTOM")
			self.DruidPower:SetStatusBarTexture(texture)
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
	end

	if(unit == "pet") then
		self.Health.colorHappiness = true
		self:SetAttribute("initial-height", (height-10))
		self:SetAttribute("initial-width", width-100)
		self.Health:SetHeight(self:GetAttribute("initial-height")*0.5)
		self.Power:SetHeight(self:GetAttribute("initial-height")*0.5)
		self:Tag(self.Health.Text, "[brunminushp]")
		
		if (ShowPetAura) then
			self.Auras = CreateFrame("Frame", nil, self)
			self.Auras:SetPoint("TOPRIGHT", self, "TOPLEFT", -2, 1)
			self.Auras:SetHeight(24 * 2)
			self.Auras:SetWidth(270)
			self.Auras.size = 24
			self.Auras.spacing = 2
			self.Auras.initialAnchor = "TOPRIGHT"
			self.Auras["growth-x"] = "LEFT"
		end
		if(unit == "pet") and (playerClass == "HUNTER") then
			self:Tag(self.Name, "[happiness]")
		end
	end

	if (unit == "focus" or unit == "focustarget" or self:GetParent():GetName() == "oUF_Party") then
		self:SetAttribute("initial-height", height)
		self:SetAttribute("initial-width", width-50)
		if (FocusShowBuffs) then
			self.Buffs = CreateFrame("Frame", nil, self)
			self.Buffs:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 0, 2)
			self.Buffs:SetHeight(17)
			self.Buffs:SetWidth(width-50)
			self.Buffs.spacing = 4
			self.Buffs.size = math.floor(self.Buffs:GetHeight() + .8)
			self.Buffs.num = math.floor(width / self.Buffs.size + .5)
			self.Buffs.initialAnchor = "BOTTOMLEFT"
			self.Buffs["growth-y"] = "UP"
			self.Buffs["growth-x"] = "RIGHT"
		end
		if (FocusShowDebuffs) then
			self.Debuffs = CreateFrame("Frame", nil, self)
			self.Debuffs:SetPoint("TOPLEFT", self, "BOTTOMLEFT",0,-4)
			self.Debuffs:SetHeight(17)
			self.Debuffs:SetWidth(self:GetAttribute("initial-width")-50)
			self.Debuffs.spacing = 4
			self.Debuffs.size = math.floor(self.Debuffs:GetHeight() + .5)
			self.Debuffs.num = math.floor(width / self.Debuffs.size + .5)
			self.Debuffs.initialAnchor = "BOTTOMLEFT"
			self.Debuffs["growth-x"] = "RIGHT"
			self.Debuffs["growth-y"] = "DOWN"
			self.Debuffs.filter = false
		end
	end
	if unit == ("targettarget") or unit == ("targettargettarget") then
		self.Name:SetFont(FONT, SMALL_FONT_SIZE , "OUTLINE")
		self.Health.Text:SetFont(FONT, SMALL_FONT_SIZE , "OUTLINE")
		self.Power.Text:SetFont(FONT, SMALL_FONT_SIZE , "OUTLINE")
		self.Info:SetFont(FONT, SMALL_FONT_SIZE , "OUTLINE")
		self.PvP:SetHeight(15)
		self.PvP:SetWidth(15)
		self.PvP:SetPoint("TOPRIGHT", 10, 10)
		self:SetAttribute("initial-height", (height-10))
		self:SetAttribute("initial-width", width-85)
		self.Health:SetHeight(self:GetAttribute("initial-height")*0.6)
		self.Power:SetHeight(self:GetAttribute("initial-height")*0.4)
	end

	if(unit == "player" or unit == "target" or unit == "pet") then
		if (oUFBcastBar) then
			self.Castbar = CreateFrame("StatusBar")
			self.Castbar:SetPoint("TOPLEFT", self.Power, "BOTTOMLEFT", 0, -2)
			self.Castbar:SetPoint("TOPRIGHT", self.Power, "BOTTOMRIGHT", 0, -2)
			self.Castbar:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background", color = {1, 1, 1, 0} })
			self.Castbar:SetFrameStrata("MEDIUM")
			self.Castbar:SetStatusBarTexture(texture)
			self.Castbar:SetStatusBarColor(1.0, 0.7, 0.0)
			self.Castbar:SetParent(self)
			self.Castbar:SetMinMaxValues(1, 100)
			self.Castbar:SetValue(1)
			self.Castbar:SetHeight(11)
			self.Castbar.bg = self.Castbar:CreateTexture(nil, "BORDER")
			self.Castbar.bg:SetAllPoints(self.Castbar)
			self.Castbar.bg:SetTexture(0.3, 0.3, 0.3)
			self.Castbar.bg:SetHeight(12)
			self.Castbar.Spark = self.Castbar:CreateTexture(nil, "OVERLAY")
			self.Castbar.Spark:SetHeight(30)
			self.Castbar.Spark:SetBlendMode("ADD")
			self.Castbar.Spark:SetWidth(10)
			self.Castbar.Spark:SetTexCoord(0, 0, 0, 1, 1, 0, 1, 1)
			self.Castbar.Time = self.Castbar:CreateFontString(nil, "OVERLAY")
			self.Castbar.Time:SetPoint("RIGHT", self.Castbar, -5, 1)
			self.Castbar.Time:SetTextColor(1, 1, 1)
			self.Castbar.Time:SetJustifyH("RIGHT")
			self.Castbar.Time:SetShadowOffset(1, -1)
			self.Castbar.Time:SetFont(FONT, SMALL_FONT_SIZE, "OUTLINE")
			self.Castbar.Text = self.Castbar:CreateFontString(nil, "OVERLAY")
			self.Castbar.Text:SetPoint("LEFT", self.Castbar, 15, 1)
			self.Castbar.Text:SetWidth(240)
			self.Castbar.Text:SetTextColor(1, 1, 1)
			self.Castbar.Text:SetShadowOffset(1, -1)
			self.Castbar.Text:SetJustifyH("LEFT")
			self.Castbar.Text:SetFont(FONT, SMALL_FONT_SIZE, "OUTLINE")
			self.Castbar.CustomTimeText = function(self, duration)
				if self.casting then
					self.Time:SetFormattedText("%.1f", self.max - duration)
				elseif self.channeling then
					self.Time:SetFormattedText("%.1f", duration)
				end
			end
			self.Castbar.SafeZone = self.Castbar:CreateTexture(nil,"BORDER")
			self.Castbar.SafeZone:SetTexture(texture)
			self.Castbar.SafeZone:SetVertexColor(1,1,1,0.7)
			self.Castbar.SafeZone:SetHeight(self.Castbar:GetHeight())
			self.Castbar.SafeZone:SetPoint("TOPRIGHT")
			self.Castbar.SafeZone:SetPoint("BOTTOMRIGHT")
			self.Castbar.Icon = self.Castbar:CreateTexture(nil, "OVERLAY")
			self.Castbar.Icon:SetHeight(self.Castbar:GetHeight())
			self.Castbar.Icon:SetWidth(self.Castbar:GetHeight())
			self.Castbar.Icon:SetTexCoord(0.07, .93, .07, .93)
			self.Castbar.Icon:SetPoint("TOPLEFT", self.Castbar, "TOPLEFT", -2, 0)
			
			if (unit == "player") and (playerClass == "DEATHKNIGHT") then
				if oUFRuneBar == true then
					self.Castbar:ClearAllPoints()
					self.Castbar:SetPoint("TOPLEFT", self.Runes, "BOTTOMLEFT", 0, -3)
					self.Castbar:SetPoint("TOPRIGHT", self.Runes, "BOTTOMRIGHT", 0, -3)
				end
			end
		end
	end
	if(unit == "target") then
		if (TargetShowBuffs) then
			self.Buffs = CreateFrame("Frame", nil, self)
			self.Buffs:SetPoint("BOTTOMRIGHT", self, "TOPRIGHT",0,3)
			self.Buffs:SetHeight(24)
			self.Buffs:SetWidth(width)
			self.Buffs.num = 20
			self.Buffs.size = 24
			self.Buffs.spacing = 1
			self.Buffs.initialAnchor = ("TOPRIGHT")
			self.Buffs["growth-y"] = ("UP")
			self.Buffs["growth-x"] = ("LEFT")
		end
		if (TargetShowDebuffs) then
			self.Debuffs = CreateFrame("Frame", nil, self)
			self.Debuffs:SetPoint("TOPLEFT", self, "BOTTOMLEFT",0,-24)
			self.Debuffs:SetHeight(24)
			self.Debuffs:SetWidth(width)
			self.Debuffs.size = math.floor(self.Debuffs:GetHeight())
			self.Debuffs.num = math.floor(width / self.Debuffs.size + .5)
			self.Debuffs.spacing = 1
			self.Debuffs.initialAnchor = ("BOTTOMLEFT")
			self.Debuffs["growth-y"] = ("DOWN")
			self.Debuffs["growth-x"] = ("RIGHT")
		end

		if (oUFBcastBar) then
			ccs:SetAlpha(.6)
			ccsbg:SetAlpha(ccs:GetAlpha() or 0.3)
			--self.Castbar:ClearAllPoints()
			--self.Castbar:SetPoint("TOPLEFT", ccs, "BOTTOMLEFT", 0, -2)
			--self.Castbar:SetPoint("TOPRIGHT", ccs, "BOTTOMRIGHT", 0, -2)
			self.Debuffs:ClearAllPoints()
			self.Debuffs:SetPoint("TOPLEFT", self.Castbar, "BOTTOMLEFT", -1, -2)
		end
		
		local cparr = {}
		cparr[1] = ccs:CreateTexture(nil, "OVERLAY")
		cparr[1]:SetHeight(10)
		cparr[1]:SetWidth(10)
		cparr[1]:SetPoint("BOTTOMRIGHT", ccs, "BOTTOMRIGHT", 0, -1)
		cparr[1]:SetTexture(combo)
		cparr[1]:SetVertexColor(1,84/255,0)

		cparr[2] = ccs:CreateTexture(nil, "OVERLAY")
		cparr[2]:SetHeight(10)
		cparr[2]:SetWidth(10)
		cparr[2]:SetPoint("RIGHT", cparr[1], "LEFT", -2, 0)
		cparr[2]:SetTexture(combo)
		cparr[2]:SetVertexColor(1,162/255,0)

		cparr[3] = ccs:CreateTexture(nil, "OVERLAY")
		cparr[3]:SetHeight(10)
		cparr[3]:SetWidth(10)
		cparr[3]:SetPoint("RIGHT", cparr[2], "LEFT", -2, 0)
		cparr[3]:SetTexture(combo)
		cparr[3]:SetVertexColor(1,246/255,0)

		cparr[4] = ccs:CreateTexture(nil, "OVERLAY")
		cparr[4]:SetHeight(10)
		cparr[4]:SetWidth(10)
		cparr[4]:SetPoint("RIGHT", cparr[3], "LEFT", -2, 0)
		cparr[4]:SetTexture(combo)
		cparr[4]:SetVertexColor(204/255,1,0)

		cparr[5] = ccs:CreateTexture(nil, "OVERLAY")
		cparr[5]:SetHeight(10)
		cparr[5]:SetWidth(10)
		cparr[5]:SetPoint("RIGHT", cparr[4], "LEFT", -2, 0)
		cparr[5]:SetTexture(combo)
		cparr[5]:SetVertexColor(76/255,236/255,0)

		self.CPoints = cparr
		self:Tag(infoliner, "[cpoints]")
	end
	
	if (not unit) then
		self:SetAttribute("initial-height", height)
		self:SetAttribute("initial-width", width-50)
		self.Range = true
		self.inRangeAlpha = 1
		self.outsideRangeAlpha = .6
	end
	if(self:GetAttribute"unitsuffix" == "pet") or (self:GetAttribute"unitsuffix" == "target") then
		self.Power:Hide()
		self.PvP:SetHeight(15)
		self.PvP:SetWidth(15)
		self.PvP:SetPoint("TOPRIGHT", 10, 10)
		self:Tag(self.Health.Text, "[brunminushp]")
		self:SetAttribute("initial-height", 15)
		self:SetAttribute("initial-width", 95)
		self.Health:SetHeight(self:GetAttribute("initial-height"))
		self.Range = true
		self.inRangeAlpha = 1
		self.outsideRangeAlpha = .6
	end

	self.DebuffHighlightBackdrop = true
	self.DebuffHighlightFilter = true
	self.PostCreateAuraIcon = PostCreateAuraIcon
	return self
end

oUF:RegisterStyle("Brun", CreateStyle)
oUF:SetActiveStyle("Brun")
oUF:Spawn("player", "oUF_player"):SetPoint(unpack(oufbrun.Player))
oUF:Spawn("target", "oUF_target"):SetPoint(unpack(oufbrun.Target))
oUF:Spawn("targettarget", "oUF_TargetTarget"):SetPoint(unpack(oufbrun.ToT))
oUF:Spawn("targettargettarget"):SetPoint(unpack(oufbrun.ToToT))
oUF:Spawn("focus", "oUF_Focus"):SetPoint(unpack(oufbrun.Focus))
oUF:Spawn("focustarget"):SetPoint(unpack(oufbrun.FocusTarget))
oUF:Spawn("pet", "oUF_Pet"):SetPoint(unpack(oufbrun.Pet))

if(oUFRuneBar == false and playerClass == "DEATHKNIGHT") then
	RuneFrame:ClearAllPoints()
	RuneFrame:SetPoint(unpack(oufbrun.Runeframe))
end

local party = oUF:Spawn("header", "oUF_Party")
party:SetPoint(unpack(oufbrun.Party))
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
		if numraid > 0 then
			party:Hide()
		else
			party:Show()
		end
	end
end)
