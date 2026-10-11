local E, L, V, P, G = unpack(select(2, ...)) --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local S = E:GetModule("Skins")

--Lua functions
local _G = _G
local ipairs, select, type, unpack = ipairs, select, type, unpack
local find, lower = string.find, string.lower
--WoW API / Variables
local PanelTemplates_GetSelectedTab = PanelTemplates_GetSelectedTab
local hooksecurefunc = hooksecurefunc

-- NOZDOR talent window: MetalFrame2X chrome, one tree page drawn by
-- FrameXML/PlayerTalentTree.lua (unnamed atlas art), views for glyphs, runes and
-- the pet. PlayerTalentFrame_Refresh is its single update entry point, so all
-- re-applied looks hang off it.
-- Never noop methods of the window's own regions or write UIPanelLayout-*
-- attributes: the window reads both, and that would taint the glyph and spec
-- actions it runs afterwards.

local INSET_BORDER = {
	"InsetBorderTopLeft", "InsetBorderTopRight", "InsetBorderBottomLeft", "InsetBorderBottomRight",
	"InsetBorderTop", "InsetBorderBottom", "InsetBorderLeft", "InsetBorderRight",
}

local TAB_PARTS = { "Left", "Middle", "Right", "LeftDisabled", "MiddleDisabled", "RightDisabled" }

local MAX_SPEC_TABS = 10 -- PlayerSpecTab1..3 in XML, 4..10 created per extra spec

local function hide(region)
	if region and region.SetTexture then
		region:SetTexture(nil)
		region:SetAlpha(0)
	end
end

local function hideRegionsByPath(frame, pattern)
	if not frame then return end
	for i = 1, frame:GetNumRegions() do
		local region = select(i, frame:GetRegions())
		if region and region:IsObjectType("Texture") then
			local path = region:GetTexture()
			if type(path) == "string" and find(lower(path), pattern, 1, true) then
				hide(region)
			end
		end
	end
end

local function setBorderColor(frame, color)
	if frame and frame.backdrop then
		frame.backdrop:SetBackdropBorderColor(unpack(color or E.media.bordercolor))
	end
end

-- Flat dark fill reusing the inset's own Bgs region (already anchored right).
local function darkenInset(inset, alpha)
	if not inset then return end
	for _, key in ipairs(INSET_BORDER) do
		local region = inset[key]
		if region then region:SetAlpha(0) end
	end
	local bgs = inset.Bgs
	if bgs then
		bgs:SetHorizTile(false)
		bgs:SetVertTile(false)
		bgs:SetTexture("Interface\\Buttons\\WHITE8X8")
		bgs:SetVertexColor(0, 0, 0, alpha)
		bgs:SetAlpha(1)
	end
end

-- UIPanelButtonTemplate re-textures its slices on show/enable/disable.
local function skinPanelButton(button)
	if not button or button.__euiSkinned then return end
	S:HandleButton(button)
	button.__euiSkinned = true
	local name = button:GetName()
	local function hideSlices()
		for _, part in ipairs({ "Left", "Middle", "Right" }) do
			local region = (name and _G[name..part]) or button[part]
			if region then region:SetAlpha(0) end
		end
	end
	button:HookScript("OnShow", hideSlices)
	button:HookScript("OnEnable", hideSlices)
	button:HookScript("OnDisable", hideSlices)
	hideSlices()
end

local function skinSizeButton(button)
	if not button or button.__euiArrow then return end
	for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture" }) do
		local tex = button[getter](button)
		if tex then tex:SetAlpha(0) end
	end
	hide(button:GetHighlightTexture())
	local arrow = button:CreateTexture(nil, "OVERLAY")
	arrow:SetTexture(E.Media.Textures.ArrowUp)
	arrow:Size(12, 12)
	arrow:Point("CENTER")
	button.__euiArrow = arrow
	button:HookScript("OnEnter", function() arrow:SetVertexColor(unpack(E.media.rgbvaluecolor)) end)
	button:HookScript("OnLeave", function() arrow:SetVertexColor(1, 1, 1) end)
end

-- Tree controls (talent page and pet page share CreateControls).
local function skinTreeControls(tree)
	if not tree or tree.__euiSkinned then return end
	tree.__euiSkinned = true

	local apply = tree.applyButton
	if apply then
		skinPanelButton(apply)
		-- "Pending changes" pulse copied the retail hover art; make it an ElvUI glow.
		if apply.glow then
			for i = 1, apply.glow:GetNumRegions() do
				local region = select(i, apply.glow:GetRegions())
				if region and region:IsObjectType("Texture") then
					region:SetTexture(E.Media.Textures.Highlight)
					region:SetTexCoord(0, 1, 0, 1)
					region:SetVertexColor(E.media.rgbvaluecolor[1], E.media.rgbvaluecolor[2], E.media.rgbvaluecolor[3], 0.6)
					region:SetInside(apply)
				end
			end
		end
	end
	skinPanelButton(tree.editButton)

	local search = tree.searchBox
	if search then
		hide(search.Left)
		hide(search.Middle)
		hide(search.Right)
		S:HandleEditBox(search)
	end
end

-- Bottom tabs -------------------------------------------------------------------

local function skinBottomTabs()
	for i = 1, 5 do
		local tab = _G["PlayerTalentFrameTab"..i]
		if tab and not tab.__euiSkinned then
			tab.__euiSkinned = true
			local name = tab:GetName()
			-- The window toggles these with Show/Hide + SetAlpha(1); no texture, no art.
			for _, part in ipairs(TAB_PARTS) do
				local region = tab[part] or _G[name..part]
				if region then region:SetTexture(nil) end
			end
			hide(tab:GetHighlightTexture())
			tab:CreateBackdrop("Default")
			tab.backdrop:Point("TOPLEFT", tab, "TOPLEFT", 2, 0)
			tab.backdrop:Point("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -2, 2)
			tab:SetHitRectInsets(0, 0, 0, 0)
			tab:HookScript("OnEnter", S.SetModifiedBackdrop)
			tab:HookScript("OnLeave", function(self)
				local selected = PanelTemplates_GetSelectedTab(_G.PlayerTalentFrame) == self:GetID()
				setBorderColor(self, selected and E.media.rgbvaluecolor)
			end)
		end
	end
end

local function updateBottomTabs()
	local selected = PanelTemplates_GetSelectedTab(_G.PlayerTalentFrame)
	for i = 1, 5 do
		local tab = _G["PlayerTalentFrameTab"..i]
		if tab then setBorderColor(tab, i == selected and E.media.rgbvaluecolor) end
	end
end

-- Spec tabs on the right ----------------------------------------------------------

local ACTIVE_SPEC_COLOR = { 0.25, 1, 0.25 }

local function updateSpecTabBorder(tab)
	if tab.Selected and tab.Selected:IsShown() then
		setBorderColor(tab, E.media.rgbvaluecolor)
	elseif tab.activeGlow and tab.activeGlow:IsShown() then
		setBorderColor(tab, ACTIVE_SPEC_COLOR)
	else
		setBorderColor(tab)
	end
end

local function lockTexCoord(tex)
	if not tex or tex.__euiCoordLocked then return end
	tex.__euiCoordLocked = true
	tex:SetTexCoord(unpack(E.TexCoords))
	hooksecurefunc(tex, "SetTexCoord", function(self)
		if self.__euiCoordSetting then return end
		self.__euiCoordSetting = true
		self:SetTexCoord(unpack(E.TexCoords))
		self.__euiCoordSetting = nil
	end)
end

local function skinSpecTab(tab)
	if not tab then return end
	if not tab.__euiSkinned then
		tab.__euiSkinned = true
		-- Rotated SpellbookTabs2x frame/hover live on the tab, the selected
		-- mark and the active-spec glow on its overlay child.
		hideRegionsByPath(tab, "spellbooktabs2x")
		hide(tab.Selected)
		hide(tab.activeGlow)
		tab:CreateBackdrop("Default")
		tab.backdrop:SetAllPoints()
		tab:StyleButton(nil, true, true)
		for _, mark in ipairs({ tab.Selected, tab.activeGlow }) do
			hooksecurefunc(mark, "Show", function() updateSpecTabBorder(tab) end)
			hooksecurefunc(mark, "Hide", function() updateSpecTabBorder(tab) end)
		end
	end
	-- PlaceSideTabIcon re-anchors and re-crops the icon on every refresh.
	local icon = tab:GetNormalTexture()
	if icon then
		icon:ClearAllPoints()
		icon:SetInside(tab.backdrop)
		lockTexCoord(icon)
	end
	updateSpecTabBorder(tab)
end

-- Tree page ----------------------------------------------------------------------
-- PlayerTalentTree draws stones, class art, an ornate nine-slice and round
-- atlas nodes. The page becomes one flat panel; nodes become square icons
-- whose ElvUI border carries the node state (the rank text colour).

local function hideTextures(frame, layer)
	if not frame then return end
	for i = 1, frame:GetNumRegions() do
		local region = select(i, frame:GetRegions())
		if region and region:IsObjectType("Texture") and (not layer or region:GetDrawLayer() == layer) then
			region:SetAlpha(0)
		end
	end
end

local function squareIcon(icon, texture)
	if not icon then return end
	if texture then icon:SetTexture(texture) end
	icon:SetTexCoord(unpack(E.TexCoords))
	if not icon.backdrop then icon:CreateBackdrop("Default") end
end

local function skinSearchArrow(arrow)
	if not arrow or arrow.__euiArrow then return end
	hideTextures(arrow)
	local tex = arrow:CreateTexture(nil, "OVERLAY")
	tex:SetTexture(E.Media.Textures.ArrowUp)
	tex:SetRotation(S.ArrowRotation.down)
	tex:Size(12, 12)
	tex:Point("CENTER")
	arrow.__euiArrow = tex
	arrow:CreateBackdrop("Default")
	arrow.backdrop:SetAllPoints()
end

local function skinTreeArt(tree)
	if tree.__euiPage then return end
	tree.__euiPage = true

	if tree.background then tree.background:SetAlpha(0) end
	if tree.art then tree.art:SetAlpha(0) end
	local inner = tree.innerFrame
	if inner then
		-- Nine-slice, divider bars and verticals are the inner frame's own textures.
		hideTextures(inner)
		inner:CreateBackdrop("Transparent")
		inner.backdrop:SetAllPoints()
	end
	for _, header in ipairs(tree.headers or {}) do
		hideTextures(header, "OVERLAY")
	end
	for _, tab in ipairs(tree.branchTabs or {}) do
		hideTextures(tab, "BACKGROUND")
		hideTextures(tab, "OVERLAY")
		if tab.selected then tab.selected:SetAlpha(0) end
		tab:CreateBackdrop("Default")
		tab.backdrop:SetAllPoints()
	end
	hideTextures(tree.points)
	if tree.preview then
		tree.preview:SetTemplate("Transparent")
		for _, row in ipairs(tree.preview.rows or {}) do
			hideTextures(row, "OVERLAY")
			if row.icon then row.icon:CreateBackdrop("Default") end
		end
	end
	skinSearchArrow(tree.searchArrow)
end

local function skinTree(tree)
	if not tree or tree.frame ~= _G.PlayerTalentFrame then return end
	skinTreeArt(tree)

	local tabs = tree.layout and tree.layout.tabs
	for index, header in ipairs(tree.headers or {}) do
		local tabInfo = tabs and tabs[index]
		if tabInfo then
			local icon = _G.PlayerTalentTree.GetBranchIcon(index, tabInfo.icon, tree.classFile)
			squareIcon(header.icon, icon)
			local tab = tree.branchTabs and tree.branchTabs[index]
			if tab then
				squareIcon(tab.icon, icon)
				setBorderColor(tab, index == tree.branch and E.media.rgbvaluecolor)
			end
		end
	end

	for _, node in ipairs(tree.nodes) do
		if node.talent and node:IsShown() then
			node.shadow:SetAlpha(0)
			node.border:SetAlpha(0)
			squareIcon(node.icon, node.talent.icon)
			local r, g, b = node.rank:GetTextColor()
			if r == g and g == b then
				node.icon.backdrop:SetBackdropBorderColor(unpack(E.media.bordercolor))
			else
				node.icon.backdrop:SetBackdropBorderColor(r, g, b)
			end
		end
	end
end

-- Window -------------------------------------------------------------------------

local function refresh()
	local frame = _G.PlayerTalentFrame
	if not frame then return end

	-- Re-shown on leaving the rune view, re-textured on every refresh.
	if _G.PlayerTalentFrameBackground then _G.PlayerTalentFrameBackground:SetAlpha(0) end
	if _G.PlayerTalentFrameTopTileStreaks then _G.PlayerTalentFrameTopTileStreaks:SetAlpha(0) end
	if frame.specRingIcon then frame.specRingIcon:Hide() end

	local glyphs = _G.GlyphFrame and _G.GlyphFrame:IsShown()
	-- LeaveGlyphView restores the marble; EnterGlyphView re-atlases the list.
	darkenInset(frame.contentInset, 0.4)
	if glyphs then darkenInset(frame.contentInset2, 0.6) end
	if frame.glyphRockBase then
		for i = 1, frame.glyphRockBase:GetNumRegions() do
			local region = select(i, frame.glyphRockBase:GetRegions())
			if region and region.SetAlpha then region:SetAlpha(0) end
		end
	end

	updateBottomTabs()
	for i = 1, MAX_SPEC_TABS do
		skinSpecTab(_G["PlayerSpecTab"..i])
	end

	skinTree(frame.tree)
	skinTree(frame.petTree)
	skinTreeControls(frame.tree)
	skinTreeControls(frame.petTree)
	skinSizeButton(frame.sizeButton)
end

S:AddCallbackForAddon("Blizzard_TalentUI", "Skin_Blizzard_TalentUI", function()
	if not E.private.skins.blizzard.enable or not E.private.skins.blizzard.talent then return end

	local frame = _G.PlayerTalentFrame
	if not frame or not _G.PlayerTalentFrame_Refresh then return end

	frame:CreateBackdrop("Transparent")
	frame.backdrop:SetAllPoints()
	S:HandleMetalFrame(frame, frame.backdrop)

	-- The "+" buy-spec button keeps its art; only its SkillLineTab backing goes.
	hide(_G.PlayerBuySpecButtonBackground)

	skinBottomTabs()
	-- Anchor the tab row's top to the window's bottom so it hangs flush below.
	_G.PlayerTalentFrameTab1:ClearAllPoints()
	_G.PlayerTalentFrameTab1:Point("TOPLEFT", frame, "BOTTOMLEFT", 11, 2)

	if _G.SizeButton2X_SetExpand then
		hooksecurefunc("SizeButton2X_SetExpand", function(button, expand)
			if button and button.__euiArrow then
				button.__euiArrow:SetRotation(S.ArrowRotation[expand and "right" or "left"])
			end
		end)
	end

	hooksecurefunc("PlayerTalentFrame_Refresh", refresh)
	-- Tree redraws that don't go through Refresh (branch tabs, compact width).
	local Tree = _G.PlayerTalentTree
	for _, method in ipairs({ "Update", "UpdatePet", "SetCompact", "SelectBranch", "SetCompactWidth" }) do
		if Tree[method] then hooksecurefunc(Tree, method, skinTree) end
	end
	refresh()
end)
