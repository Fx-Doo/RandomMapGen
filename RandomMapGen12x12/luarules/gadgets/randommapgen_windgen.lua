local engineVersion = 100 -- just filled this in here incorrectly but old engines arent used anyway
if Engine and Engine.version then
	local function Split(s, separator)
		local results = {}
		for part in s:gmatch("[^"..separator.."]+") do
			results[#results + 1] = part
		end
		return results
	end
	engineVersion = Split(Engine.version, '-')
	if engineVersion[2] ~= nil and engineVersion[3] ~= nil then
		engineVersion = tonumber(string.gsub(engineVersion[1], '%.', '')..engineVersion[2])
	else
		engineVersion = tonumber(Engine.version)
	end
elseif Game and Game.version then
	engineVersion = tonumber(Game.version)
end

-- fixed: https://springrts.com/mantis/view.php?id=5864
if not ((engineVersion < 1000 and engineVersion <= 105) or engineVersion >= 10401803) then
	return
end

function gadget:GetInfo()
	return {
		name	= "Wind generation",
		desc	= "Sets wind generation values",
		author	= "Doo",
		date	= "July,2016",
		layer	= 11,
		enabled = true,
	}
end


--------------------------------------------------------------------------------
-- synced
--------------------------------------------------------------------------------
if gadgetHandler:IsSyncedCode() then
	function gadget:Initialize()
		local typemap = Spring.GetGameRulesParam("typemap")
		local minw, maxw
		local r = math.random
		if typemap == "arctic" then
			minw = r(3,8)
			maxw = r(13,20)
		elseif typemap == "temperate" then
			minw = r(2,4)
			maxw = r(8,13)
		elseif typemap == "desert" then
			minw = r(1,2)
			maxw = r(8,16)
		else
			minw = 0
			maxw = 1
		end
		Spring.SetWind(minw,maxw)
	end
end

