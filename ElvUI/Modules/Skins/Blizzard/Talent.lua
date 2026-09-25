local E, L, V, P, G = unpack(select(2, ...)) --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local S = E:GetModule("Skins")

--Lua functions
local _G = _G
local unpack = unpack
--WoW API / Variables

S:AddCallbackForAddon("Blizzard_TalentUI", "Skin_Blizzard_TalentUI", function()
	if not E.private.skins.blizzard.enable or not E.private.skins.blizzard.talent then return end

	PlayerTalentFrame:StripTextures(true)
	PlayerTalentFrame:CreateBackdrop("Transparent")
	PlayerTalentFrame.backdrop:Point("TOPLEFT", 2, -2)
	PlayerTalentFrame.backdrop:Point("BOTTOMRIGHT", -2, 2)

	S:SetBackdropHitRect(PlayerTalentFrame)

	-- Base metal-frame adaptation: hide the server's rock background + top shadow so the
	-- flat ElvUI backdrop shows.
	if S.HandleMetalFrame then S:HandleMetalFrame(PlayerTalentFrame, PlayerTalentFrame.backdrop) end
	if _G.PlayerTalentFrameBackground then _G.PlayerTalentFrameBackground:SetAlpha(0) end
	if _G.PlayerTalentFrameTopTileStreaks then _G.PlayerTalentFrameTopTileStreaks:SetAlpha(0) end
	-- Do NOT backdrop this inset: the glyph parchment/rune circle sit on frames BELOW it.
	-- Noop the setters after blanking — HideGlyphFrame re-shows the marble on tab switch
	-- with no OnShow, so a one-shot blank would come back.
	local function CleanTalentInset(inset)
		if not inset then return end
		if inset.GetRegions then
			local j = 1
			while true do
				local r = select(j, inset:GetRegions())
				if not r then break end
				if r.GetObjectType and r:GetObjectType() == "Texture" then
					r:SetTexture(nil)
					r:SetAlpha(0)
					r.SetTexture = E.noop
					r.SetAlpha = E.noop
					r.Show = E.noop
				end
				j = j + 1
			end
		end
		if inset.backdrop then inset.backdrop:Hide() end
	end
	local talentInset = _G.PlayerTalentFrameContentInset
	if talentInset then
		CleanTalentInset(talentInset)
		if not talentInset.__euiInsetHooked then
			talentInset.__euiInsetHooked = true
			talentInset:HookScript("OnShow", CleanTalentInset)
		end
	end


do
		local TALENT_CHARFRAME_OFFSET = 211

		-- numTalentGroups, numPetTalentGroups
		-- force = true
		local function UpdateTalentFrameOffset(numTalentGroups, numPetTalentGroups, force)
			-- Rune view is pinned to 512 wide for the round circle; the dual-spec width
			-- offset would stretch it to an oval, so never add it while RuneHost is shown.
			local runeHost = PlayerTalentFrame.RuneHost
			if runeHost and runeHost:IsShown() then
				if force or PlayerTalentFrame.ElvUI_OffsetActive then
					S:SetUIPanelWindowInfo(PlayerTalentFrame, "width")
					PlayerTalentFrame.ElvUI_OffsetActive = false
				end
				return
			end

			if not numTalentGroups or not numPetTalentGroups then
				numTalentGroups = GetNumTalentGroups(false, false)
				numPetTalentGroups = GetNumTalentGroups(false, true)
			end

			local needOffset = (numTalentGroups + numPetTalentGroups) > 1

			if needOffset then
				if force or not PlayerTalentFrame.ElvUI_OffsetActive then
					S:SetUIPanelWindowInfo(PlayerTalentFrame, "width", nil, TALENT_CHARFRAME_OFFSET)
					PlayerTalentFrame.ElvUI_OffsetActive = true
				end
			else
				if force or PlayerTalentFrame.ElvUI_OffsetActive then
					S:SetUIPanelWindowInfo(PlayerTalentFrame, "width")
					PlayerTalentFrame.ElvUI_OffsetActive = false
				end
			end
		end

		PlayerTalentFrame.ElvUI_UpdateTalentOffset = UpdateTalentFrameOffset

		if not PlayerTalentFrame.ElvUI_TalentOffsetHooked then
			PlayerTalentFrame.ElvUI_TalentOffsetHooked = true

			hooksecurefunc("PlayerTalentFrame_UpdateSpecs", function(_, numTalentGroups, _, numPetTalentGroups)
				UpdateTalentFrameOffset(numTalentGroups, numPetTalentGroups)
			end)

			-- Re-run the offset on enter/leave rune view so the window snaps to 512-wide and back.
			if _G.PlayerTalentFrame_ShowRuneFrame then
				hooksecurefunc("PlayerTalentFrame_ShowRuneFrame", function()
					UpdateTalentFrameOffset(nil, nil, true)
				end)
			end
			if _G.PlayerTalentFrame_HideRuneFrame then
				hooksecurefunc("PlayerTalentFrame_HideRuneFrame", function()
					UpdateTalentFrameOffset(nil, nil, true)
				end)
			end
		end

		UpdateTalentFrameOffset(nil, nil, true)
	end

	S:HandleCloseButton(PlayerTalentFrameCloseButton, PlayerTalentFrame.backdrop)

	local function glyphFrameOnShow(self)
		if GlyphFrame and GlyphFrame:IsShown() then
			self:Hide()
		end
	end

	PlayerTalentFrameStatusFrame:HookScript("OnShow", glyphFrameOnShow)
	PlayerTalentFrameActivateButton:HookScript("OnShow", glyphFrameOnShow)

	PlayerTalentFrameStatusFrame:StripTextures()
	PlayerTalentFramePointsBar:StripTextures()
	PlayerTalentFramePreviewBar:StripTextures()

	S:HandleButton(PlayerTalentFrameActivateButton)
	S:HandleButton(PlayerTalentFrameResetButton)
	S:HandleButton(PlayerTalentFrameLearnButton)

	if PlayerTalentFramePointsBarResetButton then
		S:HandleButton(PlayerTalentFramePointsBarResetButton)
	end

	-- Grid-view control bar has its own Learn/Reset buttons (PlayerTalentFrameControlBar*).
	-- UIPanelButtonTemplate re-SetTextures its Left/Middle/Right on every OnShow/Enable/
	-- Disable and the Learn button toggles state, undoing a one-shot HandleButton — so
	-- re-blank the edges after any state change.
	local function SkinControlButton(btn)
		if not btn then return end
		S:HandleButton(btn)
		local name = btn:GetName()
		local function hideEdges()
			for _, sfx in ipairs({ "Left", "Middle", "Right" }) do
				local r = (name and _G[name..sfx]) or btn[sfx]
				if r and r.SetAlpha then r:SetAlpha(0) end
			end
		end
		btn:HookScript("OnShow", hideEdges)
		btn:HookScript("OnEnable", hideEdges)
		btn:HookScript("OnDisable", hideEdges)
		hideEdges()
	end
	SkinControlButton(PlayerTalentFrameControlBarLearnButton)
	SkinControlButton(PlayerTalentFrameControlBarResetButton)

	-- Talent trees are three grid columns, each an InsetFrameTemplate. Flatten each to a
	-- dark panel by REUSING the inset's own Bgs region as the dark fill (already anchored
	-- to the column) — avoids the frame-level/visibility pitfalls of a separate backdrop.
	local GRID_BG_SUFFIX = {
		"Background", "BackgroundTopLeft", "BackgroundTopRight",
		"BackgroundBottomLeft", "BackgroundBottomRight",
	}
	local GRID_INSET_BORDER = {
		"InsetBorderTopLeft", "InsetBorderTopRight",
		"InsetBorderBottomLeft", "InsetBorderBottomRight",
		"InsetBorderTop", "InsetBorderBottom", "InsetBorderLeft", "InsetBorderRight",
	}
	local function SkinGridColumns()
		for c = 1, 3 do
			local inset = _G["PlayerTalentFrameGridColumn"..c.."Inset"]
			if inset then
				for _, key in ipairs(GRID_INSET_BORDER) do
					local r = inset[key]
					if r then r:SetAlpha(0); if r.Hide then r:Hide() end end
				end
				if inset.Bgs then
					inset.Bgs:Show()
					inset.Bgs:SetHorizTile(false)
					inset.Bgs:SetVertTile(false)
					inset.Bgs:SetTexture("Interface\\Buttons\\WHITE8X8")
					inset.Bgs:SetVertexColor(0, 0, 0, 0.6)
				elseif not inset.__euiBackdrop then
					inset.__euiBackdrop = true
					inset:CreateBackdrop("Transparent")
					inset.backdrop:SetBackdropColor(0, 0, 0, 0.6)
				end
			end
			for _, sfx in ipairs(GRID_BG_SUFFIX) do
				local bg = _G["PlayerTalentFrameGridColumn"..c..sfx]
				if bg then bg:SetTexture(nil); bg:SetAlpha(0) end
			end
		end
	end
	if _G.TalentFrame_ApplyColumnInsets then
		hooksecurefunc("TalentFrame_ApplyColumnInsets", function(tf)
			if tf == PlayerTalentFrame then SkinGridColumns() end
		end)
	end
	SkinGridColumns()

	-- Rune-view chrome and the rune selection popup are skinned in Runes.lua.

	--PlayerTalentFramePreviewBarFiller:StripTextures()

	PlayerTalentFrameScrollFrame:StripTextures()
	PlayerTalentFrameScrollFrame:CreateBackdrop("Default")
	S:HandleScrollBar(PlayerTalentFrameScrollFrameScrollBar)

	for i = 1, MAX_NUM_TALENTS do
		local talent = _G["PlayerTalentFrameTalent"..i]
		local icon = _G["PlayerTalentFrameTalent"..i.."IconTexture"]
		local rank = _G["PlayerTalentFrameTalent"..i.."Rank"]

		if talent then
			talent:StripTextures()
			talent:SetTemplate("Default")
			talent:StyleButton()

			icon:SetInside()
			icon:SetTexCoord(unpack(E.TexCoords))
			icon:SetDrawLayer("ARTWORK")

			rank:SetFont(E.LSM:Fetch("font", E.db.general.font), 12, "OUTLINE")
		end
	end

	for i = 1, 5 do
		local tab = _G["PlayerTalentFrameTab"..i]
		S:HandleTab(tab)
		if tab and tab.backdrop then
			tab.backdrop:Point("TOPLEFT", tab, "TOPLEFT", 2, 0)
			tab.backdrop:Point("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -2, 2)
			tab:SetHitRectInsets(0, 0, 0, 0)
		end
	end

	-- Side spec tabs: drop the SpellBook-SkillLineTab backing (a 64x64 texture that
	-- sticks out behind the 32x32 button) and keep only the spec picture itself.
	for i = 1, MAX_TALENT_TABS do
		local tab = _G["PlayerSpecTab"..i]
		if tab then
			local bg = _G["PlayerSpecTab"..i.."Background"]
			if bg then bg:SetTexture(nil); bg:SetAlpha(0) end
			local nt = tab:GetNormalTexture()
			if nt then
				nt:SetTexCoord(unpack(E.TexCoords))
				nt:ClearAllPoints()
				nt:SetAllPoints(tab)
			end
		end
	end

	-- "Buy second spec" side button: same SkillLineTab backing; keep only its icon.
	if _G.PlayerBuySpecButton then
		if _G.PlayerBuySpecButtonBackground then
			_G.PlayerBuySpecButtonBackground:SetTexture(nil)
			_G.PlayerBuySpecButtonBackground:SetAlpha(0)
		end
		if _G.PlayerBuySpecButtonIcon then
			_G.PlayerBuySpecButtonIcon:SetTexCoord(unpack(E.TexCoords))
		end
	end

	PlayerTalentFrameStatusFrame:Point("TOPLEFT", 57, -40)
	PlayerTalentFrameActivateButton:Point("TOP", 0, -40)

	PlayerTalentFrameScrollFrame:Width(302)
	PlayerTalentFrameScrollFrame:Point("TOPRIGHT", PlayerTalentFrame, "TOPRIGHT", -62, -77)
	PlayerTalentFrameScrollFrame:SetPoint("BOTTOM", PlayerTalentFramePointsBar, "TOP", 0, 0)

	PlayerTalentFrameScrollFrameScrollBar:Point("TOPLEFT", PlayerTalentFrameScrollFrame, "TOPRIGHT", 4, -18)
	PlayerTalentFrameScrollFrameScrollBar:Point("BOTTOMLEFT", PlayerTalentFrameScrollFrame, "BOTTOMRIGHT", 4, 18)

	PlayerTalentFrameResetButton:Point("RIGHT", -4, 1)
	PlayerTalentFrameLearnButton:Point("RIGHT", PlayerTalentFrameResetButton, "LEFT", -3, 0)

	-- The old -33 x offset was tuned to the stock frame border and pulled the spec tabs
	-- INTO the new metal window; anchor them just past the right edge instead.
	PlayerSpecTab1:Point("TOPLEFT", PlayerTalentFrame, "TOPRIGHT", -2, -45)
	PlayerSpecTab1.ClearAllPoints = E.noop
	PlayerSpecTab1.SetPoint = E.noop

	-- Anchor the bottom tab row's TOP to the window's BOTTOM so it hangs flush below the
	-- frame (the old y=46 dragged the row up into the content).
	PlayerTalentFrameTab1:ClearAllPoints()
	PlayerTalentFrameTab1:Point("TOPLEFT", PlayerTalentFrame, "BOTTOMLEFT", 11, 2)
end)