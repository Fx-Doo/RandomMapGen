
function gadget:GetInfo()
	return {
		name	= "MapGen",
		desc	= "MapGENERATOR325550",
		author	= "Doo",
		date	= "July,2016",
		layer	= -100,
        enabled = (select(1, Spring.GetGameFrame()) <= 0),
		}
end


--------------------------------------------------------------------------------
-- synced
--------------------------------------------------------------------------------
if gadgetHandler:IsSyncedCode() then

	local gdheight = Spring.GetGroundHeight
	local testBuild = Spring.TestBuildOrder
	local mapOptions = Spring.GetMapOptions
	local SetHeightMap = Spring.SetHeightMap
	local SetSmoothMesh = Spring.SetSmoothMesh
	local SetMetal = Spring.SetMetalAmount

	-- MAPDEPENDANT VARS
	local sizeX = Game.mapSizeX
	local sizeZ = Game.mapSizeZ
	local sqr = Game.squareSize
	local startingSize = 512
	while sizeX%(startingSize*2) == 0 and sizeZ%(startingSize*2) == 0 do -- get the highest startingSize possible
		startingSize = startingSize*2
	end

	-- PARAMS
	local height
	local roadlevelfactor
	local flattenRatio
	local heightGrouping
	local nbRoads
	local nbMountains
	local levelground
	local nbMetalSpots
	local symType
	local typemap
	local flatness -- goal standard derivation of height = math.sqrt(variance) (per 8x8 sqr)
	local variance
	local meanHeight
	local nCells
	local roadHeight
	local metalspotvalue
	
	function gadget:Initialize()
		local randomSeed
		variance = 0
		meanHeight = 1
		nCells = 0
		if mapOptions() and mapOptions().seed and tonumber(mapOptions().seed) ~= 0 then
			randomSeed = tonumber(mapOptions().seed)
		else
			randomSeed = math.random(1,10000)
		end
		math.randomseed( randomSeed )
		Spring.Echo("Random Seed = "..tostring(randomSeed)..", Symtype = "..tostring((mapOptions() and mapOptions().symtype and tonumber(mapOptions().symtype)) or 0))
		
		local nbTeams = 0
		for i, team in pairs (Spring.GetTeamList()) do
			if team ~= Spring.GetGaiaTeamID() then
				nbTeams = nbTeams + 1
			end
		end
		
	-- PARAMS
		metalspotvalue = math.random(128,255)
		flatness = math.random(300,500)
		height = math.random(256,1024)
		roadlevelfactor = math.random(10,100)/10 -- higher means flatter roads
		flattenRatio = 1 -- math.random(25,200)/100 -- lower means flatter final render
		heightGrouping = math.random(10,64) -- higher means more plateaus, lower means smoother but more regular height differences
		heightGrouping = (heightGrouping)/flattenRatio
		nbRoads = math.random(1,12)
		nbMountains = math.random(1,6)
		nbMetalSpots = math.random(28,44)
		symType = (mapOptions() and mapOptions().symtype and ((tonumber(mapOptions().symtype))~= 0) and tonumber(mapOptions().symtype)) or math.random(1,6)
		typemap = math.random(1,4)
		if typemap == 1 then
			Spring.SetGameRulesParam("typemap", "arctic")
			heightGrouping = math.floor(heightGrouping*0.3) + 1
			height = math.floor(height*1.5)
			flatness = flatness * 1.5
			nbRoads = math.floor(nbRoads*0.4)
			roadHeight = height
			roadlevelfactor = roadlevelfactor/4
			nbMountains = math.floor(nbMountains*2)
			nbMetalSpots = math.floor(nbMetalSpots*1)
			levelground = 0
		elseif typemap == 2 then
			Spring.SetGameRulesParam("typemap", "desert")
			heightGrouping = math.random(60,80)
			height = math.floor(height*1.0)
			flatness = flatness
			nbRoads = math.floor(nbRoads*0)
			roadHeight = height
			roadlevelfactor = roadlevelfactor / 10
			nbMountains = math.floor(nbMountains*0.6)
			nbMetalSpots = math.floor(nbMetalSpots*1.0)
			levelground = math.random(-80,110)
		elseif typemap == 3 then
			Spring.SetGameRulesParam("typemap", "moon")
			heightGrouping = math.floor(heightGrouping*0.1) + 1
			height = math.floor(height*0.6)
			flatness = flatness * 0.8
			nbRoads = math.floor(nbRoads*0)
			roadlevelfactor = roadlevelfactor/10
			roadHeight = height
			nbMountains = math.floor(nbMountains*1.5)
			nbMetalSpots = math.floor(nbMetalSpots*1.1)
			levelground = 300
		elseif typemap == 4 then
			Spring.SetGameRulesParam("typemap", "temperate")
			heightGrouping = math.floor(heightGrouping*0.8) + 1
			height = math.floor(height*1)
			flatness = flatness
			nbRoads = math.floor(nbRoads*1)
			roadHeight = -40
			roadlevelfactor = roadlevelfactor/5
			nbMountains = math.floor(nbMountains*1.3)
			nbMetalSpots = math.floor(nbMetalSpots*1)
			levelground = math.random(-100,40)
		end
		
		if symType == 6 then
			nbMetalSpots = nbMetalSpots * 2
		end
		
		Heightranges = height
		symTable = GenerateSymmetryTable() -- Generate a symmetry table (symTable.x[x] => x')
		local Cells,Size = GenerateCells(startingSize) -- generate the initial cell(s)
		roads = GenerateRoads(Size)	-- Generate a set of "roads"
		mountains = GenerateMountains(Size) -- Generate a set of "mountains"		
		Cells,Size = ApplySymmetry(Cells,Size, symTable) -- Apply a first symmetry (prolly useless but it's not heavy anyway)
		
		while Size >= sqr*2^5 do -- use diamond square rendering for startingSize => squareSize * 8
			Cells,Size,Heightranges = SquareDiamond(Cells, Size, Heightranges)
		end
		
		Cells,Size = ApplySymmetry(Cells,Size, symTable) -- Reapply the symetry
		
		while Size >= sqr*2^3 do -- use diamond square rendering for startingSize => squareSize * 4
			Cells,Size,Heightranges = SquareDiamond(Cells, Size, Heightranges)
		end
		
		Cells,Size = GroupCellsByHeight(Cells,Size) -- Apply congruence to cells heights
		CreateSmoothMesh(Cells,Size)
		while Size >= sqr*2 do
			Cells,Size = SquareDiamondSmoothing(Cells, Size) -- Complete rendering to squareSize/2
		end
		
		while Size >= sqr*2 do -- failsafe to make sure final stage is squareSize/2
			Cells,Size = FinishCells(Cells,Size)
		end
		
		for i = 1,5 do -- smooth (mean of 8 closest cells), repeated 5 times
			Cells, Size = FinalSmoothing(Cells, Size)
		end

		Cells, Size = FlattenRoads(Cells, Size)
		Spring.SetHeightMapFunc(ApplyHeightMap, Cells) -- Apply the height map
		nbMetalSpots = math.floor(math.sqrt(nbTeams^(1.75)) * nbMetalSpots)
		metalspots = GenerateMetalSpots(nbMetalSpots)
		SetUpMetalSpots(metalspots)
		
		Cells = nil
		metalspots = nil
		mountains = nil
		roads = nil
	end
	
	function CreateSmoothMesh(cells, size)
		Spring.SetSmoothMeshFunc(SmoothMeshFunc, cells, size)
	end
	
	SmoothMeshFunc = function(cells, size)
		for x = 0,sizeX, size do
			for z = 0, sizeZ, size do
				SetSmoothMesh(x, z, cells[x][z] * flattenRatio + levelground + 120)
			end
		end
	end
		
	function FlattenRoads(cells, size)
		for i = 1,4 do
			for x = 0, sizeX, size do
				for z = 0, sizeZ, size do
					if roads[x] and roads[x][z] then
						local additiveValue = 0
						local ct = 0
						for k = -3,3 do
							for v = -3,3 do
								local mult = 1
								if k == 0 and v == 0 then
									mult = roadlevelfactor
								elseif roads[x+k*size] and roads[x+k*size][z+v*size] then
									mult = roadlevelfactor
								end
								if cells[x+k*size] and cells[x+k*size][z+v*size] then
									mult = mult
									additiveValue = additiveValue + cells[x+k*size][z+v*size] * mult
									ct = ct + mult
								else
									mult = 0
								end
							end
						end
						if cells[x] and cells[x][z] then
							cells[x][z] = additiveValue / ct
						end
					end
				end
			end
		end
		return cells, size
	end
	
	
	function SetUpMetalSpots(metal)
		for x = 0,sizeX,sqr/2 do
			for z = 0,sizeZ,sqr/2 do
				if metal and metal[x] and metal[x][z] then
					local X, Z = math.floor(x/16), math.floor(z/16)
					SetMetal(X,Z, metalspotvalue)
				else
					local X, Z = math.floor(x/16), math.floor(z/16)
					SetMetal(X,Z, 0)		
				end
			end
		end
	end
	
	function GenerateSymmetryTable()
		local symTable = {x = {}, z = {}}
		if symType == 1 then -- Central Symetry
			symTable = function(x,z,size)
				return {x = sizeX - x, z = sizeZ - z}
			end
		elseif symType == 2 then -- vertical symTable
			symTable = function(x,z,size)
				return {x = sizeX - x, z = z}
			end
		elseif symType == 3 then -- horizontal symTable
			symTable = function(x,z,size)
				return {x = x, z = sizeZ - z}
			end
		elseif symType == 4 then -- diagonal c1 symTable
			symTable = function(x,z,size)
				return {x = z, z = x}
			end
		elseif symType == 5 then -- diagonal c2 symTable
			symTable = function(x,z,size)
				return {x = sizeZ - z, z = sizeX - x}
			end
		elseif symType == 6 then
			symTable = function(x,z,size)
				return {x = x, z = z}
			end
		end
		return symTable
	end
	
	function CloseMetalSpot(x,z,metal)
		local radiussqr = 320^2
		local symdissqr = (symTable(x,z).x - x)^2 + (symTable(x,z).z - z)^2
		if symType == 6 then
			symdissqr = 321^2
		end
		if symdissqr < radiussqr then
			return true
		end
		for i = 1, #metal do
			local pos = metal[i]
			local addsqr =  (pos.x - x)^2 + (pos.z - z)^2
			if addsqr < radiussqr then
				return true
			end
		end
		return false
	end
		
	function GenerateMetalSpots(n)
		local metalSpotSize = 48
		local metal = {}
		local METAL = {}
		for i = 1,n*2,2 do
			local x = math.random(metalSpotSize,sizeX-metalSpotSize)
			local z = math.random(metalSpotSize,sizeZ-metalSpotSize)
			local metalSpotCloseBy = CloseMetalSpot(x,z,metal)
				while (testBuild(UnitDefNames["armmoho"].id, x,gdheight(x,z),z, 1) == 0 and testBuild(UnitDefNames["armuwmme"].id, x,gdheight(x,z),z, 1) == 0) or metalSpotCloseBy == true do
					x = math.random(metalSpotSize,sizeX-metalSpotSize)
					z = math.random(metalSpotSize,sizeZ-metalSpotSize)
					metalSpotCloseBy = CloseMetalSpot(x,z,metal)
				end
			x = x - x%metalSpotSize
			z = z - z%metalSpotSize
			metal[i] = {x = x, z = z, size = metalSpotSize}
			metal[i+1] = {x = symTable(x,z).x, z = symTable(x,z).z, size = metalSpotSize}
		end
		for i = 1, #metal do
			local pos = metal[i]
			for v = -pos.size/2,pos.size/2 -1, sqr/2 do
				for w = -pos.size/2,pos.size/2 -1, sqr/2 do
					METAL[pos.x + v] = METAL[pos.x + v] or {}
					METAL[pos.x + v][pos.z + w] = true
					-- METAL[symTable(pos.x + v, pos.z + w,sqr/2).x] = METAL[symTable(pos.x + v, pos.z + w,sqr/2).x] or {}
					-- METAL[symTable(pos.x + v, pos.z + w,sqr/2).x][symTable(pos.x + v, pos.z + w,sqr/2).z] = true
				end
			end
		end
		return METAL
	end
			
	function ApplySymmetry(cells, size, symTable)
		local newroads, newmountains = {}, {}
		local newcells = {}
		if math.random(0,1) == 1 then -- pick source -- SOURCE = NORTH/WEST
			for x = 0,sizeX,size do
				for z = 0,sizeZ,size do
						newcells[x] = newcells[x] or {}
						newcells[symTable(x,z,size).x] = newcells[symTable(x,z,size).x] or {}		
						newcells[x][z] = cells[symTable(x,z,size).x][symTable(x,z,size).z]
						newcells[symTable(x,z,size).x][symTable(x,z,size).z] = cells[symTable(x,z,size).x][symTable(x,z,size).z]
				end
			end
			for x = 0,sizeX,sqr/2 do
				for z = 0,sizeZ,sqr/2 do
						if roads and roads[symTable(x,z,size).x] and roads[symTable(x,z,size).x][symTable(x,z,size).z] then
							newroads[x] = newroads[x] or {}
							newroads[symTable(x,z,size).x] = newroads[symTable(x,z,size).x] or {}
							newroads[x][z] = roads[symTable(x,z,size).x][symTable(x,z,size).z]
							newroads[symTable(x,z,size).x][symTable(x,z,size).z] = roads[symTable(x,z,size).x][symTable(x,z,size).z]						
						end
						if mountains and mountains[symTable(x,z,size).x] and mountains[symTable(x,z,size).x][symTable(x,z,size).z] then
							newmountains[x] = newmountains[x] or {}
							newmountains[symTable(x,z,size).x] = newmountains[symTable(x,z,size).x] or {}
							newmountains[x][z] = mountains[symTable(x,z,size).x][symTable(x,z,size).z]
							newmountains[symTable(x,z,size).x][symTable(x,z,size).z] = mountains[symTable(x,z,size).x][symTable(x,z,size).z]						
						end
				end
			end
		else
			for x = 0,sizeX,size do
				for z = 0,sizeZ,size do
						newcells[x] = newcells[x] or {}
						newcells[symTable(x,z,size).x] = newcells[symTable(x,z,size).x] or {}		
						newcells[x][z] = cells[x][z]
						newcells[symTable(x,z,size).x][symTable(x,z,size).z] = cells[x][z]
				end
			end
			for x = 0,sizeX,sqr/2 do
				for z = 0,sizeZ,sqr/2 do
						if roads and roads[x] and roads[x][z] then
							newroads[x] = newroads[x] or {}
							newroads[symTable(x,z,size).x] = newroads[symTable(x,z,size).x] or {}
							newroads[x][z] = roads[x][z]
							newroads[symTable(x,z,size).x][symTable(x,z,size).z] = roads[x][z]					
						end
						if mountains and mountains[x] and mountains[x][z] then
							newmountains[x] = newmountains[x] or {}
							newmountains[symTable(x,z,size).x] = newmountains[symTable(x,z,size).x] or {}
							newmountains[x][z] = mountains[x][z]
							newmountains[symTable(x,z,size).x][symTable(x,z,size).z] = mountains[x][z]					
						end
				end
			end
		end
		roads = newroads
		mountains = newmountains
		return newcells, size
	end
	
	function GroupCellsByHeight(cells, size)
		for x = 0,sizeX,size do
			for z = 0,sizeZ,size do
				if cells[x][z] then
					cells[x][z] = cells[x][z] - (cells[x][z]%heightGrouping)
				end
			end
		end
		return cells, size
	end
	
	function GenerateRoads(size)
		local ROADS = {}
		local road = {}
		if nRoads == 1 then
			return ROADS
		end
		for i = 1, nbRoads do
			if math.random(0,1) == 1 then
				rSize = 16*2^(math.random(1,3))
				local curX = math.random(0,sizeX/2)
				local curZ = math.random(0,sizeZ)
				curX = curX - curX%sqr/2
				curZ = curZ - curZ%sqr/2
				local positions = {[1] = {x = curX, z = curZ, ["size"] = rSize}}
				for j = 2,256 do
					if math.random(0,1) == 1 then
						curX = curX + rSize
					else
						curZ = curZ + ((math.random(0,1) == 1) and 1 or -1) * rSize
					end
					curX = curX - curX%sqr/2
					curZ = curZ - curZ%sqr/2
					positions[j] = {x = curX, z = curZ, ["size"] = rSize}
					if curX <= 0 or curX >= sizeX or curZ <= 0 or curZ >= sizeZ then
						break
					end
				end
				road[i] = positions
			else
				rSize = 16*2^(math.random(1,3))
				local curX = math.random(sizeX/2,sizeX)
				local curZ = math.random(0,sizeZ)
				curX = curX - curX%sqr/2
				curZ = curZ - curZ%sqr/2
				local positions = {[1] = {x = curX, z = curZ, ["size"] = rSize}}
				for j = 2,256 do
					if math.random(0,1) == 1 then
						curX = curX - rSize
					else
						curZ = curZ - ((math.random(0,1) == 1) and 1 or -1) * rSize
					end
					curX = curX - curX%sqr/2
					curZ = curZ - curZ%sqr/2
					positions[j] = {x = curX, z = curZ, ["size"] = rSize}
					if curX <= 0 or curX >= sizeX or curZ <= 0 or curZ >= sizeZ then
						break
					end
				end
				road[i] = positions
			end	
		end	
		for i = 1, nbRoads do
			local rpositions = road[i]
			for j = 1, #rpositions do
				local pos = rpositions[j]
				for v = -pos.size/2,pos.size/2 -1, sqr/2 do
					for w = -pos.size/2,pos.size/2 -1, sqr/2 do
						ROADS[pos.x + v] = ROADS[pos.x + v] or {}
						ROADS[pos.x + v][pos.z + w] = true
					end
				end
			end
		end
		return ROADS
	end
	
	function GenerateMountains(size)
		local MOUNTAINS = {}
		if nbMountains == 0 then
			return ROADS
		end
		for i = 1,nbMountains do
			local x = math.random(0,sizeX)
			local z = math.random(0,sizeZ)
			local size = math.random (64,256)
			x = x - x%sqr/2
			z = z - z%sqr/2
			size = size - size%sqr/2
			for v = -size, size-1, sqr/2 do
				for w = -size, size-1, sqr/2 do
					if v^2 + w^2 < size^2 then
						MOUNTAINS[x+v] = MOUNTAINS[x+v] or {}
						MOUNTAINS[x+v][z+w] = true
					end
				end
			end
		end
		return MOUNTAINS
	end
	
	function ApplyHeightMap(cells)
		for x = 0,sizeX,sqr do
			for z = 0,sizeZ,sqr do
				local height = cells[x][z] * flattenRatio + levelground -- avoid -2 < height < 2 because it looks weird...
				if height >= -1 and height <= 3 then
					height = 3
				end
				SetHeightMap(x,z, height )
			end
		end
	end
	
	function GenerateCells(size)
		local cells = {}
		nCells = 0
		for x = 0,sizeX,size do
			for z = 0,sizeZ,size do
				cells[x] = cells[x] or {}
				cells[x][z] = math.random(0,size/8)
				meanHeight = size/16
				variance = (variance*nCells + (cells[x][z] - meanHeight)^2)/(nCells+1)
				nCells = nCells + 1
			end
		end
		return cells,size
	end
	
	function FinishCells(cells, size)
		local newsize = size/2
		for x = 0,sizeX,size do
			for z = 0,sizeZ,size do
				for k =0,size-1,newsize do
					for v = 0,size-1,newsize do
						cells[x+k] = cells[x+k] or {}
						cells[x+k][z+v] = cells[x][z]
					end
				end
			end
		end
		return cells, newsize
	end
	
	function PickRandom(range, variance)
		local ratio = 1
		local min = 0
		local max = 0
		stdDerivation = math.sqrt(variance)
		if stdDerivation > flatness then
			ratio = flatness/stdDerivation
		end
		if typemap == 1 then
			min = -range*ratio
			max = range*ratio
		elseif typemap == 2 then
			min = -range*ratio
			max = range*ratio
		elseif typemap == 3 then
			min = -range*ratio
			max = 0
		elseif typemap == 4 then
			min = -range*ratio
			max = range*ratio
		end
		return (math.random(min, max))
	end
	
	function SquareDiamond(cells, size, heightranges)
		local newsize = size / 2
		for x = 0,sizeX,size do --SquareCenter
			for z = 0,sizeZ,size do
				if x + newsize <= sizeX and z+newsize <= sizeZ then
					local heightChangeRange = (mountains and mountains[x+newsize] and mountains[x+newsize][z+newsize] and heightranges*2) or heightranges/4
					if not (roads and roads[x+newsize] and roads[x+newsize][z+newsize]) then
						cells[x+newsize] = cells[x+newsize] or {}
						local ct = 0
						local a = (cells[x] and cells[x][z]) or 0
						ct = ct + ((cells[x] and cells[x][z] and 1) or 0)
						local b = (cells[x] and cells[x][z+size]) or 0
						ct = ct + ((cells[x] and cells[x][z+size] and 1) or 0)
						local c = (cells[x+size] and cells[x+size][z]) or 0
						ct = ct + ((cells[x+size] and cells[x+size][z] and 1) or 0)
						local d = (cells[x+size] and cells[x+size][z+size]) or 0
						ct = ct + ((cells[x+size] and cells[x+size][z+size] and 1) or 0)
						cells[x+newsize][z+newsize] = (a+b+c+d)/ct + PickRandom(heightChangeRange, variance)
					elseif roads and roads[x+newsize] and roads[x+newsize][z+newsize] then
						cells[x+newsize] = cells[x+newsize] or {}
						local ct = 0
						local a = ((cells[x] and cells[x][z]) or 0) * ((roads and roads[x] and roads[x][z] and roadlevelfactor) or (math.random(0,25)/100))
						ct = ct + (((cells[x] and cells[x][z] and 1) or 0)) * ((roads and roads[x] and roads[x][z] and roadlevelfactor) or (math.random(0,25)/100))
						local b = ((cells[x] and cells[x][z+size]) or 0) * ((roads and roads[x] and roads[x][z+size] and roadlevelfactor) or (math.random(0,25)/100))
						ct = ct + (((cells[x] and cells[x][z+size] and 1) or 0)) * ((roads and roads[x] and roads[x][z+size] and roadlevelfactor) or (math.random(0,25)/100))
						local c = ((cells[x+size] and cells[x+size][z]) or 0) * ((roads and roads[x+size] and roads[x+size][z] and roadlevelfactor) or (math.random(0,25)/100))
						ct = ct + (((cells[x+size] and cells[x+size][z] and 1) or 0)) * ((roads and roads[x+size] and roads[x+size][z] and roadlevelfactor) or (math.random(0,25)/100))
						local d = ((cells[x+size] and cells[x+size][z+size]) or 0) * ((roads and roads[x+size] and roads[x+size][z+size] and roadlevelfactor) or (math.random(0,25)/100))
						ct = ct + (((cells[x+size] and cells[x+size][z+size] and 1) or 0)) * ((roads and roads[x+size] and roads[x+size][z+size] and roadlevelfactor) or (math.random(0,25)/100))
						cells[x+newsize][z+newsize] = (roadHeight*roadlevelfactor+a+b+c+d)/(ct+roadlevelfactor)
					end
				end
			end
		end
		variance = 0
		nCells = 0
		for x = 0,sizeX,newsize do -- Edges
			for z = 0,sizeZ,newsize do
				local heightChangeRange = (mountains and mountains[x] and mountains[x][z] and heightranges*2) or heightranges/4
				if not (cells[x] and cells[x][z]) then
					if not (roads and roads[x] and roads[x][z]) then
						cells[x] = cells[x] or {}
						local ct = 0
						local a = (cells[x] and cells[x][z-newsize]) or 0
						ct = ct + ((cells[x] and cells[x][z-newsize] and 1) or 0)
						local b = (cells[x] and cells[x][z+newsize]) or 0
						ct = ct + ((cells[x] and cells[x][z+newsize] and 1) or 0)
						local c = (cells[x-newsize] and cells[x-newsize][z]) or 0
						ct = ct + ((cells[x-newsize] and cells[x-newsize][z] and 1) or 0)
						local d = (cells[x+newsize] and cells[x+newsize][z]) or 0
						ct = ct + ((cells[x+newsize] and cells[x+newsize][z] and 1) or 0)
						cells[x][z] = (a+b+c+d)/ct + PickRandom(heightChangeRange, variance)
					elseif roads and roads[x] and roads[x][z] then
						cells[x] = cells[x] or {}
						local ct = 0
						local a = ((cells[x] and cells[x][z-newsize]) or 0) * ((roads and roads[x] and roads[x][z-newsize] and roadlevelfactor) or (math.random(0,25)/100))
						ct = ct + (((cells[x] and cells[x][z-newsize] and 1) or 0)) * ((roads and roads[x] and roads[x][z-newsize] and roadlevelfactor) or (math.random(0,25)/100))
						local b = ((cells[x] and cells[x][z+newsize]) or 0) * ((roads and roads[x] and roads[x][z+newsize] and roadlevelfactor) or (math.random(0,25)/100))
						ct = ct + (((cells[x] and cells[x][z+newsize] and 1) or 0)) * ((roads and roads[x] and roads[x][z+newsize] and roadlevelfactor) or (math.random(0,25)/100))
						local c = ((cells[x-newsize] and cells[x-newsize][z]) or 0) * ((roads and roads[x-newsize] and roads[x-newsize][z] and roadlevelfactor) or (math.random(0,25)/100))
						ct = ct + (((cells[x-newsize] and cells[x-newsize][z] and 1) or 0)) * ((roads and roads[x-newsize] and roads[x-newsize][z] and roadlevelfactor) or (math.random(0,25)/100))
						local d = ((cells[x+newsize] and cells[x+newsize][z]) or 0) * ((roads and roads[x+newsize] and roads[x+newsize][z] and roadlevelfactor) or (math.random(0,25)/100))
						ct = ct + (((cells[x+newsize] and cells[x+newsize][z] and 1) or 0)) * ((roads and roads[x+newsize] and roads[x+newsize][z] and roadlevelfactor) or (math.random(0,25)/100))
						cells[x][z] = (roadHeight*roadlevelfactor+a+b+c+d)/(ct+roadlevelfactor)
					end
				end
				variance = (variance*nCells + (cells[x][z] - meanHeight)^2) / (nCells+1)
				nCells = nCells + 1
			end
		end
		heightranges = heightranges/2
		return cells, newsize, heightranges
	end
	
	function SquareDiamondSmoothing(cells, size)
		local newsize = size / 2
		for x = 0,sizeX,size do --SquareCenter
			for z = 0,sizeZ,size do
				if x + newsize <= sizeX and z+newsize <= sizeZ then
					if not (roads and roads[x+newsize] and roads[x+newsize][z+newsize]) then
						cells[x+newsize] = cells[x+newsize] or {}
						local ct = 0
						local a = (cells[x] and cells[x][z]) or 0
						ct = ct + ((cells[x] and cells[x][z] and 1) or 0)
						local b = (cells[x] and cells[x][z+size]) or 0
						ct = ct + ((cells[x] and cells[x][z+size] and 1) or 0)
						local c = (cells[x+size] and cells[x+size][z]) or 0
						ct = ct + ((cells[x+size] and cells[x+size][z] and 1) or 0)
						local d = (cells[x+size] and cells[x+size][z+size]) or 0
						ct = ct + ((cells[x+size] and cells[x+size][z+size] and 1) or 0)
						cells[x+newsize][z+newsize] = (a+b+c+d)/ct
					elseif roads and roads[x+newsize] and roads[x+newsize][z+newsize] then
						cells[x+newsize] = cells[x+newsize] or {}
						local ct = 0
						local a = ((cells[x] and cells[x][z]) or 0) * ((roads and roads[x] and roads[x][z] and roadlevelfactor) or (math.random(0,25)/100))
						ct = ct + (((cells[x] and cells[x][z] and 1) or 0)) * ((roads and roads[x] and roads[x][z] and roadlevelfactor) or (math.random(0,25)/100))
						local b = ((cells[x] and cells[x][z+size]) or 0) * ((roads and roads[x] and roads[x][z+size] and roadlevelfactor) or (math.random(0,25)/100))
						ct = ct + (((cells[x] and cells[x][z+size] and 1) or 0)) * ((roads and roads[x] and roads[x][z+size] and roadlevelfactor) or (math.random(0,25)/100))
						local c = ((cells[x+size] and cells[x+size][z]) or 0) * ((roads and roads[x+size] and roads[x+size][z] and roadlevelfactor) or (math.random(0,25)/100))
						ct = ct + (((cells[x+size] and cells[x+size][z] and 1) or 0)) * ((roads and roads[x+size] and roads[x+size][z] and roadlevelfactor) or (math.random(0,25)/100))
						local d = ((cells[x+size] and cells[x+size][z+size]) or 0) * ((roads and roads[x+size] and roads[x+size][z+size] and roadlevelfactor) or (math.random(0,25)/100))
						ct = ct + (((cells[x+size] and cells[x+size][z+size] and 1) or 0)) * ((roads and roads[x+size] and roads[x+size][z+size] and roadlevelfactor) or (math.random(0,25)/100))
						cells[x+newsize][z+newsize] = (roadHeight*roadlevelfactor+a+b+c+d)/(ct+roadlevelfactor)
					end
				end
			end
		end
		variance = 0
		nCells = 0
		for x = 0,sizeX,newsize do -- Edges
			for z = 0,sizeZ,newsize do
				if not (cells[x] and cells[x][z]) then
					if not (roads and roads[x] and roads[x][z]) then
						cells[x] = cells[x] or {}
						local ct = 0
						local a = (cells[x] and cells[x][z-newsize]) or 0
						ct = ct + ((cells[x] and cells[x][z-newsize] and 1) or 0)
						local b = (cells[x] and cells[x][z+newsize]) or 0
						ct = ct + ((cells[x] and cells[x][z+newsize] and 1) or 0)
						local c = (cells[x-newsize] and cells[x-newsize][z]) or 0
						ct = ct + ((cells[x-newsize] and cells[x-newsize][z] and 1) or 0)
						local d = (cells[x+newsize] and cells[x+newsize][z]) or 0
						ct = ct + ((cells[x+newsize] and cells[x+newsize][z] and 1) or 0)
						cells[x][z] = (a+b+c+d)/ct
					elseif roads and roads[x] and roads[x][z] then
						cells[x] = cells[x] or {}
						local ct = 0
						local a = ((cells[x] and cells[x][z-newsize]) or 0) * ((roads and roads[x] and roads[x][z-newsize] and roadlevelfactor) or (math.random(0,25)/100))
						ct = ct + (((cells[x] and cells[x][z-newsize] and 1) or 0)) * ((roads and roads[x] and roads[x][z-newsize] and roadlevelfactor) or (math.random(0,25)/100))
						local b = ((cells[x] and cells[x][z+newsize]) or 0) * ((roads and roads[x] and roads[x][z+newsize] and roadlevelfactor) or (math.random(0,25)/100))
						ct = ct + (((cells[x] and cells[x][z+newsize] and 1) or 0)) * ((roads and roads[x] and roads[x][z+newsize] and roadlevelfactor) or (math.random(0,25)/100))
						local c = ((cells[x-newsize] and cells[x-newsize][z]) or 0) * ((roads and roads[x-newsize] and roads[x-newsize][z] and roadlevelfactor) or (math.random(0,25)/100))
						ct = ct + (((cells[x-newsize] and cells[x-newsize][z] and 1) or 0)) * ((roads and roads[x-newsize] and roads[x-newsize][z] and roadlevelfactor) or (math.random(0,25)/100))
						local d = ((cells[x+newsize] and cells[x+newsize][z]) or 0) * ((roads and roads[x+newsize] and roads[x+newsize][z] and roadlevelfactor) or (math.random(0,25)/100))
						ct = ct + (((cells[x+newsize] and cells[x+newsize][z] and 1) or 0)) * ((roads and roads[x+newsize] and roads[x+newsize][z] and roadlevelfactor) or (math.random(0,25)/100))
						cells[x][z] = (roadHeight*roadlevelfactor+a+b+c+d)/(ct+roadlevelfactor)
					end
				end
				variance = (variance*nCells + (cells[x][z] - meanHeight)^2) / (nCells+1)
				nCells = nCells + 1
			end
		end
		return cells, newsize
	end
	
	function FinalSmoothing(cells, size)
		variance = 0
		nCells = 0
		for x = 0,sizeX,size do
			for z = 0,sizeZ,size do
				local ct = 0
				local a = (cells[x] and cells[x][z-size]) or 0
				ct = ct + ((cells[x] and cells[x][z-size] and 1) or 0)
				local b = (cells[x] and cells[x][z+size]) or 0
				ct = ct + ((cells[x] and cells[x][z+size] and 1) or 0)
				local c = (cells[x-size] and cells[x-size][z]) or 0
				ct = ct + ((cells[x-size] and cells[x-size][z] and 1) or 0)
				local d = (cells[x+size] and cells[x+size][z]) or 0
				ct = ct + ((cells[x+size] and cells[x+size][z] and 1) or 0)
				local e = (cells[x-size] and cells[x-size][z-size]) or 0
				ct = ct + ((cells[x-size] and cells[x-size][z-size] and 1) or 0)
				local f = (cells[x-size] and cells[x-size][z+size]) or 0
				ct = ct + ((cells[x-size] and cells[x-size][z+size] and 1) or 0)
				local g = (cells[x+size] and cells[x+size][z-size]) or 0
				ct = ct + ((cells[x+size] and cells[x+size][z-size] and 1) or 0)
				local h = (cells[x+size] and cells[x+size][z+size]) or 0
				ct = ct + ((cells[x+size] and cells[x+size][z+size] and 1) or 0)
				cells[x][z] = (a+b+c+d+e+f+g+h)/ct
				variance = (variance*nCells + (cells[x][z] - meanHeight)^2) / (nCells+1)
				nCells = nCells + 1
			end
		end
		return cells, size
	end
	
end

