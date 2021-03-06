--[[
	Copyright (C) 2006-2007 Nymbia
	Copyright (C) 2010-2017 Hendrik "Nevcairiel" Leppkes < h.leppkes@gmail.com >
	Copyright (C) 2014 ccfreak < ccfreak987+qzsch@gmail.com >
	Copyright (C) 2022 호불-아즈샤라 < hobulian@gmail.com >

	This program is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]
local Quartz3 = LibStub("AceAddon-3.0"):GetAddon("Quartz3")
local L = LibStub("AceLocale-3.0"):GetLocale("Quartz3")

local MODNAME = "School"
local School = Quartz3:NewModule(MODNAME, "AceEvent-3.0", "AceHook-3.0")
School.Update = {}

--[[
	LOCALS
]]
local barInfo = {
	player = {
		module = Quartz3:GetModule("Player"),
		name = "Player"
	},
	pet = {
		module = Quartz3:GetModule("Pet"),
		name = "Pet"
	},
	target = {
		module = Quartz3:GetModule("Target"),
		name = "Target"
	},
	focus = {
		module = Quartz3:GetModule("Focus"),
		name = "Focus"
	}
}

local castColor, schools, mschools, modifier, db, getOptions, cache, curSpells = {1, 0.7, 0}, {
	Physical = 1,
	Holy = 2,
	Fire = 4,
	Nature = 8,
	Frost = 16,
	Shadow = 32,
	Arcane = 64
}, {
	Radient = 6,
	Firestorm = 12,
	Frostfire = 20,
	Froststorm = 24,
	Elemental = 28,
	Twilight = 34,
	Shadowflame = 36,
	Plague = 40,
	Shadowfrost = 48,
	Astral = 72,
	Fel = 99,
	Cosmic = 106,
	Chromatic = 124,
	Magic = 126,
	Chaos = 127
}

local defaults = {
	profile = {
		player = {
			cast = 1
		},
		pet = {},
		target = {},
		focus = {},
		useSchool = {
			[1] = 1,
			[2] = 1,
			[4] = 1,
			[8] = 1,
			[16] = 1,
			[32] = 1,
			[64] = 1
		},
		schoolColor = {
			[1] = {1, 0.7, 0},
			[2] = {1, 0.9, 0.5},
			[4] = {1, 0.35, 0},
			[6] = {1, 0.9, 0.5},
			[8] = {0.3, 0.9, 0.3},
			[12] = {1, 0.5, 0},
			[16] = {0.5, 1, 1},
			[20] = {0.77, 0.85, 1},
			[24] = {0.42, 0.67, 1},
			[28] = {0.3, 1, 0.72},
			[32] = {0.5, 0.5, 1},
			[34] = {0.7, 0.5, 1},
			[36] = {0.57, 0.27, 0.74},
			[40] = {0.08, 0.86, 0.61},
			[48] = {0.65, 0.65, 1},
			[64] = {1, 0.5, 1},
			[72] = {1, 0.67, 1},
			[99] = {0.61, 1, 0},
			[106] = {0.95, 0.92, 0.75},
			[124] = {0.33, 0, 1},
			[126] = {1, 0.35, 1},
			[127] = {0.61, 1, 0}
		},
	}
}
--[[
	INIT
]]
function School:OnInitialize()
	self.db = Quartz3.db:RegisterNamespace(MODNAME, defaults)
	db = self.db.profile
	
	self:SetEnabledState(Quartz3:GetModuleEnabled(MODNAME))
	Quartz3:RegisterModuleOptions(MODNAME, getOptions, MODNAME)
end

function School:OnEnable()
	cache = {
		[GetSpellInfo(5143)] = 64, -- "Arcane Missiles", localized
	}
	curSpells = {}
	modifier = {
	[3] = 2, --HolyStrike
	[10] = 2, --HolyStorm
	[5] = 4, --FlameStrike
	[66] = db.useSchool[6] and 6 or 2,--Divine
	[9] = 8, --StormStrike
	[68] = db.useSchool[12] and 12 or 4, --SpellFire
	[17] = 16, --FrostStrike
	[18] = db.useSchool[20] and 20 or 16, --HolyFrost
	[80] = db.useSchool[20] and 20 or 16, --SpellFrost
	[33] = 32, --ShadowStrike
	[96] = db.useSchool[34] and 34 or 32, --SpellShadow
	[65] = 64, --SpellStrike
	[62] = db.useSchool[126] and 126 or 64, --Chromatic
	}
	self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP", "UnitSpellcastStop")
	self:RegisterEvent("UNIT_SPELLCAST_STOP", "UnitSpellcastStop")
end

function School:OnDisable()
	self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	self:UnregisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
	self:UnregisterEvent("UNIT_SPELLCAST_STOP")
	cache = nil
	curSpells = nil
	modifier = nil
end

--[[
	EVENT HANDELERS
]]
function School:UnitSpellcastStop(event, unit)
	if Quartz3:GetModuleEnabled(MODNAME) and curSpells[unit] then
		curSpells[unit] = nil
	end
end

function School:CombatEventTriggered( ... )
	local _, type, _, sourceGUID = ...
	if type == "SPELL_CAST_START" or type == "SPELL_CAST_SUCCESS" then
		local spellId, name, school = select(12, ...)
		if cache[name] then
			return
		end
		cache[name] = modifier[school] or school
		-- UNIT_SPELLCAST-events happens before combat log, update bars casting the spell
		for unit, spell in pairs(curSpells) do
			if spell == name then
				self:UpdateCastBar(unit, spell)
			end
		end
	end
end

function School:COMBAT_LOG_EVENT_UNFILTERED(event)
	self:CombatEventTriggered(CombatLogGetCurrentEventInfo())
end

function School:UNIT_SPELLCAST_START(object, bar, unit)
	self.hooks[object].UNIT_SPELLCAST_START(object, bar, unit)
	if Quartz3:GetModuleEnabled(MODNAME) then
		self:UpdateCastBar(unit)
	end
end

for unit, info in pairs(barInfo) do
	if info.module.UNIT_SPELLCAST_START then
		School:RawHook(info.module, "UNIT_SPELLCAST_START")
	else
		function info.module:UNIT_SPELLCAST_START(bar, unit)
			if Quartz3:GetModuleEnabled(MODNAME) then
				School:UpdateCastBar(unit)
			end
		end
	end
end

function School:UpdateCastBar(unit, spell)
	if not barInfo[unit] or not Quartz3:GetModuleEnabled(barInfo[unit].name) then
		return
	end
	local mod = barInfo[unit].module
	table.foreach(mod.db, print)
	table.foreach(mod.Bar, print)
	if mod.db.profile.noInterruptChangeColor then 
		if (mod.Bar.channeling and select(7,UnitChannelInfo(unit))) or select(8,UnitCastingInfo(unit)) then 
			return
		end
	end
	if not spell then
		if mod.Bar.channeling then
			spell = UnitChannelInfo(unit)
		else
			spell = UnitCastingInfo(unit)
		end
	end
	curSpells[unit] = spell
	if ( not mod.Bar.channeling and not db[unit].cast ) or ( mod.Bar.channeling and not db[unit].channel ) or not db.schoolColor[cache[spell]] or not db.useSchool[cache[spell]] then
		return
	end
	
	local schoolColor = db.schoolColor[cache[spell]]
	if UnitIsUnit(unit, "player") then
		local class = UnitClassBase("player")
		if (db.useSchool[99] and cache[spell] == 4) and
		((class == "WARLOCK" and IsSpellKnown(101508) and GetSpecializationInfo(GetSpecialization()) == 267) or 
		class == "DEMONHUNTER") then
			schoolColor = db.schoolColor[99]
		end
	end
	mod.Bar.Bar:SetStatusBarColor(unpack(schoolColor))
end

--[[
	UTILS
]]
local function clrStr(str, clr)
	return "\124c" .. clr .. str .. "\124r"
end

local function classStr(classId)
	if not classId then return end
	local locale, class, Id = GetClassInfo(classId)
	local c = RAID_CLASS_COLORS[class]
	return "\124c" .. c.colorStr .. locale .. "\124r"
end

local function spellInfoStr (spellId)
	if not spellId then return end
	local name, _, icon = GetSpellInfo(spellId)
	local size = 14
	return CreateTextureMarkup(icon, size, size, 0, 0, 0, 1, 0, 1) .. name
end

--[[
	OPTIONS
]]
function School:WipeSettings()
	self.db:ResetProfile()
	LibStub("AceConfigRegistry-3.0"):NotifyChange("Quartz3")
end

local colorOptions
local function GetColorOptions()
	if not colorOptions then
		local os, defaultColors, mschoolText, pos = 0, {
			[1] = {1, 0.7, 0},
			[2] = {1, 0.9, 0.5},
			[4] = {1, 0.35, 0},
			[6] = {1, 0.9, 0.5},
			[8] = {0.3, 0.9, 0.3},
			[12] = {1, 0.5, 0},
			[16] = {0.5, 1, 1},
			[20] = {0.77, 0.85, 1},
			[24] = {0.42, 0.67, 1},
			[28] = {0.3, 1, 0.72},
			[32] = {0.5, 0.5, 1},
			[34] = {0.7, 0.5, 1},
			[36] = {0.57, 0.27, 0.74},
			[40] = {0.08, 0.86, 0.61},
			[48] = {0.65, 0.65, 1},
			[64] = {1, 0.5, 1},
			[72] = {1, 0.67, 1},
			[99] = {0.61, 1, 0},
			[106] = {0.95, 0.92, 0.75},
			[124] = {0.33, 0, 1},
			[126] = {1, 0.35, 1},
			[127] = {0.61, 1, 0}
		}, {
			[24] = spellInfoStr(92380) .. "(" .. classStr(3) .. " "..BATTLE_PET_NAME_8 ..")",
			[28] = spellInfoStr(117014) .. "(" .. classStr(7) .. ")",
			[36] = spellInfoStr(105174) .. "(" .. classStr(9) .. ")",
			[72] = spellInfoStr(197626) .. "(".. classStr(11) .. ")",
			[99] = "Fel-Fire(" .. classStr(9) .. ", ".. classStr(12) .. ")",
			[106] = "9.2 Patch",
			[124] = spellInfoStr(116858) .. "(" .. classStr(9) .. ")\n" .. spellInfoStr(198013) .. "(" .. classStr(12) .. ")",
		}
		colorOptions = {
			type = "group",
			name = "Colors",
			desc = "Colors",
			order = 103,
			args = {}
		}
		for school, id in pairs(schools) do
			pos = id * 2
			colorOptions.args[school .. "Color"] = {
				type = "color",
				name = school,
				desc = school .. " color",
				get = function() return unpack(db.schoolColor[id]) end,
				set = function(info, ...) db.schoolColor[id] = {...} end,
				order = pos
			}
			pos = pos + 1
			colorOptions.args[school .. "Enabled"] = {
				type = "toggle",
				name = L["Enable"],
				get = function() return db.useSchool[id] end,
				set = function(info, enabled) db.useSchool[id] = enabled end,
				order = pos
			}
			pos = pos + 1
			colorOptions.args[school .. "Default"] = {
				type = "execute",
				name = "Default",
				func = function() db.schoolColor[id] = defaultColors[id] end,
				order = pos
			}
			if os < pos then -- get the higest position from single-schools
				os = pos
			end
		end
		colorOptions.args["headerMultiSchool"] = {
			type = "header",
			name = "Multi Schools",
			order = os + 1
		}
		colorOptions.args["tipMultiSchool"] = {
			type = "description",
			name = clrStr("Tip:", "ff00ff00") .. " Examples are on tooltip. If not it's for NPC only",
			order = os + 2
		}
		os = os + 2
		for school, id in pairs(mschools) do
			pos = id * 3 + os
			colorOptions.args[school .. "Color"] = {
				type = "color",
				name = school,
				desc = mschoolText[id] and school .. " color\n\n" .. clrStr("EX:", "ff00ff00") .. "\n" .. mschoolText[id] or school .. " color",
				get = function() return unpack(db.schoolColor[id]) end,
				set = function(info, ...) db.schoolColor[id] = {...} end,
				order = pos
			}
			pos = pos + 1
			colorOptions.args[school .. "Enabled"] = {
				type = "toggle",
				name = L["Enable"],
				get = function() return db.useSchool[id] end,
				set = function(info, enabled) db.useSchool[id] = enabled end,
				order = pos
			}
			pos = pos + 1
			colorOptions.args[school .. "Default"] = {
				type = "execute",
				name = "Default",
				func = function() db.schoolColor[id] = defaultColors[id] end,
				order = pos
			}
		end
	end
	return colorOptions
end

do
	local options
	
	function getOptions()
		if options then
			return options
		end
		options = {
			type = "group",
			name = "School",
			order = 600,
			childGroups = "tab",
			args = {
				toggle = {
					type = "toggle",
					name = L["Enable"],
					desc = L["Enable"],
					get = function() return Quartz3:GetModuleEnabled(MODNAME) end,
					set = function(info, v) Quartz3:SetModuleEnabled(MODNAME, v) end,
					order = 100
				},
				version = {
					type = "description",
					name = clrStr("Version: ", "ff00ff00") .. GetAddOnMetadata("Quartz_School", "Version"),
					order = 101
				},
				general = {
					type = "group",
					name = "General",
					desc = "General",
					order = 102,
					args = {
						generaldesc = {
							type = "description",
							name = "Select what unit cast bars you wish to color.",
							order = 1,
						},
						toggleplayercast = {
							type = "toggle",
							name = "Player Casts",
							desc = "Color player casts",
							get = function()
								return db.player.cast
							end,
							set = function(info, ...)
								db.player.cast = ...
							end,
							order = 2,
						},
						toggleplayerchannel = {
							type = "toggle",
							name = "Player Channels",
							desc = "Color player channels",
							get = function()
								return db.player.channel
							end,
							set = function(info, ...)
								db.player.channel = ...
							end,
							order = 3,
						},
						toggletargetcast = {
							type = "toggle",
							name = "Target Casts",
							desc = "Color target casts",
							get = function()
								return db.target.cast
							end,
							set = function(info, ...)
								db.target.cast = ...
							end,
							order = 4,
						},
						toggletargetchannel = {
							type = "toggle",
							name = "Target Channels",
							desc = "Color target channels",
							get = function()
								return db.target.channel
							end,
							set = function(info, ...)
								db.target.channel = ...
							end,
							order = 5,
						},
						togglepetcast = {
							type = "toggle",
							name = "Pet Casts",
							desc = "Color pet casts",
							get = function()
								return db.pet.cast
							end,
							set = function(info, ...)
								db.pet.cast = ...
							end,
							order = 6,
						},
						togglepetchannel = {
							type = "toggle",
							name = "Pet Channels",
							desc = "Color pet channels",
							get = function()
								return db.pet.channel
							end,
							set = function(info, ...)
								db.pet.channel = ...
							end,
							order = 7,
						},
						togglefocuscast = {
							type = "toggle",
							name = "Focus Casts",
							desc = "Color focus casts",
							get = function()
								return db.focus.cast
							end,
							set = function(info, ...)
								db.focus.cast = ...
							end,
							order = 8,
						},
						togglefocuschannel = {
							type = "toggle",
							name = "Focus Channels",
							desc = "Color focus channels",
							get = function()
								return db.focus.channel
							end,
							set = function(info, ...)
								db.focus.channel = ...
							end,
							order = 9,
						},
						headerSplit = {
							type = "header",
							name = "",
							order = 10,
						},
						wipe = {
							type = "execute",
							name = "Reset",
							desc = "Reset School settings for this profile.",
							func = function()
								School:WipeSettings()
							end,
							confirm = function()
								return "You are about to wipe the School module options for this profile. Are you sure about this?"
							end,
							width = "half",
							order = 11,
						}
					}
				}
			}
		}
		options.args.colors = GetColorOptions()
		return options
	end
end