local E, L, V, P, G = unpack(select(2, ...)) --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local S = E:GetModule("Skins")

local _G = _G
local ipairs, select, type, unpack = ipairs, select, type, unpack
local hooksecurefunc = hooksecurefunc

-- Runes tab (hosted inside PlayerTalentFrame). The server builds the round rune
-- circle natively at a forced 512x424 (UlduarSecretsFrame in PlayerTalentFrameRuneHost).
-- We must NOT re-implement or resize any of it — only flatten the host CHROME to the
-- ElvUI look. Keeping the 512-wide (round) size is handled in Talent.lua.

-- Blank every Texture region a frame owns (leaves child frames/fontstrings alone).
local function blankTextureRegions(frame)
	if not frame or not frame.GetRegions then return end
	for _, r in ipairs({ frame:GetRegions() }) do
		if r.GetObjectType and r:GetObjectType() == "Texture" then
			r:SetAlpha(0)
		end
	end
end

S:AddCallbackForAddon("Blizzard_TalentUI", "Skin_Blizzard_Runes", function()
	if not E.private.skins.blizzard.enable or not E.private.skins.blizzard.talent then return end

	-- Flatten only the host chrome; never touch UlduarSecretsFrame (the circle).
	local function SkinRuneChrome()
		local ptf = _G.PlayerTalentFrame
		if not ptf then return end

		if S.HandleMetalFrame then
			S:HandleMetalFrame(ptf, ptf.backdrop)
		end

		local host = ptf.RuneHost
		if host then
			-- Blank all of RuneHost's own regions; the circle is a child frame so it stays.
			blankTextureRegions(host)
			-- RuneHost's own template close button is a child frame (region hide misses it).
			if host.CloseButton then host.CloseButton:Hide() end
		end
	end

	-- Tab clicks reach the rune view through the window's local SelectView,
	-- not the PlayerTalentFrame_ShowRuneFrame global; Refresh is the shared path.
	if _G.PlayerTalentFrame_Refresh then
		hooksecurefunc("PlayerTalentFrame_Refresh", SkinRuneChrome)
	end

	-- Rune selection popup (UlduarRuneSelectionPanel). Rune list rows are server content,
	-- left as-is; buttons re-texture themselves on state/show, so re-apply on every show.
	local function ReapplyRunePopup(panel)
		panel = panel or _G.UlduarRuneSelectionPanel
		if not panel then return end

		if panel.Bg then panel.Bg:SetAlpha(0) end
		if panel.topLeftCorner then panel.topLeftCorner:Hide() end
		blankTextureRegions(panel)

		if _G.UlduarRuneActivateButton then S:HandleButton(_G.UlduarRuneActivateButton) end
		if _G.UlduarRuneRemoveAllButton then S:HandleButton(_G.UlduarRuneRemoveAllButton) end
	end

	local function SkinRunePopup(panel)
		panel = panel or _G.UlduarRuneSelectionPanel
		if not panel then return end

		if not panel.__euiSkinned then
			panel.__euiSkinned = true

			panel:CreateBackdrop("Transparent")
			panel.backdrop:Point("TOPLEFT", 2, -2)
			panel.backdrop:Point("BOTTOMRIGHT", -2, 2)

			if S.HandleMetalFrame then S:HandleMetalFrame(panel, panel.backdrop) end

			if panel.Inset then
				panel.Inset:StripTextures()
				if not panel.Inset.backdrop then
					panel.Inset:CreateBackdrop("Transparent")
				end
			end

			if _G.UlduarRuneScrollFrameScrollBar then
				S:HandleScrollBar(_G.UlduarRuneScrollFrameScrollBar)
			end

			panel:HookScript("OnShow", function(self) ReapplyRunePopup(self) end)
		end

		ReapplyRunePopup(panel)
	end

	-- PopulateRuneList runs on every panel open (side menu is dynamic per rune click),
	-- so it's the reliable place to (re)skin; it passes the panel as first arg.
	if _G.PopulateRuneList then
		hooksecurefunc("PopulateRuneList", function(panel)
			SkinRunePopup(panel)
		end)
	end
end)

-- NOZDOR rune window (FrameXML/Custom_Runes/RuneWindow_UI.lua), embedded into the
-- talent window's rune view. Built lazily on the first RuneUI.Embed; slots, tier
-- headers and catalog rows are pooled and re-dressed on every RuneUI.Refresh.
-- Nothing in it is secure.

local function hideTextures(frame, layer)
	if not frame then return end
	for i = 1, frame:GetNumRegions() do
		local region = select(i, frame:GetRegions())
		if region and region:IsObjectType("Texture") and (not layer or region:GetDrawLayer() == layer) then
			region:SetAlpha(0)
		end
	end
end

local function hexColor(hex)
	if type(hex) ~= "string" or #hex < 6 then return end
	hex = hex:sub(-6)
	return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end

local function setQualityBorder(frame, quality, dim)
	if not (frame and frame.backdrop) then return end
	local r, g, b = hexColor(quality and _G.RuneUI.GetQualityColor(quality))
	if r and not dim then
		frame.backdrop:SetBackdropBorderColor(r, g, b)
	else
		frame.backdrop:SetBackdropBorderColor(unpack(E.media.bordercolor))
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

-- SettingsWidgets filter button: an unstored three-slice re-atlased on every
-- state change; alpha survives that.
local function skinFilterButton(button)
	if not button or button.__euiSkinned then return end
	button.__euiSkinned = true
	hideTextures(button, "BACKGROUND")
	button:CreateBackdrop("Default")
	button.backdrop:SetAllPoints()
	button:HookScript("OnEnter", S.SetModifiedBackdrop)
	button:HookScript("OnLeave", S.SetOriginalBackdrop)
end

local function skinGlow(button)
	local glow = button and button.Glow
	if not glow then return end
	for i = 1, glow:GetNumRegions() do
		local region = select(i, glow:GetRegions())
		if region and region:IsObjectType("Texture") then
			region:SetTexture(E.Media.Textures.Highlight)
			region:SetTexCoord(0, 1, 0, 1)
			region:SetVertexColor(E.media.rgbvaluecolor[1], E.media.rgbvaluecolor[2], E.media.rgbvaluecolor[3], 0.6)
			region:SetInside(button)
		end
	end
end

local function skinPanel(panel)
	if not panel or panel.backdrop then return end
	-- Fill, dim layer and the ornate/scroll-corner frame are all unnamed textures.
	hideTextures(panel)
	panel:CreateBackdrop("Transparent")
	panel.backdrop:SetAllPoints()
end

local function skinSlot(button)
	if not button.__euiSkinned then
		button.__euiSkinned = true
		-- Bg and Ring only get Show/Hide and vertex colour later.
		button.Bg:SetTexture(nil)
		button.Ring:SetTexture(nil)
		button.Icon:SetTexCoord(unpack(E.TexCoords))
		button:CreateBackdrop("Default")
		button.backdrop:SetOutside(button.Icon)
		if button.Hl then
			button.Hl:SetTexture(1, 1, 1, 0.3)
			button.Hl:SetAllPoints(button.Icon)
		end
	end
	-- SetQualityFrame re-atlases this on every refresh.
	button.Quality:SetAlpha(0)
	setQualityBorder(button, button.def and button.def.quality, button.locked)
end

local function skinRow(row)
	if not row.__euiSkinned then
		row.__euiSkinned = true
		row.Stripe:SetTexture(nil)
		if row.Hover then
			row.Hover:SetTexture(1, 1, 1, 0.1)
			row.Hover:SetTexCoord(0, 1, 0, 1)
		end
		row.Icon:SetTexCoord(unpack(E.TexCoords))
		row.Icon:CreateBackdrop("Default")
		skinPanelButton(row.Buy)
	end
	row.IconBorder:SetAlpha(0)
	local locked = row.Icon:GetAlpha() < 1
	setQualityBorder(row.Icon, row.def and row.def.quality, locked)
end

local function skinPools()
	local content = _G.RuneWindowContent
	if not content then return end

	local left = content.Left
	if left and left.Scroll and left.Scroll.Child then
		for _, child in ipairs({ left.Scroll.Child:GetChildren() }) do
			if child.Line then
				child.Line:SetTexture(nil)
			elseif child.Icon and child.Quality then
				skinSlot(child)
			end
		end
	end

	local right = content.Right
	if right and right.Scroll and right.Scroll.Child then
		for _, row in ipairs({ right.Scroll.Child:GetChildren() }) do
			if row.IconBorder and row.Stripe then skinRow(row) end
		end
	end
end

local function skinWindow()
	local content = _G.RuneWindowContent
	if not content or content.__euiSkinned then return end
	content.__euiSkinned = true

	if content.WindowBg then content.WindowBg:SetAlpha(0) end
	skinPanel(content.Left)
	skinPanel(content.Right)

	local top = content.TopBar
	if top then
		skinFilterButton(top.SetButton)
		local plate = top.CurrencyPlate
		if plate then
			hideTextures(plate)
			plate:CreateBackdrop("Default")
			plate.backdrop:SetAllPoints()
		end
	end

	local bottom = content.Bottom
	if bottom then
		skinPanelButton(bottom.Apply)
		skinGlow(bottom.Apply)
	end

	local right = content.Right
	if right then
		skinFilterButton(right.Filter)
		local search = right.Search
		if search then
			for _, key in ipairs({ "Left", "Middle", "Right" }) do
				if search[key] then search[key]:SetAlpha(0) end
			end
			S:HandleEditBox(search)
		end
		skinPanelButton(right.SlotRemove)
		skinPanelButton(right.SlotRandom)
		if right.SlotClose then S:HandleCloseButton(right.SlotClose) end
	end
end

S:AddCallback("Skin_Nozdor_RuneWindow", function()
	if not E.private.skins.blizzard.enable or not E.private.skins.blizzard.talent then return end
	local RuneUI = _G.RuneUI
	if not RuneUI or not RuneUI.Embed or not RuneUI.Refresh then return end

	hooksecurefunc(RuneUI, "Embed", function()
		skinWindow()
		skinPools()
	end)
	hooksecurefunc(RuneUI, "Refresh", skinPools)
end)
