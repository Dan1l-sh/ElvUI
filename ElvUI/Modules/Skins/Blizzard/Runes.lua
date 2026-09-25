local E, L, V, P, G = unpack(select(2, ...)) --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local S = E:GetModule("Skins")

local _G = _G
local ipairs = ipairs
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

	if _G.PlayerTalentFrame_ShowRuneFrame then
		hooksecurefunc("PlayerTalentFrame_ShowRuneFrame", SkinRuneChrome)
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
