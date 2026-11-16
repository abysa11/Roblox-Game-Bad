--[[
	SkinData
	Purely cosmetic weapon finishes. A skin only recolours / re-materials the parts of the
	procedural weapon model tagged "Body" and "Accent" (see WeaponModels). No stats live here.
]]

local SkinData = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

SkinData.Rarities = {
	Common = { Order = 1, Color = rgb(176, 195, 217) },
	Rare = { Order = 2, Color = rgb(75, 105, 255) },
	Epic = { Order = 3, Color = rgb(136, 71, 255) },
	Legendary = { Order = 4, Color = rgb(235, 75, 75) },
	Mythic = { Order = 5, Color = rgb(255, 196, 46) },
}

-- Skin definitions grouped by weapon. Ids are globally unique and are what gets saved.
local defs = {
	USP = {
		{ "USP_Desert", "Desert Haze", 40, "Common", rgb(196, 170, 120), rgb(120, 98, 70), "SmoothPlastic" },
		{ "USP_Cortex", "Cortex", 120, "Rare", rgb(30, 34, 44), rgb(0, 210, 255), "SmoothPlastic", true },
		{ "USP_Royal", "Royal Guard", 260, "Epic", rgb(28, 40, 110), rgb(230, 190, 70), "Metal" },
		{ "USP_KillConfirmed", "Night Ink", 480, "Legendary", rgb(16, 16, 18), rgb(255, 40, 60), "Glass", true },
	},
	Glock = {
		{ "Glock_Sand", "Sand Dune", 40, "Common", rgb(214, 190, 140), rgb(90, 80, 60), "SmoothPlastic" },
		{ "Glock_Candy", "Candy Pop", 110, "Rare", rgb(255, 120, 200), rgb(120, 230, 255), "SmoothPlastic" },
		{ "Glock_Fade", "Sunset Fade", 250, "Epic", rgb(255, 120, 40), rgb(160, 60, 255), "Metal", true },
		{ "Glock_Gold", "Gilded", 520, "Legendary", rgb(255, 200, 70), rgb(120, 80, 20), "Foil" },
	},
	Deagle = {
		{ "Deagle_Urban", "Urban Grey", 50, "Common", rgb(120, 125, 130), rgb(60, 62, 66), "Concrete" },
		{ "Deagle_Blaze", "Blaze", 160, "Rare", rgb(240, 90, 20), rgb(255, 210, 60), "SmoothPlastic", true },
		{ "Deagle_Ocean", "Deep Ocean", 300, "Epic", rgb(10, 70, 120), rgb(0, 255, 200), "Metal", true },
		{ "Deagle_Pharaoh", "Pharaoh", 600, "Legendary", rgb(230, 180, 60), rgb(20, 90, 160), "Foil" },
	},
	AK47 = {
		{ "AK47_Jungle", "Jungle Camo", 60, "Common", rgb(80, 105, 60), rgb(60, 50, 35), "Fabric" },
		{ "AK47_Redline", "Redline", 180, "Rare", rgb(25, 25, 28), rgb(220, 30, 40), "SmoothPlastic" },
		{ "AK47_Vulkan", "Volcano", 340, "Epic", rgb(40, 20, 15), rgb(255, 110, 20), "Basalt", true },
		{ "AK47_Neon", "Neon Rider", 650, "Legendary", rgb(30, 10, 60), rgb(255, 0, 230), "Glass", true },
		{ "AK47_Gold", "Golden Age", 1200, "Mythic", rgb(255, 205, 80), rgb(255, 245, 200), "Foil", true },
	},
	M4A1S = {
		{ "M4_Arctic", "Arctic", 60, "Common", rgb(225, 232, 240), rgb(140, 150, 165), "SmoothPlastic" },
		{ "M4_Cyrex", "Cyber Red", 190, "Rare", rgb(200, 30, 40), rgb(230, 230, 235), "SmoothPlastic" },
		{ "M4_Hyper", "Hyper Beast", 360, "Epic", rgb(0, 160, 140), rgb(255, 60, 120), "Metal", true },
		{ "M4_Ice", "Glacier", 680, "Legendary", rgb(150, 220, 255), rgb(255, 255, 255), "Ice", true },
	},
	SCAR = {
		{ "SCAR_Forest", "Woodland", 60, "Common", rgb(70, 90, 55), rgb(110, 85, 55), "Fabric" },
		{ "SCAR_Carbon", "Carbon", 170, "Rare", rgb(22, 24, 28), rgb(90, 95, 105), "Slate" },
		{ "SCAR_Toxic", "Toxic", 330, "Epic", rgb(40, 50, 30), rgb(160, 255, 40), "SmoothPlastic", true },
		{ "SCAR_Brick", "Toy Brick", 620, "Legendary", rgb(230, 40, 40), rgb(255, 210, 0), "Plastic" },
	},
	AWP = {
		{ "AWP_Safari", "Safari", 80, "Common", rgb(190, 160, 100), rgb(100, 80, 50), "Fabric" },
		{ "AWP_Electric", "Electric Hive", 240, "Rare", rgb(20, 60, 140), rgb(80, 220, 255), "Metal", true },
		{ "AWP_Dragon", "Dragon Scale", 520, "Epic", rgb(120, 20, 20), rgb(255, 180, 40), "Slate", true },
		{ "AWP_Asiimov", "Starlight", 900, "Legendary", rgb(240, 240, 240), rgb(255, 120, 0), "SmoothPlastic", true },
		{ "AWP_Jade", "Jade Serpent", 1500, "Mythic", rgb(20, 140, 90), rgb(255, 215, 90), "Marble", true },
	},
	Knife = {
		{ "Knife_Stone", "Obsidian", 120, "Rare", rgb(20, 20, 24), rgb(90, 70, 160), "Slate" },
		{ "Knife_Fade", "Prism Fade", 400, "Epic", rgb(255, 80, 180), rgb(80, 200, 255), "Metal", true },
		{ "Knife_Gold", "Sun Blade", 800, "Legendary", rgb(255, 200, 60), rgb(255, 120, 20), "Foil", true },
		{ "Knife_Glacier", "Frostbite", 1400, "Mythic", rgb(170, 230, 255), rgb(255, 255, 255), "Ice", true },
	},
}

SkinData.ById = {}
SkinData.ByWeapon = {}

for weaponId, list in pairs(defs) do
	SkinData.ByWeapon[weaponId] = {}
	for _, d in ipairs(list) do
		local skin = {
			Id = d[1],
			Name = d[2],
			Price = d[3],
			Rarity = d[4],
			Body = d[5],
			Accent = d[6],
			Material = Enum.Material[d[7]],
			NeonAccent = d[8] == true,
			Weapon = weaponId,
		}
		SkinData.ById[skin.Id] = skin
		table.insert(SkinData.ByWeapon[weaponId], skin)
	end
	table.sort(SkinData.ByWeapon[weaponId], function(a, b)
		return a.Price < b.Price
	end)
end

function SkinData.Get(id)
	return SkinData.ById[id]
end

function SkinData.ForWeapon(weaponId)
	return SkinData.ByWeapon[weaponId] or {}
end

return SkinData
