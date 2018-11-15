
function gadget:GetInfo()
  return {
    name      = "Unified Texturing",
    desc      = "Applies basic textures on maps based on slopemap",
    author    = "Google Frog (edited for randommapgen purposes by Doo",
    date      = "25 June 2012, edited 2018", --24 August 2013
    license   = "GNU GPL, v2 or later",
    layer     = -10,
    enabled   = true --  loaded by default?
  }
end

local MAP_WIDTH = Game.mapSizeX
local MAP_HEIGHT = Game.mapSizeZ
local SQUARE_SIZE = 1024
local SQUARES_X = MAP_WIDTH/SQUARE_SIZE
local SQUARES_Z = MAP_HEIGHT/SQUARE_SIZE
local UHM_WIDTH = 64
local UHM_HEIGHT = 64
local UHM_X = UHM_WIDTH/MAP_WIDTH
local UHM_Z = UHM_HEIGHT/MAP_HEIGHT
local BLOCK_SIZE = 8

local spSetMapSquareTexture = Spring.SetMapSquareTexture
local spGetMapSquareTexture = Spring.GetMapSquareTexture
local spGetMyTeamID         = Spring.GetMyTeamID
local spGetGroundHeight     = Spring.GetGroundHeight
local spGetGroundOrigHeight = Spring.GetGroundOrigHeight
local floor = math.floor

if (gadgetHandler:IsSyncedCode()) then

else
local sqrTex = {}
local glTexture = gl.Texture
local glCreateTexture = gl.CreateTexture
local glDeleteTexture = gl.DeleteTexture
local CallAsTeam = CallAsTeam
local textureSet = {'desert/', 'temperate/', 'arctic/', 'moon/'}
local usetextureSet = textureSet[math.random(1,4)]
local texturePath = 'unittextures/tacticalview/'..usetextureSet

local TEXTURE_COUNT = 20
local texturePool = {
	-- [0] == original map texture
	[1] = {
		texture = texturePath.."v1.png",
		size = 92,
		tile = 1,
	},
	[2] = {
		texture = texturePath.."v2.png",
		size = 92,
		tile = 1,
	},
	[3] = {
		texture = texturePath.."v3.png",
		size = 92,
		tile = 1,
	},
	[4] = {
		texture = texturePath.."v4.png",
		size = 92,
		tile = 1,
	},
	[5] = {
		texture = texturePath.."v5.png",
		size = 92,
		tile = 1,
	},
	[6] = {
		texture = texturePath.."b1.png",
		size = 92,
		tile = 1,
	},
	[7] = {
		texture = texturePath.."b2.png",
		size = 92,
		tile = 1,
	},
	[8] = {
		texture = texturePath.."b3.png",
		size = 92,
		tile = 1,
	},
	[9] = {
		texture = texturePath.."b4.png",
		size = 92,
		tile = 1,
	},
	[10] = {
		texture = texturePath.."b5.png",
		size = 92,
		tile = 1,
	},
	[11] = {
		texture = texturePath.."n1.png",
		size = 92,
		tile = 1,
	},
	[12] = {
		texture = texturePath.."n2.png",
		size = 92,
		tile = 1,
	},
	[13] = {
		texture = texturePath.."n3.png",
		size = 92,
		tile = 1,
	},
	[14] = {
		texture = texturePath.."n4.png",
		size = 92,
		tile = 1,
	},
	[15] = {
		texture = texturePath.."n5.png",
		size = 92,
		tile = 1,
	},
	[16] = {
		texture = texturePath.."m.png",
		size = 92,
		tile = 1,
	},
	[17] = {
		texture = texturePath.."uwv.png",
		size = 92,
		tile = 1,
	},
	[18] = {
		texture = texturePath.."uwb.png",
		size = 92,
		tile = 1,
	},
	[19] = {
		texture = texturePath.."uwn.png",
		size = 92,
		tile = 1,
	},
	[20] = {
		texture = texturePath.."uwm.png",
		size = 92,
		tile = 1,
	},
}

local LuaShader = VFS.Include("LuaRules/gadgets/libs/LuaShader.lua")
local GaussianBlur = VFS.Include("LuaRules/gadgets/libs/GaussianBlur.lua")
local GL_RGBA = 0x1908
local GL_RGBA16F = 0x881A
local GL_RGBA32F = 0x8814
local gb
local texIn, texOut

local mapTex = {} -- 2d array of textures

local blockStateMap = {} -- keeps track of drawn texture blocks.
local chunkMap = {} -- map of UHM chunk that stores pending changes.
local chunkUpdateList = {count = 0, data = {}} -- list of chuncks to update
local chunkUpdateMap = {} -- map of chunks which are in list. Prevent duplicate entry if UHMU is called twice

local syncedHeights = {} -- list of synced heightmap point values

local UMHU_updatequeue = {} -- send update data from gadget:UnsyncedHeightMapUpdate() to gadget:DrawWorld()


local function drawTextureOnSquare(x,z,size,sx,sz,xsize, zsize)
	local x1 = 2*x/SQUARE_SIZE - 1
	local z1 = 2*z/SQUARE_SIZE - 1
	local x2 = 2*(x+size)/SQUARE_SIZE - 1
	local z2 = 2*(z+size)/SQUARE_SIZE - 1
	gl.TexRect(x1,z1,x2,z2,sx,sz,sx+xsize,sz+zsize)
end

local function drawTextureOnMapTex(x,z)
	local x1 = 2*x/Game.mapSizeX - 1
	local z1 = 2*z/Game.mapSizeZ - 1
	local x2 = 2*(x+8)/Game.mapSizeX - 1
	local z2 = 2*(z+8)/Game.mapSizeZ - 1
	gl.TexRect(x1,z1,x2,z2)
end

local function drawCopySquare()
	gl.TexRect(-1,1,1,-1)
end
local function drawRectOnTex(x1,z1,x2,z2,sx1,sz1, sx2,sz2)
	gl.TexRect(x1,z1,x2,z2,sx1,sz1, sx2,sz2)
end

function SetTextureSet(textureSetName)
	usetextureSet = textureSetName..'/'
	texturePath = 'unittextures/tacticalview/'..usetextureSet
	texturePool = {
	[1] = {
		texture = texturePath.."v1.png",
		size = 92,
		tile = 1,
	},
	[2] = {
		texture = texturePath.."v2.png",
		size = 92,
		tile = 1,
	},
	[3] = {
		texture = texturePath.."v3.png",
		size = 92,
		tile = 1,
	},
	[4] = {
		texture = texturePath.."v4.png",
		size = 92,
		tile = 1,
	},
	[5] = {
		texture = texturePath.."v5.png",
		size = 92,
		tile = 1,
	},
	[6] = {
		texture = texturePath.."b1.png",
		size = 92,
		tile = 1,
	},
	[7] = {
		texture = texturePath.."b2.png",
		size = 92,
		tile = 1,
	},
	[8] = {
		texture = texturePath.."b3.png",
		size = 92,
		tile = 1,
	},
	[9] = {
		texture = texturePath.."b4.png",
		size = 92,
		tile = 1,
	},
	[10] = {
		texture = texturePath.."b5.png",
		size = 92,
		tile = 1,
	},
	[11] = {
		texture = texturePath.."n1.png",
		size = 92,
		tile = 1,
	},
	[12] = {
		texture = texturePath.."n2.png",
		size = 92,
		tile = 1,
	},
	[13] = {
		texture = texturePath.."n3.png",
		size = 92,
		tile = 1,
	},
	[14] = {
		texture = texturePath.."n4.png",
		size = 92,
		tile = 1,
	},
	[15] = {
		texture = texturePath.."n5.png",
		size = 92,
		tile = 1,
	},
	[16] = {
		texture = texturePath.."m.png",
		size = 92,
		tile = 1,
	},
	[17] = {
		texture = texturePath.."uwv.png",
		size = 92,
		tile = 1,
	},
	[18] = {
		texture = texturePath.."uwb.png",
		size = 92,
		tile = 1,
	},
	[19] = {
		texture = texturePath.."uwn.png",
		size = 92,
		tile = 1,
	},
	[20] = {
		texture = texturePath.."uwm.png",
		size = 92,
		tile = 1,
	},
}
end

function GaussianInitialize(fullTex)

	texIn = fullTex
	texOut = gl.CreateTexture(SQUARE_SIZE,SQUARE_SIZE,
	{
		format = GL_RGBA16F,
		border = false,
		min_filter = GL.LINEAR,
		mag_filter = GL.LINEAR,
		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
		fbo = true,
	})

	--(texIn, texOut, unusedTexId, downScale, linearSampling, sigma, halfKernelSize, valMult, repeats, blurTexIntFormat)
	gb = GaussianBlur({
		texIn = texIn,
		texOut = texOut,
		unusedTexId = nil,
		downScale = 2,
		linearSampling = true,
		sigma = 3.0,
		halfKernelSize = 5,
		valMult = 1.0,
		repeats = 2,
		blurTexIntFormat = GL_RGBA16F})
end

function gadget:DrawGenesis()
	if initialized ~= true then
		return
	end
	if mapfullyprocessed == true then
		return
	end
	if not fulltex then -- create fullsize blank tex
		fulltex = gl.CreateTexture(Game.mapSizeX,Game.mapSizeZ,
		{
			border = false,
			min_filter = GL.LINEAR,
			mag_filter = GL.LINEAR,
			wrap_s = GL.CLAMP_TO_EDGE,
			wrap_t = GL.CLAMP_TO_EDGE,
			fbo = true,
		})
	end
	for x= 0 , Game.mapSizeX - 1,8 do -- apply 8x8 textures blocks on the fullsize tex
		for z= 0 , Game.mapSizeZ - 1,8 do
			local tex = mapTex[x][z]
			glTexture(tex)
			gl.RenderToTexture(fulltex, drawTextureOnMapTex, x, z)
			glTexture(false)
		end
	end
	if not fulltex then
		return
	end
	if gl.CreateShader then
		GaussianInitialize(fulltex)
		gb:Initialize()
		gb:Execute()
	else
		texOut = fulltex
	end
	for x = 0,Game.mapSizeX - 1, SQUARE_SIZE do -- Create sqr textures for each sqr
		for z = 0,Game.mapSizeZ - 1, SQUARE_SIZE do
			sqrTex[x] = sqrTex[x] or {}
			sqrTex[x][z] = glCreateTexture(SQUARE_SIZE,SQUARE_SIZE,
			{
				border = false,
				min_filter = GL.LINEAR,
				mag_filter = GL.LINEAR,
				wrap_s = GL.CLAMP_TO_EDGE,
				wrap_t = GL.CLAMP_TO_EDGE,
				fbo = true,
			})
			glTexture(texOut) -- apply corresponding part of fulltex to each sqrTex 
			gl.RenderToTexture(sqrTex[x][z], drawTextureOnSquare, 0,0,SQUARE_SIZE, x/Game.mapSizeX, z/Game.mapSizeZ, SQUARE_SIZE/Game.mapSizeX, SQUARE_SIZE/Game.mapSizeZ)
			glTexture(false)
			
			gl.GenerateMipmap(sqrTex[x][z]) -- generate mipmap and apply texture to square
			Spring.SetMapSquareTexture((x/SQUARE_SIZE),(z/SQUARE_SIZE), sqrTex[x][z])
			-- gl.DeleteTexture(sqrTex[x][z])
			sqrTex[x][z] = nil
		end
	end
	if gl.CreateShader then
		gb:Finalize()
		gl.DeleteTextureFBO(texOut)
		texOut = nil
	end
	gl.DeleteTextureFBO(fulltex)
	fulltex = nil
	gl.DeleteTextureFBO(texOut)
	texOut = nil
	mapfullyprocessed = true
end

local function UpdateAll()
	for x = 0, Game.mapSizeX-1, 8 do
		for z = 0, Game.mapSizeZ-1, 8 do
			mapTex[x] = mapTex[x] or {}
			mapTex[x][z] = texturePool[SlopeType(x, z)].texture
		end
	end
end

local function Shutdown()
	for x = 0, SQUARES_X-1 do
		if mapTex[x] then
			for z = 0, SQUARES_Z-1 do
				if mapTex[x][z] then
					spSetMapSquareTexture(x,z, "")
				end
			end
		end
	end
	activestate = false
end

function SlopeType(x,z)
	if Spring.TestBuildOrder(UnitDefNames["armfmine3"].id, x, Spring.GetGroundHeight(x,z),z, 0) == 0 then
		if Spring.GetMetalAmount(math.floor(x/16), math.floor(z/16)) > 0 then
			return 16
		elseif Spring.TestMoveOrder(UnitDefNames["armstump"].id, x, Spring.GetGroundHeight(x,z),z, 0,0,0, true, false, true) then
			return math.random(1,5)
		elseif Spring.TestMoveOrder(UnitDefNames["armpw"].id, x, Spring.GetGroundHeight(x,z),z, 0,0,0, true, false, true) then
			return math.random(6,10)
		else
			return math.random(11,15)
		end
	else
		if Spring.GetMetalAmount(math.floor(x/16), math.floor(z/16)) > 0 then
			return 20
		elseif Spring.TestMoveOrder(UnitDefNames["armstump"].id, x, Spring.GetGroundHeight(x,z),z, 0,0,0, true, false, true) then
			return 17
		elseif Spring.TestMoveOrder(UnitDefNames["armpw"].id, x, Spring.GetGroundHeight(x,z),z, 0,0,0, true, false, true) then
			return 18
		else
			return 19
		end
	end
end

function gadget:Initialize()
	if (not gl.RenderToTexture) then --super bad graphic driver
		return
	end
	SetTextureSet(Spring.GetGameRulesParam("typemap"))
	UpdateAll()
	initialized = true
	activestate = true
end

end