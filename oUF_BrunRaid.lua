--[[-------------------------------------------------------------------------
  Copyright (c) Lasse G. Brun. All rights reserved.
  Licensed under the MIT License. See LICENSE in the project root.
---------------------------------------------------------------------------]]

local addonName, ns = ...
local oUF = ns.oUF or _G.oUF
assert(oUF, "oUF_Brun requires oUF to be loaded.")

local nop = _G.nop or function() end

local raidWidth = ns.raidWidth or 85
local raidHeight = ns.raidHeight or 24
local FONT = ns.GetFontPath and ns.GetFontPath() or ns.FONT
local TEXTURE = ns.GetStatusBarTexture and ns.GetStatusBarTexture() or ns.TEXTURE
local HIGHLIGHT = ns.HIGHLIGHT
local RAID_FONT_SIZE = ns.RAID_FONT_SIZE or 10

--===================================================--
-- Blizzard CompactRaidFrameContainer Hider
--===================================================--

do
	local hidden = false
	local inEditMode = false
	local pending = false

	function ns.UpdateBlizzardRaidFramesVisibility()
		if InCombatLockdown() then
			pending = true
			return
		end
		pending = false
		local container = _G.CompactRaidFrameContainer
		if not container then return end
		local shouldHide = ns.IsRaidFramesEnabled() and not inEditMode
		if container.AddRoleset and container.RemoveRoleset then
			if shouldHide and not hidden then
				if pcall(container.AddRoleset, container, "alwaysBlocked") then
					hidden = true
				end
			elseif not shouldHide and hidden then
				if pcall(container.RemoveRoleset, container, "alwaysBlocked") then
					hidden = false
				end
			end
		elseif container.SetRolesets then
			if shouldHide and not hidden then
				if pcall(container.SetRolesets, container, "alwaysBlocked") then
					hidden = true
				end
			elseif not shouldHide and hidden then
				if pcall(container.SetRolesets, container, "") then
					hidden = false
				end
			end
		elseif shouldHide then
			container:UnregisterAllEvents()
			container:Hide()
			hidden = true
		elseif hidden then
			pcall(container.SetAlpha, container, 1)
			hidden = false
		end
	end

	local raidHider = CreateFrame("Frame")
	raidHider:RegisterEvent("PLAYER_LOGIN")
	raidHider:RegisterEvent("PLAYER_ENTERING_WORLD")
	raidHider:RegisterEvent("GROUP_ROSTER_UPDATE")
	raidHider:RegisterEvent("PLAYER_REGEN_ENABLED")
	raidHider:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_REGEN_ENABLED" and not pending then return end
		ns.UpdateBlizzardRaidFramesVisibility()
	end)

	if _G.EditModeManagerFrame then
		_G.EditModeManagerFrame:HookScript("OnShow", function()
			inEditMode = true
			ns.UpdateBlizzardRaidFramesVisibility()
		end)
		_G.EditModeManagerFrame:HookScript("OnHide", function()
			inEditMode = false
			ns.UpdateBlizzardRaidFramesVisibility()
		end)
	end
end

--===================================================--
-- Compact 8-Group Raid Unit Style
--===================================================--

local function CreateRaidStyle(self)
	self:SetScript("OnEnter", ns.UnitFrameOnEnter)
	self:SetScript("OnLeave", ns.UnitFrameOnLeave)
	self:RegisterForClicks("AnyUp")
	ns.RegisterClickCastFrame(self)

	ns.ApplyBackdrop(self)
	self:SetSize(raidWidth, raidHeight)
	self.Range = {
		insideAlpha = 1,
		outsideAlpha = 0.45,
	}

	local hp = CreateFrame("StatusBar", nil, self)
	hp:SetPoint("TOPRIGHT")
	hp:SetPoint("TOPLEFT")
	hp:SetStatusBarTexture(ns.GetStatusBarTexture and ns.GetStatusBarTexture() or TEXTURE)
	if ns.TrackStatusBar then ns.TrackStatusBar(hp) end
	hp:SetHeight(20)
	hp:SetAlpha(ns.GetBarAlpha and ns.GetBarAlpha() or 0.8)
	if ns.TrackHealthBar then ns.TrackHealthBar(hp) end
	hp.colorDisconnected = true
	hp.colorTapping = true
	hp.colorClass = (ns.UseClassHealthColor == nil) or ns.UseClassHealthColor()
	hp.colorReaction = true
	hp.colorHealth = true
	hp.smoothing = ns.smoothInterpolation
	hp.PostUpdateColor = ns.PostUpdateBarColor
	self.Health = hp

	if ns.IsHealthPredictionEnabled() then
		ns.CreateHealthPrediction(self)
	end

	self.ThreatIndicator = {
		IsObjectType = nop,
		Show = nop,
		Hide = nop,
		PostUpdate = ns.PostUpdateThreat,
	}

	local hpbg = hp:CreateTexture(nil, "BORDER")
	hpbg:SetAllPoints(self)
	hpbg:SetTexture(ns.GetStatusBarTexture and ns.GetStatusBarTexture() or TEXTURE)
	if ns.TrackBarTexture then ns.TrackBarTexture(hpbg) end
	hpbg:SetAlpha(0.3)
	hp.bg = hpbg

	local hpp = hp:CreateFontString(nil, "OVERLAY")
	hpp:SetFont(ns.GetFontPath and ns.GetFontPath() or FONT, math.max(7, RAID_FONT_SIZE + (ns.GetFontSizeOffset and ns.GetFontSizeOffset() or 0)), ns.GetFontFlags and ns.GetFontFlags() or "OUTLINE")
	if ns.TrackFontString then ns.TrackFontString(hpp, RAID_FONT_SIZE) end
	hpp:SetPoint("RIGHT", -1, 0)
	hpp:SetTextColor(1, 1, 1)
	hp.value = hpp
	self:Tag(hpp, "[brunraid_status]")

	local pp = CreateFrame("StatusBar", nil, self)
	pp:SetPoint("TOPRIGHT", hp, "BOTTOMRIGHT", 0, -1)
	pp:SetPoint("TOPLEFT", hp, "BOTTOMLEFT", 0, -1)
	pp:SetStatusBarTexture(ns.GetStatusBarTexture and ns.GetStatusBarTexture() or TEXTURE)
	if ns.TrackStatusBar then ns.TrackStatusBar(pp) end
	pp:SetHeight(3)
	pp.frequentUpdates = true
	pp.colorDisconnected = true
	pp.colorTapping = true
	pp.colorPower = true
	pp.smoothing = ns.smoothInterpolation
	pp.PostUpdateColor = ns.PostUpdateBarColor
	self.Power = pp

	local ppbg = pp:CreateTexture(nil, "BORDER")
	ppbg:SetAllPoints()
	ppbg:SetTexture(ns.GetStatusBarTexture and ns.GetStatusBarTexture() or TEXTURE)
	if ns.TrackBarTexture then ns.TrackBarTexture(ppbg) end
	ppbg:SetAlpha(0.3)
	pp.bg = ppbg

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

	local raidrole = hp:CreateTexture(nil, "OVERLAY")
	raidrole:SetSize(14, 14)
	raidrole:SetPoint("CENTER", hp, "TOP", -28, 1)
	self.RaidRoleIndicator = raidrole

	local ricon = hp:CreateTexture(nil, "OVERLAY")
	ricon:SetSize(14, 14)
	ricon:SetPoint("CENTER", hp, "TOP", -14, 1)
	self.RaidTargetIndicator = ricon

	local lfdrole = hp:CreateTexture(nil, "OVERLAY")
	lfdrole:SetSize(12, 12)
	lfdrole:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 1, 1)
	self.GroupRoleIndicator = lfdrole

	local readycheck = hp:CreateTexture(nil, "OVERLAY")
	readycheck:SetSize(16, 16)
	readycheck:SetPoint("CENTER")
	self.ReadyCheckIndicator = readycheck

	local resurrect = hp:CreateTexture(nil, "OVERLAY")
	resurrect:SetSize(16, 16)
	resurrect:SetPoint("CENTER")
	self.ResurrectIndicator = resurrect

	local summon = hp:CreateTexture(nil, "OVERLAY")
	summon:SetSize(18, 18)
	summon:SetPoint("CENTER")
	self.SummonIndicator = summon

	local name = hp:CreateFontString(nil, "OVERLAY")
	name:SetPoint("LEFT", 2, 0)
	name:SetPoint("RIGHT", hpp, "LEFT", -4, 0)
	name:SetWordWrap(false)
	name:SetJustifyH("LEFT")
	name:SetFont(ns.GetFontPath and ns.GetFontPath() or FONT, math.max(7, RAID_FONT_SIZE + (ns.GetFontSizeOffset and ns.GetFontSizeOffset() or 0)), ns.GetFontFlags and ns.GetFontFlags() or "OUTLINE")
	if ns.TrackFontString then ns.TrackFontString(name, RAID_FONT_SIZE) end
	self.Name = name
	self:Tag(name, "[brunraid_name][afkdnd]")

	local hl = self:CreateTexture(nil, "HIGHLIGHT")
	hl:SetPoint("TOPLEFT", 0, -1)
	hl:SetPoint("BOTTOMRIGHT", 0, -1)
	hl:SetBlendMode("ADD")
	hl:SetTexture(HIGHLIGHT)
	self.Highlight = hl

	if ns.IsDispelHighlightEnabled() then
		local debuffs = ns.CreateAuraWidget(self, "HARMFUL|RAID", 30, 14, 2, "RIGHT", "UP", {
			maxFrameCount = 2,
			disableMouse = true,
			frameLevel = hp:GetFrameLevel() + 4,
		})
		debuffs:SetPoint("CENTER", hp, "CENTER", 0, 0)
	end
end

oUF:RegisterStyle("BrunRaid", CreateRaidStyle)

--===================================================--
-- Raid Solo Test Mode (/brun test)
--===================================================--

local TEST_DUMMY_ROSTER = {
	-- Group 1
	{ "Bruners", "MAGE", 0.92, 0.68, 1, false, nil },
	{ "aadal", "PRIEST", 0.74, 0.84, 0, false, nil },
	{ "shrty", "PALADIN", 0.86, 0.78, 0, false, nil },
	{ "Synx", "WARRIOR", 0.58, 0.62, 0, false, nil },
	{ "elaijne", "HUNTER", 1.00, 1.00, 3, false, nil },
	-- Group 2
	{ "arie", "DRUID", 1.00, 0.95, 1, false, nil },
	{ "Iidaen", "DEATHKNIGHT", 1.00, 0.45, 6, false, nil },
	{ "Robeso", "ROGUE", 0.42, 0.55, 2, false, nil },
	{ "alida", "WARLOCK", 1.00, 0.72, 0, true, nil },
	{ "Furore", "DEMONHUNTER", 0.00, 0.00, 17, false, "Dead" },
	-- Group 3
	{ "Addoran", "SHAMAN", 0.94, 0.88, 0, false, nil },
	{ "amb", "MONK", 0.81, 0.90, 3, false, nil },
	{ "Boblefisk", "EVOKER", 1.00, 0.91, 0, false, nil },
	{ "Valdeen", "WARRIOR", 1.00, 0.35, 1, false, nil },
	{ "Meta", "PRIEST", 0.63, 0.52, 0, false, nil },
	-- Group 4
	{ "Bullzeye", "PALADIN", 1.00, 1.00, 0, false, nil },
	{ "D4ffy", "MAGE", 1.00, 0.65, 0, true, nil },
	{ "danny", "SHAMAN", 0.49, 0.40, 0, false, nil },
	{ "dinosaurfossil", "DRUID", 1.00, 0.80, 3, false, nil },
	{ "Emoteph", "ROGUE", 0.88, 0.75, 3, false, nil },
	-- Group 5
	{ "fesken4", "DEATHKNIGHT", 0.77, 0.60, 6, false, nil },
	{ "fetpelle", "MONK", 1.00, 0.94, 0, false, nil },
	{ "fGr", "WARLOCK", 1.00, 0.85, 0, false, nil },
	{ "Freke", "HUNTER", 0.00, 0.00, 2, true, "Offl" },
	{ "gatordile", "EVOKER", 0.91, 0.70, 0, false, nil },
	-- Group 6
	{ "Glennakin", "PALADIN", 1.00, 0.88, 0, false, nil },
	{ "GoldWing", "PRIEST", 0.66, 0.73, 0, false, nil },
	{ "halg", "WARRIOR", 1.00, 0.50, 1, false, nil },
	{ "heffalomp", "MAGE", 0.95, 0.90, 0, false, nil },
	{ "IngNaut", "SHAMAN", 1.00, 0.82, 0, false, nil },
	-- Group 7
	{ "Iska", "DRUID", 1.00, 0.96, 0, false, nil },
	{ "Jafs", "HUNTER", 0.72, 0.64, 2, false, nil },
	{ "Jim", "ROGUE", 1.00, 0.90, 3, false, nil },
	{ "Kafarsken", "DEATHKNIGHT", 0.00, 0.00, 6, true, "Ghst" },
	{ "kaseidu", "MONK", 0.89, 0.77, 0, false, nil },
	-- Group 8
	{ "Klas", "DEMONHUNTER", 1.00, 0.55, 17, false, nil },
	{ "KmV", "WARLOCK", 0.84, 0.69, 0, false, nil },
	{ "Kumadori", "PALADIN", 1.00, 0.93, 0, false, nil },
	{ "Leafiam", "PRIEST", 0.55, 0.48, 0, false, nil },
	{ "Mahadevaa", "SHAMAN", 1.00, 0.87, 0, false, nil },
}

local testRaidDummies = {}

function ns.RefreshRaidTestDummyColors()
	if not ns.GetHealthBarColorForClass then return end
	for _, dummy in pairs(testRaidDummies) do
		if dummy.hp and dummy.classToken then
			local r, g, b = ns.GetHealthBarColorForClass(dummy.classToken)
			dummy.hp:SetStatusBarColor(r, g, b, 0.8)
			if dummy.hpbg then
				dummy.hpbg:SetVertexColor(r, g, b, 0.3)
			end
		end
	end
end

local function BuildRaidTestDummy(parent, groupIdx, memberIdx)
	local slotIndex = (groupIdx - 1) * 5 + memberIdx
	local sample = TEST_DUMMY_ROSTER[((slotIndex - 1) % #TEST_DUMMY_ROSTER) + 1]
	local nameTxt, classToken, hpPct, ppPct, powerType, isOOR, statusTxt = unpack(sample)

	local dummy = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	dummy:SetSize(raidWidth, raidHeight)
	ns.ApplyBackdrop(dummy)

	local col = (groupIdx - 1) % 5
	local row = math.floor((groupIdx - 1) / 5)
	local rowOffset = raidHeight * 5 + 3 * 4 + 12
	local xOffset = col * (raidWidth + 5)
	local yOffset = -row * rowOffset - (memberIdx - 1) * (raidHeight + 3)
	dummy:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, yOffset)

	local cr, cg, cb
	if ns.GetHealthBarColorForClass then
		cr, cg, cb = ns.GetHealthBarColorForClass(classToken)
	else
		local clsColor = (CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[classToken])
			or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken])
			or { r = 0.5, g = 0.5, b = 0.5 }
		cr, cg, cb = clsColor.r, clsColor.g, clsColor.b
	end
	local pwrColor = oUF.colors.power[powerType] or oUF.colors.power.MANA

	local hp = CreateFrame("StatusBar", nil, dummy)
	hp:SetPoint("TOPLEFT")
	hp:SetPoint("TOPRIGHT")
	hp:SetHeight(20)
	hp:SetStatusBarTexture(ns.GetStatusBarTexture and ns.GetStatusBarTexture() or TEXTURE)
	if ns.TrackStatusBar then ns.TrackStatusBar(hp) end
	hp:SetMinMaxValues(0, 1)
	hp:SetValue(hpPct)
	hp:SetStatusBarColor(cr, cg, cb, 0.8)

	local hpbg = hp:CreateTexture(nil, "BORDER")
	hpbg:SetAllPoints(dummy)
	hpbg:SetTexture(ns.GetStatusBarTexture and ns.GetStatusBarTexture() or TEXTURE)
	if ns.TrackBarTexture then ns.TrackBarTexture(hpbg) end
	hpbg:SetVertexColor(cr, cg, cb, 0.3)

	dummy.classToken = classToken
	dummy.hp = hp
	dummy.hpbg = hpbg
	if groupIdx == 1 and memberIdx == 2 then
		dummy.testThreatStatus = 3
	elseif groupIdx == 1 and memberIdx == 3 then
		dummy.testThreatStatus = 2
	elseif groupIdx == 2 and memberIdx == 2 then
		dummy.testThreatStatus = 1
	else
		dummy.testThreatStatus = 0
	end

	local pp = CreateFrame("StatusBar", nil, dummy)
	pp:SetPoint("TOPLEFT", hp, "BOTTOMLEFT", 0, -1)
	pp:SetPoint("TOPRIGHT", hp, "BOTTOMRIGHT", 0, -1)
	pp:SetHeight(3)
	pp:SetStatusBarTexture(ns.GetStatusBarTexture and ns.GetStatusBarTexture() or TEXTURE)
	if ns.TrackStatusBar then ns.TrackStatusBar(pp) end
	pp:SetMinMaxValues(0, 1)
	pp:SetValue(ppPct)
	local pr, pg, pb = pwrColor:GetRGB()
	pp:SetStatusBarColor(pr, pg, pb)

	local ppbg = pp:CreateTexture(nil, "BORDER")
	ppbg:SetAllPoints()
	ppbg:SetTexture(ns.GetStatusBarTexture and ns.GetStatusBarTexture() or TEXTURE)
	if ns.TrackBarTexture then ns.TrackBarTexture(ppbg) end
	ppbg:SetVertexColor(pr, pg, pb, 0.3)

	local statusStr = hp:CreateFontString(nil, "OVERLAY")
	statusStr:SetFont(ns.GetFontPath and ns.GetFontPath() or FONT, math.max(7, RAID_FONT_SIZE + (ns.GetFontSizeOffset and ns.GetFontSizeOffset() or 0)), ns.GetFontFlags and ns.GetFontFlags() or "OUTLINE")
	if ns.TrackFontString then ns.TrackFontString(statusStr, RAID_FONT_SIZE) end
	statusStr:SetPoint("RIGHT", -1, 0)
	if statusTxt then
		statusStr:SetText(statusTxt)
		statusStr:SetTextColor(statusTxt == "Offl" and 0.7 or 1, statusTxt == "Offl" and 0.7 or 0.5, statusTxt == "Offl" and 0.7 or 0.5)
	else
		statusStr:SetFormattedText("%d%%", math.floor(hpPct * 100 + 0.5))
		statusStr:SetTextColor(1, 1, 1)
	end

	local nameStr = hp:CreateFontString(nil, "OVERLAY")
	nameStr:SetFont(ns.GetFontPath and ns.GetFontPath() or FONT, math.max(7, RAID_FONT_SIZE + (ns.GetFontSizeOffset and ns.GetFontSizeOffset() or 0)), ns.GetFontFlags and ns.GetFontFlags() or "OUTLINE")
	if ns.TrackFontString then ns.TrackFontString(nameStr, RAID_FONT_SIZE) end
	nameStr:SetPoint("LEFT", 2, 0)
	nameStr:SetPoint("RIGHT", statusStr, "LEFT", -4, 0)
	nameStr:SetJustifyH("LEFT")
	nameStr:SetWordWrap(false)
	nameStr:SetText(nameTxt:sub(1, 4))
	nameStr:SetTextColor(1, 1, 1)

	dummy:SetAlpha(isOOR and 0.45 or 1)
	dummy:EnableMouse(true)
	dummy:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:AddLine("oUF_Brun Raid Preview (" .. nameTxt .. ")")
		GameTooltip:AddLine("Slot 1 in each group uses your live character for click-casting", 0.8, 0.8, 0.8, true)
		GameTooltip:Show()
	end)
	dummy:SetScript("OnLeave", function() GameTooltip:Hide() end)

	return dummy
end

function ns.RefreshRaidTestDummyThreat()
	if not ns.PostUpdateThreat then return end
	local active = ns.IsTestModeActive and ns.IsTestModeActive() or false
	for _, dummy in pairs(testRaidDummies) do
		local status = (active and dummy:IsShown()) and (dummy.testThreatStatus or 0) or 0
		ns.PostUpdateThreat({ __owner = dummy }, nil, status)
	end
end

function ns.ToggleRaidTestFrames(testModeActive)
	if InCombatLockdown() then return end

	for _, dummy in pairs(testRaidDummies) do
		dummy:Hide()
	end

	if not ns.IsRaidFramesEnabled() then return end

	local raidAnchor = _G.oUF_BrunRaidAnchor
	for i = 1, 8 do
		local header = _G["oUF_BrunRaid" .. i]
		if header then
			if testModeActive then
				UnregisterAttributeDriver(header, "state-visibility")
				header:SetAttribute("showSolo", true)
				header:SetAttribute("showParty", true)
				header:SetAttribute("showPlayer", true)
				header:SetAttribute("groupFilter", IsInRaid() and tostring(i) or nil)
				header:Show()

				if raidAnchor then
					local startSlot = 2
					for c = 1, 5 do
						local child = header:GetAttribute("child" .. c)
						if child and child:IsShown() then
							startSlot = c + 1
						end
					end
					for m = startSlot, 5 do
						local key = (i - 1) * 5 + m
						if not testRaidDummies[key] then
							testRaidDummies[key] = BuildRaidTestDummy(raidAnchor, i, m)
						end
						testRaidDummies[key]:Show()
					end
				end
			else
				header:SetAttribute("showSolo", nil)
				header:SetAttribute("showParty", nil)
				header:SetAttribute("showPlayer", nil)
				header:SetAttribute("groupFilter", tostring(i))
				header:SetVisibility("custom [group:raid] show; hide")
			end
		end
	end

	ns.RefreshRaidTestDummyThreat()
end

--===================================================--
-- Raid Group Header Spawning
--===================================================--

function ns.SpawnRaidFrames(self)
	if not ns.IsRaidFramesEnabled() then return end

	ns.UpdateBlizzardRaidFramesVisibility()
	local raidAnchor = ns.CreatePositionAnchor(
		"Raid",
		raidWidth * 5 + 5 * 4,
		(raidHeight * 5 + 3 * 4) * 2 + 12,
		ns.defaultRaidPoint
	)
	local rowOffset = raidHeight * 5 + 3 * 4 + 12

	self:SetActiveStyle("BrunRaid")
	for i = 1, 8 do
		local header = self:SpawnHeader(
			"oUF_BrunRaid" .. i,
			nil,
			"showRaid", true,
			"point", "TOP",
			"yOffset", -3,
			"groupFilter", tostring(i),
			"sortMethod", "INDEX",
			"oUF-initialConfigFunction", string.format("self:SetWidth(%d) self:SetHeight(%d)", raidWidth, raidHeight)
		)
		local col = (i - 1) % 5
		local row = math.floor((i - 1) / 5)
		header:SetPoint("TOPLEFT", raidAnchor, "TOPLEFT", col * (raidWidth + 5), -row * rowOffset)
		header:SetVisibility("custom [group:raid] show; hide")
	end
	self:SetActiveStyle("Brun")
end

-- Handle late / demand-loaded execution if oUF:Factory already ran at the end of oUF_Brun.lua.
if IsLoggedIn() and not _G.oUF_BrunRaidAnchor then
	oUF:Factory(function(self)
		if ns.IsRaidFramesEnabled() and not _G.oUF_BrunRaidAnchor then
			ns.SpawnRaidFrames(self)
		end
	end)
end
