local E, L, V, P, G = unpack(select(2, ...)) -- Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local S = E:GetModule("Skins")

--Lua functions
local _G = _G
local unpack = unpack
local ipairs = ipairs
local type = type
local hooksecurefunc = hooksecurefunc
--WoW API / Variables
local GetInventoryItemID = GetInventoryItemID
local GetItemInfo = GetItemInfo
local GetItemQualityColor = GetItemQualityColor

-- base helpers: remove insets + backgrounds, as the player windows do.

-- InsetFrameTemplate marble border pieces (parentKeys).
local INSET_BORDER = {
	"InsetBorderTopLeft", "InsetBorderTopRight",
	"InsetBorderBottomLeft", "InsetBorderBottomRight",
	"InsetBorderTop", "InsetBorderBottom", "InsetBorderLeft", "InsetBorderRight",
}
local GRID_BG_SUFFIX = {
	"Background", "BackgroundTopLeft", "BackgroundTopRight",
	"BackgroundBottomLeft", "BackgroundBottomRight",
}

local function hide(obj)
	if obj and obj.SetAlpha then obj:SetAlpha(0) end
end

-- Turn a texture region into a flat dark fill (reuse an existing bg texture).
local function darkenTex(tex, alpha)
	if not tex then return end
	tex:Show()
	if tex.SetHorizTile then tex:SetHorizTile(false) end
	if tex.SetVertTile then tex:SetVertTile(false) end
	tex:SetTexture("Interface\\Buttons\\WHITE8X8")
	tex:SetVertexColor(0, 0, 0, alpha or 0.6)
end

-- Flatten an InsetFrameTemplate: hide its marble Bgs + the 8 border pieces.
local function flattenInset(inset)
	if not inset then return end
	for _, key in ipairs(INSET_BORDER) do
		local r = inset[key]
		if r then r:SetAlpha(0); if r.Hide then r:Hide() end end
	end
	if inset.Bgs then inset.Bgs:SetAlpha(0) end
end

-- Reuse an inset's own (marble) Bgs region as a flat dark fill. Only safe when the
-- inset sits BELOW the content (as the talent content inset does under the grid).
local function darkenInset(inset)
	if not inset then return end
	for _, key in ipairs(INSET_BORDER) do
		local r = inset[key]
		if r then r:SetAlpha(0); if r.Hide then r:Hide() end end
	end
	if inset.Bgs then
		inset.Bgs:Show()
		inset.Bgs:SetHorizTile(false)
		inset.Bgs:SetVertTile(false)
		inset.Bgs:SetTexture("Interface\\Buttons\\WHITE8X8")
		inset.Bgs:SetVertexColor(0, 0, 0, 0.6)
	end
end

-- Blank every Texture region a frame owns (leaves child frames / fontstrings alone).
local function blankTextureRegions(frame)
	if not frame or not frame.GetRegions then return end
	for _, r in ipairs({ frame:GetRegions() }) do
		if r.GetObjectType and r:GetObjectType() == "Texture" then r:SetAlpha(0) end
	end
end

-- Hide rock/marble bg textures by texture path (keeps the rest, e.g. the parchment) —
-- for frames whose bg is an unnamed runtime texture.
local function hideRockRegions(frame)
	if not frame or not frame.GetRegions then return end
	for _, r in ipairs({ frame:GetRegions() }) do
		if r.GetObjectType and r:GetObjectType() == "Texture" and r.GetTexture then
			local t = r:GetTexture()
			if type(t) == "string" then
				local lt = t:lower()
				if lt:find("ui%-background%-rock") or lt:find("_ui%-frame") then
					r:SetAlpha(0)
				end
			end
		end
	end
end

S:AddCallbackForAddon("Blizzard_InspectUI", "Skin_Blizzard_InspectUI", function()
	if not E.private.skins.blizzard.enable or not E.private.skins.blizzard.inspect then return end

	-- main window frame (once)
	InspectFrame:StripTextures(true)
	InspectFrame:CreateBackdrop("Transparent")
	InspectFrame.backdrop:Point("TOPLEFT", 2, -2)
	InspectFrame.backdrop:Point("BOTTOMRIGHT", -2, 2)

	S:SetUIPanelWindowInfo(InspectFrame, "width")
	S:SetBackdropHitRect(InspectFrame)

	-- The server re-textures the ring on show/unit-change, so re-flatten on that.
	local function FlattenChrome()
		if S.HandleMetalFrame then S:HandleMetalFrame(InspectFrame, InspectFrame.backdrop) end
		-- HandleMetalFrame hides ringPortrait/specRingIcon, but the stock portrait texture
		-- and the 3D portrait model still show — hide them too.
		hide(_G.InspectFramePortrait)
		if _G.InspectFramePortraitModel then _G.InspectFramePortraitModel:Hide() end
		if _G.InspectFramePortraitModelModel then _G.InspectFramePortraitModelModel:Hide() end
		if InspectFrame.portrait then hide(InspectFrame.portrait) end
		if InspectFrame.ringPortrait then InspectFrame.ringPortrait:Hide() end
	end
	FlattenChrome()
	if _G.InspectFrame_UpdateRingPortrait then
		hooksecurefunc("InspectFrame_UpdateRingPortrait", FlattenChrome)
	end

	-- 5 NozdorFinder tabs.
	for i = 1, 5 do
		local tab = _G["InspectFrameTab"..i]
		if tab then
			S:HandleTab(tab)
			if tab.backdrop then
				-- Pull the backdrop 1px down out of the window (tabs overlapped it).
				tab.backdrop:Point("TOPLEFT", tab, "TOPLEFT", 2, -1)
				tab.backdrop:Point("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -2, 2)
				tab:SetHitRectInsets(0, 0, 0, 0)
			end
		end
	end

	-- per-tab background/inset removal. IMPORTANT: set up BEFORE the one-time
	-- paperdoll/rotate/PVP styling, since that styling can throw on the server's
	-- redesigned widgets and a throw would abort the whole callback (why the inspect
	-- window previously "never changed"). Applied on every tab switch/show.
	local function SkinPaperDoll()
		hide(_G.InspectPaperDollRockBg)
		hide(_G.InspectPaperDollHeaderRock)
		hide(_G.InspectPaperDollTopTileStreaks)
		hide(_G.InspectBottomDivider)
		flattenInset(_G.InspectPaperDollInset)
		-- Model scene quadrants + overlay — hide so the model sits on the flat backdrop.
		hide(_G.InspectModelFrameBgTopLeft)
		hide(_G.InspectModelFrameBgTopRight)
		hide(_G.InspectModelFrameBgBotLeft)
		hide(_G.InspectModelFrameBgBotRight)
		hide(_G.InspectModelFrameBgOverlay)
		-- Model frame border (Char-Paperdoll-Horizontal/Vertical edges).
		for _, sfx in ipairs({ "Top", "Bottom", "Left", "Right", "TopLeft", "TopRight", "BottomLeft", "BottomRight" }) do
			hide(_G["InspectModelBorder"..sfx])
		end
	end

	local function SkinPVP()
		if _G.InspectPVPFrame then
			hide(InspectPVPFrame.RockBg)
			hide(InspectPVPFrame.TopTileStreaks)
		end
		local inset = _G.InspectPVPInset
		if inset then
			for _, key in ipairs(INSET_BORDER) do
				local r = inset[key]
				if r then r:SetAlpha(0); if r.Hide then r:Hide() end end
			end
			-- This inset's fill is pvp-conquest art on parentKey .Bg (not .Bgs); hide the
			-- marble Bgs behind it, then reuse .Bg as a strong dark fill.
			hide(inset.Bgs)
			darkenTex(inset.Bg or inset.Bgs, 0.75)
		end
	end

	-- Talents: dark panel per column (reuse each column inset's Bgs as the dark fill).
	-- Grid buttons draw above the inset, so this doesn't cover the icons.
	local function SkinTalentGrid()
		for c = 1, 3 do
			local col = _G["InspectTalentFrameGridColumn"..c]
			local inset = _G["InspectTalentFrameGridColumn"..c.."Inset"]
			if inset then
				darkenInset(inset)
				-- Inset is created after the talent buttons, so its dark fill draws over
				-- them; push it below the column content so the icons sit above.
				if col then
					inset:SetFrameLevel(math.max((col:GetFrameLevel() or 1) - 1, 0))
				end
			end
			for _, sfx in ipairs(GRID_BG_SUFFIX) do
				hide(_G["InspectTalentFrameGridColumn"..c..sfx])
			end
		end
	end
	local function SkinTalents()
		local frame = _G.InspectTalentFrame
		if not frame then return end
		hideRockRegions(frame)
		-- Content inset sits under the whole grid — just flatten it (columns provide the dark).
		flattenInset(frame.contentInset or _G.InspectTalentFrameContentInset)
		SkinTalentGrid()
	end

	local function SkinGlyphs()
		local frame = _G.InspectGlyphFrame
		if not frame then return end
		hideRockRegions(frame)
		flattenInset(frame.contentInset or _G.InspectGlyphFrameContentInset)
		if _G.InspectGlyphFrameBackground then _G.InspectGlyphFrameBackground:SetAlpha(0.6) end
	end

	local function SkinRunes()
		local host = _G.InspectRuneFrameHost
		if not host then return end
		blankTextureRegions(host)
		if host.CloseButton then host.CloseButton:Hide() end
	end

	local function SkinCurrentTab()
		SkinPaperDoll()
		SkinPVP()
		SkinTalents()
		SkinGlyphs()
		SkinRunes()
		FlattenChrome()
	end
	SkinCurrentTab()

	if _G.TalentFrame_ApplyColumnInsets then
		hooksecurefunc("TalentFrame_ApplyColumnInsets", function(tf)
			if tf == _G.InspectTalentFrame then SkinTalentGrid() end
		end)
	end
	if _G.InspectSwitchTabs then
		hooksecurefunc("InspectSwitchTabs", SkinCurrentTab)
	end
	if _G.InspectFrame_OnShow then
		hooksecurefunc("InspectFrame_OnShow", SkinCurrentTab)
	end

	-- paperdoll gear (once)
	InspectPaperDollFrame:StripTextures()

	local slots = {
		"HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot", "ChestSlot",
		"ShirtSlot", "TabardSlot", "WristSlot", "HandsSlot", "WaistSlot",
		"LegsSlot", "FeetSlot", "Finger0Slot", "Finger1Slot", "Trinket0Slot",
		"Trinket1Slot", "MainHandSlot", "SecondaryHandSlot", "RangedSlot",
	}
	for _, slot in ipairs(slots) do
		local icon = _G["Inspect"..slot.."IconTexture"]
		local frame = _G["Inspect"..slot]
		if frame then
			frame:StripTextures()
			frame:SetFrameLevel(frame:GetFrameLevel() + 2)
			frame:CreateBackdrop("Default")
			frame.backdrop:SetAllPoints()
			frame:StyleButton()
			if icon then
				icon:SetTexCoord(unpack(E.TexCoords))
				icon:SetInside()
			end
		end
	end

	local styleButton
	do
		local function awaitCache(button)
			if InspectFrame.unit then styleButton(button) end
		end
		styleButton = function(button)
			if button.hasItem then
				local itemID = GetInventoryItemID(InspectFrame.unit, button:GetID())
				if itemID then
					local _, _, quality = GetItemInfo(itemID)
					if not quality then
						E:Delay(0.1, awaitCache, button)
						return
					elseif quality then
						button.backdrop:SetBackdropBorderColor(GetItemQualityColor(quality))
						return
					end
				end
			end
			button.backdrop:SetBackdropBorderColor(unpack(E.media.bordercolor))
		end
	end
	hooksecurefunc("InspectPaperDollItemSlotButton_Update", styleButton)

	-- Rotate arrows: the server's custom arrows have no NormalTexture, so HandleRotateButton
	-- throws; use HandleButton instead (same fix as the character pet-model arrows).
	if _G.InspectModelRotateLeftButton then S:HandleButton(InspectModelRotateLeftButton) end
	if _G.InspectModelRotateRightButton then S:HandleButton(InspectModelRotateRightButton) end

	-- PVP (once)
	if _G.InspectPVPFrame then InspectPVPFrame:StripTextures() end
	for i = 1, (MAX_ARENA_TEAMS or 0) do
		local frame = _G["InspectPVPTeam"..i]
		if frame then
			frame:StripTextures()
			frame:CreateBackdrop("Transparent")
			frame.backdrop:Point("TOPLEFT", 9, -6)
			frame.backdrop:Point("BOTTOMRIGHT", -24, -5)
			S:SetBackdropHitRect(frame)
		end
	end

	-- Average item level is drawn by the server's own redesigned inspect window
	-- (ItemLevelMixIn); an ElvUI copy here duplicated the number, so it's not added.
end)
