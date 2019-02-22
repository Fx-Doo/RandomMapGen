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
if not ((engineVersion < 1000 and engineVersion <= 105) or engineVersion >= 10401803) or (Game and Game.version and tonumber(Game.version) == 103) then
	return
end

function gadget:GetInfo()
	return {
		name	= "Wind generation",
		desc	= "Sets wind generation values",
		author	= "Doo",
		date	= "July,2016",
		layer	= 11,
        enabled = (select(1, Spring.GetGameFrame()) <= 0),
	}
end


--------------------------------------------------------------------------------
-- synced
--------------------------------------------------------------------------------
if gadgetHandler:IsSyncedCode() then
	function gadget:Initialize()
		local typemap = Spring.GetGameRulesParam("typemap")
		local minw, maxw
		local aparams = {}
		local sparam = {}
		local r = math.random
		if typemap == "arctic" then
			aparams = {
			sunColor = {0.8, 0.6, 0.3, 1},
			skyColor = {0.4, 0.4, 0.4, 0.6},
			cloudColor = {0.6, 0.6, 0.6, 0.9},
			fogColor = {0.4, 0.4, 0.4, 0},
			}
			sparams = {
			groundAmbientColor = {0.5, 0.5, 0.5},
			groundDiffuseColor = {0.8, 0.8, 0.8},
			unitAmbientColor = {0.4, 0.4, 0.4},
			unitDiffuseColor = {0.85, 0.85, 0.85},
			}
			minw = r(3,8)
			maxw = r(13,20)
		elseif typemap == "temperate" then
			aparams = {
			sunColor = {1, 0.8, 0.4, 1},
			skyColor = {0.1, 0.2, 0.9, 1.0},
			cloudColor = {0.85, 0.7, 0.7, 0.4},
			fogColor = {0.85, 0.7, 0.7, 0.4},
			}
			sparams = {
			groundAmbientColor = {0.4, 0.3, 0.4},
			groundDiffuseColor = {0.7, 0.7, 0.7},
			unitAmbientColor = {0.3, 0.2, 0.3},
			unitDiffuseColor = {0.8, 0.8, 0.8},
			}
			minw = r(2,4)
			maxw = r(8,13)
		elseif typemap == "desert" then
			Spring.SetMapRenderingParams({
			   splatTexScales = {0.006, 0.01, 0.02, 0.02},
			})
			aparams = {
			sunColor = {1, 0.8, 0.4, 1},
			skyColor = {0.1, 0.2, 0.9, 1},
			cloudColor = {0.1, 0.2, 0.9, 0},
			fogColor = {0.1, 0.2, 0.9, 0},
			}
			sparams = {
			groundAmbientColor = {0.7, 0.7, 0.7},
			groundDiffuseColor = {0.9, 0.9, 0.9},
			unitAmbientColor = {0.8, 0.8, 0.8},
			unitDiffuseColor = {1, 1, 1},
			}
			minw = r(1,2)
			maxw = r(8,16)
		else
			Spring.SetMapRenderingParams({
			   splatTexScales = {0.02, 0.015, 0.02, 0.02},
			})
			aparams = {
			sunColor = {1, 0.8, 0.8, 1},
			skyColor = {0, 0, 0, 1},
			cloudColor = {1, 1, 1, 1},
			fogColor = {0, 0, 0, 1},
			}
			sparams = {
			groundAmbientColor = {0.5, 0.5, 0.5},
			groundDiffuseColor = {1, 1, 1},
			unitAmbientColor = {0.4, 0.4, 0.4},
			unitDiffuseColor = {1, 1, 1},
			}
			minw = 0
			maxw = 1
		end
		Spring.SetAtmosphere(aparams)
		Spring.SetSunLighting(sparams)
		Spring.SetWind(minw,maxw)
	end
end

