local E, L, V, P, G = unpack(select(2, ...)) --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local S = E:GetModule("Skins")

--Lua functions
local _G = _G
local unpack = unpack
--WoW API / Variables
local GetItemInfo = GetItemInfo
local GetItemQualityColor = GetItemQualityColor
local GetLFGDungeonRewardLink = GetLFGDungeonRewardLink
local GetLFGDungeonRewards = GetLFGDungeonRewards
local hooksecurefunc = hooksecurefunc

S:AddCallback("Skin_LFD", function()
	if not E.private.skins.blizzard.enable or not E.private.skins.blizzard.lfd then return end

	LFDQueueFrame:StripTextures(true)
	LFDQueueFrame:CreateBackdrop("Transparent")
	LFDQueueFrame.backdrop:Point("TOPLEFT", 11, -12)
	LFDQueueFrame.backdrop:Point("BOTTOMRIGHT", -3, 4)

	S:HookScript(LFDParentFrame, "OnShow", function(self)
		S:SetUIPanelWindowInfo(self, "width", 341)
		S:SetBackdropHitRect(self, LFDQueueFrame.backdrop)
		S:Unhook(self, "OnShow")
	end)

	S:HandleCloseButton((LFDParentFrame:GetChildren()), LFDQueueFrame.backdrop)

	LFDParentFramePortrait:Kill()

	S:HandleCheckBox(LFDQueueFrameRoleButtonTank.checkButton)
	LFDQueueFrameRoleButtonTank.checkButton:SetFrameLevel(LFDQueueFrameRoleButtonTank.checkButton:GetFrameLevel() + 2)
	S:HandleCheckBox(LFDQueueFrameRoleButtonHealer.checkButton)
	LFDQueueFrameRoleButtonHealer.checkButton:SetFrameLevel(LFDQueueFrameRoleButtonHealer.checkButton:GetFrameLevel() + 2)
	S:HandleCheckBox(LFDQueueFrameRoleButtonDPS.checkButton)
	LFDQueueFrameRoleButtonDPS.checkButton:SetFrameLevel(LFDQueueFrameRoleButtonDPS.checkButton:GetFrameLevel() + 2)
	S:HandleCheckBox(LFDQueueFrameRoleButtonLeader.checkButton)
	LFDQueueFrameRoleButtonLeader.checkButton:SetFrameLevel(LFDQueueFrameRoleButtonLeader.checkButton:GetFrameLevel() + 2)

	S:HandleDropDownBox(LFDQueueFrameTypeDropDown)
	LFDQueueFrameTypeDropDown:HookScript("OnShow", function(self) self:Width(200) end)

	for i = 1, NUM_LFD_CHOICE_BUTTONS do
		local button = _G["LFDQueueFrameSpecificListButton"..i]
		button.enableButton:StripTextures()
		button.enableButton:CreateBackdrop("Default")
		button.enableButton.backdrop:SetInside(nil, 4, 4)

		S:HandleCollapseExpandButton(button.expandOrCollapseButton, "+")
	end

	LFDQueueFrameSpecificListScrollFrame:StripTextures()
	S:HandleScrollBar(LFDQueueFrameRandomScrollFrameScrollBar)
	S:HandleScrollBar(LFDQueueFrameSpecificListScrollFrameScrollBar)

	S:HandleButton(LFDQueueFrameFindGroupButton)
	S:HandleButton(LFDQueueFrameCancelButton)

	S:HandleButton(LFDQueueFramePartyBackfillBackfillButton)
	S:HandleButton(LFDQueueFramePartyBackfillNoBackfillButton)

	S:HandleButton(LFDQueueFrameNoLFDWhileLFRLeaveQueueButton)

	LFDQueueFrameRandomScrollFrameScrollBar:Point("TOPLEFT", LFDQueueFrameRandomScrollFrame, "TOPRIGHT", 5, -22)
	LFDQueueFrameRandomScrollFrameScrollBar:Point("BOTTOMLEFT", LFDQueueFrameRandomScrollFrame, "BOTTOMRIGHT", 5, 19)

	LFDQueueFrameSpecificListScrollFrameScrollBar:Point("TOPLEFT", LFDQueueFrameSpecificListScrollFrame, "TOPRIGHT", 5, -17)
	LFDQueueFrameSpecificListScrollFrameScrollBar:Point("BOTTOMLEFT", LFDQueueFrameSpecificListScrollFrame, "BOTTOMRIGHT", 5, 17)

	LFDQueueFrameFindGroupButton:Point("BOTTOMLEFT", 19, 12)
	LFDQueueFrameCancelButton:Point("BOTTOMRIGHT", -11, 12)

	LFDQueueFrameTypeDropDown:Point("TOPLEFT", 152, -119)

	LFDQueueFrameSpecificListButton1:Point("TOPLEFT", 25, -154)
	LFDQueueFrameRandomScrollFrame:Point("BOTTOMRIGHT", -34, 41)

	LFDQueueFrameCooldownFrame:Size(325, 259)
	LFDQueueFrameCooldownFrame:Point("BOTTOMRIGHT", LFDQueueFrame, "BOTTOMRIGHT", -11, 37)

	LFDQueueFrameCooldownFrame:HookScript("OnShow", function(self)
		self:SetFrameLevel(self:GetParent():GetFrameLevel() + 5)
	end)

	local function skinLFDRandomDungeonLoot(frame)
		if frame.isSkinned then return end

		local icon = _G[frame:GetName().."IconTexture"]
		local nameFrame = _G[frame:GetName().."NameFrame"]
		local count = _G[frame:GetName().."Count"]

		frame:StripTextures()
		frame:CreateBackdrop("Transparent")
		frame.backdrop:SetOutside(icon)

		icon:SetTexCoord(unpack(E.TexCoords))
		icon:SetDrawLayer("BORDER")
		icon:SetParent(frame.backdrop)

		nameFrame:SetSize(118, 39)

		count:SetParent(frame.backdrop)

		frame.isSkinned = true
	end

	local function getLFGDungeonRewardLinkFix(dungeonID, rewardIndex)
		local _, link = GetLFGDungeonRewardLink(dungeonID, rewardIndex)

		if not link then
			E.ScanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
			E.ScanTooltip:SetLFGDungeonReward(dungeonID, rewardIndex)
			_, link = E.ScanTooltip:GetItem()
			E.ScanTooltip:Hide()
		end

		return link
	end

	hooksecurefunc("LFDQueueFrameRandom_UpdateFrame", function()
		local dungeonID = LFDQueueFrame.type
		if not dungeonID then return end

		local _, _, _, _, _, numRewards = GetLFGDungeonRewards(dungeonID)
		for i = 1, numRewards do
			local frame = _G["LFDQueueFrameRandomScrollFrameChildFrameItem"..i]
			local name = _G["LFDQueueFrameRandomScrollFrameChildFrameItem"..i.."Name"]

			skinLFDRandomDungeonLoot(frame)

			local link = getLFGDungeonRewardLinkFix(dungeonID, i)
			if link then
				local _, _, quality = GetItemInfo(link)
				if quality then
					local r, g, b = GetItemQualityColor(quality)
					frame.backdrop:SetBackdropBorderColor(r, g, b)
					name:SetTextColor(r, g, b)
				end
			else
				frame.backdrop:SetBackdropBorderColor(unpack(E.media.bordercolor))
				name:SetTextColor(1, 1, 1)
			end
		end
	end)

	-- LFDDungeonReadyStatus
	LFDDungeonReadyStatus:SetTemplate("Transparent")
	S:HandleCloseButton(LFDDungeonReadyStatusCloseButton, nil, "-")

	LFDSearchStatus:SetTemplate("Transparent")

	-- LFDRoleCheckPopup
	LFDRoleCheckPopup:SetTemplate("Transparent")

	S:HandleCheckBox(LFDRoleCheckPopupRoleButtonTank.checkButton)
	S:HandleCheckBox(LFDRoleCheckPopupRoleButtonHealer.checkButton)
	S:HandleCheckBox(LFDRoleCheckPopupRoleButtonDPS.checkButton)

	S:HandleButton(LFDRoleCheckPopupAcceptButton)
	S:HandleButton(LFDRoleCheckPopupDeclineButton)

	-- LFDDungeonReadyDialog
	LFDDungeonReadyDialog:SetTemplate("Transparent")

	LFDDungeonReadyDialog.label:Size(280, 0)
	LFDDungeonReadyDialog.label:Point("TOP", 0, -10)

	LFDDungeonReadyDialog:CreateBackdrop("Default")
	LFDDungeonReadyDialog.backdrop:Point("TOPLEFT", 10, -35)
	LFDDungeonReadyDialog.backdrop:Point("BOTTOMRIGHT", -10, 40)

	LFDDungeonReadyDialog.backdrop:SetFrameLevel(LFDDungeonReadyDialog:GetFrameLevel())
	LFDDungeonReadyDialog.background:SetInside(LFDDungeonReadyDialog.backdrop)

	LFDDungeonReadyDialogFiligree:SetTexture("")
	LFDDungeonReadyDialogBottomArt:SetTexture("")

	S:HandleCloseButton(LFDDungeonReadyDialogCloseButton, nil, "-")

	LFDDungeonReadyDialogEnterDungeonButton:Point("BOTTOMRIGHT", LFDDungeonReadyDialog, "BOTTOM", -7, 10)
	S:HandleButton(LFDDungeonReadyDialogEnterDungeonButton)
	LFDDungeonReadyDialogLeaveQueueButton:Point("BOTTOMLEFT", LFDDungeonReadyDialog, "BOTTOM", 7, 10)
	S:HandleButton(LFDDungeonReadyDialogLeaveQueueButton)

--[[
	LFDDungeonReadyDialogRoleIcon:Size(57)
	LFDDungeonReadyDialogRoleIcon:Point("BOTTOM", 1, 54)
	LFDDungeonReadyDialogRoleIcon:SetTemplate("Default")
	LFDDungeonReadyDialogRoleIconTexture:SetInside()

	function GetTexCoordsForRole(role)
		if role == "GUIDE" then
			return 0.0625, 0.1953125, 0.05859375, 0.19140625
		elseif role == "TANK" then
			return 0.0625, 0.1953125, 0.3203125, 0.453125
		elseif role == "HEALER" ) then
			return 0.32421875, 0.45703125, 0.0546875, 0.1875
		elseif role == "DAMAGER" then
			return 0.32421875, 0.453125, 0.31640625, 0.4453125
		end
	end
	GameTooltip:SetLFGDungeonReward(287, 1)
--]]

	local function skinLFDDungeonReadyDialogReward(button)
		if button.isSkinned then return end

		button:Size(28)
		button:SetTemplate("Default")
		button.texture:SetInside()
		button.texture:SetTexCoord(unpack(E.TexCoords))
		button:DisableDrawLayer("OVERLAY")

		button.isSkinned = true
	end

	hooksecurefunc("LFDDungeonReadyDialogReward_SetMisc", function(button)
		skinLFDDungeonReadyDialogReward(button)

		SetPortraitToTexture(button.texture, "")
		button.texture:SetTexture("Interface\\Icons\\inv_misc_coin_02")
	end)

	hooksecurefunc("LFDDungeonReadyDialogReward_SetReward", function(button, dungeonID, rewardIndex)
		skinLFDDungeonReadyDialogReward(button)

		local link = getLFGDungeonRewardLinkFix(dungeonID, rewardIndex)
		if link then
			local _, _, quality = GetItemInfo(link)
			button:SetBackdropBorderColor(GetItemQualityColor(quality))
		else
			button:SetBackdropBorderColor(unpack(E.media.bordercolor))
		end

		local texturePath = button.texture:GetTexture()
		if texturePath then
			SetPortraitToTexture(button.texture, "")
			button.texture:SetTexture(texturePath)
		end
	end)
end)
-- NOZDOR "Finder" redesign (LFDParentFrame inherits MetalFrame2X; the HK_LFDShell
-- re-decorates on every view switch). Its own callback so a crash in the stock LFD
-- skin above can't block it. Rather than name every HK_ inset one by one, RECURSIVELY
-- sweep the finder subtree: flatten InsetFrameTemplates and blank known decorative
-- background textures. Re-run on every view switch + show.
do
	local _G = _G
	local ipairs = ipairs
	local type = type
	local hooksecurefunc = hooksecurefunc

	local INSET_BORDER = {
		"InsetBorderTopLeft", "InsetBorderTopRight",
		"InsetBorderBottomLeft", "InsetBorderBottomRight",
		"InsetBorderTop", "InsetBorderBottom", "InsetBorderLeft", "InsetBorderRight",
	}

	-- Decorative background art paths in the finder tree, kept broad on purpose. NB:
	-- "pvpqueue" is intentionally absent — in the finder that atlas is content (currency
	-- rings, season-record arrow, arena-points bar, prestige ring), not chrome, so
	-- blanking it erased art we want kept.
	local BG_PATTERNS = {
		"ui%-background%-rock", "ui%-background%-marble", "bluemenu",
		"ui%-lfg%-background", "ui%-lfg%-bluebg", "ui%-frame",
		"pvp%-conquest", "questpaper", "dressupbackground", "uigroupfinderflipbook",
		"char%-paperdoll", "char%-inner", "%-goldborder", "common%-dropdown",
	}
	-- NB: "itemupgrade" is intentionally NOT a pattern — the same atlas draws the gear
	-- slot's "+"/blink icons, which must stay; the gear art is blanked in SkinGear instead.
	local function isBgTexture(t)
		if type(t) ~= "string" then return false end
		local lt = t:lower()
		for _, p in ipairs(BG_PATTERNS) do
			if lt:find(p) then return true end
		end
		return false
	end

	local function hide(obj)
		if obj and obj.SetAlpha then obj:SetAlpha(0) end
	end

	-- Dropdown arrow: the server re-applies its arrow texture on hover and HandleDropDownBox
	-- early-returns on isSkinned/existing backdrop, so freeze the button's own textures and
	-- draw our own ElvUI arrow overlay the server can't touch.
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

	-- Finder dropdowns: the server re-lays-out the 3-slice holder + arrow every pass, and
	-- HandleDropDownBox fought that (mangled the box, dropped its selected-value text).
	-- Instead freeze the holder slices blank, lay a flat ElvUI backdrop over the holder
	-- geometry (live-anchored to the server's Left/Button so it tracks re-layout), swap in
	-- a frozen ElvUI arrow, and leave the server's text + geometry untouched.
	local function skinFinderDropdown(dd)
		local name = dd and dd.GetName and dd:GetName()
		if not name or dd.__euiDD then return end
		local left, middle, right = _G[name.."Left"], _G[name.."Middle"], _G[name.."Right"]
		local button = _G[name.."Button"]
		if not (left and middle and right and button) then return end
		dd.__euiDD = true
		for _, t in ipairs({ left, middle, right }) do
			t:SetTexture(nil); t:SetAlpha(0)
			t.SetTexture = E.noop; t.SetAlpha = E.noop; t.Show = E.noop
		end
		if not dd.backdrop then dd:CreateBackdrop("Transparent") end
		dd.backdrop:ClearAllPoints()
		dd.backdrop:Point("TOPLEFT", left, "TOPLEFT", 0, -1)
		dd.backdrop:Point("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 1)
		skinDropArrow(button)
	end

	-- Recursively flatten every inset + background texture in a frame subtree, and
	-- skin any dropdown/scrollbar found along the way.
	local function sweep(frame, depth)
		depth = depth or 0
		if not frame or depth > 12 then return end
		-- Defensive: never descend into the pvp content frames (arena-points bar, prestige
		-- ring). They draw with the pvpqueue atlas, kept so no future pattern can erase them.
		local apb = _G.HK_PvpDevContainer and _G.HK_PvpDevContainer._hkArenaBar
		if apb and frame == apb then return end
		if frame == _G.HK_PvpDevContainerDevInsetRing then return end
		-- InsetFrameTemplate marble + border pieces (parentKeys).
		local isInset = frame.Bgs ~= nil
		for _, key in ipairs(INSET_BORDER) do
			local r = frame[key]
			if r then isInset = true; if r.SetAlpha then r:SetAlpha(0); if r.Hide then r:Hide() end end end
		end
		if frame.Bgs and frame.Bgs.SetAlpha then frame.Bgs:SetAlpha(0) end
		-- Sizeable content panels get a dark recessed backdrop so the darkening follows
		-- the content per view; tiny chrome insets are just flattened above.
		if isInset and not frame.__euiBackdrop and frame.CreateBackdrop and frame.GetWidth then
			local w, h = frame:GetWidth() or 0, frame:GetHeight() or 0
			if w > 60 and h > 60 then
				frame.__euiBackdrop = true
				frame:CreateBackdrop("Transparent")
			end
		end
		-- Blank own decorative bg textures + detect finder input fields (carry a
		-- common-input-border texture we must replace, not merely blank).
		local hasInputBorder = false
		if frame.GetRegions then
			for _, r in ipairs({ frame:GetRegions() }) do
				if r.GetObjectType and r:GetObjectType() == "Texture" and r.GetTexture then
					local tex = r:GetTexture()
					if type(tex) == "string" and tex:lower():find("common%-input%-border") then
						hasInputBorder = true
						r:SetAlpha(0)
					elseif isBgTexture(tex) then
						r:SetAlpha(0)
					end
				end
			end
		end
		-- Finder input field: backdrop the FIELD, not the inner editBox — an editBox
		-- backdrop draws over the field's placeholder and hides it.
		local innerEdit = frame.editBox or frame.searchBox
		if (hasInputBorder or (innerEdit and frame.placeholder)) and not frame.__euiInputField then
			frame.__euiInputField = true
			-- Mark editbox children so the editbox branch skips them. Multiline fields
			-- reparent their editbox into a ScrollFrame and manage their own interactive
			-- stack, so leave them untouched beyond the border — an extra child backdrop
			-- disturbed the description field's click-to-focus.
			local isMultiline = frame._hkDescScroll ~= nil
			if innerEdit then innerEdit.__euiSkipEditBox = true end
			if frame.GetChildren then
				for _, c in ipairs({ frame:GetChildren() }) do
					if c.GetObjectType then
						local t = c:GetObjectType()
						if t == "EditBox" then
							c.__euiSkipEditBox = true
						elseif t == "ScrollFrame" then
							isMultiline = true
						end
					end
				end
			end
			if not isMultiline and not frame.backdrop and frame.CreateBackdrop then
				frame:CreateBackdrop("Transparent")
				if frame.backdrop.SetFrameLevel then
					frame.backdrop:SetFrameLevel(math.max(0, (frame:GetFrameLevel() or 1) - 1))
				end
			end
		end
		-- Dropdowns / scrollbars / buttons / editboxes found anywhere in the tree.
		local name = frame.GetName and frame:GetName()
		local ot = frame.GetObjectType and frame:GetObjectType()
		-- 3-slice buttons, incl. ANONYMOUS ones (e.g. gear upgrade) that expose slices as
		-- parentKeys .Left/.Middle/.Right — the named-only branch below would miss those.
		if ot == "Button" and not frame.__euiFinder then
			local threeSlice = (frame.Left and frame.Middle and frame.Right)
				or (name and _G[name.."Left"] and _G[name.."Middle"] and _G[name.."Right"])
			if threeSlice then
				frame.__euiFinder = true
				if S.HandleButton then S:HandleButton(frame) end
			end
		end
		if name and not frame.__euiFinder then
			if ot == "Slider" and name:find("ScrollBar$") then
				frame.__euiFinder = true
				if S.HandleScrollBar then S:HandleScrollBar(frame) end
			elseif ot == "EditBox" then
				-- Skip editboxes belonging to a finder input field (a backdrop draws over the
				-- placeholder / swallows the multiline click-to-focus). Multiline fields
				-- reparent into a ScrollFrame so the flag isn't on the direct parent — walk up.
				local skip = frame.__euiSkipEditBox
				if not skip then
					local p = frame
					for _ = 1, 4 do
						p = p and p.GetParent and p:GetParent()
						if not p then break end
						if p.__euiInputField then skip = true; break end
					end
				end
				if not skip then
					frame.__euiFinder = true
					if S.HandleEditBox then S:HandleEditBox(frame) end
				end
			elseif ot ~= "Button" and _G[name.."Button"] and _G[name.."Middle"] then
				-- Dropdown (UIDropDownMenu-like): a Frame with an arrow button + middle.
				frame.__euiFinder = true
				skinFinderDropdown(frame)
			end
		end
		if frame.GetChildren then
			for _, c in ipairs({ frame:GetChildren() }) do
				sweep(c, depth + 1)
			end
		end
	end

	S:AddCallback("Skin_LFD_Nozdor", function()
		if not E.private.skins.blizzard.enable or not E.private.skins.blizzard.lfd then return end
		local frame = _G.LFDParentFrame
		-- Only the redesigned finder (native MetalFrame2X + HK shell).
		if not frame or not _G.HK_LFDShell_SetTab then return end

		if not frame.backdrop then
			frame:CreateBackdrop("Transparent")
			frame.backdrop:Point("TOPLEFT", 2, -2)
			frame.backdrop:Point("BOTTOMRIGHT", -2, 2)
			S:SetBackdropHitRect(frame)
		end

		-- Chrome: metal border + corner ring + close; hide the eye/ring portrait.
		local function FlattenChrome()
			if S.HandleMetalFrame then S:HandleMetalFrame(frame, frame.backdrop) end
			hide(_G.LFDParentFramePortrait)
			if _G.HK_LFDPortraitFrame then _G.HK_LFDPortraitFrame:Hide() end
		end

		-- Top tabs (Dungeons / PvP / Stats / Gear / Keys).
		local TOP_TABS = {
			"HK_LFDTopTabDungeons", "HK_LFDTopTabPvp", "HK_LFDTopTabStats",
			"HK_LFDTopTabGear", "HK_LFDTopTabKeys",
		}
		local function SkinTabs()
			for _, n in ipairs(TOP_TABS) do
				local tab = _G[n]
				if tab and not tab.__euiSkinned then
					tab.__euiSkinned = true
					if tab.bg then tab.bg:SetAlpha(0) end
					if tab.selection then tab.selection:SetAlpha(0) end
					if S.HandleTab then S:HandleTab(tab) end
					-- Tighten the backdrop to the tab (default HandleTab insets detach it).
					if tab.backdrop then
						tab.backdrop:ClearAllPoints()
						tab.backdrop:Point("TOPLEFT", tab, "TOPLEFT", 2, -2)
						tab.backdrop:Point("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -2, 2)
					end
				end
			end
		end

		-- Battle Pass sidebar button -> small ElvUI button (was 185x44 store art).
		local function SkinButtons()
			local bp = _G.HK_LFDBattlePassButton
			if bp and not bp.__euiSkinned then
				bp.__euiSkinned = true
				if S.HandleButton then S:HandleButton(bp) end
				bp:SetSize(120, 22)
				if bp.Highlight then bp.Highlight:SetTexture(nil) end
				-- Re-centre the "Боевой пропуск" label (was offset for the store icon).
				if bp.GetRegions then
					for _, r in ipairs({ bp:GetRegions() }) do
						if r.GetObjectType and r:GetObjectType() == "FontString" then
							r:ClearAllPoints()
							r:SetPoint("CENTER", bp, "CENTER", 0, 0)
							r:SetJustifyH("CENTER")
						end
					end
				end
			end
		end

		-- Narrow the stock queue-frame backdrop to just the content right of the sidebar
		-- (it spanned the whole width).
		local function FixContentBackdrop()
			local q = _G.LFDQueueFrame
			if q and q.backdrop and _G.HK_LFDSidebar then
				q.backdrop:ClearAllPoints()
				-- Nudged so the darkening lines up with the PVE rewards content on both sides.
				q.backdrop:Point("TOPLEFT", _G.HK_LFDSidebar, "TOPRIGHT", 3, 0)
				q.backdrop:Point("BOTTOMRIGHT", q, "BOTTOMRIGHT", -3, 4)
			end
		end

		-- PVP dev container: the left panel's battleground image and the dev inset panelBg
		-- can't be blanked by the pvpqueue pattern (shared with the currency rings/bar), so
		-- target these panels directly. SetAlpha(0) survives the server's later Show().
		local function SkinPvpDev()
			local c = _G.HK_PvpDevContainer
			if not c then return end
			local left = c.leftPanel
			if left then
				if left.bg and left.bg.SetAlpha then left.bg:SetAlpha(0) end
				if left.Bgs and left.Bgs.SetAlpha then left.Bgs:SetAlpha(0) end
				if not left.__euiBackdrop and left.CreateBackdrop then
					left.__euiBackdrop = true
					left:CreateBackdrop("Transparent")
					if left.backdrop and left.backdrop.SetFrameLevel then
						left.backdrop:SetFrameLevel(math.max(0, (left:GetFrameLevel() or 1) - 1))
					end
				end
			end
			local inset = c.devInset
			if inset and inset.panelBg and inset.panelBg.SetAlpha then
				inset.panelBg:SetAlpha(0)
			end
		end

		-- Left sidebar tab buttons: give each its own flat dark panel behind the
		-- icon/ring/text, drawn below the button's own content.
		local SIDEBAR_BTNS = {
			"HK_LFDSidebarRandomBtn", "HK_LFDSidebarPremadeBtn", "HK_LFDSidebarQuickBtn",
			"HK_LFDSidebarRatedBtn", "HK_LFDSidebarTrainingBtn", "HK_LFDSidebarPvpBtn",
			"HK_LFDSidebarSpectateBtn", "HK_LFDSidebarBracket1v1Btn",
			"HK_LFDSidebarBracket2v2Btn", "HK_LFDSidebarBracket3v3Btn",
			"HK_LFDSidebarBracketRbgBtn",
		}
		-- Selected sidebar tab = accent border (server sets btn._hkActive in
		-- setSidebarTabState). Hover = a translucent accent fill on the HIGHLIGHT layer
		-- (ElvUI's list-row idiom), which WoW shows automatically on mouseover.
		local function sidebarSelect(b)
			if not b.backdrop then return end
			b.backdrop:SetBackdropBorderColor(unpack(b._hkActive and E.media.rgbvaluecolor or E.media.bordercolor))
		end
		local function SkinSidebarButtons()
			for _, n in ipairs(SIDEBAR_BTNS) do
				local b = _G[n]
				if b then
					if not b.__euiBackdrop and b.CreateBackdrop then
						b.__euiBackdrop = true
						b:CreateBackdrop("Transparent")
						if b.backdrop and b.backdrop.SetFrameLevel then
							b.backdrop:SetFrameLevel(math.max(0, (b:GetFrameLevel() or 1) - 1))
						end
					end
					-- Replace the server's own selection art with the ElvUI accents.
					if b.selection and b.selection.SetAlpha then b.selection:SetAlpha(0) end
					if not b.__euiHL and b.backdrop then
						b.__euiHL = true
						-- Drop the server's native highlight so only the ElvUI fill shows.
						if b.SetHighlightTexture then b:SetHighlightTexture("") end
						local hl = b:CreateTexture(nil, "HIGHLIGHT")
						hl:SetTexture(E.Media.Textures.Highlight)
						hl:SetVertexColor(E.media.rgbvaluecolor[1], E.media.rgbvaluecolor[2], E.media.rgbvaluecolor[3], 0.35)
						hl:SetInside(b.backdrop)
					end
					sidebarSelect(b)
				end
			end
		end

		local function SkinAll()
			FlattenChrome()
			sweep(frame, 0)
			-- PVPSpectatorFrame is a sibling, not a child of LFDParentFrame — sweep it too.
			if _G.PVPSpectatorFrame then sweep(_G.PVPSpectatorFrame, 0) end
			SkinPvpDev()
			SkinSidebarButtons()
			SkinTabs()
			SkinButtons()
			FixContentBackdrop()
			-- Shift the description panel's dark backdrop 3px left.
			local di = _G.HK_LFDDescInset
			if di and di.backdrop then
				di.backdrop:ClearAllPoints()
				di.backdrop:Point("TOPLEFT", di, "TOPLEFT", -4, 1)
				di.backdrop:Point("BOTTOMRIGHT", di, "BOTTOMRIGHT", -2, -1)
			end
		end
		SkinAll()

		if _G.HK_LFDShell_SetTab then
			hooksecurefunc("HK_LFDShell_SetTab", SkinAll)
		end
		frame:HookScript("OnShow", SkinAll)

		-- Dropdowns are laid out by the server's finder layout pass, which can run after
		-- SkinAll for lazily-created ones — re-skin each right after (one-shot per frame).
		if _G.HK_LFDShell_ApplyFinderDropdownLayout then
			hooksecurefunc("HK_LFDShell_ApplyFinderDropdownLayout", function(dd)
				skinFinderDropdown(dd)
			end)
		end

		-- Spectate view is shown/re-decorated by the server on demand, so the one-shot
		-- SkinAll misses it — re-skin after every spectator content layout. The portrait
		-- + 3D model are re-shown by the frame's own data refresh after our hook, so a
		-- one-time Hide is undone: freeze them.
		local function freezeHidden(obj)
			if not obj or obj.__euiFrozen then return end
			obj.__euiFrozen = true
			if obj.SetAlpha then obj:SetAlpha(0) end
			if obj.Hide then obj:Hide() end
			obj.Show = E.noop
		end
		local function SkinSpectator()
			local host = _G.HK_SpectatorHost
			if host then sweep(host, 0) end
			if _G.PVPSpectatorFrame then sweep(_G.PVPSpectatorFrame, 0) end
			local inset = host and host.inset
			if inset and inset.Bgs and inset.Bgs.SetAlpha then inset.Bgs:SetAlpha(0) end
			-- The round portrait, its ring and the 3D model — all leftover window chrome.
			freezeHidden(_G.PVPSpectatorFramePortrait)
			freezeHidden(_G.PVPSpectatorFramePortraitModel)
			freezeHidden(_G.PVPSpectatorFramePortraitModelModel)
		end
		if _G.HK_LFDShell_ApplySpectatorContentLayout then
			hooksecurefunc("HK_LFDShell_ApplySpectatorContentLayout", SkinSpectator)
		end

		-- HK_LFDBgScroll is created lazily in HK_LFDShell_ApplyBgList (after the first
		-- SkinAll), so its scrollbar was only skinned on the second open — skin it here.
		if _G.HK_LFDShell_ApplyBgList then
			hooksecurefunc("HK_LFDShell_ApplyBgList", function()
				local sb = _G.HK_LFDBgScrollScrollBar
				if sb and not sb.__euiFinder then
					sb.__euiFinder = true
					if S.HandleScrollBar then S:HandleScrollBar(sb) end
				end
			end)
		end

		-- Gear upgrade tab: blank the itemupgrade top/bottom art into a flat backdrop (the
		-- anonymous upgrade button + dropdowns are skinned by the sweep). Re-run per layout.
		local function SkinGear()
			local c = _G.HK_GearUpgradeContainer
			if not c then return end
			if c.top and c.top.SetAlpha then c.top:SetAlpha(0) end
			if c.bottom and c.bottom.SetAlpha then c.bottom:SetAlpha(0) end
			if not c.__euiBackdrop and c.CreateBackdrop then
				c.__euiBackdrop = true
				c:CreateBackdrop("Transparent")
				if c.backdrop and c.backdrop.SetFrameLevel then
					c.backdrop:SetFrameLevel(math.max(0, (c:GetFrameLevel() or 1) - 1))
				end
			end
			sweep(c, 0)
		end
		if _G.HK_GearUpgrade_ApplyLayout then
			hooksecurefunc("HK_GearUpgrade_ApplyLayout", SkinGear)
		end

		-- The bottom tab bar sits 2px too low; the server re-anchors it per layout pass,
		-- so nudge it up 2px after each (re-reads the server points → no drift).
		if _G.HK_LFDShell_ApplyTopTabLayout then
			hooksecurefunc("HK_LFDShell_ApplyTopTabLayout", function()
				local bar = _G.HK_LFDTopTabBar
				if not bar then return end
				local p1, r1, rp1, x1, y1 = bar:GetPoint(1)
				local p2, r2, rp2, x2, y2 = bar:GetPoint(2)
				if p1 then bar:SetPoint(p1, r1, rp1, x1, (y1 or 0) + 2) end
				if p2 then bar:SetPoint(p2, r2, rp2, x2, (y2 or 0) + 2) end
			end)
		end
	end)
end
