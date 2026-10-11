local E, L, V, P, G = unpack(select(2, ...)) --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local S = E:GetModule("Skins")

--Lua functions
local _G = _G
local ipairs, pairs, select, type, unpack = ipairs, pairs, select, type, unpack
local find, lower = string.find, string.lower
--WoW API / Variables
local GetTradeSkillIcon = GetTradeSkillIcon
local hooksecurefunc = hooksecurefunc

-- NOZDOR profession window (FrameXML/Custom_TradeSkill): docked inside the
-- spellbook (which carries the ElvUI backdrop) or shown in its own compact
-- MetalFrame2X window. Layout belongs to the UI (TradeSkillFrame_SetCompact);
-- this only restyles. The minimal scrollbars are kept.

local INSET_BORDER = {
	"InsetBorderTopLeft", "InsetBorderTopRight", "InsetBorderBottomLeft", "InsetBorderBottomRight",
	"InsetBorderTop", "InsetBorderBottom", "InsetBorderLeft", "InsetBorderRight",
}

local MENU_BUTTON_PIECES = {
	"TopLeft", "TopRight", "BottomLeft", "BottomRight",
	"TopMiddle", "MiddleLeft", "MiddleRight", "BottomMiddle", "MiddleMiddle",
}

local function hide(region)
	if region and region.SetTexture then
		region:SetTexture(nil)
		region:SetAlpha(0)
	end
end

local function hideRegionsByPath(frame, pattern)
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

local function hideEditBoxArt(box)
	if not box then return end
	hide(box.Left)
	hide(box.Middle)
	hide(box.Right)
	S:HandleEditBox(box)
end

-- RedButton2X adds its own slices and tiles more middles on every resize.
local function hideRedButtonArt(button)
	local pieces = button.RedPieces
	if pieces then
		for _, piece in pairs(pieces) do piece:SetAlpha(0) end
	end
	if button.RedMiddle then
		for _, tile in ipairs(button.RedMiddle) do tile:SetAlpha(0) end
	end
end

local function skinRedButton(button)
	if not button or button.__euiSkinned then return end
	button.__euiSkinned = true
	S:HandleButton(button)
	hideRedButtonArt(button)
	button:HookScript("OnSizeChanged", hideRedButtonArt)
	button:HookScript("OnShow", hideRedButtonArt)
end

-- Square icon with a 1px ElvUI border drawn as a texture of the icon's own
-- frame: a backdrop child frame ended up above the reagent and result icons.
local function iconBorder(owner, icon)
	icon:SetTexCoord(unpack(E.TexCoords))
	if icon:GetDrawLayer() == "BACKGROUND" then icon:SetDrawLayer("BORDER") end
	local border = owner:CreateTexture(nil, "BACKGROUND")
	border:SetTexture(unpack(E.media.bordercolor))
	border:SetPoint("TOPLEFT", icon, "TOPLEFT", -E.mult, E.mult)
	border:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", E.mult, -E.mult)
end

-- Recipe group headers: retail plate pieces become a flat strip; the UI
-- tints them on hover with SetVertexColor, which a white texture keeps.
local function flattenHeaders()
	for i = 1, TRADE_SKILLS_DISPLAYED or 0 do
		local button = _G["TradeSkillSkill"..i]
		local pieces = button and button.HeaderPieces
		if pieces and not button.__euiHeader then
			button.__euiHeader = true
			for _, piece in ipairs(pieces) do
				piece:SetTexture("Interface\\Buttons\\WHITE8X8")
				piece:SetTexCoord(0, 1, 0, 1)
				piece:SetAlpha(0.12)
			end
		end
	end
end

local function updateResultIcon(id)
	local button = _G.TradeSkillSkillIcon
	local round = button and button.Round
	if not round then return end
	-- The UI draws the product round (SetPortraitToTexture); show it square.
	local texture = id and GetTradeSkillIcon(id)
	if texture then
		round:SetTexture(texture)
		round:SetTexCoord(unpack(E.TexCoords))
	end
end

S:AddCallback("Skin_TradeSkill", function()
	if not E.private.skins.blizzard.enable or not E.private.skins.blizzard.tradeskill then return end

	local frame = _G.TradeSkillFrame
	if not frame or not frame.DetailsInset or not _G.TradeSkillFrame_SetCompact then return end

	hide(frame.TrainerBg)
	if frame.ShadowFrame then
		for i = 1, frame.ShadowFrame:GetNumRegions() do
			local region = select(i, frame.ShadowFrame:GetRegions())
			if region and region.SetAlpha then region:SetAlpha(0) end
		end
	end

	local inset = frame.DetailsInset
	for _, key in ipairs(INSET_BORDER) do hide(inset[key]) end
	hide(inset.Bgs)
	-- Profession card art is re-set per profession (UpdateProfessionArt); alpha survives.
	if inset.Art then inset.Art:SetAlpha(0) end

	-- Docked, the window lies over the professions overview inside the book, so
	-- its base must be opaque. The backdrop goes on the frame itself and the
	-- panels are its own BACKGROUND textures: child backdrop frames sat above
	-- the rows and reagents (they are not children of these anchors) and dimmed them.
	frame:SetTemplate("Default")
	local function tint(...)
		local tex = frame:CreateTexture(nil, "BACKGROUND")
		tex:SetTexture(0, 0, 0, 0.35)
		for i = 1, select("#", ...), 5 do
			local point, relativeTo, relativePoint, x, y = select(i, ...)
			tex:SetPoint(point, relativeTo, relativePoint, x, y)
		end
	end
	tint("TOPLEFT", inset, "TOPLEFT", 0, 0, "BOTTOMRIGHT", inset, "BOTTOMRIGHT", 0, 0)
	local list = _G.TradeSkillListScrollFrame
	if list then
		tint("TOPLEFT", list, "TOPLEFT", -4, 4, "BOTTOMRIGHT", list, "BOTTOMRIGHT", 4, -4)
	end
	S:HandleProfessionBar(_G.TradeSkillRankFrameProfession)
	-- The ornate panel border is built on the window's first OnShow.
	frame:HookScript("OnShow", function()
		if inset.ornate then
			for _, piece in ipairs(inset.ornate) do hide(piece) end
		end
	end)

	-- Compact (standalone) window.
	local compact = _G.TradeSkillCompactFrame
	if compact and not compact.backdrop then
		compact:CreateBackdrop("Transparent")
		compact.backdrop:SetAllPoints()
		S:HandleMetalFrame(compact, compact.backdrop)
		if compact.PortraitFrame then compact.PortraitFrame:SetAlpha(0) end
	end
	local sizeButton = _G.TradeSkillFrameSizeButton
	if sizeButton then
		for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture" }) do
			local tex = sizeButton[getter](sizeButton)
			if tex then tex:SetAlpha(0) end
		end
		hide(sizeButton:GetHighlightTexture())
		local arrow = sizeButton:CreateTexture(nil, "OVERLAY")
		arrow:SetTexture(E.Media.Textures.ArrowUp)
		arrow:Size(12, 12)
		arrow:Point("CENTER")
		hooksecurefunc("TradeSkillFrame_SetCompact", function(isCompact)
			arrow:SetRotation(S.ArrowRotation[isCompact and "right" or "left"])
		end)
		arrow:SetRotation(S.ArrowRotation[frame.compact and "right" or "left"])
	end

	-- Header controls.
	local filter = frame.FilterButton
	if filter then
		for _, key in ipairs(MENU_BUTTON_PIECES) do hide(filter[key]) end
		S:HandleButton(filter)
	end
	hideEditBoxArt(frame.SearchBox)

	-- Bottom controls.
	skinRedButton(_G.TradeSkillCreateButton)
	skinRedButton(_G.TradeSkillCreateAllButton)
	hideEditBoxArt(_G.TradeSkillInputBox)
	S:HandleNextPrevButton(_G.TradeSkillInputBoxDecrementButton, "left", nil, true)
	S:HandleNextPrevButton(_G.TradeSkillInputBoxIncrementButton, "right", nil, true)

	local track = _G.TradeSkillTrackRecipeCheck
	if track then
		S:HandleCheckBox(track)
		if track.Text then track.Text:SetTextColor(1, 1, 1) end
	end

	-- Result icon: square in an ElvUI border, no ring.
	local result = _G.TradeSkillSkillIcon
	if result and result.Round then
		hide(result.Ring)
		hide(result.IconBorder)
		iconBorder(result, result.Round)
	end
	hooksecurefunc("TradeSkillFrame_SetSelection", updateResultIcon)
	hooksecurefunc("TradeSkillFrame_Update", flattenHeaders)

	-- Reagents: square icons; the profession frame around each is unnamed.
	for i = 1, MAX_TRADE_SKILL_REAGENTS or 8 do
		local reagent = _G["TradeSkillReagent"..i]
		if reagent and reagent.Icon then
			hideRegionsByPath(reagent, "professionoverview2xc60")
			iconBorder(reagent, reagent.Icon)
		end
	end
end)
