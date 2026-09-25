local E, L, V, P, G = unpack(select(2, ...))
local S = E:GetModule("Skins")

local _G = _G
local ipairs = ipairs
local unpack = unpack
local math_max = math.max
local floor = math.floor

-- Mass close-button replacement: the server's CloseButton2X_Apply runs after our
-- per-window skinning and overrode the ElvUI "X". Hook it once so every button it
-- styles is re-skinned automatically, no per-button handling.
if _G.CloseButton2X_Apply and not _G.__ElvUI_CloseButton2XHooked then
	_G.__ElvUI_CloseButton2XHooked = true
	hooksecurefunc("CloseButton2X_Apply", function(btn)
		if btn and S.HandleCloseButton then S:HandleCloseButton(btn) end
	end)
end
-- The other half: MetalFrame2X_Decorate creates its own CloseButton (not via
-- CloseButton2X_Apply), so hook that too.
if _G.MetalFrame2X_Decorate and not _G.__ElvUI_MetalDecorateHooked then
	_G.__ElvUI_MetalDecorateHooked = true
	hooksecurefunc("MetalFrame2X_Decorate", function(frame)
		if frame and frame.CloseButton and S.HandleCloseButton then
			S:HandleCloseButton(frame.CloseButton)
		end
	end)
end

local function SafeHandleTab(tab)
	if not tab then return end
	if tab.HighlightLeft and tab.HighlightLeft.StripTextures then tab.HighlightLeft:StripTextures() end
	if tab.HighlightMiddle and tab.HighlightMiddle.StripTextures then tab.HighlightMiddle:StripTextures() end
	if tab.HighlightRight and tab.HighlightRight.StripTextures then tab.HighlightRight:StripTextures() end
	if S.HandleTab then S:HandleTab(tab) end
end

local function GetRotateButtons()
	local f = _G.CharacterModelFrame
	local left  = _G.CharacterModelFrameRotateLeftButton or (f and f.RotateLeftButton) or _G.PaperDollFrameRotateLeftButton
	local right = _G.CharacterModelFrameRotateRightButton or (f and f.RotateRightButton) or _G.PaperDollFrameRotateRightButton
	return left, right
end

local BACKDROP_TPL = (BackdropTemplateMixin and "BackdropTemplate") or nil

local function MakeBD(parent, w, h)
    local f = CreateFrame("Frame", nil, parent, BACKDROP_TPL)
    if w and h then f:SetSize(w, h) end
    if f.SetBackdrop then
        f:SetBackdrop({ bgFile = "Interface/Buttons/WHITE8x8",
                        edgeFile = "Interface/Buttons/WHITE8x8", edgeSize = 1 })
        f:SetBackdropColor(0,0,0, .7)
        f:SetBackdropBorderColor(0,0,0,1)
    end
    return f
end

-- Zebra striping for list rows: a faint WHITE8X8 fill on every other row, keyed by the
-- row's fixed slot index (rows are recycled on scroll). Header rows are excluded (pass
-- isHeader) so they keep the server's category plate. Toggled each call so a recycled
-- slot that becomes a header can turn its stripe off.
local function AddRowStripe(row, i, rightPad, isHeader, leftPad)
	if not row or not row.CreateTexture then return end
	if (i % 2) == 0 and not row.__euiStripe then
		-- On a child frame so the row skinners' StripTextures can't wipe it (never recurses).
		local holder = CreateFrame("Frame", nil, row)
		holder:SetAllPoints(row)
		if holder.SetFrameLevel and row.GetFrameLevel then
			holder:SetFrameLevel(math_max((row:GetFrameLevel() or 1) - 1, 0))
		end
		local stripe = holder:CreateTexture(nil, "BACKGROUND")
		stripe:SetPoint("TOPLEFT", row, "TOPLEFT", leftPad or 0, 0)
		stripe:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", rightPad or 0, 0)
		stripe:SetTexture("Interface\\Buttons\\WHITE8X8")
		stripe:SetVertexColor(1, 1, 1)
		stripe:SetAlpha(0.05)
		row.__euiStripe = stripe
	end
	if row.__euiStripe then
		row.__euiStripe:SetShown((i % 2) == 0 and not isHeader)
	end
end

-- The title plate the server draws on skill headers (left cap + stretched middle +
-- mirrored right cap from commonbuttons), copied so rep/currency headers match.
local PLATE_TEX   = "Interface\\Buttons\\commonbuttons"
local PLATE_LEFT  = { 0.916992, 0.955078, 0.145508, 0.282227 }
local PLATE_RIGHT = { 0.955078, 0.916992, 0.145508, 0.282227 } -- mirrored
local PLATE_MID   = { 0.40, 0.60, 0.145508, 0.282227 }
local PLATE_H, PLATE_CAP = 24, 7

-- Header plate on its own child frame so SkinReputationRow's StripTextures can't wipe
-- it. Returns the holder so callers can raise a row's label above it where needed.
local function EnsureBlackPlate(row)
	if not row.__euiHdrPlate then
		local holder = CreateFrame("Frame", nil, row)
		holder:SetAllPoints(row)
		if holder.SetFrameLevel and row.GetFrameLevel then
			holder:SetFrameLevel(math_max((row:GetFrameLevel() or 1) - 1, 0))
		end
		local left = holder:CreateTexture(nil, "ARTWORK")
		left:SetTexture(PLATE_TEX); left:SetTexCoord(unpack(PLATE_LEFT))
		left:SetPoint("LEFT", holder, "LEFT", 2, 0); left:SetSize(PLATE_CAP, PLATE_H)
		local right = holder:CreateTexture(nil, "ARTWORK")
		right:SetTexture(PLATE_TEX); right:SetTexCoord(unpack(PLATE_RIGHT))
		right:SetPoint("RIGHT", holder, "RIGHT", -2, 0); right:SetSize(PLATE_CAP, PLATE_H)
		local body = holder:CreateTexture(nil, "ARTWORK")
		body:SetTexture(PLATE_TEX); body:SetTexCoord(unpack(PLATE_MID))
		body:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0)
		body:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", 0, 0)
		row.__euiHdrPlate = holder
	end
	return row.__euiHdrPlate
end

-- ElvUI-style +/- for the reputation sub-category dropdown button (rowType 3): hide the
-- server's red dropdown texture, show a plain +/- glyph. Re-applied each SetRowType
-- (server re-textures it), collapsed => "+", expanded => "-".
local function StyleRepExpandButton(btn, collapsed)
	if not btn then return end
	if btn.SetNormalTexture then btn:SetNormalTexture("") end
	if btn.SetPushedTexture then btn:SetPushedTexture("") end
	if btn.SetHighlightTexture then btn:SetHighlightTexture("") end
	local nt = btn.GetNormalTexture and btn:GetNormalTexture()
	if nt then nt:SetTexture(nil) end
	if not btn.__euiSign and btn.CreateFontString then
		local fs = btn:CreateFontString(nil, "OVERLAY")
		if fs.FontTemplate then fs:FontTemplate(nil, 16) end
		fs:SetPoint("CENTER", btn, "CENTER", 0, 0)
		btn.__euiSign = fs
	end
	if btn.__euiSign then btn.__euiSign:SetText(collapsed and "+" or "-") end
end

-- Header rows are excluded from the zebra and get the copied plate UNLESS they carry a
-- +/- expand button (wantPlate=false, so plate and button don't collide). wantPlate
-- defaults to isHeader.
local function SetRowHeaderStyle(row, i, isHeader, rightPad, wantPlate)
	if not row then return end
	if wantPlate == nil then wantPlate = isHeader end
	if wantPlate then
		EnsureBlackPlate(row):Show()
	elseif row.__euiHdrPlate then
		row.__euiHdrPlate:Hide()
	end
	AddRowStripe(row, i, rightPad, isHeader)
end

-- NOZDOR: PaperDollFrame's inner panels/model frame are decorated with art re-applied
-- after ElvUI's one-time strip. These frames are pure decorative containers (stats text,
-- model and item slots are separate child objects), so blank ALL their own texture
-- regions to let the flat backdrop show. FontStrings and the model are left untouched.
local function BlankDecorTextures(frame)
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

-- Stat-category headers (ItemLevel / Stat1 / Stat2): replace the server plate behind
-- their label with a flat ElvUI panel + hover highlight.
local function StyleStatHeader(header)
	if not header then return end
	if header.Background then
		header.Background:SetTexture(nil)
		header.Background:Hide()
	end
	if header.CreateBackdrop and not header.backdrop then
		header:CreateBackdrop("Transparent")
		header.backdrop:Point("TOPLEFT", header, "TOPLEFT", 4, -4)
		header.backdrop:Point("BOTTOMRIGHT", header, "BOTTOMRIGHT", -4, 4)
		if header.HookScript and S.SetModifiedBackdrop then
			header:HookScript("OnEnter", S.SetModifiedBackdrop)
			header:HookScript("OnLeave", S.SetOriginalBackdrop)
		end
	end
end

local function CleanPaperDollDecor()
	BlankDecorTextures(_G.PaperDollFrameNewPanel)
	BlankDecorTextures(_G.PaperDollFrameEquipInset)
	BlankDecorTextures(_G.PaperDollFrameInset)
	BlankDecorTextures(_G.CharacterModelFrame)
	StyleStatHeader(_G.ItemLevelHeader)
	StyleStatHeader(_G.Stat1Header)
	StyleStatHeader(_G.Stat2Header)
end

-- The corner "portrait" is a live 3D PlayerModel, not a texture, so stripping misses it.
-- Hide it and keep it hidden against the portrait system re-showing it on UNIT_PORTRAIT_UPDATE.
local function HideCharacterPortraitModel()
	for _, name in ipairs({ "CharacterFramePortraitModel", "CharacterFramePortraitModelModel" }) do
		local model = _G[name]
		if model and model.Hide then
			model:Hide()
			if model.HookScript and not model.__elvHidden then
				model.__elvHidden = true
				model:HookScript("OnShow", model.Hide)
			end
		end
	end
end

-- Pet tab: blank the shared CharacterFrameInset marble fill and the PetAttributesFrame
-- plate to the flat ElvUI look. The rotate arrows also read too big.
local function SkinPetFrame()
	BlankDecorTextures(_G.CharacterFrameInset)

	local attr = _G.PetAttributesFrame
	if attr then
		BlankDecorTextures(attr)
		if attr.CreateBackdrop and not attr.backdrop then
			attr:CreateBackdrop("Transparent")
		end
	end

	for _, name in ipairs({ "PetModelFrameRotateLeftButton", "PetModelFrameRotateRightButton" }) do
		local btn = _G[name]
		if btn and S.HandleButton then S:HandleButton(btn) end
		local icon = _G[name.."Icon"]
		if icon and icon.SetSize then icon:SetSize(13, 13) end
	end
end

local function LoadSkin()
	if E.private.skins.blizzard.enable ~= true or E.private.skins.blizzard.character ~= true then return end

	if _G.CharacterFrame and _G.CharacterFrame.StripTextures then
		_G.CharacterFrame:StripTextures(true)
	end
	if _G.CharacterFrame and _G.CharacterFrame.CreateBackdrop and not _G.CharacterFrame.backdrop then
		_G.CharacterFrame:CreateBackdrop("Transparent", nil, nil, nil, true)
	end
	if _G.CharacterFrame and _G.CharacterFrame.backdrop and _G.CharacterFrame.backdrop.SetAllPoints then
		_G.CharacterFrame.backdrop:SetAllPoints(_G.CharacterFrame)
	end
    if _G.CharacterFrame and _G.CharacterFrame.backdrop then
        local cf = _G.CharacterFrame
        local bd = cf.backdrop

        bd:SetFrameStrata(cf:GetFrameStrata() or "MEDIUM")
        bd:SetFrameLevel(math_max((cf:GetFrameLevel() or 1) - 2, 0))
    end

	-- NOZDOR: the MetalFrame2X chrome is built on CharacterFrame's first OnShow (it
	-- doesn't exist yet here), so neutralize it on show + hide the rock background. The
	-- chrome-building OnShow hook is registered earlier, so it always runs before this.
	if _G.CharacterFrame then
		_G.CharacterFrame:HookScript("OnShow", function(frame)
			if S.HandleMetalFrame then S:HandleMetalFrame(frame, frame.backdrop) end
			if _G.CharacterFrameBg then _G.CharacterFrameBg:SetAlpha(0) end
			if _G.CharacterFrameTopTileStreaks then _G.CharacterFrameTopTileStreaks:SetAlpha(0) end
			HideCharacterPortraitModel()
		end)
	end

	if _G.CHARACTERFRAME_SUBFRAMES then
		for i = 1, #_G.CHARACTERFRAME_SUBFRAMES do
			local tab = _G["CharacterFrameTab"..i]
			SafeHandleTab(tab)
			-- The NozdorFinder tabs are much wider than stock, so ElvUI's default 10px side
			-- insets leave big gaps — hug the button instead (backdrop tracks runtime width).
			if tab and tab.backdrop then
				tab.backdrop:Point("TOPLEFT", tab, "TOPLEFT", 2, 0)
				tab.backdrop:Point("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -2, 2)
				tab:SetHitRectInsets(0, 0, 0, 0)
			end
		end
		-- Anchor the tab row's TOP to the window's BOTTOM so it hangs flush below (chains off Tab1).
		if _G.CharacterFrameTab1 and _G.CharacterFrame then
			_G.CharacterFrameTab1:ClearAllPoints()
			_G.CharacterFrameTab1:Point("TOPLEFT", _G.CharacterFrame, "BOTTOMLEFT", 10, 0)
		end
	end

	if _G.GearManagerDialog then
		_G.GearManagerDialog:StripTextures()
		_G.GearManagerDialog:CreateBackdrop("Transparent")
		_G.GearManagerDialog.backdrop:Point("TOPLEFT", 5, -2)
		_G.GearManagerDialog.backdrop:Point("BOTTOMRIGHT", -1, 4)
		if S.HandleCloseButton and _G.CharacterFrameCloseButton then
			S:HandleCloseButton(_G.CharacterFrameCloseButton)
			_G.CharacterFrameCloseButton:ClearAllPoints()
			_G.CharacterFrameCloseButton:Point("TOPRIGHT", _G.CharacterFrame, "TOPRIGHT", -4, -4)
		end
		for i = 1, 10 do
			local b = _G["GearSetButton"..i]
			if b then
				b:StripTextures()
				if b.StyleButton then b:StyleButton() end
				b:CreateBackdrop("Default")
				b.backdrop:SetAllPoints()
				local icon = _G["GearSetButton"..i.."Icon"]
				if icon then
					icon:SetTexCoord(unpack(E.TexCoords))
					if icon.SetInside then icon:SetInside() end
				end
			end
		end
		if S.HandleButton then
			if _G.GearManagerDialogDeleteSet then S:HandleButton(_G.GearManagerDialogDeleteSet) end
			if _G.GearManagerDialogEquipSet then S:HandleButton(_G.GearManagerDialogEquipSet) end
			if _G.GearManagerDialogSaveSet then S:HandleButton(_G.GearManagerDialogSaveSet) end
		end
	end

	if _G.PlayerTitleFrame then
		_G.PlayerTitleFrame:StripTextures()
		_G.PlayerTitleFrame:CreateBackdrop("Default")
		_G.PlayerTitleFrame.backdrop:Point("TOPLEFT", 20, 3)
		_G.PlayerTitleFrame.backdrop:Point("BOTTOMRIGHT", -16, 15)
		_G.PlayerTitleFrame.backdrop:SetFrameLevel(_G.PlayerTitleFrame:GetFrameLevel())
	end
	if S.HandleNextPrevButton and _G.PlayerTitleFrameButton then
		S:HandleNextPrevButton(_G.PlayerTitleFrameButton)
		_G.PlayerTitleFrameButton:Size(16)
		_G.PlayerTitleFrameButton:Point("TOPRIGHT", _G.PlayerTitleFrameRight, "TOPRIGHT", -18, -16)
	end
	if _G.PlayerTitlePickerFrame then
		_G.PlayerTitlePickerFrame:StripTextures()
		_G.PlayerTitlePickerFrame:CreateBackdrop("Transparent")
		_G.PlayerTitlePickerFrame.backdrop:Point("TOPLEFT", 6, -10)
		_G.PlayerTitlePickerFrame.backdrop:Point("BOTTOMRIGHT", -13, 6)
		_G.PlayerTitlePickerFrame.backdrop:SetFrameLevel(_G.PlayerTitlePickerFrame:GetFrameLevel())
	end

if IsAddOnLoaded and IsAddOnLoaded("Blizzard_CharacterUI") then
    InstallStrengthenHooks()
else
    local f = CreateFrame("Frame")
    f:RegisterEvent("ADDON_LOADED")
    f:SetScript("OnEvent", function(_, addon)
        if addon=="Blizzard_CharacterUI" then
            InstallStrengthenHooks()
            f:UnregisterEvent("ADDON_LOADED")
        end
    end)
end


if IsAddOnLoaded("Blizzard_CharacterUI") then
    InstallStrengthenScrollbarHooks()
else
    local waiter = CreateFrame("Frame")
    waiter:RegisterEvent("ADDON_LOADED")
    waiter:SetScript("OnEvent", function(_, addon)
        if addon == "Blizzard_CharacterUI" then
            InstallStrengthenScrollbarHooks()
            waiter:UnregisterEvent("ADDON_LOADED")
        end
    end)
end


	


	if _G.PlayerTitlePickerScrollFrame and _G.PlayerTitlePickerScrollFrame.buttons then
		for _, button in ipairs(_G.PlayerTitlePickerScrollFrame.buttons) do
			if button.text and button.text.FontTemplate then button.text:FontTemplate() end
			if S.HandleButtonHighlight then S:HandleButtonHighlight(button) end
		end
	end

	local rotateLeft, rotateRight = GetRotateButtons()
	if rotateLeft and S.HandleRotateButton then S:HandleRotateButton(rotateLeft) end
	if rotateRight and S.HandleRotateButton then S:HandleRotateButton(rotateRight) end

	if _G.CharacterAttributesFrame then
		_G.CharacterAttributesFrame:StripTextures()
	end

	if _G.PaperDollFrame then
		-- Inner panels are re-textured after the one-time strip, so clean their decor
		-- on every show and after each stats relayout (and once now).
		_G.PaperDollFrame:HookScript("OnShow", CleanPaperDollDecor)
		if _G.PaperDollFrame_UpdateStats then hooksecurefunc("PaperDollFrame_UpdateStats", CleanPaperDollDecor) end
		if _G.CharacterModelFrame then _G.CharacterModelFrame:HookScript("OnShow", CleanPaperDollDecor) end
		CleanPaperDollDecor()

		local slots = {
			[1] = _G.CharacterHeadSlot,[2] = _G.CharacterNeckSlot,[3] = _G.CharacterShoulderSlot,[4] = _G.CharacterShirtSlot,
			[5] = _G.CharacterChestSlot,[6] = _G.CharacterWaistSlot,[7] = _G.CharacterLegsSlot,[8] = _G.CharacterFeetSlot,
			[9] = _G.CharacterWristSlot,[10] = _G.CharacterHandsSlot,[11] = _G.CharacterFinger0Slot,[12] = _G.CharacterFinger1Slot,
			[13] = _G.CharacterTrinket0Slot,[14] = _G.CharacterTrinket1Slot,[15] = _G.CharacterBackSlot,[16] = _G.CharacterMainHandSlot,
			[17] = _G.CharacterSecondaryHandSlot,[18] = _G.CharacterRangedSlot,[19] = _G.CharacterTabardSlot,[20] = _G.CharacterAmmoSlot,
		}
		for i, slotFrame in ipairs(slots) do
			if slotFrame then
				local slotFrameName = slotFrame:GetName()
				local icon = _G[slotFrameName.."IconTexture"]
				slotFrame:StripTextures()
				if slotFrame.StyleButton then slotFrame:StyleButton(false) end
				if slotFrame.SetTemplate then slotFrame:SetTemplate("Default", true, true) end
                if slotFrame.backdrop and slotFrame.GetFrameLevel then slotFrame.backdrop:SetFrameLevel(slotFrame:GetFrameLevel() + 1) end
				if icon then
					if icon.SetInside then icon:SetInside() end
					icon:SetTexCoord(unpack(E.TexCoords))
				end
				if slotFrame.SetFrameLevel then
					slotFrame:SetFrameLevel((_G.PaperDollFrame:GetFrameLevel() or 1) + 10)
                    if slotFrame.backdrop then
                        slotFrame.backdrop:SetFrameLevel(slotFrame:GetFrameLevel() + 1)
                    end
				end
				if i ~= 20 then
					local cooldown = _G[slotFrameName.."Cooldown"]
					local popout = _G[slotFrameName.."PopoutButton"]
					if cooldown then E:RegisterCooldown(cooldown) end
					if popout then
						popout:StripTextures()
						if popout.HookScript then
							popout:HookScript("OnEnter", function(self) if self.icon then self.icon:SetVertexColor(unpack(E.media.rgbvaluecolor)) end end)
							popout:HookScript("OnLeave", function(self) if self.icon then self.icon:SetVertexColor(1,1,1) end end)
						end
						if not popout.icon then
							popout.icon = popout:CreateTexture(nil, "ARTWORK")
							popout.icon:Size(24)
							popout.icon:SetPoint("CENTER")
							popout.icon:SetTexture(E.Media.Textures.ArrowUp)
						end
					end
				end
			end
		end
	end

	do
		local i, prev = 1, nil
		while true do
			local tab = _G["PaperDollFrameTab"..i]
			if not tab then break end
			SafeHandleTab(tab)
            tab:SetFrameLevel((_G.CharacterFrame:GetFrameLevel() or 1) + 20)
            if tab.backdrop then
                tab.backdrop:SetFrameLevel(tab:GetFrameLevel() - 1)
            end
			tab:ClearAllPoints()
			if i == 1 then
				tab:SetPoint("BOTTOMLEFT", _G.CharacterFrame, "BOTTOMLEFT", 0, -1)
			else
				tab:SetPoint("LEFT", prev, "RIGHT", 0, 0)
			end
			if tab.backdrop and tab.backdrop.SetInside then
				tab.backdrop:SetInside(tab, 0, 0)
			end
			prev = tab
			i = i + 1
		end
	end

	if _G.PetPaperDollFrame then
		_G.PetPaperDollFrame:StripTextures(true)
		for i = 1, 3 do
			local tab = _G["PetPaperDollFrameTab"..i]
			if not tab then break end
			tab:StripTextures()
			tab:CreateBackdrop("Default", true)
			tab.backdrop:Point("TOPLEFT", 2, -7)
			tab.backdrop:Point("BOTTOMRIGHT", -1, -10)
			if S.SetBackdropHitRect then S:SetBackdropHitRect(tab) end
			if tab.HookScript then
				tab:HookScript("OnEnter", S.SetModifiedBackdrop)
				tab:HookScript("OnLeave", S.SetOriginalBackdrop)
			end
		end
		-- SkinPetFrame runs now and on every pet show (the marble is applied on the first
		-- open, after this one-time pass). It uses HandleButton to avoid HandleRotateButton's
		-- nil-highlight crash.
		_G.PetPaperDollFrame:HookScript("OnShow", SkinPetFrame)
		SkinPetFrame()
	end

--	do
--		local parent = _G.CharacterFrame and _G.CharacterFrame.backdrop
--		if parent then
--			local model = _G.CharacterModelFrame
--			if model and model.StripTextures then model:StripTextures(true) end
--			if parent.__ModelBD then parent.__ModelBD:Hide(); parent.__ModelBD = nil end
--			if model then
--				local bd = CreateFrame("Frame", nil, parent)
--				bd:SetTemplate("Transparent")
--				bd:SetFrameStrata(parent:GetFrameStrata())
--				bd:SetFrameLevel(parent:GetFrameLevel() + 1)
--				bd:SetPoint("TOPLEFT",     model, "TOPLEFT",     -6,  6)
--				bd:SetPoint("BOTTOMRIGHT", model, "BOTTOMRIGHT",  6, -6)
--				parent.__ModelBD = bd
--			end
--
--			local stats = _G.CharacterAttributesFrame
--			if stats and stats.StripTextures then stats:StripTextures(true) end
--			if parent.__StatsBD then parent.__StatsBD:Hide(); parent.__StatsBD = nil end
--			if stats then
--				local raise = (_G.PaperDollFrameTab1 and _G.PaperDollFrameTab1.GetHeight) and (_G.PaperDollFrameTab1:GetHeight() + 8) or 36
--				local bd = CreateFrame("Frame", nil, parent)
--				bd:SetTemplate("Transparent")
--				bd:SetFrameStrata(parent:GetFrameStrata())
--				bd:SetFrameLevel(parent:GetFrameLevel() + 1)
--				bd:SetPoint("TOPLEFT",  stats, "TOPLEFT",  -6,  6)
--				bd:SetPoint("BOTTOMRIGHT", _G.CharacterFrame, "BOTTOMRIGHT", -6, raise)
--				parent.__StatsBD = bd
--			end
--		end
--	end

	do
		local function qualityColor(q)
			if not q or q < 1 then return 0.1,0.1,0.1 end
			local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
			if c then return c.r, c.g, c.b end
			return 1,1,1
		end
		local function updateSlot(slotFrame, slotId)
			if not slotFrame then return end
			local q = GetInventoryItemQuality("player", slotId)
			local r,g,b = qualityColor(q)
			local borderHost = slotFrame.backdrop or slotFrame
			if borderHost.SetBackdropBorderColor then
				borderHost:SetBackdropBorderColor(r, g, b)
			end
		end
		local slotIds = {
			HeadSlot=1, NeckSlot=2, ShoulderSlot=3, ShirtSlot=4, ChestSlot=5, WaistSlot=6, LegsSlot=7, FeetSlot=8,
			WristSlot=9, HandsSlot=10, Finger0Slot=11, Finger1Slot=12, Trinket0Slot=13, Trinket1Slot=14, BackSlot=15,
			MainHandSlot=16, SecondaryHandSlot=17, RangedSlot=18, TabardSlot=19
		}
		local frames = {}
		for name,id in pairs(slotIds) do
			local f = _G["Character"..name]
			if f then frames[id] = f end
		end

        local function updateAllOnce()
            for id,frame in pairs(frames) do
                updateSlot(frame, id)
            end
        end 

		local function updateAll()
            updateAllOnce()
			if C_Timer and C_Timer.After then
				C_Timer.After(0.10, updateAllOnce)
                C_Timer.After(0.25, updateAllOnce)
			end
		end
		local f = CreateFrame("Frame")
		f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
		f:RegisterEvent("UPDATE_INVENTORY_DURABILITY")
		f:RegisterEvent("PLAYER_ENTERING_WORLD")
		f:SetScript("OnEvent", function(_, evt, arg1)
            if evt == "UNIT_INVENTORY_CHANGED" and arg1 ~= "player" then return end
		    updateAll()
        end)
	end
        _G.EUI_UpdateAllSlots = updateAll

	do
		local stats = _G.CharacterAttributesFrame
		if stats then
			for i = 1, stats:GetNumRegions() do
				local r = select(i, stats:GetRegions())
				if r and r.GetText and r:GetText() then
					local txt = r:GetText()
					if txt:find("Основные") or txt:find("Ближний") or txt:find("General") or txt:find("Attributes") or txt:find("Spell") or txt:find("Defense") then
						r:SetTextColor(1, 0.82, 0)
					else
						r:SetTextColor(0.6, 0.9, 0.6)
					end
					if r.FontTemplate then r:FontTemplate(nil, 12) end
				end
			end
		end
	end
	
	do
    local parent = CharacterFrame and CharacterFrame.backdrop
    local bd = parent and parent.__StatsBD
    if bd then
        local raise = (PaperDollFrameTab1 and PaperDollFrameTab1.GetHeight) and (PaperDollFrameTab1:GetHeight() + 6) or 34
        bd:ClearAllPoints()
        bd:SetPoint("TOPLEFT",  CharacterAttributesFrame, "TOPLEFT",  -6,  6)
        bd:SetPoint("BOTTOMRIGHT", CharacterFrame, "BOTTOMRIGHT", -6, raise)
    end
end
	do
    local stats = CharacterAttributesFrame
    if stats then
        for i = 1, stats:GetNumRegions() do
            local r = select(i, stats:GetRegions())
            if r and r.GetText and r:GetText() then
                local t = r:GetText()
                if t:find("Основные") or t:find("Ближний") then
                    r:SetTextColor(1, 0.85, 0)
                    if r.SetFont then r:SetFont(r:GetFont(), 13, "OUTLINE") end
                else
                    r:SetTextColor(0.65, 1, 0.65)
                    if r.SetFont then r:SetFont(r:GetFont(), 12, "OUTLINE") end
                end
            end
        end
    end
end
do
    local toStrip = {
        "PaperDollFrame",
        "CharacterAttributesFrame",
        "PaperDollFrameStrengthenFrame",
        "PaperDollFrameStrengthenScrollBarScrollChildFrame",
        "PaperDollFrameNewPanel",
		"PaperDollFrameEquipInset",
		"PaperDollFrameInset",
    }
    for _, name in ipairs(toStrip) do
        local f = _G[name]
        if f then
            if f.StripTextures then f:StripTextures(true) end
            if f.DisableDrawLayer then
                f:DisableDrawLayer("BACKGROUND")
                f:DisableDrawLayer("BORDER")
                f:DisableDrawLayer("ARTWORK")
            end
            local i = 1
            while true do
                local r = select(i, f:GetRegions())
                if not r then break end
                if r.GetObjectType and r:GetObjectType() == "Texture" then
                    r:SetTexture(nil)
                    r:SetAlpha(0)
                end
                i = i + 1
            end
        end
    end
end

local function SkinStrengthenSB() --скроллбар заебал
    local sb = _G.PaperDollFrameStrengthenScrollBarScrollBar
    if not sb or sb.__MY_SKINNED then return end

    if sb.StripTextures then sb:StripTextures() end
    for _, r in next, {sb.Background, sb.Top, sb.Bottom, sb.Middle, sb.Track} do
        if r and r.Hide then r:Hide() end
    end
    local regs = { sb:GetRegions() }
    for i=1,#regs do
        local tex = regs[i]
        if tex and tex.GetObjectType and tex:GetObjectType()=="Texture" then
            tex:SetTexture(nil); tex:SetAlpha(0)
        end
    end

    local getThumb = sb.GetThumbTexture
    local thumb = sb.ThumbTexture or (getThumb and getThumb(sb))
    if thumb then
        thumb:SetAlpha(0)
        if not sb.__thumb then
			local t = MakeBD(sb)
			t:SetSize(14, 28)
            t:SetBackdrop({ bgFile="Interface/Buttons/WHITE8x8",
                            edgeFile="Interface/Buttons/WHITE8x8", edgeSize=1 })
            t:SetBackdropColor(0,0,0,.75)
            t:SetBackdropBorderColor(0,0,0,1)
            t:SetFrameLevel((sb:GetFrameLevel() or 0) + 10)
            sb.__thumb = t
        end
        sb.__thumb:ClearAllPoints()
        sb.__thumb:SetPoint("CENTER", thumb, "CENTER")
        sb.__thumb:Show()
    end

    local anchor = sb:GetParent() or _G.PaperDollFrameStrengthenFrame or _G.PaperDollFrame
    sb:ClearAllPoints()
    sb:SetPoint("TOPRIGHT",    anchor, "TOPRIGHT",    2, -14)
    sb:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 2,  15)
    sb:SetWidth(20)

    sb.__MY_SKINNED = true
end

local function InstallStrengthenSBHooks()
    C_Timer.After(0, SkinStrengthenSB)
    if _G.CharacterFrame and _G.CharacterFrame.HookScript then
        _G.CharacterFrame:HookScript("OnShow", function() C_Timer.After(0, SkinStrengthenSB) end)
    end
    if _G.PaperDollFrame and _G.PaperDollFrame.HookScript then
        _G.PaperDollFrame:HookScript("OnShow", function() C_Timer.After(0, SkinStrengthenSB) end)
    end
    if _G.PaperDollFrameStrengthenFrame and _G.PaperDollFrameStrengthenFrame.HookScript then
        _G.PaperDollFrameStrengthenFrame:HookScript("OnShow", function() C_Timer.After(0, SkinStrengthenSB) end)
    end
    if _G.CharacterFrame_ShowSubFrame then
        hooksecurefunc("CharacterFrame_ShowSubFrame", function()
            C_Timer.After(0, SkinStrengthenSB)
        end)
    end
    if C_Timer and C_Timer.NewTicker then
        C_Timer.NewTicker(0.10, SkinStrengthenSB, 30)
    end
end

if IsAddOnLoaded and IsAddOnLoaded("Blizzard_CharacterUI") then
    InstallStrengthenSBHooks()
else
    local f = CreateFrame("Frame")
    f:RegisterEvent("ADDON_LOADED")
    f:SetScript("OnEvent", function(_, addon)
        if addon=="Blizzard_CharacterUI" then
            InstallStrengthenSBHooks()
            f:UnregisterEvent("ADDON_LOADED")
        end
    end)
end

local function SkinReputationRow(i)
    local row   = _G["ReputationBar"..i]
    if not row or row.__EUI_skinned then return end

    local name  = _G["ReputationBar"..i.."FactionName"]
    local sb    = _G["ReputationBar"..i.."ReputationBar"]
    local btn   = _G["ReputationBar"..i.."ExpandOrCollapseButton"]
    local warCB = _G["ReputationBar"..i.."AtWarCheck"]

    if row.StripTextures then row:StripTextures(true) end

    if sb then
        if sb.StripTextures then sb:StripTextures(true) end
        if sb.SetStatusBarTexture and E and E.media and E.media.normTex then
            sb:SetStatusBarTexture(E.media.normTex)
        end
        if not sb.backdrop then
            sb:CreateBackdrop("Default", true)
            sb.backdrop:SetFrameLevel(sb:GetFrameLevel() - 1)
        end
        sb:SetHeight(14)
    end

    -- The server manages the +/- expand button per row type, so ElvUI must NOT re-skin it
    -- — HandleCollapseExpandButton noops the setters and breaks the dynamic +/-. The
    -- server also positions the faction title itself.

    if warCB and S and S.HandleCheckBox then
        S:HandleCheckBox(warCB)
    end

    -- Zebra + title plates are applied by the ReputationFrame_SetRowType hook below.

    row.__EUI_skinned = true
end

local function SkinReputation()
    if _G.ReputationFrame then
        _G.ReputationFrame:StripTextures(true)
    end
    if _G.ReputationFrameInset then
        _G.ReputationFrameInset:StripTextures(true)
        _G.ReputationFrameInset:SetAlpha(0)
    end

    local sf = _G.ReputationListScrollFrame
    if sf then
        if sf.StripTextures then sf:StripTextures(true) end
        local sb = sf.ScrollBar or _G.ReputationListScrollFrameScrollBar
        if sb and S and S.HandleScrollBar then
            S:HandleScrollBar(sb)
            sb:ClearAllPoints()
            sb:SetPoint("TOPLEFT",  sf, "TOPRIGHT",  1, -14)
            sb:SetPoint("BOTTOMLEFT", sf, "BOTTOMRIGHT", 1,  15)
        end
    end

    local NUM = _G.NUM_FACTIONS_DISPLAYED or 15
    for i = 1, NUM do
        SkinReputationRow(i)
    end

    local det = _G.ReputationDetailFrame
    if det then
        det:StripTextures(true)
        if det.backdrop then det.backdrop:StripTextures() end
        det:CreateBackdrop("Transparent")
        -- Shrink the panel backdrop 1px in from the right and bottom.
        if det.backdrop then
            det.backdrop:ClearAllPoints()
            det.backdrop:Point("TOPLEFT", det, "TOPLEFT", 0, 0)
            det.backdrop:Point("BOTTOMRIGHT", det, "BOTTOMRIGHT", -1, 1)
        end

        -- The panel is redecorated when it opens, AFTER this one-time strip, so strip its
        -- own textures again on every OnShow so first open matches the reopened state.
        if not det.__euiDetailHooked then
            det.__euiDetailHooked = true
            det:HookScript("OnShow", function(frame)
                if frame.StripTextures then frame:StripTextures(true) end
            end)
        end

        -- Text area: drop the server's CollectionsBackgroundTile, give it a slightly
        -- darker backdrop.
        local tc = _G.ReputationDetailFrameTextContainer
        if tc then
            if tc.BackgroundTile then tc.BackgroundTile:SetTexture(nil); tc.BackgroundTile:Hide() end
            if tc.StripTextures then tc:StripTextures(true) end
            if tc.CreateBackdrop and not tc.backdrop then
                tc:CreateBackdrop("Transparent")
                if tc.backdrop.SetBackdropColor then tc.backdrop:SetBackdropColor(0, 0, 0, 0.55) end
                if tc.backdrop.SetFrameLevel then tc.backdrop:SetFrameLevel(tc:GetFrameLevel()) end
            end
        end

        if _G.ReputationDetailCloseButton and S and S.HandleCloseButton then
            S:HandleCloseButton(_G.ReputationDetailCloseButton)
        end
        if S and S.HandleCheckBox then
            if _G.ReputationDetailAtWarCheckBox       then S:HandleCheckBox(_G.ReputationDetailAtWarCheckBox) end
            if _G.ReputationDetailInactiveCheckBox    then S:HandleCheckBox(_G.ReputationDetailInactiveCheckBox) end
            if _G.ReputationDetailMainScreenCheckBox  then S:HandleCheckBox(_G.ReputationDetailMainScreenCheckBox) end
            if _G.ReputationDetailLFGBonusReputationCheckBox then S:HandleCheckBox(_G.ReputationDetailLFGBonusReputationCheckBox) end
        end
    end
end

if _G.CharacterFrame and _G.CharacterFrame.HookScript then
    _G.CharacterFrame:HookScript("OnShow", function() if _G.ReputationFrame and _G.ReputationFrame:IsShown() then SkinReputation() end end)
end
if _G.ReputationFrame and _G.ReputationFrame.HookScript then
    _G.ReputationFrame:HookScript("OnShow", SkinReputation)
end
if _G.CharacterFrame_ShowSubFrame then
    hooksecurefunc("CharacterFrame_ShowSubFrame", function(frameName)
        if frameName == "ReputationFrame" then SkinReputation() end
    end)
end

C_Timer.After(0, SkinReputation)

-- Reputation rows are recycled as you scroll. ReputationFrame_SetRowType runs per row
-- with a reliable rowType (0/1 = data, 2/3 = headers); refresh the plate + zebra right
-- after so it follows recycled rows across scroll.
if _G.ReputationFrame_SetRowType then
    hooksecurefunc("ReputationFrame_SetRowType", function(factionRow, rowType)
        if not factionRow or not factionRow.GetName then return end
        local i = tonumber((factionRow:GetName() or ""):match("ReputationBar(%d+)$"))
        if not i then return end
        -- rowType 2 = top category (text sign, wants a plate); rowType 3 = sub-category
        -- (already has a +/- dropdown button, so no plate). Both are excluded from zebra.
        SetRowHeaderStyle(factionRow, i, (rowType == 2 or rowType == 3), 0, rowType == 2)
        if rowType == 3 then
            StyleRepExpandButton(_G[factionRow:GetName().."ExpandOrCollapseButton"], factionRow.isCollapsed)
        end
    end)
end
-- The per-row hook only fires during ReputationFrame_Update; force one on show so the
-- plates appear immediately instead of only after the first scroll.
if _G.CharacterFrame and _G.CharacterFrame.HookScript then
    _G.CharacterFrame:HookScript("OnShow", function()
        if _G.ReputationFrame and _G.ReputationFrame:IsShown() and _G.ReputationFrame_Update then
            _G.ReputationFrame_Update()
        end
    end)
end
if _G.ReputationFrame and _G.ReputationFrame.HookScript and _G.ReputationFrame_Update then
    _G.ReputationFrame:HookScript("OnShow", _G.ReputationFrame_Update)
end

local function KillTextures(frame)
    if not frame then return end
    if frame.StripTextures then frame:StripTextures(true) end
    local regs = { frame:GetRegions() }
    for i = 1, #regs do
        local r = regs[i]
        if r and r.GetObjectType and r:GetObjectType() == "Texture" then
            r:SetTexture(nil); r:SetAlpha(0)
        end
    end
    if frame.NineSlice then frame.NineSlice:SetAlpha(0) end
    if frame.Bg then frame.Bg:SetAlpha(0) end
end

local function ClearReputationBackground()
    KillTextures(_G.CharacterFrameInset)
    if _G.CharacterFrameInset then _G.CharacterFrameInset:Hide() end

    local sf = _G.ReputationListScrollFrame
    KillTextures(sf)
    if sf and sf.backdrop then sf.backdrop:Hide() end

    local NUM = _G.NUM_FACTIONS_DISPLAYED or 15
    for i = 1, NUM do
        local bg = _G["ReputationBar"..i.."Background"]
        if bg then bg:Hide(); bg:SetAlpha(0) end
        local row = _G["ReputationBar"..i]
        if row and row.backdrop then row.backdrop:SetAlpha(0) end
    end
end

if _G.ReputationFrame and _G.ReputationFrame.HookScript then
    _G.ReputationFrame:HookScript("OnShow", ClearReputationBackground)
end
if _G.CharacterFrame and _G.CharacterFrame.HookScript then
    _G.CharacterFrame:HookScript("OnShow", function()
        if _G.ReputationFrame and _G.ReputationFrame:IsShown() then
            ClearReputationBackground()
        end
    end)
end
if _G.CharacterFrame_ShowSubFrame then
    hooksecurefunc("CharacterFrame_ShowSubFrame", function(name)
        if name == "ReputationFrame" then ClearReputationBackground() end
    end)
end
C_Timer.After(0, ClearReputationBackground)

local function SkinSkillRow(i)
    -- A skill DATA line is the SkillRankFrame<i> status bar, already styled by the server
    -- (SkillFrame_StyleBar). Fighting it killed its border and pushed rows into the header
    -- above, so leave the bar alone and only add the full-row zebra. The stripe spans from
    -- the name (-309) to just past the bar (+2); the bar is hidden on header slots, so the
    -- zebra follows.
    local bar = _G["SkillRankFrame"..i]
    if not bar then return end

    AddRowStripe(bar, i, 2, false, -309)
end

local function SkinSkills()
    if _G.SkillFrame then _G.SkillFrame:StripTextures(true) end
    if _G.CharacterFrameInset then
        _G.CharacterFrameInset:StripTextures(true)
        _G.CharacterFrameInset:SetAlpha(0)
    end

    local list = _G.SkillListScrollFrame
    if list then
        if list.StripTextures then list:StripTextures(true) end
        local sb = list.ScrollBar or _G.SkillListScrollFrameScrollBar
        if sb and S and S.HandleScrollBar then
            S:HandleScrollBar(sb)
            sb:ClearAllPoints()
            sb:SetPoint("TOPLEFT",  list, "TOPRIGHT",  1, -14)
            sb:SetPoint("BOTTOMLEFT", list, "BOTTOMRIGHT", 1,  15)
        end
    end

    if _G.SkillDetailScrollFrame and _G.SkillDetailScrollFrame.StripTextures then
        _G.SkillDetailScrollFrame:StripTextures(true)
    end
    local dSB = _G.SkillDetailScrollFrame and (_G.SkillDetailScrollFrame.ScrollBar or _G.SkillDetailScrollFrameScrollBar)
    if dSB and S and S.HandleScrollBar then
        S:HandleScrollBar(dSB)
    end

    -- The skill detail status bar is coloured/valued by the server; overriding it made
    -- it read as an empty box, so leave it to the server like the list bars.

    -- The "All" button is a server-built tab. HandleCollapseExpandButton left a broken
    -- +/- square, so hide the server atlas, give it a flat ElvUI backdrop + hover, and
    -- drive a +/- sign from the server's own SkillFrame_StyleAllButton(btn, collapsed).
    local allTab = _G.SkillFrameExpandButtonFrame
    if allTab then
        for _, k in ipairs({ "capL", "capR", "body" }) do
            if allTab[k] and allTab[k].SetAlpha then allTab[k]:SetAlpha(0) end
        end
    end
    -- Keep the server's yellow +/- texture hidden and show our own text sign;
    -- collapsed=true (all collapsed) => "+", expanded => "-".
    local function UpdateAllBtnSign(btn, collapsed)
        if not btn or not btn.CreateFontString then return end
        if btn.SetNormalTexture then btn:SetNormalTexture("") end
        if btn.SetPushedTexture then btn:SetPushedTexture("") end
        local nt = btn.GetNormalTexture and btn:GetNormalTexture()
        if nt then nt:SetTexture(nil) end
        if not btn.__euiSign then
            local fs = btn:CreateFontString(nil, "OVERLAY")
            if fs.FontTemplate then fs:FontTemplate(nil, 18) end
            btn.__euiSign = fs
        end
        btn.__euiSign:SetText(collapsed and "+" or "-")
        -- The server centres the "All" label off-centre, leaving label + sign lopsided;
        -- group them centred (label just left of centre, sign right after it).
        local label = btn.GetFontString and btn:GetFontString()
        if label then
            label:ClearAllPoints()
            label:SetPoint("CENTER", btn, "CENTER", -6, 0)
            btn.__euiSign:ClearAllPoints()
            btn.__euiSign:SetPoint("LEFT", label, "RIGHT", 4, 0)
        else
            btn.__euiSign:ClearAllPoints()
            btn.__euiSign:SetPoint("CENTER", btn, "CENTER", 0, 0)
        end
    end

    local allBtn = _G.SkillFrameCollapseAllButton
    if allBtn then
        if allBtn.SetHighlightTexture then allBtn:SetHighlightTexture("") end
        if allBtn.CreateBackdrop and not allBtn.backdrop then
            allBtn:CreateBackdrop("Default", true)
            if allBtn.HookScript then
                allBtn:HookScript("OnEnter", S.SetModifiedBackdrop)
                allBtn:HookScript("OnLeave", S.SetOriginalBackdrop)
            end
        end
        -- Set the sign now — StyleAllButton fires only on toggle, so without this the
        -- +/- appeared only after the first click. isExpanded == 1 => expanded.
        UpdateAllBtnSign(allBtn, allBtn.isExpanded ~= 1)
    end
    if _G.SkillFrame_StyleAllButton and not S.__euiAllBtnHooked then
        S.__euiAllBtnHooked = true
        hooksecurefunc("SkillFrame_StyleAllButton", UpdateAllBtnSign)
    end
    if _G.SkillFrameFilterCheckButton and S and S.HandleCheckBox then
        S:HandleCheckBox(_G.SkillFrameFilterCheckButton)
    end

    local NUM = _G.SKILLS_TO_DISPLAY or 12
    for i = 1, NUM do
        SkinSkillRow(i)
    end
end

if _G.SkillFrame and _G.SkillFrame.HookScript then
    _G.SkillFrame:HookScript("OnShow", SkinSkills)
end
if _G.CharacterFrame and _G.CharacterFrame.HookScript then
    _G.CharacterFrame:HookScript("OnShow", function()
        if _G.SkillFrame and _G.SkillFrame:IsShown() then SkinSkills() end
    end)
end
if _G.CharacterFrame_ShowSubFrame then
    hooksecurefunc("CharacterFrame_ShowSubFrame", function(name)
        if name == "SkillFrame" then SkinSkills() end
    end)
end
C_Timer.After(0, function() if _G.SkillFrame and _G.SkillFrame:IsShown() then SkinSkills() end end)

local function KillTex(f) if not f or not f.GetRegions then return end local t={f:GetRegions()} for i=1,#t do local r=t[i] if r and r.GetObjectType and r:GetObjectType()=="Texture" then if r.Hide then r:Hide() end if r.SetAlpha then r:SetAlpha(0) end if r.SetTexture then r:SetTexture(nil) end end end end

local function FindHeaderFS(row)
  local regs={row:GetRegions()}
  for i=1,#regs do local r=regs[i]; if r and r.GetObjectType and r:GetObjectType()=="FontString" then local tx=r:GetText(); if tx and tx~="" then return r end end end
  return row.text or row.Text or row:GetFontString()
end

local function StyleHeader(row)
  -- The server renders currency category headers itself (catPlate + +/- catSign + label,
  -- like the skills tab). The old code wiped that with KillTex and re-centred the label;
  -- leave the server styling alone and just hide the leftover old category art.
  for _,r in next,{row.CategoryLeft,row.CategoryRight,row.CategoryMiddle,row.Left,row.Right,row.Middle,row.Bg,row.Background,row.Highlight} do if r and r.Hide then r:Hide() end end
  if row.__hdr then row.__hdr:Hide() end
end

local function StyleNormal(row)
  if row.Highlight then row.Highlight:Hide() end
  for _,r in next,{row.Left,row.Right,row.Middle,row.Bg,row.Background,row.Highlight} do if r and r.Hide then r:Hide() end end
  local icon = row.icon or row.Icon
	if icon then
    icon:SetDesaturated(false)
    icon:SetVertexColor(1,1,1)
    icon:SetAlpha(1)
    -- The server draws ring emblems (honor/arena) at 20x20 while other currency icons are
    -- 15x15; force a uniform 15x15 and crop the emblems to fill so they match.
    local tex = icon.GetTexture and icon:GetTexture()
    if type(tex) == "string" and tex:lower():find("pvpcurrency", 1, true) then
        icon:SetTexCoord(0.171875, 0.859375, 0.140625, 0.828125)
    else
        icon:SetTexCoord(.08, .92, .08, .92)
    end
    icon:SetSize(15, 15)
    icon:SetDrawLayer("ARTWORK", 1)

    if not icon.backdrop then
        local b = CreateFrame("Frame", nil, row, BACKDROP_TPL)
        b:SetPoint("TOPLEFT",  icon, -1,  1)
        b:SetPoint("BOTTOMRIGHT", icon,  1, -1)
        b:SetFrameLevel((row:GetFrameLevel() or 2) - 1)
        b:SetBackdrop({ edgeFile = "Interface/Buttons/WHITE8x8", edgeSize = 1 })
        b:SetBackdropBorderColor(0,0,0,1)
        icon.backdrop = b
    else
        icon.backdrop:SetFrameLevel((row:GetFrameLevel() or 2) - 1)
    end
end
  local watch=row.Watch or row.watch or row.Check or row.WatchCheck
  if watch and S and S.HandleCheckBox then S:HandleCheckBox(watch) end
end

local function FixTokenIcon(icon)
    if not icon or icon.__patched then return end
    icon._SetDesaturated = icon.SetDesaturated
    icon._SetVertexColor = icon.SetVertexColor
    icon.SetDesaturated = function(self, _)  return self:_SetDesaturated(false) end
    icon.SetVertexColor = function(self, _,_,_,a) return self:_SetVertexColor(1,1,1,a) end
    icon:_SetDesaturated(false)
    icon:_SetVertexColor(1,1,1, icon:GetAlpha() or 1)
    icon.__patched = true
end

local function SkinTokenRow(i)
    local row = _G["TokenFrameContainerButton"..i]
    if not row then return end

    -- wantPlate=false: the server already draws the header plate (catPlate); we only
    -- need the zebra exclusion here (header rows get no stripe).
    SetRowHeaderStyle(row, i, row.isHeader, 0, false)

    if row.isHeader then
        StyleHeader(row)
    else
        StyleNormal(row)
        local ic = row.icon or row.Icon
        if ic then
            FixTokenIcon(ic)
            if not ic.backdrop then
                local b = MakeBD(row)
                b:SetPoint("TOPLEFT", ic, -1, 1)
                b:SetPoint("BOTTOMRIGHT", ic, 1, -1)
                b:SetFrameLevel((row:GetFrameLevel() or 2) + 2)
                ic.backdrop = b
            end
        end
        for _, k in next, {"IconBorder","iconBorder","IconOverlay","iconOverlay","DisabledIcon","disabledIcon"} do
            local t = row[k]; if t then t:Hide(); t:SetAlpha(0) end
        end
    end
end


local function SkinTokenPopup()
  local f=_G.TokenFramePopup; if not f then return end
  f:StripTextures(true)
  -- The popup carries a stock UI-DialogBox frame backdrop that StripTextures can't remove
  -- (showed up white); clear it and give it a dark ElvUI backdrop.
  if f.SetBackdrop then f:SetBackdrop(nil) end
  if f.CreateBackdrop and not f.backdrop then
    f:CreateBackdrop("Transparent")
    if f.backdrop.SetBackdropColor then f.backdrop:SetBackdropColor(0, 0, 0, 0.55) end
  end
  if _G.TokenFramePopupCloseButton and S and S.HandleCloseButton then S:HandleCloseButton(_G.TokenFramePopupCloseButton) end
  if S and S.HandleCheckBox then
    if _G.TokenFramePopupInactiveCheckBox then S:HandleCheckBox(_G.TokenFramePopupInactiveCheckBox) end
    if _G.TokenFramePopupBackpackCheckBox then S:HandleCheckBox(_G.TokenFramePopupBackpackCheckBox) end
  end
end

local function SkinTokenFrame()
  if CharacterFrameInset then CharacterFrameInset:StripTextures(true) CharacterFrameInset:Hide() CharacterFrameInset:SetAlpha(0) end
  if TokenFrame then TokenFrame:StripTextures(true) end
  if TokenFrameContainer and TokenFrameContainer.StripTextures then TokenFrameContainer:StripTextures(true) end
  local sb=(TokenFrameContainer and (TokenFrameContainer.ScrollBar or TokenFrameContainer.Scrollbar)) or TokenFrameContainerScrollBar
  if sb and S and S.HandleScrollBar then S:HandleScrollBar(sb) end
  for i=1,30 do SkinTokenRow(i) end
  SkinTokenPopup()
end

if TokenFrame and TokenFrame.HookScript then TokenFrame:HookScript("OnShow", SkinTokenFrame) end
if CharacterFrame and CharacterFrame.HookScript then CharacterFrame:HookScript("OnShow", function() if TokenFrame and TokenFrame:IsShown() then SkinTokenFrame() end end) end
if CharacterFrame_ShowSubFrame then hooksecurefunc("CharacterFrame_ShowSubFrame", function(n) if n=="TokenFrame" then SkinTokenFrame() end end) end
if TokenFramePopup and TokenFramePopup.HookScript then TokenFramePopup:HookScript("OnShow", SkinTokenPopup) end
C_Timer.After(0, function() if TokenFrame and TokenFrame:IsShown() then SkinTokenFrame() end end)

hooksecurefunc("TokenFrame_Update", function()
    for i=1,30 do SkinTokenRow(i) end
    SkinTokenPopup()
end)

end

local function EUI_ApplyCharacterDecor()
	if CharacterFrame and CharacterFrame:IsShown() and _G.EUI_UpdateAllSlots then
		_G.EUI_UpdateAllSlots()
	end
end

if CharacterFrame and CharacterFrame.HookScript then
	CharacterFrame:HookScript("OnShow", EUI_ApplyCharacterDecor)
end
if hooksecurefunc then
	hooksecurefunc("PaperDollFrame_UpdateStats", EUI_ApplyCharacterDecor)
	hooksecurefunc("PaperDollItemSlotButton_Update", EUI_ApplyCharacterDecor)
end

S:AddCallback("Skin_Character", LoadSkin)
