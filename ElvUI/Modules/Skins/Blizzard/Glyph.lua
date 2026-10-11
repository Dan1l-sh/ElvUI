local E, L, V, P, G = unpack(select(2, ...)) --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local S = E:GetModule("Skins")

--Lua functions
local _G = _G
local ipairs, select = ipairs, select
--WoW API / Variables
local hooksecurefunc = hooksecurefunc

-- Glyphs are a view of the NOZDOR talent window (EnterGlyphView in
-- Blizzard_TalentUI). The window chrome, its rock base and both insets are
-- handled from Talent.lua's PlayerTalentFrame_Refresh hook. The parchment wheel,
-- sockets, list rows, headers and the minimal scrollbar are server art and kept.

local GLYPH_BG_ALPHA = 0.6

local function styleParchment()
	if _G.GlyphFrameBackground then _G.GlyphFrameBackground:SetAlpha(GLYPH_BG_ALPHA) end
	if _G.GlyphFrameGlow then _G.GlyphFrameGlow:SetAlpha(GLYPH_BG_ALPHA) end
end

-- Search box and the availability filter are created on the first list populate.
local function skinListControls()
	local search = _G.GlyphFrameSearchBox
	if search and not search.backdrop then
		for _, key in ipairs({ "Left", "Middle", "Right" }) do
			if search[key] then search[key]:SetAlpha(0) end
		end
		S:HandleEditBox(search)
	end

	local filter = _G.GlyphFrameFilterButton
	if filter and not filter.__euiSkinned then
		filter.__euiSkinned = true
		-- Its three-slice art is re-atlased on hover/press; alpha survives that.
		for i = 1, filter:GetNumRegions() do
			local region = select(i, filter:GetRegions())
			if region and region:IsObjectType("Texture") and region:GetDrawLayer() == "BACKGROUND" then
				region:SetAlpha(0)
			end
		end
		filter:CreateBackdrop("Default")
		filter.backdrop:SetAllPoints()
		filter:HookScript("OnEnter", S.SetModifiedBackdrop)
		filter:HookScript("OnLeave", S.SetOriginalBackdrop)
	end
end

local function update()
	if _G.GlyphFrame and _G.GlyphFrame:IsShown() then
		styleParchment()
		skinListControls()
	end
end

S:AddCallbackForAddon("Blizzard_GlyphUI", "Skin_Blizzard_GlyphUI", function()
	if not E.private.skins.blizzard.enable or not E.private.skins.blizzard.glyph then return end
	if not _G.GlyphFrame then return end

	_G.GlyphFrame:HookScript("OnShow", update)
	hooksecurefunc("GlyphFrame_Update", update)
	update()
end)
