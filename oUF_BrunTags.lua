local _, ns = ...
local oUF = ns.oUF or _G.oUF
assert(oUF, "oUF_Brun requires oUF to be loaded.")

local issecretvalue = _G.issecretvalue
local isForever = (WOW_PROJECT_ID == WOW_PROJECT_CAMELOT) or (GameVersion and GameVersion.Forever)
local CreateAbbreviateConfig, AbbreviateNumbers = _G.CreateAbbreviateConfig, _G.AbbreviateNumbers
local WrapString = C_StringUtil and C_StringUtil.WrapString
local TruncateWhenZero = C_StringUtil and C_StringUtil.TruncateWhenZero
local StripHyperlinks = C_StringUtil and C_StringUtil.StripHyperlinks
local GetContentDifficultyCreatureForPlayer = C_PlayerInfo and C_PlayerInfo.GetContentDifficultyCreatureForPlayer
local GetDifficultyColor = _G.GetDifficultyColor

local NumberAbbrConfig = CreateAbbreviateConfig and {
	config = CreateAbbreviateConfig({
		{ breakpoint = 1e9, abbreviation = "b", significandDivisor = 1e5, fractionDivisor = 1e4, abbreviationIsGlobal = false },
		{ breakpoint = 1e6, abbreviation = "m", significandDivisor = 1e4, fractionDivisor = 1e2, abbreviationIsGlobal = false },
		{ breakpoint = 1e5, abbreviation = "k", significandDivisor = 1e3, fractionDivisor = 1, abbreviationIsGlobal = false },
		{ breakpoint = 1e4, abbreviation = "k", significandDivisor = 1e2, fractionDivisor = 1e1, abbreviationIsGlobal = false },
	})
}

-- Truncate UTF-8 strings safely by character count rather than byte length to prevent broken multi-byte glyphs.
local function utf8sub(str, maxChars, dots)
	if not str or issecretvalue(str) then
		return str or ""
	end
	local bytes = #str
	if bytes <= maxChars then
		return str
	end

	local len, pos = 0, 1
	while pos <= bytes do
		len = len + 1
		local c = str:byte(pos)
		pos = pos + (c < 192 and 1 or (c < 224 and 2 or (c < 240 and 3 or 4)))
		if len == maxChars then break end
	end

	if len == maxChars and pos <= bytes then
		return str:sub(1, pos - 1) .. (dots and "..." or "")
	end
	return str
end

local function siValue(val)
	if not val then return 0 end
	if AbbreviateNumbers and NumberAbbrConfig then
		return AbbreviateNumbers(val, NumberAbbrConfig)
	end
	if issecretvalue(val) then
		return val
	end
	if val >= 1e6 then
		return ("%.1f"):format(val / 1e6):gsub("%.", "m")
	elseif val >= 1e4 then
		return ("%.1f"):format(val / 1e3):gsub("%.", "k")
	end
	return val
end
ns.siValue = siValue

-- Secret-safe zero-suppression: returns "" when amount is 0, or `text` when amount > 0.
local function FormatZero(amount, text)
	if WrapString and TruncateWhenZero and StripHyperlinks then
		local link = WrapString(TruncateWhenZero(amount), "|Hitem:", string.format("|h%s|h", text))
		return StripHyperlinks(link, true, false, false, false, true)
	end
	return TruncateWhenZero and TruncateWhenZero(amount) or text
end
ns.FormatZero = FormatZero

local function RegisterTag(name, events, fn)
	oUF.Tags.Methods[name] = fn
	oUF.Tags.Events[name] = events
end

RegisterTag("brunhp", "UNIT_HEALTH UNIT_MAXHEALTH UNIT_CONNECTION", function(u)
	local m, n = UnitHealthMax(u), UnitHealth(u)
	if not m then return end
	if issecretvalue(m) or issecretvalue(n) then
		return string.format("%s | %d%%", siValue(n), UnitHealthPercent(u, true, CurveConstants.ScaleTo100))
	end
	return m == 0 and 0
		or (not UnitIsFriend("player", u) and string.format("%s | %d%%", siValue(n), n / m * 100))
		or m ~= n and string.format("|cffff8585-%s|r  %s/%s", siValue(m - n), siValue(n), siValue(m))
		or siValue(m)
end)

RegisterTag("brunhppp", "UNIT_HEALTH UNIT_MAXHEALTH UNIT_POWER_UPDATE", function(u)
	return string.format("%s | %s", siValue(UnitPower(u) or 0), siValue(UnitHealth(u) or 0))
end)

RegisterTag("brunminushp", "UNIT_HEALTH UNIT_MAXHEALTH UNIT_CONNECTION", function(u)
	local m, n = UnitHealthMax(u), UnitHealth(u)
	if not m then return end
	if issecretvalue(m) or issecretvalue(n) then
		local missing = UnitHealthMissing(u)
		return FormatZero(missing, string.format("|cffff8585-%s|r", siValue(missing)))
	end
	return m == 0 and 0
		or n ~= m and string.format("|cffff8585-%s|r", siValue(m - n))
		or siValue(m)
end)

RegisterTag("brunpp", "UNIT_POWER_FREQUENT UNIT_MAXPOWER UNIT_DISPLAYPOWER UNIT_CONNECTION", function(u)
	local m, n = UnitPowerMax(u), UnitPower(u)
	if not m then return end
	if issecretvalue(m) or issecretvalue(n) then
		return FormatZero(n, string.format("%s/%s", siValue(n), siValue(m)))
	end
	return n == 0 and ""
		or m == 0 and 0
		or n ~= m and string.format("%s/%s", siValue(n), siValue(m))
		or siValue(m)
end)

local function GetFormattedUnitName(u, r, maxChars, dots)
	local unit = r or u
	if not unit or not UnitExists(unit) then return "" end

	local baseName = (UnitNameUnmodified and UnitNameUnmodified(unit)) or UnitName(unit)
	if not baseName or baseName == "" then return "" end

	if isForever and ns.firstNameOnly and (UnitIsPlayer(unit) or (UnitInPartyIsAI and UnitInPartyIsAI(unit))) then
		return utf8sub(baseName, maxChars, dots)
	end

	local fullName
	if NameUtil then
		if NameUtil.FormatUnitNameForDisplay then
			fullName = NameUtil.FormatUnitNameForDisplay(unit)
		elseif NameUtil.GetUnmodifiedUnitFullName then
			fullName = NameUtil.GetUnmodifiedUnitFullName(unit)
		end
	end

	local name = baseName
	if type(fullName) == "string" and fullName ~= "" then
		-- Deduplicate if Forever engine returned "First First" for characters without surnames
		local first, last = fullName:match("^(%S+)%s+(%S+)$")
		if first and last and first == last then
			fullName = first
		end
		-- Verify fullName actually belongs to this unit (contains or starts with baseName)
		if fullName:find(baseName, 1, true) then
			name = fullName
		end
	end

	return utf8sub(name, maxChars, dots)
end

RegisterTag("ShortName", "UNIT_NAME_UPDATE GROUP_ROSTER_UPDATE UNIT_CONNECTION PARTY_MEMBER_ENABLE PARTY_MEMBER_DISABLE", function(u, r)
	local name = GetFormattedUnitName(u, r, 8, false)
	if type(name) == "string" then
		local first = name:match("^(%S+)")
		if first then name = first end
	end
	return utf8sub(name, 8, false)
end)

RegisterTag("NormalName", "UNIT_NAME_UPDATE GROUP_ROSTER_UPDATE UNIT_CONNECTION PARTY_MEMBER_ENABLE PARTY_MEMBER_DISABLE", function(u, r)
	return GetFormattedUnitName(u, r, 27, true)
end)

RegisterTag("afkdnd", "PLAYER_FLAGS_CHANGED", function(u)
	local isAFK = UnitIsAFK(u)
	local isDND = UnitIsDND(u)
	if issecretvalue(isAFK) or issecretvalue(isDND) then return end
	return isAFK and "|cffffff00<A>|r" or isDND and "|cffffff00<D>|r"
end)

RegisterTag("smarterrace", "UNIT_NAME_UPDATE GROUP_ROSTER_UPDATE", function(u)
	return (UnitIsPlayer(u) and UnitRace(u)) or UnitCreatureFamily(u) or UnitCreatureType(u)
end)

local function GetGreenRange()
	if C_QuestLog and C_QuestLog.GetTrivialRange then
		return C_QuestLog.GetTrivialRange()
	elseif GetQuestGreenRange then
		return GetQuestGreenRange()
	elseif UnitQuestTrivialLevelRange then
		return UnitQuestTrivialLevelRange("player")
	end
	return 6
end

oUF.Tags.SharedEvents.PLAYER_LEVEL_CHANGED = true
oUF.Tags.SharedEvents.GROUP_ROSTER_UPDATE = true
oUF.Tags.SharedEvents.PARTY_MEMBER_ENABLE = true
oUF.Tags.SharedEvents.PARTY_MEMBER_DISABLE = true

RegisterTag("difficulty", "UNIT_FACTION UNIT_LEVEL PLAYER_LEVEL_UP PLAYER_LEVEL_CHANGED", function(u)
	if GetContentDifficultyCreatureForPlayer and GetDifficultyColor then
		local diff = GetContentDifficultyCreatureForPlayer(u)
		if diff and not issecretvalue(diff) then
			local color = GetDifficultyColor(diff)
			if color then
				return Hex(color.r, color.g, color.b)
			end
		end
	end

	local l = UnitEffectiveLevel(u)
	if not l or issecretvalue(l) then
		return Hex(GetCreatureDifficultyColor(999))
	end
	if isForever then
		if l <= 0 then
			return Hex(QuestDifficultyColors["impossible"])
		end
		local levelDiff = l - UnitEffectiveLevel("player")
		if levelDiff >= 5 then
			return Hex(QuestDifficultyColors["impossible"])
		elseif levelDiff >= 3 then
			return Hex(QuestDifficultyColors["verydifficult"])
		elseif levelDiff >= -2 then
			return Hex(QuestDifficultyColors["difficult"])
		elseif -levelDiff <= GetGreenRange() then
			return Hex(QuestDifficultyColors["standard"])
		else
			return Hex(QuestDifficultyColors["trivial"])
		end
	end
	return Hex(GetCreatureDifficultyColor(l > 0 and l or 999))
end)
