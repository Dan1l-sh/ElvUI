local E, L, V, P, G = unpack(select(2, ...)) --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local S = E:GetModule("Skins")

--Lua functions
local _G = _G
local unpack = unpack
local type = type
local ipairs = ipairs

-- Dropdown arrow (same fix as the finder): the server re-applies its arrow texture on
-- hover and HandleDropDownBox early-returns on an existing backdrop, so freeze the
-- button's own textures and draw our own ElvUI arrow the server can't touch.
local function skinDropArrow(btn)
	if not btn or btn.__euiArrow then return end
	btn.__euiArrow = true
	for _, g in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }) do
		local t = btn[g] and btn[g](btn)
		if t then
			t:SetTexture(nil); t:SetAlpha(0)
			t.SetTexture = E.noop; t.SetAlpha = E.noop; t.Show = E.noop
		end
	end
	btn.SetNormalTexture = E.noop
	btn.SetPushedTexture = E.noop
	btn.SetHighlightTexture = E.noop
	btn.SetDisabledTexture = E.noop
	local a = btn:CreateTexture(nil, "OVERLAY")
	a:SetTexture(E.Media.Textures.ArrowUp)
	a:SetRotation(S.ArrowRotation and S.ArrowRotation.down or 3.14)
	a:SetSize(12, 12)
	a:SetPoint("CENTER", btn, "CENTER", 0, 0)
	a:SetVertexColor(1, 1, 1)
end

S:AddCallbackForAddon("Blizzard_GlyphUI", "Skin_Blizzard_GlyphUI", function()
	if not E.private.skins.blizzard.enable or not E.private.skins.blizzard.talent then return end

	if not PlayerTalentFrame then
		TalentFrame_LoadUI()
	end

	-- Do NOT StripTextures the GlyphFrame: its only regions are the server-owned
	-- parchment (GlyphFrameBackground) and socket glow, both kept. The ElvUI backdrop
	-- below is faded out while the glyph tab is open, so it never covers the parchment.

	if not GlyphFrame.backdrop then
		GlyphFrame:CreateBackdrop("Transparent")
	end
	GlyphFrame.backdrop:ClearAllPoints()
	GlyphFrame.backdrop:Point("TOPLEFT", 11, -12)
	GlyphFrame.backdrop:Point("BOTTOMRIGHT", -32, 76)
	S:SetBackdropHitRect(GlyphFrame)

	-- Metal-frame cleanup on the shared PlayerTalentFrame, plus blank the glyph view's
	-- own full-window rock base (PlayerTalentFrame.glyphRockBase) so the flat ElvUI
	-- backdrop shows instead of the rock tile bleeding through.
	local function HideGlyphRock()
		local base = _G.PlayerTalentFrame and _G.PlayerTalentFrame.glyphRockBase
		if base then
			if base.GetRegions then
				local j = 1
				while true do
					local r = select(j, base:GetRegions())
					if not r then break end
					if r.SetAlpha then r:SetAlpha(0) end
					j = j + 1
				end
			end
			base:Hide()
		end
	end

	local function CleanTalentChrome()
		if S.HandleMetalFrame and _G.PlayerTalentFrame then
			S:HandleMetalFrame(_G.PlayerTalentFrame, _G.PlayerTalentFrame.backdrop)
		end
		if _G.PlayerTalentFrameBackground then _G.PlayerTalentFrameBackground:SetAlpha(0) end
		if _G.PlayerTalentFrameTopTileStreaks then _G.PlayerTalentFrameTopTileStreaks:SetAlpha(0) end
		HideGlyphRock()
	end
	CleanTalentChrome()
	GlyphFrame:HookScript("OnShow", CleanTalentChrome)

	-- Parchment + glyph rings are server-owned now (the old ElvUI code re-parented the
	-- parchment and re-laid the rings, which is what made it look zoomed/scattered) —
	-- leave the layout alone. Only make the parchment semi-transparent so the dark
	-- backdrop reads through, and keep the glow over it as one panel. Server re-anchors
	-- both on update, so re-apply here.
	local GLYPH_BG_ALPHA = 0.6
	local function StyleGlyphParchment()
		local bg = _G.GlyphFrameBackground
		if bg then bg:SetAlpha(GLYPH_BG_ALPHA) end
		local glow = _G.GlyphFrameGlow
		if glow and bg then
			glow:ClearAllPoints()
			glow:SetAllPoints(bg)
			glow:SetDrawLayer("BORDER", 0) -- just above the BACKGROUND parchment
			glow:SetAlpha(GLYPH_BG_ALPHA)
		end
	end
	StyleGlyphParchment()
	GlyphFrame:HookScript("OnShow", StyleGlyphParchment)

	hooksecurefunc("GlyphFrame_Update", function()
		if GlyphFrame and GlyphFrame:IsShown() then
			HideGlyphRock()
			StyleGlyphParchment()
		end
	end)

	-- Right-hand glyph finder panel (server custom on PlayerTalentFrame.contentInset2).
	-- Rows are left alone. Everything is created lazily, so skin after GlyphSidebar_Populate.
	local function BlankTextures(frame)
		if not frame or not frame.GetRegions then return end
		local i = 1
		while true do
			local r = select(i, frame:GetRegions())
			if not r then break end
			if r.GetObjectType and r:GetObjectType() == "Texture" then
				r:SetTexture(nil)
				r:SetAlpha(0)
			end
			i = i + 1
		end
	end

	-- InsetFrameTemplate marble border pieces (parentKeys) — hide to drop the stock frame.
	local INSET_BORDER = {
		"InsetBorderTopLeft", "InsetBorderTopRight",
		"InsetBorderBottomLeft", "InsetBorderBottomRight",
		"InsetBorderTop", "InsetBorderBottom", "InsetBorderLeft", "InsetBorderRight",
	}
	local function HideInsetBorder(inset)
		if not inset then return end
		for _, key in ipairs(INSET_BORDER) do
			local r = inset[key]
			if r then r:SetAlpha(0); if r.Hide then r:Hide() end end
		end
	end

	local function SkinGlyphSidebar()
		local pt = _G.PlayerTalentFrame
		local ci2 = pt and pt.contentInset2
		if not ci2 then return end

		-- contentInset2 is itself an InsetFrameTemplate: blank its bg + border, then backdrop.
		if ci2.Bgs then ci2.Bgs:SetTexture(nil); ci2.Bgs:SetAlpha(0) end
		HideInsetBorder(ci2)
		if not ci2.__euiBackdrop then
			ci2.__euiBackdrop = true
			ci2:CreateBackdrop("Transparent")
		end

		-- Search box + availability dropdown.
		local sb = _G.GlyphFrameSearchBox
		if sb and not sb.__euiSkinned then
			sb.__euiSkinned = true
			S:HandleEditBox(sb)
		end
		local dd = _G.GlyphFrameAvailDropDown
		if dd then
			if not dd.__euiSkinned then
				dd.__euiSkinned = true
				S:HandleDropDownBox(dd)
			end
			-- Extend the arrow button's hit rect left across the box width so the whole
			-- box opens the menu (keyed off contentInset2 width, set on each populate).
			local ddButton = _G.GlyphFrameAvailDropDownButton
			local w = ci2:GetWidth()
			if ddButton and w and w > 1 then
				ddButton:SetHitRectInsets(-(w - 35), 0, 0, 0)
			end
			-- Replace the server's flashing arrow with a frozen ElvUI down-arrow.
			skinDropArrow(ddButton)
		end

		-- Scrollbar: the server drew rail art onto the list's inset border; blank that
		-- border's textures and give the scrollbar the ElvUI look.
		local scroll = _G.GlyphFrameListScroll
		if scroll and not scroll.__euiSkinned then
			scroll.__euiSkinned = true
			local border = scroll:GetParent()
			HideInsetBorder(border)
			BlankTextures(border)
			if border and not border.__euiBackdrop then
				border.__euiBackdrop = true
				border:CreateBackdrop("Transparent")
			end
			local sbar = _G.GlyphFrameListScrollScrollBar
			if sbar then S:HandleScrollBar(sbar) end
		end

		-- Category header buttons: strip the server plate (textures only, keep the
		-- label/sign FontStrings) and give them a flat ElvUI backdrop.
		local list = ci2._glyphList
		if list and list.headers then
			for _, h in ipairs(list.headers) do
				if h and not h.__euiSkinned then
					h.__euiSkinned = true
					BlankTextures(h)
					h:CreateBackdrop("Transparent")
					-- Backdrop draws above the header's OVERLAY FontStrings; re-parent the
					-- label + collapse sign onto the backdrop so they sit above the plate.
					if h.text then h.text:SetParent(h.backdrop) end
					if h.sign then h.sign:SetParent(h.backdrop) end
				end
			end
		end
	end
	if _G.GlyphSidebar_Populate then
		hooksecurefunc("GlyphSidebar_Populate", SkinGlyphSidebar)
	end
	GlyphFrame:HookScript("OnShow", SkinGlyphSidebar)

	local function FadeBackdropBG(bd, alpha)
	if not bd then return end
	if not bd.__savedGlyphBG then
		bd.__savedGlyphBG = { bd:GetBackdropColor() }
	end

	local r, g, b = bd.__savedGlyphBG[1], bd.__savedGlyphBG[2], bd.__savedGlyphBG[3]
		bd:SetBackdropColor(r, g, b, alpha)
	end

	local function RestoreBackdropBG(bd)
		if not bd or not bd.__savedGlyphBG then return end
		bd:SetBackdropColor(unpack(bd.__savedGlyphBG))
		bd.__savedGlyphBG = nil
	end

	local function FadeBackdropBorder(bd, alpha)
	if not bd then return end
	if not bd.__savedGlyphBorder then
		bd.__savedGlyphBorder = { bd:GetBackdropBorderColor() }
	end

	local r, g, b = bd.__savedGlyphBorder[1], bd.__savedGlyphBorder[2], bd.__savedGlyphBorder[3]
		bd:SetBackdropBorderColor(r, g, b, alpha)
	end

	local function RestoreBackdropBorder(bd)
		if not bd or not bd.__savedGlyphBorder then return end
		bd:SetBackdropBorderColor(unpack(bd.__savedGlyphBorder))
		bd.__savedGlyphBorder = nil
	end

	-- Keep the original ElvUI behavior hiding Talent UI bits while glyph tab is open
	GlyphFrame:HookScript("OnShow", function()
		PlayerTalentFrameTitleText:Hide()
		PlayerTalentFramePointsBar:Hide()
		PlayerTalentFrameScrollFrame:Hide()
		PlayerTalentFrameStatusFrame:Hide()
		PlayerTalentFrameActivateButton:Hide()

		if PlayerTalentFrame.ElvUI_UpdateTalentOffset then
			PlayerTalentFrame.ElvUI_UpdateTalentOffset(nil, nil, true)
		end
		FadeBackdropBG(GlyphFrame.backdrop, 0)
		FadeBackdropBorder(GlyphFrame.backdrop, 0)
		-- FadeBackdropBG(PlayerTalentFrame.backdrop, 0)
	end)

	GlyphFrame:SetScript("OnHide", function()
		PlayerTalentFrameTitleText:Show()
		PlayerTalentFramePointsBar:Show()
		PlayerTalentFrameScrollFrame:Show()

		if PlayerTalentFrame.ElvUI_UpdateTalentOffset then
			PlayerTalentFrame.ElvUI_UpdateTalentOffset(nil, nil, true)
		end
		RestoreBackdropBG(GlyphFrame.backdrop)
		RestoreBackdropBorder(GlyphFrame.backdrop)
		-- RestoreBackdropBG(PlayerTalentFrame.backdrop)
	end)

	hooksecurefunc(PlayerTalentFrame, "updateFunction", function()
		if GlyphFrame:IsShown() then
			PlayerTalentFramePreviewBar:Hide()
		end
	end)
end)
