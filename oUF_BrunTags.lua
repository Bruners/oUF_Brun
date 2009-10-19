local utf8sub = function(string, i, dots)
	local bytes = string:len()
	if (bytes <= i) then
		return string
	else
		local len, pos = 0, 1
		while(pos <= bytes) do
			len = len + 1
			local c = string:byte(pos)
			if (c > 0 and c <= 127) then
				pos = pos + 1
			elseif (c >= 192 and c <= 223) then
				pos = pos + 2
			elseif (c >= 224 and c <= 239) then
				pos = pos + 3
			elseif (c >= 240 and c <= 247) then
				pos = pos + 4
			end
			if (len == i) then break end
		end

		if (len == i and pos <= bytes) then
			return string:sub(1, pos - 1)..(dots and '...' or '')
		else
			return string
		end
	end
end

local function Hex(r, g, b)
	if type(r) == "table" then
		if r.r then r, g, b = r.r, r.g, r.b else r, g, b = unpack(r) end
	end
	return string.format("|cff%02x%02x%02x", r*255, g*255, b*255)
end

local siValue = function(val)
	if(val >= 1e4) then
		return ("%.1f"):format(val / 1e3):gsub("%.", "k")
	else
		return val
	end
end

if(not oUF.Tags["[happiness]"]) then
	oUF.Tags["[happiness]"] = function(u)
		if(u == "pet") then
			local happiness = { ":<", ":|", ":D" }
			return happiness[GetPetHappiness()]
		end
	end
end
oUF.Tags["[brunhp]"] = function(u)
	local m, n = UnitHealthMax(u), UnitHealth(u)
	if m then
		return m == 0 and 0 or (not UnitIsFriend("player", u) and string.format("%s | %d%%", siValue(n),n/m*100)) or m ~=  n and string.format("|cffff8585-%s|r  %s/%s", siValue(m - n), siValue(n),siValue(m)) or n == m and m
	end
end
oUF.Tags["[brunhppp]"] = function(u)
	local hp =  UnitHealth(u) or 0
	local pp = UnitPower(u) or 0
	if hp or pp then
		return string.format("%s | %s", pp, hp)
	end
end
oUF.Tags["[brunminushp]"] = function(u)
	local m, n = UnitHealthMax(u), UnitHealth(u)
	if m then
		return m == 0 and 0 or n ~= m and string.format("|cffff8585-%s|r", siValue(m - n)) or m == n and siValue(m)
	end
end
oUF.Tags["[brunpp]"] = function(u)
	local m, n = UnitPowerMax(u), UnitPower(u)
	if m then
		return n == 0 and "" or m == 0 and 0 or n ~= m and string.format("%s/%s", siValue(n),siValue(m)) or m == n and m
	end
end
oUF.Tags["[ShortName]"] = function(u)
	local name = UnitName(u)
	if (u == 'pet' and name == 'Unknown') then
		return 'Pet'
	else
		return utf8sub(name, 8, false)
	end
end
oUF.Tags["[NormalName]"] = function(u)
	local name = UnitName(u)
	return utf8sub(name, 27, true)
end

oUF.Tags["[afkdnd]"] = function(u)
	if u then return UnitIsAFK(u) and "|cffffff00<A>|r" or UnitIsDND(u) and "|cffffff00<D>|r" end
end
oUF.Tags["[smarterrace]"] = function(u)
	if u then return (UnitIsPlayer(u) and UnitRace(u)) or UnitCreatureFamily(u) or UnitCreatureType(u) end
end

oUF.Tags["[difficulty]"] = function(u)
	if u then local l = UnitLevel(u); return Hex(GetQuestDifficultyColor((l > 0) and l or 99)) end
end

oUF.TagEvents["[happiness]"] = "UNIT_HAPPINESS"
oUF.TagEvents["[smarterrace]"] = "PLAYER_TARGET_CHANGED"
oUF.TagEvents["[ShortName]"] = "UNIT_NAME_UPDATE"
oUF.TagEvents["[NormalName]"] = "UNIT_NAME_UPDATE"
oUF.TagEvents["[afkdnd]"] = "PLAYER_FLAGS_CHANGED"
oUF.TagEvents["[brunhp]"] = "UNIT_HEALTH UNIT_MAXHEALTH"
oUF.TagEvents["[brunminushp]"] = "UNIT_HEALTH UNIT_MAXHEALTH"
oUF.TagEvents["[brunpp]"] = "UNIT_MAXENERGY UNIT_MAXFOCUS UNIT_MAXMANA UNIT_MAXRAGE UNIT_ENERGY UNIT_FOCUS UNIT_MANA UNIT_RAGE UNIT_MAXRUNIC_POWER UNIT_RUNIC_POWER"
oUF.TagEvents["[brunhppp]"] = "UNIT_HEALTH UNIT_ENERGY UNIT_FOCUS UNIT_MANA UNIT_RAGE UNIT_RUNIC_POWER"