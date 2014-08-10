local MAJOR, MINOR = 'LibProcessable', 1

assert(LibStub, MAJOR .. ' requires LibStub')

local lib, oldMinor = LibStub:NewLibrary(MAJOR, MINOR)
if(not lib) then
	return
end

local data
local inscriptionSkill, jewelcraftingSkill, enchantingSkill, blacksmithingSkill

local MILLING = 51005
function lib:IsMillable(itemID)
	if(IsSpellKnown(MILLING)) then
		local skillRequired = data.herbs[itemID]
		return skillRequired and skillRequired <= inscriptionSkill
	end
end

local PROSPECTING = 31252
function lib:IsProspectable(itemID)
	if(IsSpellKnown(PROSPECTING)) then
		local skillRequired = data.ores[itemID]
		return skillRequired and skillRequired <= jewelcraftingSkill
	end
end

local function GetSkillRequired(quality, level)
	if(quality == 2) then
		if(level <= 20) then
			return 1
		elseif(level <= 25) then
			return 25
		elseif(level <= 30) then
			return 50
		elseif(level <= 35) then
			return 75
		elseif(level <= 40) then
			return 100
		elseif(level <= 45) then
			return 125
		elseif(level <= 50) then
			return 150
		elseif(level <= 55) then
			return 175
		elseif(level <= 60) then
			return 200
		elseif(level <= 99) then
			return 225
		elseif(level <= 120) then
			return 275
		elseif(level <= 151) then
			return 325
		elseif(level <= 187) then
			return 350
		elseif(level <= 333) then
			return 425
		else
			return 475
		end
	elseif(quality == 3) then
		if(level <= 25) then
			return 25
		elseif(level <= 30) then
			return 50
		elseif(level <= 35) then
			return 75
		elseif(level <= 40) then
			return 100
		elseif(level <= 45) then
			return 125
		elseif(level <= 50) then
			return 150
		elseif(level <= 55) then
			return 175
		elseif(level <= 60) then
			return 200
		elseif(level <= 97) then
			return 225
		elseif(level <= 115) then
			return 275
		elseif(level <= 200) then
			return 325
		elseif(level <= 377) then
			return 450
		elseif(level <= 424) then
			return 525
		else
			return 550
		end
	elseif(quality == 4) then
		if(level <= 20) then
			return 25
		elseif(level <= 40) then
			return 100
		elseif(level <= 45) then
			return 125
		elseif(level <= 50) then
			return 150
		elseif(level <= 55) then
			return 175
		elseif(level <= 60) then
			return 200
		elseif(level <= 95) then
			return 225
		elseif(level <= 190) then
			return 300
		elseif(level <= 284) then
			return 375
		elseif(level <= 416) then
			return 475
		else
			return 575
		end
	end
end

local DISENCHANTING = 13262
function lib:IsDisenchantable(itemID)
	if(IsSpellKnown(DISENCHANTING)) then
		local _, _, quality, level = GetItemInfo(itemID)
		if(IsEquippableItem(itemID) and quality and level) then
			local skillRequired = GetSkillRequired(quality, level)
			return skillRequired <= enchantingSkill
		end
	end
end

local LOCKPICKING = 1804
local BLACKSMITH = 2018
function lib:IsOpenable(itemID)
	if(IsSpellKnown(LOCKPICKING)) then
		local container = data.containers[itemID]
		if(container and (container[1] / 5) >= UnitLevel('player')) then
			return true
		end
	elseif(GetSpellBookItemInfo(GetSpellInfo(BLACKSMITH))) then
		local container = data.containers[itemID]
		if(container) then
			for index = container[2], #data.keys do
				local key = data.keys[index]
				if(GetItemCount(key[1]) > 0 and key[2] <= blacksmithingSkill) then
					return true, key[1]
				end
			end
		end
	end
end

local Handler = CreateFrame('Frame')
Handler:RegisterEvent('SKILL_LINES_CHANGED')
Handler:SetScript('OnEvent', function(s, event)
	inscriptionSkill, jewelcraftingSkill, enchantingSkill, blacksmithingSkill = 0, 0, 0, 0

	local first, second = GetProfessions()
	if(first) then
		local _, _, skill, _, _, _, id = GetProfessionInfo(first)
		if(id == 773) then
			inscriptionSkill = skill
		elseif(id == 755) then
			jewelcraftingSkill = skill
		elseif(id == 333) then
			enchantingSkill = skill
		elseif(id == 164) then
			blacksmithingSkill = skill
		end
	end

	if(second) then
		local _, _, skill, _, _, _, id = GetProfessionInfo(second)
		if(id == 773) then
			inscriptionSkill = skill
		elseif(id == 755) then
			jewelcraftingSkill = skill
		elseif(id == 333) then
			enchantingSkill = skill
		elseif(id == 164) then
			blacksmithingSkill = skill
		end
	end
end)

data = {
	herbs = { -- http://www.wowhead.com/items?filter=cr=159:161:128;crs=1:1:1;crv=0:0:0
		[765] = 1, -- Silverleaf
		[785] = 1, -- Mageroyal
		[2447] = 1, -- Peacebloom
		[2449] = 1, -- Earthroot
		[2450] = 25, -- Briarthorn
		[2452] = 25, -- Swiftthistle
		[2453] = 25, -- Bruiseweed
		[3820] = 25, -- Stranglekelp
		[3355] = 75, -- Wild Steelbloom
		[3356] = 75, -- Kingsblood
		[3357] = 75, -- Liferoot
		[3369] = 75, -- Grave Moss
		[3358] = 125, -- Khadgar''s Whisker
		[3818] = 125, -- Fadeleaf
		[3819] = 125, -- Dragon''s Teeth
		[3821] = 125, -- Goldthorn
		[4625] = 175, -- Firebloom
		[8831] = 175, -- Purple Lotus
		[8836] = 175, -- Arthas'' Tears
		[8838] = 175, -- Sungrass
		[8839] = 175, -- Blindweed
		[8845] = 175, -- Ghost Mushroom
		[8846] = 175, -- Gromsblood
		[13467] = 200, -- Icecap
		[13463] = 225, -- Dreamfoil
		[13464] = 225, -- Golden Sansam
		[13465] = 225, -- Mountain Silversage
		[13466] = 225, -- Sorrowmoss
		[22785] = 275, -- Felweed
		[22786] = 275, -- Dreaming Glory
		[22787] = 275, -- Ragveil
		[22789] = 275, -- Terocone
		[22790] = 275, -- Ancient Lichen
		[22791] = 275, -- Netherbloom
		[22792] = 275, -- Nightmare Vine
		[22793] = 275, -- Mana Thistle
		[36901] = 325, -- Goldclover
		[36903] = 325, -- Adder''s Tongue
		[36904] = 325, -- Tiger Lily
		[36905] = 325, -- Lichbloom
		[36906] = 325, -- Icethorn
		[36907] = 325, -- Talandra''s Rose
		[37921] = 325, -- Deadnettle
		[39970] = 325, -- Fire Leaf
		[52983] = 425, -- Cinderbloom
		[52984] = 425, -- Stormvine
		[52985] = 450, -- Azshara''s Veil
		[52986] = 450, -- Heartblossom
		[52987] = 475, -- Twilight Jasmine
		[52988] = 475, -- Whiptail
		[72234] = 500, -- Green Tea Leaf
		[72235] = 500, -- Silkweed
		[72237] = 500, -- Rain Poppy
		[79010] = 500, -- Snow Lily
		[79011] = 500, -- Fool''s Cap
		[89639] = 500, -- Desecrated Herb
	},
	ores = { -- http://www.wowhead.com/items?filter=cr=89:161:128;crs=1:1:1;crv=0:0:0
		[2770] = 1, -- Copper Ore
		[2771] = 50, -- Tin Ore
		[2772] = 125, -- Iron Ore
		[3858] = 175, -- Mithril Ore
		[10620] = 250, -- Thorium Ore
		[23424] = 275, -- Fel Iron Ore
		[23425] = 325, -- Adamantite Ore
		[36909] = 350, -- Cobalt Ore
		[36912] = 400, -- Saronite Ore
		[53038] = 425, -- Obsidium Ore
		[36910] = 450, -- Titanium Ore
		[52185] = 475, -- Elementium Ore
		[52183] = 500, -- Pyrite Ore
		[72092] = 500, -- Ghost Iron Ore
		[72093] = 550, -- Kyparite
		[72094] = 600, -- Black Trillium Ore
		[72103] = 600, -- White Trillium Ore
	},
	containers = { -- http://www.wowhead.com/items?filter=cr=10:161:128;crs=1:1:1;crv=0:0:0
		[4632] = {1, 1}, -- Ornate Bronze Lockbox
		[6354] = {1, 1}, -- Small Locked Chest
		[16882] = {1, 1}, -- Battered Junkbox
		[4633] = {25, 1}, -- Heavy Bronze Lockbox
		[4634] = {70, 2}, -- Iron Lockbox
		[6355] = {70, 2}, -- Sturdy Locked Chest
		[16883] = {70, 2}, -- Worn Junkbox
		[4636] = {125, 2}, -- Strong Iron Lockbox
		[4637] = {175, 3}, -- Steel Lockbox
		[13875] = {175, 3}, -- Ironbound Locked Chest
		[16884] = {175, 3}, -- Sturdy Junkbox
		[4638] = {225, 4}, -- Reinforced Steel Lockbox
		[5758] = {225, 4}, -- Mithril Lockbox
		[5759] = {225, 4}, -- Thorium Lockbox
		[5760] = {225, 4}, -- Eternium Lockbox
		[13918] = {250, 4}, -- Reinforced Locked Chest
		[16885] = {250, 4}, -- Heavy Junkbox
		[12033] = {275, 4}, -- Thaurissan Family Jewels
		[29569] = {300, 4}, -- Strong Junkbox
		[31952] = {325, 5}, -- Khorium Lockbox
		[43575] = {350, 5}, -- Reinforced Junkbox
		[43622] = {375, 5}, -- Froststeel Lockbox
		[43624] = {400, 6}, -- Titanium Lockbox
		[45986] = {400, 6}, -- Tiny Titanium Lockbox
		[63349] = {400, 6}, -- Flame-Scarred Junkbox
		[68729] = {425, 7}, -- Elementium Lockbox
		[88567] = {450, 8}, -- Ghost Iron Lockbox
		[88165] = {450, 8}, -- Vine-Cracked Junkbox
	},
	keys = { -- http://www.wowhead.com/items?filter=na=key;cr=86;crs=2;crv=0
		{15869, 100}, -- Silver Skeleton Key
		{15870, 150}, -- Golden Skeleton Key
		{15871, 200}, -- Truesilver Skeleton Key
		{15872, 275}, -- Arcanite Skeleton Key
		{43854, 350}, -- Colbat Skeleton Key
		{43853, 430}, -- Titanium Skeleton Key
		{55053, 475}, -- Obsidium Skeleton Key
		{82960, 500}, -- Ghostly Skeleton Key
	}
}
