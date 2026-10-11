local E, L, V, P, G = unpack(select(2, ...)) --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local S = E:GetModule("Skins")

--Lua functions
local _G = _G
local ipairs, select, type, unpack = ipairs, select, type, unpack
local find, lower = string.find, string.lower
--WoW API / Variables
local GetSpellInfo = GetSpellInfo
local hooksecurefunc = hooksecurefunc

-- NOZDOR spellbook (FrameXML/Custom_SpellBook): MetalFrame2X chrome, retail page
-- art built in Lua, rotated side tabs, a professions overview and the rotation
-- panel. Most of the art is only toggled with SetShown/SetTexCoord at runtime,
-- so SetTexture(nil) once is enough; the exceptions are re-done in hooks below.
-- Many buttons here are secure: never move or resize them, only restyle.

local INSET_BORDER = {
	"InsetBorderTopLeft", "InsetBorderTopRight", "InsetBorderBottomLeft", "InsetBorderBottomRight",
	"InsetBorderTop", "InsetBorderBottom", "InsetBorderLeft", "InsetBorderRight",
}

local function hide(region)
	if region and region.SetTexture then
		region:SetTexture(nil)
		region:SetAlpha(0)
	end
end

-- Lua-created art has no names; find it by texture path.
local function hideRegionsByPath(frame, ...)
	if not frame then return end
	for i = 1, frame:GetNumRegions() do
		local region = select(i, frame:GetRegions())
		if region and region:IsObjectType("Texture") then
			local path = region:GetTexture()
			if type(path) == "string" then
				path = lower(path)
				for j = 1, select("#", ...) do
					if find(path, (select(j, ...)), 1, true) then
						hide(region)
						break
					end
				end
			end
		end
	end
end

local function flattenInset(inset)
	if not inset then return end
	for _, key in ipairs(INSET_BORDER) do
		hide(inset[key])
	end
	hide(inset.Bgs)
end

local function setBorderActive(frame, active)
	if not (frame and frame.backdrop) then return end
	if active then
		frame.backdrop:SetBackdropBorderColor(unpack(E.media.rgbvaluecolor))
	else
		frame.backdrop:SetBackdropBorderColor(unpack(E.media.bordercolor))
	end
end

-- The UI keeps re-cropping tab icons to its rotated frame (0.1..0.9); pin ours.
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

-- Rotated book/profession side tab: flat square with the icon inside and an
-- accent border while the tab's own .Selected mark is shown.
local function skinSideTab(tab)
	if not tab or tab.__euiSkinned then return end
	tab.__euiSkinned = true

	hide(tab.Frame)
	hide(tab.Highlight)
	hideRegionsByPath(tab, "spellbooktabs2x")

	tab:CreateBackdrop("Default")
	tab.backdrop:SetAllPoints()
	tab:StyleButton(nil, true, true)

	local icon = tab:GetNormalTexture()
	if icon then
		icon:ClearAllPoints()
		icon:SetInside(tab.backdrop)
		lockTexCoord(icon)
	end

	local selected = tab.Selected
	if selected then
		hide(selected)
		hooksecurefunc(selected, "Show", function() setBorderActive(tab, true) end)
		hooksecurefunc(selected, "Hide", function() setBorderActive(tab, false) end)
		setBorderActive(tab, selected:IsShown())
	end
end

local function skinCheckBox(check, small)
	if not check then return end
	S:HandleCheckBox(check, small)
	local text = check.Text or _G[(check:GetName() or "").."Text"]
	if text then text:SetTextColor(1, 1, 1) end
end

-- Spell buttons ---------------------------------------------------------------

local function skinSpellButton(button)
	local name = button:GetName()
	hide(_G[name.."Background"])
	hide(_G[name.."SlotFrame"])
	hide(_G[name.."NormalTexture"])
	hide(button.UnlearnedFrame)
	hide(button.PassiveFrame)
	hide(button.PassiveHighlight)
	hide(button.TrainFrame)
	hide(button.TrainTextBackground)
	hide(button.IconTextureBg)
	hide(button.TextBackground)

	button:CreateBackdrop("Default")
	button.backdrop:SetOutside(button)
	button:StyleButton()
end

-- Runs after every per-button update (also for empty slots).
local function updateSpellButton(button)
	if not button.backdrop then return end
	local name = button:GetName()
	local icon = _G[name.."IconTexture"]
	local hasSpell = button.data ~= nil

	if hasSpell then button.backdrop:Show() else button.backdrop:Hide() end
	if icon then
		-- Passives are drawn round (SetPortraitToTexture) and smaller; square them.
		if button.isPassive and hasSpell then
			local texture = select(3, GetSpellInfo(button.data))
			if texture then icon:SetTexture(texture) end
		end
		icon:ClearAllPoints()
		icon:SetAllPoints(button)
		icon:SetTexCoord(unpack(E.TexCoords))
	end

	if button.SpellName then
		if button.Disabled and not button.isTrain then
			button.SpellName:SetTextColor(0.6, 0.6, 0.6)
		else
			button.SpellName:SetTextColor(1, 0.82, 0)
		end
		button.SpellName:SetShadowOffset(1, -1)
	end
	if button.SpellSubName then button.SpellSubName:SetTextColor(0.75, 0.75, 0.75) end
	if button.RequiredLevelString then button.RequiredLevelString:SetTextColor(0.75, 0.75, 0.75) end
end

-- Book window ------------------------------------------------------------------

local function skinBottomTabs()
	for i = 1, 5 do
		local tab = _G["SpellBookFrameTabButton"..i]
		if tab and not tab.__euiSkinned then
			tab.__euiSkinned = true
			-- Geometry stays with the UI: secure click overlays are laid over
			-- the tabs from their current position.
			hide(tab.Body)
			hide(tab.CapLeft)
			hide(tab.CapRight)
			tab:CreateBackdrop("Default")
			tab.backdrop:Point("TOPLEFT", tab, "TOPLEFT", 0, 0)
			tab.backdrop:Point("BOTTOMRIGHT", tab, "BOTTOMRIGHT", 0, 6)
			tab:HookScript("OnEnter", S.SetModifiedBackdrop)
			tab:HookScript("OnLeave", function(self) setBorderActive(self, self:IsEnabled() ~= 1) end)
		end
	end
end

local function updateBottomTabs()
	for i = 1, 5 do
		local tab = _G["SpellBookFrameTabButton"..i]
		if tab then setBorderActive(tab, tab:IsEnabled() ~= 1) end
	end
end

local function updateSizeButton()
	local button = _G.SpellBookFrameSizeButton
	if not (button and button.__euiArrow) then return end
	local expanded = _G.SpellBookFrame:GetWidth() > 700
	button.__euiArrow:SetRotation(S.ArrowRotation[expanded and "left" or "right"])
end

local function skinSizeButton()
	local button = _G.SpellBookFrameSizeButton
	if not button or button.__euiArrow then return end
	-- Its state textures get new TexCoords on every layout; alpha survives that.
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
	updateSizeButton()
end

local function skinRotationButton()
	local button = _G.SpellBookRotationButton
	if not button or button.__euiSkinned then return end
	button.__euiSkinned = true
	hide(button.Shadow)
	hide(button.Frame)
	button:CreateBackdrop("Default")
	button.backdrop:SetOutside(button.Icon or button)
	if button.Icon then button.Icon:SetTexCoord(unpack(E.TexCoords)) end
end

-- Rotation panel is built on its first Toggle; InitPanel replaces its OnShow,
-- so we skin from a Toggle hook instead of OnShow.
local function skinRotationPanel()
	local panel = _G.NozdorRotationFrame
	if not panel or not panel.slots or panel.__euiSkinned then return end
	panel.__euiSkinned = true

	panel:CreateBackdrop("Transparent")
	panel.backdrop:SetAllPoints()
	S:HandleMetalFrame(panel, panel.backdrop)

	local content = panel.Content
	if content then
		flattenInset(content)
		hide(content.Page)
	end

	for _, row in ipairs(panel.slots) do
		for _, slot in ipairs(row) do
			hide(slot.Shadow)
			hide(slot.Frame)
			slot:CreateBackdrop("Default")
			slot.backdrop:SetOutside(slot.Icon or slot)
			if slot.Icon then slot.Icon:SetTexCoord(unpack(E.TexCoords)) end
		end
	end

	skinCheckBox(panel.HighlightCheck)
	skinCheckBox(panel.InstantCheck)
end

-- Professions overview ---------------------------------------------------------

local PROFESSION_FRAMES = {
	"PrimaryProfession1", "PrimaryProfession2", "PrimaryProfession3", "PrimaryProfession4",
	"SecondaryProfession1", "SecondaryProfession2", "SecondaryProfession3",
}

local function skinProfessionButton(button)
	if not button or button.__euiSkinned then return end
	button.__euiSkinned = true
	hide(button.IconFrame)
	button:CreateBackdrop("Default")
	button.backdrop:SetOutside(button)
	if button.iconTexture then button.iconTexture:SetTexCoord(unpack(E.TexCoords)) end
	local highlight = button.highlightTexture
	if highlight then
		highlight:SetTexture(1, 1, 1, 0.3)
		highlight:SetTexCoord(0, 1, 0, 1)
		highlight:ClearAllPoints()
		highlight:SetAllPoints(button)
	end
end

local function skinProfessions()
	local block = _G.SpellBookProfessionFrame
	if not block then return end

	hide(_G.SpellBookProfessionBackground)
	-- Edge shadows (NozdorAddEdgeShadow) are this block's OVERLAY regions.
	for i = 1, block:GetNumRegions() do
		local region = select(i, block:GetRegions())
		if region and region:IsObjectType("Texture") and region:GetDrawLayer() == "OVERLAY" then
			region:SetAlpha(0)
		end
	end

	-- Cards and the animated skill bars are profession art and stay as they are.
	for _, frameName in ipairs(PROFESSION_FRAMES) do
		local learn = _G[frameName] and _G[frameName].Learn
		if learn then
			skinProfessionButton(learn.button1)
			skinProfessionButton(learn.button2)
			if learn.unlearn and not learn.unlearn.__euiSkinned then
				learn.unlearn.__euiSkinned = true
				S:HandleCloseButton(learn.unlearn)
				learn.unlearn:SetHitRectInsets(0, 0, 0, 0)
			end
		end
	end

	skinSideTab(_G.SpellBookProfessionOverviewTab)
	for i = 1, 6 do
		skinSideTab(_G["SpellBookProfessionTab"..i])
	end

	skinCheckBox(_G.SpellBookShowAltReagentsCheck, true)
end

S:AddCallback("Skin_Spellbook", function()
	if not E.private.skins.blizzard.enable or not E.private.skins.blizzard.spellbook then return end

	local frame = _G.SpellBookFrame
	if not frame or not frame.MetalBorder then return end

	frame:CreateBackdrop("Transparent")
	frame.backdrop:SetAllPoints()
	S:HandleMetalFrame(frame, frame.backdrop)
	hide(_G.SpellBookFrameBg)
	if frame.PortraitIcon and frame.PortraitIcon:GetParent() then
		frame.PortraitIcon:GetParent():SetAlpha(0)
	end

	-- Retail pages and the professions fill are unnamed Lua textures.
	hideRegionsByPath(frame, "spellbookbackgroundpage", "professionoverviewbackground")
	if frame.Ribbon then frame.Ribbon:SetAlpha(0) end
	hide(_G.SpellBookPageHeaderDivider)
	if _G.SpellBookPageHeader then _G.SpellBookPageHeader:SetTextColor(1, 0.82, 0) end
	if _G.SpellBookPageText then _G.SpellBookPageText:SetTextColor(0.8, 0.8, 0.8) end

	skinSizeButton()
	skinBottomTabs()

	S:HandleNextPrevButton(_G.SpellBookPrevPageButton, nil, nil, true)
	S:HandleNextPrevButton(_G.SpellBookNextPageButton, nil, nil, true)
	skinCheckBox(_G.ShowAllSpellRanksCheckBox)

	local search = _G.SpellBookSearchBox
	if search then
		hide(search.Left)
		hide(search.Middle)
		hide(search.Right)
		S:HandleEditBox(search)
	end

	for i = 1, 8 do
		skinSideTab(_G["SpellBookSkillLineTab"..i])
	end

	for i = 1, 24 do
		local button = _G["SpellButton"..i]
		if button then
			skinSpellButton(button)
			updateSpellButton(button)
		end
	end
	hooksecurefunc("SpellButton_UpdateFrame", updateSpellButton)

	skinProfessions()
	skinRotationButton()

	hooksecurefunc("SpellBookFrame_Update", function()
		updateBottomTabs()
		updateSizeButton()
		skinRotationButton()
	end)
	frame:HookScript("OnSizeChanged", updateSizeButton)

	local rotation = _G.NozdorRotation
	if rotation and rotation.Toggle then
		hooksecurefunc(rotation, "Toggle", skinRotationPanel)
	end
end)
