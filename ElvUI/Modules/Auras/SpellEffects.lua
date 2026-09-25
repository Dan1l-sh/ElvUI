local E, L, V, P, G = unpack(select(2, ...)) --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB

--Lua functions
local _G = _G
local ipairs, tonumber, tostring = ipairs, tonumber, tostring
local floor = math.floor
local concat = table.concat
--WoW API / Variables
local CreateFrame = CreateFrame
local GetCVar = GetCVar
local SetCVar = SetCVar

-- Вкладка «Эффекты заклинаний» в /ec → «Эффекты и ауры». Данные и CVar'ы
-- берутся из FrameXML (SPELL_FX_*, InterfaceOptionsPanels.lua), чтобы
-- стоковая панель и ElvUI правили одно и то же. Без Extension.dll CVar'ов
-- нет, и вкладка не добавляется.

local function Available()
	return _G.SPELL_FX_KINDS and _G.SpellFx_Available and _G.SpellFx_Available()
end

local function IsHidden(kind, source)
	local mask = tonumber(GetCVar(kind.cvar)) or 0
	return floor(mask / source.bit) % 2 == 1
end

local function NotifyChange()
	local ACR = E.Libs.AceConfigRegistry
	if ACR then ACR:NotifyChange("ElvUI") end
end

local function Lines(...)
	local out = {}
	for i = 1, select("#", ...) do
		local lines = select(i, ...)
		if lines then out[#out + 1] = concat(lines, "\n") end
	end
	return concat(out, "\n\n")
end

local function BuildOptions()
	local ACH = E.Libs.ACH
	local zones = _G.SPELL_FX_DROPDOWNS.zones

	local group = ACH:Group("Эффекты заклинаний", nil, 20, nil, nil, nil, false, false)
	group.args.header = ACH:Header("Эффекты заклинаний: что показывать", 1)
	group.args.intro = ACH:Description(concat(_G.SPELL_FX_TITLE_INFO, "\n"), 2, "medium")

	for r, source in ipairs(_G.SPELL_FX_SOURCES) do
		local row = ACH:Group(source.label, nil, 10 + r)
		row.guiInline = true

		for i, kind in ipairs(_G.SPELL_FX_KINDS) do
			local toggle
			if source.npc and kind.key == "aura" then
				-- Ауры НИП и боссов расширение не скрывает никогда.
				toggle = ACH:Toggle(kind.label, Lines({"Ауры НИП и боссов видны всегда: это подсказки механик."}), i, nil, nil, nil,
					function() return true end, nil, true)
			else
				toggle = ACH:Toggle(kind.label, Lines(source.info, kind.info), i, nil, nil, nil,
					function() return not IsHidden(kind, source) end,
					function(_, value) _G.SpellFx_SetBit(kind.cvar, source.bit, not value) end)
			end
			row.args[kind.key] = toggle
		end

		group.args["source"..r] = row
	end

	local presets = ACH:Group("Быстрая настройка", nil, 30)
	presets.guiInline = true
	for i, preset in ipairs(_G.SPELL_FX_PRESETS) do
		presets.args["preset"..i] = ACH:Execute(preset.text, preset.tooltip, i, function()
			_G.SpellFx_ApplyPreset(preset)
			NotifyChange()
		end)
	end
	group.args.presets = presets

	local zoneValues = {}
	for _, option in ipairs(zones.options) do
		zoneValues[option.value] = option.text
	end
	group.args.zones = ACH:Select(zones.label, zones.tooltip, 40, zoneValues, nil, nil,
		function() return GetCVar(zones.cvar) or "0" end,
		function(_, value)
			SetCVar(zones.cvar, tostring(value))
			_G.SpellFx_UpdateActive()
		end)

	return group
end

local function InsertOptions()
	if not Available() then return end

	local auras = E.Options.args.auras
	if auras and auras.args then
		auras.args.spellEffects = BuildOptions()
	else
		E.Options.args.spellEffects = BuildOptions()
	end
end

-- E.Options.args.auras создаёт ElvUI_OptionsUI при загрузке и затирает
-- таблицу целиком, поэтому вставляем вкладку только после неё.
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, _, addon)
	if addon ~= "ElvUI_OptionsUI" then return end
	self:UnregisterEvent("ADDON_LOADED")
	InsertOptions()
end)
