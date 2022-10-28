std = 'lua51'

quiet = 1 -- suppress report output for files without warnings

-- see https://luacheck.readthedocs.io/en/stable/warnings.html#list-of-warnings
-- and https://luacheck.readthedocs.io/en/stable/cli.html#patterns
ignore = {
	'212/self', -- unused argument self
	'212/event', -- unused argument event
	'212/unit', -- unused argument unit
	'212/element', -- unused argument element
	'312/event', -- unused value of argument event
	'312/unit', -- unused value of argument unit
	'431', -- shadowing an upvalue
	'614', -- trailing whitespace in a comment
	'631', -- line is too long
}

exclude_files = {}

globals = {}

read_globals = {
	table = {fields = {'wipe'}},

	-- SharedXML objects
	'CopyTable', -- SharedXML/TableUtil.lua

	-- SharedXML functions
	'GetItemInfoFromHyperlink', -- SharedXML/LinkUtil.lua

	-- namespaces
	'Enum',
	'C_Item',
	'C_TradeSkillUI',

	-- GlobalStrings
	'TRADE_SKILLS',

	-- enums (old style)
	'LE_ITEM_QUALITY_UNCOMMON', -- classic only
	'LE_ITEM_QUALITY_EPIC', -- classic only
	'LE_EXPANSION_CLASSIC',
	'LE_EXPANSION_BURNING_CRUSADE',
	'LE_EXPANSION_WRATH_OF_THE_LICH_KING',
	'LE_EXPANSION_CATACLYSM',
	'LE_EXPANSION_MISTS_OF_PANDARIA',
	'LE_EXPANSION_WARLORDS_OF_DRAENOR',
	'LE_EXPANSION_LEGION',
	'LE_EXPANSION_BATTLE_FOR_AZEROTH',
	'LE_EXPANSION_SHADOWLANDS',
	'LE_EXPANSION_DRAGONFLIGHT',

	-- API
	'CreateFrame',
	'GetBuildInfo',
	'GetItemCount',
	'GetItemInfo',
	'GetProfessionInfo',
	'GetProfessions',
	'GetSpellInfo',
	'IsSpellKnown',
	'UnitLevel',
	'IsPlayerSpell',
	'GetNumSkillLines', -- classic only
	'GetSkillLineInfo', -- classic only
	'ExpandSkillHeader', -- classic only

	-- exposed from other addons
	'LibStub',
}
