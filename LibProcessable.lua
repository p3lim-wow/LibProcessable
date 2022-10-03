local MAJOR, MINOR = 'LibProcessable', 56
assert(LibStub, MAJOR .. ' requires LibStub')

local lib, oldMinor = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then
	return
end

local data = {} -- private table for storing data without exposing it
local professions = {} -- private table for storing cached profession info

local CLASSIC = select(4, GetBuildInfo()) < 90000
local DRAGONFLIGHT = select(4, GetBuildInfo()) >= 100000

-- upvalue constants with fallbacks
local LE_ITEM_QUALITY_UNCOMMON = LE_ITEM_QUALITY_UNCOMMON or Enum.ItemQuality.Uncommon
local LE_ITEM_QUALITY_EPIC = LE_ITEM_QUALITY_EPIC or Enum.ItemQuality.Epic
local LE_ITEM_CLASS_ARMOR = LE_ITEM_CLASS_ARMOR or 4
local LE_ITEM_CLASS_WEAPON = LE_ITEM_CLASS_WEAPON or 2
local LE_ITEM_CLASS_GEM = LE_ITEM_CLASS_GEM or 3
local LE_ITEM_ARMOR_COSMETIC = LE_ITEM_ARMOR_COSMETIC or 5
local LE_ITEM_SUBCLASS_ARTIFACT = 11 -- no existing constant for this one
local LE_ITEM_EQUIPLOC_SHIRT = Enum and Enum.InventoryType and Enum.InventoryType.IndexBodyType or 4

local LE_EXPANSION_CLASSIC = LE_EXPANSION_CLASSIC or 0
local LE_EXPANSION_BURNING_CRUSADE = LE_EXPANSION_BURNING_CRUSADE or 1
local LE_EXPANSION_WRATH_OF_THE_LICH_KING = LE_EXPANSION_WRATH_OF_THE_LICH_KING or 2
local LE_EXPANSION_CATACLYSM = LE_EXPANSION_CATACLYSM or 3
local LE_EXPANSION_MISTS_OF_PANDARIA = LE_EXPANSION_MISTS_OF_PANDARIA or 4
local LE_EXPANSION_WARLORDS_OF_DRAENOR = LE_EXPANSION_WARLORDS_OF_DRAENOR or 5
local LE_EXPANSION_LEGION = LE_EXPANSION_LEGION or 6
local LE_EXPANSION_BATTLE_FOR_AZEROTH = LE_EXPANSION_BATTLE_FOR_AZEROTH or 7
local LE_EXPANSION_SHADOWLANDS = LE_EXPANSION_SHADOWLANDS or 8
local LE_EXPANSION_DRAGONFLIGHT = LE_EXPANSION_DRAGONFLIGHT or LE_EXPANSION_10_0 or 9 -- ahead of our time

--[[ LibProcessable:IsMillable(_item[, ignoreMortar]_)
Returns whether the player can mill the given item.

**Arguments:**
* `item`: item ID or link
* `ignoreMortar`: whether the [Draenic Mortar](http://www.wowhead.com/item=114942) should be ignored or not _(boolean, optional)_

**Return values:**
* `isMillable`: Whether or not the player can mill the given item _(boolean)_
* `mortarUsed`: Whether or not a Draenic Mortar can be used
--]]
function lib:IsMillable(itemID, ignoreMortar)
	if type(itemID) == 'string' then
		assert(string.match(itemID, 'item:(%d+):') or tonumber(itemID), 'item must be an item ID or item Link')
		itemID = (tonumber(itemID)) or (GetItemInfoFromHyperlink(itemID))
	end

	if self:HasProfession(773) then -- Inscription
		if CLASSIC then
			local currentSkill = professions[773]
			return data.herbs[itemID] and currentSkill >= data.herbs[itemID]
		else
			-- any herb can be milled at level 1
			return not not data.herbs[itemID]
		end
	elseif not ignoreMortar and GetItemCount(114942) > 0 then
		-- Draenic Mortar can mill Draenor herbs without a profession
		return itemID >= 109124 and itemID <= 109130, true
	end
end

--[[ LibProcessable:IsProspectable(_item_)
Returns whether the player can prospect the given item.

**Arguments:**
* `item`: item ID or link

**Return values:**
* `isProspectable`: Whether or not the player can prospect the given item _(boolean)_

**Notes**:
* This does not check if the player has the required skills to use the profession items
   * Only Outland and Pandaria ores have skill level requirements
--]]
function lib:IsProspectable(itemID)
	if type(itemID) == 'string' then
		assert(string.match(itemID, 'item:(%d+):') or tonumber(itemID), 'item must be an item ID or item Link')
		itemID = (tonumber(itemID)) or (GetItemInfoFromHyperlink(itemID))
	end

	if self:HasProfession(755) then -- Jewelcrafting
		if CLASSIC then
			local currentRank = professions[755]
			local requiredRank = data.ores[itemID]
			return requiredRank and currentRank >= requiredRank
		else
			local itemInfo = data.ores[itemID]
			if itemInfo then
				if type(itemInfo) == 'table' then
					-- itemInfo contains expansion and requiredRank
					local currentRank = professions[755][itemInfo[1]]
					local requiredRank = itemInfo[2]
					print(currentRank, requiredRank)
					return requiredRank and currentRank >= requiredRank
				else
					-- itemInfo contains requiredRank only
					-- any herb can be milled at level 1
					return true
				end
			end
		end
	end
end

--[[ LibProcessable:IsDisenchantable(_item_)
Returns whether the player can disenchant the given item.

**Arguments:**
* `item`: item ID or link

**Return values:**
* `isDisenchantable`: Whether or not the player can disenchant the given item _(boolean)_

**Notes**:
* Many items that are not disenchantable will still return as `true`
   * These items are hard to keep track of since they're not flagged in any known database, and thus hard to keep track of
--]]
function lib:IsDisenchantable(item)
	local itemID = item
	if type(itemID) == 'string' then
		assert(string.match(itemID, 'item:(%d+):') or tonumber(itemID), 'item must be an item ID or item Link')
		itemID = (tonumber(itemID)) or (GetItemInfoFromHyperlink(itemID))
	end

	-- TODO: skill level requirements for classic?

	if self:HasProfession(333) then -- Enchanting
		if data.enchantingItems[itemID] then
			-- special items that can be disenchanted
			return true
		else
			local _, _, quality, _, _, _, _, _, _, _, _, class, subClass = GetItemInfo(item)
			return quality and ((quality >= LE_ITEM_QUALITY_UNCOMMON and quality <= LE_ITEM_QUALITY_EPIC)
				and C_Item.GetItemInventoryTypeByID(itemID) ~= LE_ITEM_EQUIPLOC_SHIRT
				and (class == LE_ITEM_CLASS_WEAPON
					or (class == LE_ITEM_CLASS_ARMOR and subClass ~= LE_ITEM_ARMOR_COSMETIC)
					or (class == LE_ITEM_CLASS_GEM and subClass == LE_ITEM_SUBCLASS_ARTIFACT)))
		end
	end
end

-- https://wowhead.com/items?filter=107:99;0:2;lockpick:0
local function GetBlacksmithingPick(pickLevel)
	if CLASSIC then
		if pickLevel <= 25 and GetItemCount(15869) > 0 then
			return 15869, nil, 100 -- Silver Skeleton Key
		end
		if pickLevel <= 125 and GetItemCount(15870) > 0 then
			return 15870, nil, 150 -- Golden Skeleton Key
		end
		if pickLevel <= 200 and GetItemCount(15871) > 0 then
			return 15871, nil, 200 -- Truesilver Skeleton Key
		end
		if pickLevel <= 300 and GetItemCount(15872) > 0 then
			return 15872, nil, 275 -- Arcanite Skeleton Key
		end
		if pickLevel <= 375 and GetItemCount(43854) > 0 then
			return 43854, nil, 375 -- Cobalt Skeleton Key
		end
		if pickLevel <= 400 and GetItemCount(43853) > 0 then
			return 43853, nil, 400 -- Titanium Skeleton Key
		end
	else
		if pickLevel <= 15 and GetItemCount(15869) > 0 then
			return 15869, LE_EXPANSION_CLASSIC, 100 -- Silver Skeleton Key
		end
		if pickLevel <= 15 and GetItemCount(15870) > 0 then
			return 15870, LE_EXPANSION_CLASSIC, 150 -- Golden Skeleton Key
		end
		if pickLevel <= 20 and GetItemCount(15871) > 0 then
			return 15871, LE_EXPANSION_CLASSIC, 200 -- Truesilver Skeleton Key
		end
		if pickLevel <= 30 and GetItemCount(15872) > 0 then
			return 15872, LE_EXPANSION_CLASSIC, 275 -- Arcanite Skeleton Key
		end
		if pickLevel <= 30 and GetItemCount(43854) > 0 then
			return 43854, LE_EXPANSION_WRATH_OF_THE_LICH_KING, 1 -- Cobalt Skeleton Key
		end
		if pickLevel <= 30 and GetItemCount(43853) > 0 then
			return 43853, LE_EXPANSION_WRATH_OF_THE_LICH_KING, 55 -- Titanium Skeleton Key
		end
		if pickLevel <= 35 and GetItemCount(55053) > 0 then
			return 55053, LE_EXPANSION_CATACLYSM, 25 -- Obsidium Skeleton Key
		end
		if pickLevel <= 35 and GetItemCount(82960) > 0 then
			return 82960, LE_EXPANSION_MISTS_OF_PANDARIA, 1 -- Ghostly Skeleton Key
		end
		if pickLevel <= 50 and GetItemCount(159826) > 0 then
			return 159826, LE_EXPANSION_BATTLE_FOR_AZEROTH, 1 -- Monelite Skeleton Key
		end
		if pickLevel <= 60 and GetItemCount(171441) > 0 then
			return 171441, LE_EXPANSION_SHADOWLANDS, 1 -- Laestrite Skeleton Key
		end
		if pickLevel <= 70 and GetItemCount(191256) > 0 then
			return 191256, LE_EXPANSION_DRAGONFLIGHT, 1 -- Tyrvite Skeleton Key
		end
	end
end

-- https://wowhead.com/items?filter=107:99;0:7;lockpick:0
local function GetJewelcraftingPick(pickLevel)
	if not CLASSIC then
		if pickLevel <= 550 and GetItemCount(130250) > 0 then
			-- BUG: this item still opens up lockboxes until 550, highly likely to get fixed
			return 130250, LE_EXPANSION_LEGION, 1 -- Jeweled Lockpick
		end
	end
end

-- https://wowhead.com/items?filter=107:99;0:15;lockpick:0
local function GetInscriptionPick(pickLevel)
	if not CLASSIC then
		if pickLevel <= 50 and GetItemCount(159825) > 0 then
			return 159825, LE_EXPANSION_BATTLE_FOR_AZEROTH, 1 -- Scroll of Unlocking
		end
		if pickLevel <= 60 and GetItemCount(173065) > 0 then
			return 173065, LE_EXPANSION_SHADOWLANDS, 1 -- Writ of Grave Robbing
		end
	end
end

-- https://wowhead.com/items?filter=107:99;0:5;lockpick:0
local function GetEngineeringPick(pickLevel)
	if not CLASSIC then
		if pickLevel <= 35 and GetItemCount(60853) > 0 then
			return 60853, LE_EXPANSION_CATACLYSM, 1 -- Volatile Seaforium Blastpack
		end
		if pickLevel <= 35 and GetItemCount(77532) > 0 then
			return 77532, LE_EXPANSION_MISTS_OF_PANDARIA, 1 -- Locksmith's Powderkeg
		end
	end
end

--[[ LibProcessable:IsOpenable(_item_)
Returns whether the player can open the given item with a class/racial ability.

**Arguments:**
* `item`: item ID or link

**Return values:**
* `isOpenable`: Whether or not the player can open the given item _(boolean)_
* `spellID`:    SpellID of the spell that can be used to open the given item _(number)_
--]]
function lib:IsOpenable(itemID)
	if type(itemID) == 'string' then
		assert(string.match(itemID, 'item:(%d+):') or tonumber(itemID), 'item must be an item ID or item Link')
		itemID = (tonumber(itemID)) or (GetItemInfoFromHyperlink(itemID))
	end

	local spellID = (IsSpellKnown(1804) and 1804) -- Pick Lock, Rogue ability
	             or (IsSpellKnown(312890) and 312890) -- Skeleton Pinkie, Mechagnome racial ability
	             or (IsSpellKnown(323427) and 323427) -- Kevin's Keyring, Necrolord soulbind ability

	if spellID then
		local pickLevel = data.containers[itemID]
		return pickLevel and pickLevel <= (UnitLevel('player') * (CLASSIC and 5 or 1)), spellID
	end
end

--[[ LibProcessable:IsOpenableProfession(_item_)
Returns the profession data if the given item can be opened by a profession item that the player
posesses.

**Arguments:**
* `item`: item ID or link

**Return values:**
* `isOpenable`:           Whether or not the player can open the given item _(boolean)_
* `requiredRank`:         The skill level required in the profession _(number)_
* `professionID`:         The profession ID _(number)_
* `expansionID`:          The associated expansion with the profession _(number/nil)_
* `professionItem`:       The itemID for the unlocking item _(number)_
--]]
function lib:IsOpenableProfession(itemID)
	if type(itemID) == 'string' then
		assert(string.match(itemID, 'item:(%d+):') or tonumber(itemID), 'item must be an item ID or item Link')
		itemID = (tonumber(itemID)) or (GetItemInfoFromHyperlink(itemID))
	end

	local pickLevel = data.containers[itemID]
	if not pickLevel then
		return
	end

	if self:HasProfession(164) then -- Blacksmithing
		local itemID, expansionID, requiredRank = GetBlacksmithingPick(pickLevel)
		if itemID then
			local currentRank = expansionID and professions[164][expansion] or professions[164] or 0
			return currentRank >= requiredRank, requiredRank, 164, expansionID, itemID
		end
	end

	if self:HasProfession(755) then -- Jewelcrafting
		local itemID, expansionID, requiredRank = GetJewelcraftingPick(pickLevel)
		if itemID then
			local currentRank = expansionID and professions[755][expansion] or professions[755] or 0
			return currentRank >= requiredRank, requiredRank, 755, expansionID, itemID
		end
	end

	if self:HasProfession(773) then -- Inscription
		local itemID, expansionID, requiredRank = GetInscriptionPick(pickLevel)
		if itemID then
			local currentRank = expansionID and professions[773][expansion] or professions[773] or 0
			return currentRank >= requiredRank, requiredRank, 773, expansionID, itemID
		end
	end

	if self:HasProfession(202) then -- Engineering
		local itemID, expansionID, requiredRank = GetEngineeringPick(pickLevel)
		if itemID then
			local currentRank = expansionID and professions[202][expansion] or professions[202] or 0
			return currentRank >= requiredRank, requiredRank, 202, expansionID, itemID
		end
	end
end

--[[ LibProcessable:HasProfession(_professionID_)
Returns whether the player has the given profession.

Here's a table with the profession ID for each profession.

| Profession Name | Profession ID |
|-----------------|:--------------|
| Alchemy         | 171           |
| Blacksmithing   | 164           |
| Enchanting      | 333           |
| Engineering     | 202           |
| Herbalism       | 182           |
| Inscription     | 773           |
| Jewelcrafting   | 755           |
| Leatherworking  | 165           |
| Mining          | 186           |
| Skinning        | 393           |
| Tailoring       | 197           |

**Arguments:**
* `professionID`: The profession ID

**Return values:**
* `hasProfession`: Whether or not the player has the profession _(boolean)_
--]]
function lib:HasProfession(professionID)
	return not not professions[professionID]
end

--[[ LibProcessable:GetProfessionCategories(_professionID_)
Returns data of all category IDs for a given (valid) profession, indexed by the expansion level index.

**Arguments:**
* `professionID`: The profession ID _(number)_

**Return values:**
* `categories`: Profession categories _(table)_
--]]
function lib:GetProfessionCategories(professionID)
	local professionCategories = data.professionCategories[professionID]
	return professionCategories and CopyTable(professionCategories)
end

--[[ LibProcessable:GetProfessionSkillLines(_professionID_)
Returns data of all skill lines for a given (valid) profession, indexed by the expansion level index.

**Arguments:**
* `professionID`: The profession ID _(number)_

**Return values:**
* `skillLines`: Profession skill lines _(table)_
--]]
function lib:GetProfessionSkillLines(professionID)
	local professionSkillLines = data.professionSkillLines[professionID]
	return professionSkillLines and CopyTable(professionSkillLines)
end

local CLASSIC_PROFESSIONS = {
	-- these are all the Apprentice-level spells
	[(GetSpellInfo(2259))]  = 171, -- Alchemy
	[(GetSpellInfo(2018))]  = 164, -- Blacksmithing
	[(GetSpellInfo(7411))]  = 333, -- Enchanting
	[(GetSpellInfo(4036))]  = 202, -- Engineering
	[(GetSpellInfo(9134))]  = 182, -- Herbalism (this is an effect on a pair of gloves, no spellID exists for herbalism)
	[(GetSpellInfo(45357)) or 0] = 773, -- Inscription
	[(GetSpellInfo(25229)) or 0] = 755, -- Jewelcrafting
	[(GetSpellInfo(2108))]  = 165, -- Leatherworking
	[(GetSpellInfo(2575))]  = 186, -- Mining
	[(GetSpellInfo(8613))]  = 393, -- Skinning
	[(GetSpellInfo(3908))]  = 197, -- Tailoring
}

local Handler = CreateFrame('Frame')
Handler:RegisterEvent('SKILL_LINES_CHANGED')
Handler:SetScript('OnEvent', function()
	table.wipe(professions)

	if CLASSIC then
		for index = 1, GetNumSkillLines() do
			local skillName, isHeader, isExpanded, skillLevel = GetSkillLineInfo(index)
			if skillName == TRADE_SKILLS and isHeader and not isExpanded then
				ExpandSkillHeader(index) -- this will expand the header and trigger SKILL_LINES_CHANGED
				return
			else
				local professionID = CLASSIC_PROFESSIONS[skillName]
				if professionID then
					professions[professionID] = skillLevel
				end
			end
		end
	else
		for _, professionIndex in next, {GetProfessions()} do
			local _, _, skillLevel, _, _, _, professionID = GetProfessionInfo(professionIndex)
			if data.professionSkillLines[professionID] then
				professions[professionID] = {}

				for expansion, skillLine in next, data.professionSkillLines[professionID] do
					if DRAGONFLIGHT then
						local professionInfo = C_TradeSkillUI.GetProfessionInfoBySkillLineID(skillLine)
						if professionInfo then
							professions[professionID][expansion] = professionInfo.skillLevel
						end
					else
						local _, currentRank = C_TradeSkillUI.GetTradeSkillLineInfoByID(skillLine)
						professions[professionID][expansion] = currentRank
					end
				end
			end
		end
	end
end)

data.ores = {
	-- http://www.wowhead.com/spell=31252/prospecting#prospected-from:0+1+17-20
	[2770] = 1, -- Copper Ore
	[2771] = CLASSIC and 50 or 1, -- Tin Ore
	[2772] = CLASSIC and 125 or 1, -- Iron Ore
	[3858] = CLASSIC and 175 or 1, -- Mithril Ore
	[10620] = CLASSIC and 250 or 1, -- Thorium Ore
	[23424] = CLASSIC and 275 or {LE_EXPANSION_BURNING_CRUSADE, 1}, -- Fel Iron Ore
	[23425] = CLASSIC and 325 or {LE_EXPANSION_BURNING_CRUSADE, 25}, -- Adamantite Ore
	[36909] = CLASSIC and 350 or 1, -- Cobalt Ore
	[36910] = CLASSIC and 450 or 1, -- Titanium Ore
	[36912] = CLASSIC and 400 or 1, -- Saronite Ore
	[52183] = 1, -- Pyrite Ore
	[52185] = 1, -- Elementium Ore
	[53038] = 1, -- Obsidium Ore
	[72092] = {LE_EXPANSION_MISTS_OF_PANDARIA, 1}, -- Ghost Iron Ore
	[72093] = {LE_EXPANSION_MISTS_OF_PANDARIA, 25}, -- Kyparite
	[72094] = {LE_EXPANSION_MISTS_OF_PANDARIA, 75}, -- Black Trillium Ore
	[72103] = {LE_EXPANSION_MISTS_OF_PANDARIA, 75}, -- White Trillium Ore
	[123918] = 1, -- Leystone Ore
	[123919] = 1, -- Felslate
	[151564] = 1, -- Empyrium
	[152579] = 1, -- Storm Silver Ore
	[152512] = 1, -- Monelite Ore
	[152513] = 1, -- Platinum Ore
	[155830] = 1, -- Runic Core, BfA Jewelcrafting Quest
	[168185] = 1, -- Osmenite Ore
	[171828] = 1, -- Laestrite
	[171829] = 1, -- Solenium
	[171830] = 1, -- Oxxein
	[171831] = 1, -- Phaedrum
	[171832] = 1, -- Sinvyr
	[171833] = 1, -- Elethium
	[187700] = 1, -- Progenium Ore

	-- UNTESTED DRAGONFLIGHT ORES:
	[188658] = 1, -- Draconium Ore
	[194545] = 1, -- Prismatic Ore
	[190313] = 1, -- Titaniclum Ore
	[190394] = 1, -- Tyrivite Ore
}

data.herbs = {
	-- http://www.wowhead.com/spell=51005/milling#milled-from:0+1+17-20
	[765] = 1, -- Silverleaf
	[785] = 1, -- Mageroyal
	[2447] = 1, -- Peacebloom
	[2449] = 1, -- Earthroot
	[2450] = CLASSIC and 25 or 1, -- Briarthorn
	[2452] = CLASSIC and 25 or 1, -- Swiftthistle
	[2453] = CLASSIC and 25 or 1, -- Bruiseweed
	[3355] = CLASSIC and 75 or 1, -- Wild Steelbloom
	[3356] = CLASSIC and 75 or 1, -- Kingsblood
	[3357] = CLASSIC and 75 or 1, -- Liferoot
	[3358] = CLASSIC and 125 or 1, -- Khadgar's Whisker
	[3369] = CLASSIC and 75 or 1, -- Grave Moss
	[3818] = CLASSIC and 125 or 1, -- Fadeleaf
	[3819] = CLASSIC and 125 or 1, -- Dragon's Teeth
	[3820] = CLASSIC and 25 or 1, -- Stranglekelp
	[3821] = CLASSIC and 125 or 1, -- Goldthorn
	[4625] = CLASSIC and 175 or 1, -- Firebloom
	[8831] = CLASSIC and 175 or 1, -- Purple Lotus
	[8836] = CLASSIC and 175 or 1, -- Arthas' Tears
	[8838] = CLASSIC and 175 or 1, -- Sungrass
	[8839] = CLASSIC and 175 or 1, -- Blindweed
	[8845] = CLASSIC and 175 or 1, -- Ghost Mushroom
	[8846] = CLASSIC and 175 or 1, -- Gromsblood
	[13463] = CLASSIC and 225 or 1, -- Dreamfoil
	[13464] = CLASSIC and 225 or 1, -- Golden Sansam
	[13465] = CLASSIC and 225 or 1, -- Mountain Silversage
	[13466] = CLASSIC and 225 or 1, -- Sorrowmoss
	[13467] = CLASSIC and 200 or 1, -- Icecap
	[22785] = CLASSIC and 275 or 1, -- Felweed
	[22786] = CLASSIC and 275 or 1, -- Dreaming Glory
	[22787] = CLASSIC and 275 or 1, -- Ragveil
	[22789] = CLASSIC and 275 or 1, -- Terocone
	[22790] = CLASSIC and 275 or 1, -- Ancient Lichen
	[22791] = CLASSIC and 275 or 1, -- Netherbloom
	[22792] = CLASSIC and 275 or 1, -- Nightmare Vine
	[22793] = CLASSIC and 275 or 1, -- Mana Thistle
	[36901] = CLASSIC and 325 or 1, -- Goldclover
	[36903] = CLASSIC and 325 or 1, -- Adder's Tongue
	[36904] = CLASSIC and 325 or 1, -- Tiger Lily
	[36905] = CLASSIC and 325 or 1, -- Lichbloom
	[36906] = CLASSIC and 325 or 1, -- Icethorn
	[36907] = CLASSIC and 325 or 1, -- Talandra's Rose
	[37921] = CLASSIC and 325 or 1, -- Deadnettle
	[39970] = CLASSIC and 325 or 1, -- Fire Leaf
	-- [39969] = CLASSIC and ? or nil, -- Fire Seed
	[52983] = 1, -- Cinderbloom
	[52984] = 1, -- Stormvine
	[52985] = 1, -- Azshara's Veil
	[52986] = 1, -- Heartblossom
	[52987] = 1, -- Twilight Jasmine
	[52988] = 1, -- Whiptail
	[72234] = 1, -- Green Tea Leaf
	[72235] = 1, -- Silkweed
	[72237] = 1, -- Rain Poppy
	[79010] = 1, -- Snow Lily
	[79011] = 1, -- Fool's Cap
	[89639] = 1, -- Desecrated Herb
	[109124] = 1, -- Frostweed
	[109125] = 1, -- Fireweed
	[109126] = 1, -- Gorgrond Flytrap
	[109127] = 1, -- Starflower
	[109128] = 1, -- Nagrand Arrowbloom
	[109129] = 1, -- Talador Orchid
	[124101] = 1, -- Aethril
	[124102] = 1, -- Dreamleaf
	[124103] = 1, -- Foxflower
	[124104] = 1, -- Fjarnskaggl
	[124105] = 1, -- Starlight Rose
	[124106] = 1, -- Felwort
	[128304] = 1, -- Yseralline Seed
	[151565] = 1, -- Astral Glory
	[152511] = 1, -- Sea Stalk
	[152509] = 1, -- Siren's Pollen
	[152508] = 1, -- Winter's Kiss
	[152507] = 1, -- Akunda's Bite
	[152506] = 1, -- Star Moss
	[152505] = 1, -- Riverbud
	[152510] = 1, -- Anchor Weed
	[168487] = 1, -- Zin'anthid
	[168583] = 1, -- Widowbloom
	[168586] = 1, -- Rising Glory
	[168589] = 1, -- Marrowroot
	[169701] = 1, -- Deathblossom
	[170554] = 1, -- Vigil's Torch
	[171315] = 1, -- Nightshade
	[187699] = 1, -- First Flower

	-- UNTESTED DRAGONFLIGHT HERBS:
	-- there's 3 of each herb because they have ranks/quality associated with them
	[191460] = 1, -- Hochenblume
	[191461] = 1, -- Hochenblume
	[191462] = 1, -- Hochenblume
	[191464] = 1, -- Saxifrage
	[191465] = 1, -- Saxifrage
	[191466] = 1, -- Saxifrage
	[191467] = 1, -- Bubble Poppy
	[191468] = 1, -- Bubble Poppy
	[191469] = 1, -- Bubble Poppy
	[191470] = 1, -- Writhebark
	[191471] = 1, -- Writhebark
	[191472] = 1, -- Writhebark
	[198412] = 1, -- Serene Pigment
	[198413] = 1, -- Serene Pigment
	[198414] = 1, -- Serene Pigment
	[198415] = 1, -- Flourishing Pigment
	[198416] = 1, -- Flourishing Pigment
	[198417] = 1, -- Flourishing Pigment
	[198418] = 1, -- Blazing Pigment
	[198419] = 1, -- Blazing Pigment
	[198420] = 1, -- Blazing Pigment
	[198421] = 1, -- Shimmering Pigment
	[198422] = 1, -- Shimmering Pigment
	[198423] = 1, -- Shimmering Pigment
}

data.containers = {
	-- https://www.wowhead.com/items?filter=10:195;1:2;:0
	[7209]   = 1, -- Tazan's Satchel
	[4632]   = CLASSIC and 1 or 15, -- Ornate Bronze Lockbox
	[6712]   = CLASSIC and 1 or nil, -- Practice Lock
	[4633]   = CLASSIC and 25 or 15, -- Heavy Bronze Lockbox
	[4634]   = CLASSIC and 70 or 15, -- Iron Lockbox
	[5046]   = CLASSIC and 70 or nil, -- Locked Gift (removed in TBC)
	[4636]   = CLASSIC and 125 or 15, -- Strong Iron Lockbox
	[4637]   = CLASSIC and 175 or 15, -- Steel Lockbox
	[4638]   = CLASSIC and 225 or 15, -- Reinforced Steel Lockbox
	[5758]   = CLASSIC and 225 or 15, -- Mithril Lockbox
	[5759]   = CLASSIC and 225 or 15, -- Thorium Lockbox
	[5760]   = CLASSIC and 225 or 15, -- Eternium Lockbox
	[6354]   = CLASSIC and 1 or 15, -- Small Locked Chest
	[6355]   = CLASSIC and 70 or 15, -- Sturdy Locked Chest
	[7869]   = CLASSIC and 70 or nil,   -- Lucius's Lockbox
	[12033]  = CLASSIC and 275 or 15, -- Thaurissan Family Jewels
	[13875]  = CLASSIC and 175 or 15, -- Ironbound Locked Chest
	[13918]  = CLASSIC and 250 or 15, -- Reinforced Locked Chest
	[16882]  = CLASSIC and 1 or 15, -- Battered Junkbox
	[16883]  = CLASSIC and 70 or 15, -- Worn Junkbox
	[16884]  = CLASSIC and 175 or 15, -- Sturdy Junkbox
	[16885]  = CLASSIC and 250 or 15, -- Heavy Junkbox
	[106895] = 15, -- Iron-Bound Junkbox
	[29569]  = CLASSIC and 300 or 30, -- Strong Junkbox
	[31952]  = CLASSIC and 325 or 30, -- Khorium Lockbox
	[43575]  = CLASSIC and 350 or 30, -- Reinforced Junkbox
	[43622]  = CLASSIC and 375 or 30, -- Froststeel Lockbox
	[43624]  = CLASSIC and 400 or 30, -- Titanium Lockbox
	[45986]  = CLASSIC and 400 or 30, -- Tiny Titanium Lockbox
	[63349]  = 30, -- Flame-Scarred Junkbox
	[68729]  = 30, -- Elementium Lockbox
	[88165]  = 35, -- Vine-Cracked Junkbox
	[88567]  = 35, -- Ghost Iron Lockbox
	[116920] = 40, -- True Steel Lockbox
	[121331] = 45, -- Leystone Lockbox
	[169475] = 50, -- Barnacled Lockbox
	[179311] = 60, -- Synvir Lockbox
	[180522] = 60, -- Phaedrum Lockbox
	[180532] = 60, -- Oxxein Lockbox
	[180533] = 60, -- Solenium Lockbox
	[186161] = 60, -- Stygian Lockbox     TODO: confirm level requirement
	[186160] = 60, -- Locked Artifact Case
	[188787] = 60, -- Locked Broker Luggage

	-- UNTESTED DRAGONFLIGHT BOXES:
	[190954] = 65, -- Tyrivite Lockbox
	[191296] = 75, -- Enchanted Lockbox (how are we supposed to get 75 skill?)
	[194037] = 9999, -- Heavy Chest (requires an item "Gilded Key" according to in-game tooltip)
}

data.enchantingItems = {
	-- Legion enchanting quest line
	[137195] = true, -- Highmountain Armor
	[137221] = true, -- Enchanted Raven Sigil
	[137286] = true, -- Fel-Crusted Rune

	-- Shadowlands profession world quests
	[182021] = true, -- Antique Kyrian Javelin
	[182043] = true, -- Antique Necromancer's Staff
	[182067] = true, -- Antique Duelist's Rapier
	[181991] = true, -- Antique Stalker's Bow
}

-- /run ChatFrame1:Clear(); for _,i in next,{C_TradeSkillUI.GetCategories()} do print(i, C_TradeSkillUI.GetCategoryInfo(i).name) end
data.professionCategories = {
	[171] = { -- Alchemy
		[LE_EXPANSION_CLASSIC]                = 604,
		[LE_EXPANSION_BURNING_CRUSADE]        = 602,
		[LE_EXPANSION_WRATH_OF_THE_LICH_KING] = 600,
		[LE_EXPANSION_CATACLYSM]              = 598,
		[LE_EXPANSION_MISTS_OF_PANDARIA]      = 596,
		[LE_EXPANSION_WARLORDS_OF_DRAENOR]    = 332,
		[LE_EXPANSION_LEGION]                 = 433,
		[LE_EXPANSION_BATTLE_FOR_AZEROTH]     = 592,
		[LE_EXPANSION_SHADOWLANDS]            = 1294,
		[LE_EXPANSION_DRAGONFLIGHT]           = 1582,
	},
	[164] = { -- Blacksmithing
		[LE_EXPANSION_CLASSIC]                = 590,
		[LE_EXPANSION_BURNING_CRUSADE]        = 584,
		[LE_EXPANSION_WRATH_OF_THE_LICH_KING] = 577,
		[LE_EXPANSION_CATACLYSM]              = 569,
		[LE_EXPANSION_MISTS_OF_PANDARIA]      = 553,
		[LE_EXPANSION_WARLORDS_OF_DRAENOR]    = 389,
		[LE_EXPANSION_LEGION]                 = 426,
		[LE_EXPANSION_BATTLE_FOR_AZEROTH]     = 542,
		[LE_EXPANSION_SHADOWLANDS]            = 1311,
		[LE_EXPANSION_DRAGONFLIGHT]           = 1566,
	},
	[333] = { -- Enchanting
		[LE_EXPANSION_CLASSIC]                = 667,
		[LE_EXPANSION_BURNING_CRUSADE]        = 665,
		[LE_EXPANSION_WRATH_OF_THE_LICH_KING] = 663,
		[LE_EXPANSION_CATACLYSM]              = 661,
		[LE_EXPANSION_MISTS_OF_PANDARIA]      = 656,
		[LE_EXPANSION_WARLORDS_OF_DRAENOR]    = 348,
		[LE_EXPANSION_LEGION]                 = 443,
		[LE_EXPANSION_BATTLE_FOR_AZEROTH]     = 647,
		[LE_EXPANSION_SHADOWLANDS]            = 1364,
		[LE_EXPANSION_DRAGONFLIGHT]           = 1588,
	},
	[202] = { -- Engineering
		[LE_EXPANSION_CLASSIC]                = 419,
		[LE_EXPANSION_BURNING_CRUSADE]        = 719,
		[LE_EXPANSION_WRATH_OF_THE_LICH_KING] = 717,
		[LE_EXPANSION_CATACLYSM]              = 715,
		[LE_EXPANSION_MISTS_OF_PANDARIA]      = 713,
		[LE_EXPANSION_WARLORDS_OF_DRAENOR]    = 347,
		[LE_EXPANSION_LEGION]                 = 469,
		[LE_EXPANSION_BATTLE_FOR_AZEROTH]     = 709,
		[LE_EXPANSION_SHADOWLANDS]            = 1381,
		[LE_EXPANSION_DRAGONFLIGHT]           = 1595,
	},
	[182] = { -- Herbalism
		[LE_EXPANSION_CLASSIC]                = 1044,
		[LE_EXPANSION_BURNING_CRUSADE]        = 1042,
		[LE_EXPANSION_WRATH_OF_THE_LICH_KING] = 1040,
		[LE_EXPANSION_CATACLYSM]              = 1038,
		[LE_EXPANSION_MISTS_OF_PANDARIA]      = 1036,
		[LE_EXPANSION_WARLORDS_OF_DRAENOR]    = 1034,
		[LE_EXPANSION_LEGION]                 = 456,
		[LE_EXPANSION_BATTLE_FOR_AZEROTH]     = 1029,
		[LE_EXPANSION_SHADOWLANDS]            = 1441,
		[LE_EXPANSION_DRAGONFLIGHT]           = 1594,
	},
	[773] = { -- Inscription
		[LE_EXPANSION_CLASSIC]                = 415,
		[LE_EXPANSION_BURNING_CRUSADE]        = 769,
		[LE_EXPANSION_WRATH_OF_THE_LICH_KING] = 767,
		[LE_EXPANSION_CATACLYSM]              = 765,
		[LE_EXPANSION_MISTS_OF_PANDARIA]      = 763,
		[LE_EXPANSION_WARLORDS_OF_DRAENOR]    = 410,
		[LE_EXPANSION_LEGION]                 = 450,
		[LE_EXPANSION_BATTLE_FOR_AZEROTH]     = 759,
		[LE_EXPANSION_SHADOWLANDS]            = 1406,
		[LE_EXPANSION_DRAGONFLIGHT]           = 1592,
	},
	[755] = { -- Jewelcrafting
		[LE_EXPANSION_CLASSIC]                = 372,
		[LE_EXPANSION_BURNING_CRUSADE]        = 815,
		[LE_EXPANSION_WRATH_OF_THE_LICH_KING] = 813,
		[LE_EXPANSION_CATACLYSM]              = 811,
		[LE_EXPANSION_MISTS_OF_PANDARIA]      = 809,
		[LE_EXPANSION_WARLORDS_OF_DRAENOR]    = 373,
		[LE_EXPANSION_LEGION]                 = 464,
		[LE_EXPANSION_BATTLE_FOR_AZEROTH]     = 805,
		[LE_EXPANSION_SHADOWLANDS]            = 1418,
		[LE_EXPANSION_DRAGONFLIGHT]           = 1593,
	},
	[165] = { -- Leatherworking
		[LE_EXPANSION_CLASSIC]                = 379,
		[LE_EXPANSION_BURNING_CRUSADE]        = 882,
		[LE_EXPANSION_WRATH_OF_THE_LICH_KING] = 880,
		[LE_EXPANSION_CATACLYSM]              = 878,
		[LE_EXPANSION_MISTS_OF_PANDARIA]      = 876,
		[LE_EXPANSION_WARLORDS_OF_DRAENOR]    = 380,
		[LE_EXPANSION_LEGION]                 = 460,
		[LE_EXPANSION_BATTLE_FOR_AZEROTH]     = 871,
		[LE_EXPANSION_SHADOWLANDS]            = 1334,
		[LE_EXPANSION_DRAGONFLIGHT]           = 1587,
	},
	[186] = { -- Mining
		[LE_EXPANSION_CLASSIC]                = 1078,
		[LE_EXPANSION_BURNING_CRUSADE]        = 1076,
		[LE_EXPANSION_WRATH_OF_THE_LICH_KING] = 1074,
		[LE_EXPANSION_CATACLYSM]              = 1072,
		[LE_EXPANSION_MISTS_OF_PANDARIA]      = 1070,
		[LE_EXPANSION_WARLORDS_OF_DRAENOR]    = 1068,
		[LE_EXPANSION_LEGION]                 = 425,
		[LE_EXPANSION_BATTLE_FOR_AZEROTH]     = 1065,
		[LE_EXPANSION_SHADOWLANDS]            = 1320,
		[LE_EXPANSION_DRAGONFLIGHT]           = 1584,
	},
	[393] = { -- Skinning
		[LE_EXPANSION_CLASSIC]                = 1060,
		[LE_EXPANSION_BURNING_CRUSADE]        = 1058,
		[LE_EXPANSION_WRATH_OF_THE_LICH_KING] = 1056,
		[LE_EXPANSION_CATACLYSM]              = 1054,
		[LE_EXPANSION_MISTS_OF_PANDARIA]      = 1042,
		[LE_EXPANSION_WARLORDS_OF_DRAENOR]    = 1050,
		[LE_EXPANSION_LEGION]                 = 459,
		[LE_EXPANSION_BATTLE_FOR_AZEROTH]     = 1046,
		[LE_EXPANSION_SHADOWLANDS]            = 1331,
		[LE_EXPANSION_DRAGONFLIGHT]           = 1586,
	},
	[197] = { -- Tailoring
		[LE_EXPANSION_CLASSIC]                = 362,
		[LE_EXPANSION_BURNING_CRUSADE]        = 956,
		[LE_EXPANSION_WRATH_OF_THE_LICH_KING] = 954,
		[LE_EXPANSION_CATACLYSM]              = 952,
		[LE_EXPANSION_MISTS_OF_PANDARIA]      = 950,
		[LE_EXPANSION_WARLORDS_OF_DRAENOR]    = 369,
		[LE_EXPANSION_LEGION]                 = 430,
		[LE_EXPANSION_BATTLE_FOR_AZEROTH]     = 942,
		[LE_EXPANSION_SHADOWLANDS]            = 1395,
		[LE_EXPANSION_DRAGONFLIGHT]           = 1591,
	},
}

-- https://wowpedia.fandom.com/wiki/TradeSkillLineID
data.professionSkillLines = {
	[171] = { -- Alchemy
		[LE_EXPANSION_CLASSIC]                = 2485,
		[LE_EXPANSION_BURNING_CRUSADE]        = 2484,
		[LE_EXPANSION_WRATH_OF_THE_LICH_KING] = 2483,
		[LE_EXPANSION_CATACLYSM]              = 2482,
		[LE_EXPANSION_MISTS_OF_PANDARIA]      = 2481,
		[LE_EXPANSION_WARLORDS_OF_DRAENOR]    = 2480,
		[LE_EXPANSION_LEGION]                 = 2479,
		[LE_EXPANSION_BATTLE_FOR_AZEROTH]     = 2478,
		[LE_EXPANSION_SHADOWLANDS]            = 2750,
		[LE_EXPANSION_DRAGONFLIGHT]           = 2823,
	},
	[164] = { -- Blacksmithing
		[LE_EXPANSION_CLASSIC]                = 2477,
		[LE_EXPANSION_BURNING_CRUSADE]        = 2476,
		[LE_EXPANSION_WRATH_OF_THE_LICH_KING] = 2475,
		[LE_EXPANSION_CATACLYSM]              = 2474,
		[LE_EXPANSION_MISTS_OF_PANDARIA]      = 2473,
		[LE_EXPANSION_WARLORDS_OF_DRAENOR]    = 2472,
		[LE_EXPANSION_LEGION]                 = 2454,
		[LE_EXPANSION_BATTLE_FOR_AZEROTH]     = 2437,
		[LE_EXPANSION_SHADOWLANDS]            = 2751,
		[LE_EXPANSION_DRAGONFLIGHT]           = 2822,
	},
	[333] = { -- Enchanting
		[LE_EXPANSION_CLASSIC]                = 2494,
		[LE_EXPANSION_BURNING_CRUSADE]        = 2493,
		[LE_EXPANSION_WRATH_OF_THE_LICH_KING] = 2492,
		[LE_EXPANSION_CATACLYSM]              = 2491,
		[LE_EXPANSION_MISTS_OF_PANDARIA]      = 2489,
		[LE_EXPANSION_WARLORDS_OF_DRAENOR]    = 2488,
		[LE_EXPANSION_LEGION]                 = 2487,
		[LE_EXPANSION_BATTLE_FOR_AZEROTH]     = 2486,
		[LE_EXPANSION_SHADOWLANDS]            = 2753,
		[LE_EXPANSION_DRAGONFLIGHT]           = 2825,
	},
	[202] = { -- Engineering
		[LE_EXPANSION_CLASSIC]                = 2506,
		[LE_EXPANSION_BURNING_CRUSADE]        = 2505,
		[LE_EXPANSION_WRATH_OF_THE_LICH_KING] = 2504,
		[LE_EXPANSION_CATACLYSM]              = 2503,
		[LE_EXPANSION_MISTS_OF_PANDARIA]      = 2502,
		[LE_EXPANSION_WARLORDS_OF_DRAENOR]    = 2501,
		[LE_EXPANSION_LEGION]                 = 2500,
		[LE_EXPANSION_BATTLE_FOR_AZEROTH]     = 2499,
		[LE_EXPANSION_SHADOWLANDS]            = 2755,
		[LE_EXPANSION_DRAGONFLIGHT]           = 2827,
	},
	[182] = { -- Herbalism
		[LE_EXPANSION_CLASSIC]                = 2556,
		[LE_EXPANSION_BURNING_CRUSADE]        = 2555,
		[LE_EXPANSION_WRATH_OF_THE_LICH_KING] = 2554,
		[LE_EXPANSION_CATACLYSM]              = 2553,
		[LE_EXPANSION_MISTS_OF_PANDARIA]      = 2552,
		[LE_EXPANSION_WARLORDS_OF_DRAENOR]    = 2551,
		[LE_EXPANSION_LEGION]                 = 2550,
		[LE_EXPANSION_BATTLE_FOR_AZEROTH]     = 2549,
		[LE_EXPANSION_SHADOWLANDS]            = 2760,
		[LE_EXPANSION_DRAGONFLIGHT]           = 2832,
	},
	[773] = { -- Inscription
		[LE_EXPANSION_CLASSIC]                = 2514,
		[LE_EXPANSION_BURNING_CRUSADE]        = 2513,
		[LE_EXPANSION_WRATH_OF_THE_LICH_KING] = 2512,
		[LE_EXPANSION_CATACLYSM]              = 2511,
		[LE_EXPANSION_MISTS_OF_PANDARIA]      = 2510,
		[LE_EXPANSION_WARLORDS_OF_DRAENOR]    = 2509,
		[LE_EXPANSION_LEGION]                 = 2508,
		[LE_EXPANSION_BATTLE_FOR_AZEROTH]     = 2507,
		[LE_EXPANSION_SHADOWLANDS]            = 2756,
		[LE_EXPANSION_DRAGONFLIGHT]           = 2828,
	},
	[755] = { -- Jewelcrafting
		[LE_EXPANSION_CLASSIC]                = 2524,
		[LE_EXPANSION_BURNING_CRUSADE]        = 2523,
		[LE_EXPANSION_WRATH_OF_THE_LICH_KING] = 2522,
		[LE_EXPANSION_CATACLYSM]              = 2521,
		[LE_EXPANSION_MISTS_OF_PANDARIA]      = 2520,
		[LE_EXPANSION_WARLORDS_OF_DRAENOR]    = 2519,
		[LE_EXPANSION_LEGION]                 = 2518,
		[LE_EXPANSION_BATTLE_FOR_AZEROTH]     = 2517,
		[LE_EXPANSION_SHADOWLANDS]            = 2757,
		[LE_EXPANSION_DRAGONFLIGHT]           = 2829,
	},
	[165] = { -- Leatherworking
		[LE_EXPANSION_CLASSIC]                = 2532,
		[LE_EXPANSION_BURNING_CRUSADE]        = 2531,
		[LE_EXPANSION_WRATH_OF_THE_LICH_KING] = 2530,
		[LE_EXPANSION_CATACLYSM]              = 2529,
		[LE_EXPANSION_MISTS_OF_PANDARIA]      = 2528,
		[LE_EXPANSION_WARLORDS_OF_DRAENOR]    = 2527,
		[LE_EXPANSION_LEGION]                 = 2526,
		[LE_EXPANSION_BATTLE_FOR_AZEROTH]     = 2525,
		[LE_EXPANSION_SHADOWLANDS]            = 2758,
		[LE_EXPANSION_DRAGONFLIGHT]           = 2830,
	},
	[186] = { -- Mining
		[LE_EXPANSION_CLASSIC]                = 2572,
		[LE_EXPANSION_BURNING_CRUSADE]        = 2571,
		[LE_EXPANSION_WRATH_OF_THE_LICH_KING] = 2570,
		[LE_EXPANSION_CATACLYSM]              = 2569,
		[LE_EXPANSION_MISTS_OF_PANDARIA]      = 2568,
		[LE_EXPANSION_WARLORDS_OF_DRAENOR]    = 2567,
		[LE_EXPANSION_LEGION]                 = 2566,
		[LE_EXPANSION_BATTLE_FOR_AZEROTH]     = 2565,
		[LE_EXPANSION_SHADOWLANDS]            = 2761,
		[LE_EXPANSION_DRAGONFLIGHT]           = 2833,
	},
	[393] = { -- Skinning
		[LE_EXPANSION_CLASSIC]                = 2564,
		[LE_EXPANSION_BURNING_CRUSADE]        = 2563,
		[LE_EXPANSION_WRATH_OF_THE_LICH_KING] = 2562,
		[LE_EXPANSION_CATACLYSM]              = 2561,
		[LE_EXPANSION_MISTS_OF_PANDARIA]      = 2560,
		[LE_EXPANSION_WARLORDS_OF_DRAENOR]    = 2559,
		[LE_EXPANSION_LEGION]                 = 2558,
		[LE_EXPANSION_BATTLE_FOR_AZEROTH]     = 2557,
		[LE_EXPANSION_SHADOWLANDS]            = 2762,
		[LE_EXPANSION_DRAGONFLIGHT]           = 2834,
	},
	[197] = { -- Tailoring
		[LE_EXPANSION_CLASSIC]                = 2540,
		[LE_EXPANSION_BURNING_CRUSADE]        = 2539,
		[LE_EXPANSION_WRATH_OF_THE_LICH_KING] = 2538,
		[LE_EXPANSION_CATACLYSM]              = 2537,
		[LE_EXPANSION_MISTS_OF_PANDARIA]      = 2536,
		[LE_EXPANSION_WARLORDS_OF_DRAENOR]    = 2535,
		[LE_EXPANSION_LEGION]                 = 2534,
		[LE_EXPANSION_BATTLE_FOR_AZEROTH]     = 2533,
		[LE_EXPANSION_SHADOWLANDS]            = 2759,
		[LE_EXPANSION_DRAGONFLIGHT]           = 2831,
	},
}
