-- NozdorCharacter — контентный скин окна персонажа (CharacterFrame).
--
-- "Хром" окна (рамка/фон/крестик/finder-табы наверху) скинится автоматически в
-- NozdorChrome.lua через хук MetalFrame2X_Rebuild. Здесь — только внутренности:
-- слоты экипировки, характеристики, репутация/навыки/валюта, менеджер экипировки,
-- выбор титула, кнопки поворота модели и кастомная панель "Усиление".
--
-- Применяется по событию Skins-модуля (S:AddCallback) + отложенно на OnShow
-- подкадров, как принято в скинах ElvUI.

local E, L, V, P, G = unpack(select(2, ...)) --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local S = E:GetModule("Skins")

local _G = _G
local ipairs, pairs, select, unpack, next = ipairs, pairs, select, unpack, next
local hooksecurefunc = hooksecurefunc
local C_Timer = C_Timer
local GetInventoryItemQuality = GetInventoryItemQuality

local function gated()
	return E.private.skins.blizzard.enable == true and E.private.skins.blizzard.character == true
end

-- Стрип текстур + скрытие остатков (используем там, где StripTextures мало).
local function killTextures(frame)
	if not frame then return end
	if frame.StripTextures then frame:StripTextures(true) end
	if frame.GetRegions then
		local regs = { frame:GetRegions() }
		for i = 1, #regs do
			local r = regs[i]
			if r and r.GetObjectType and r:GetObjectType() == "Texture" then
				if r.SetTexture then r:SetTexture(nil) end
				if r.SetAlpha then r:SetAlpha(0) end
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Слоты экипировки + цветная рамка по качеству предмета
--------------------------------------------------------------------------------

local SLOT_IDS = {
	HeadSlot = 1, NeckSlot = 2, ShoulderSlot = 3, ShirtSlot = 4, ChestSlot = 5,
	WaistSlot = 6, LegsSlot = 7, FeetSlot = 8, WristSlot = 9, HandsSlot = 10,
	Finger0Slot = 11, Finger1Slot = 12, Trinket0Slot = 13, Trinket1Slot = 14,
	BackSlot = 15, MainHandSlot = 16, SecondaryHandSlot = 17, RangedSlot = 18,
	TabardSlot = 19, AmmoSlot = 20,
}

local function qualityColor(q)
	if not q or q < 1 then return 0.1, 0.1, 0.1 end
	local c = _G.ITEM_QUALITY_COLORS and _G.ITEM_QUALITY_COLORS[q]
	if c then return c.r, c.g, c.b end
	return 1, 1, 1
end

local function updateSlotBorder(slotFrame, slotId)
	if not slotFrame then return end
	local r, g, b = qualityColor(GetInventoryItemQuality("player", slotId))
	local host = slotFrame.backdrop or slotFrame
	if host.SetBackdropBorderColor then
		host:SetBackdropBorderColor(r, g, b)
	end
end

local slotFrames = {}

local function updateAllSlots()
	for id, frame in pairs(slotFrames) do
		updateSlotBorder(frame, id)
	end
end

local function skinPaperDollSlots()
	if not _G.PaperDollFrame then return end
	for name, id in pairs(SLOT_IDS) do
		local slotFrame = _G["Character" .. name]
		if slotFrame and not slotFrame.__nozdorSkinned then
			slotFrame.__nozdorSkinned = true
			slotFrames[id] = slotFrame

			local icon = _G["Character" .. name .. "IconTexture"]
			slotFrame:StripTextures()
			if slotFrame.StyleButton then slotFrame:StyleButton(false) end
			if slotFrame.SetTemplate then slotFrame:SetTemplate("Default", true, true) end
			if icon then
				if icon.SetInside then icon:SetInside() end
				icon:SetTexCoord(unpack(E.TexCoords))
			end
			slotFrame:SetFrameLevel((_G.PaperDollFrame:GetFrameLevel() or 1) + 10)
			if slotFrame.backdrop then
				slotFrame.backdrop:SetFrameLevel(slotFrame:GetFrameLevel() + 1)
			end

			if id ~= 20 then
				local cooldown = _G["Character" .. name .. "Cooldown"]
				local popout = _G["Character" .. name .. "PopoutButton"]
				if cooldown and E.RegisterCooldown then E:RegisterCooldown(cooldown) end
				if popout then
					popout:StripTextures()
					if not popout.icon then
						popout.icon = popout:CreateTexture(nil, "ARTWORK")
						popout.icon:Size(24)
						popout.icon:SetPoint("CENTER")
						popout.icon:SetTexture(E.Media.Textures.ArrowUp)
					end
					popout:HookScript("OnEnter", function(self)
						if self.icon then self.icon:SetVertexColor(unpack(E.media.rgbvaluecolor)) end
					end)
					popout:HookScript("OnLeave", function(self)
						if self.icon then self.icon:SetVertexColor(1, 1, 1) end
					end)
				end
			end
		end
	end
	updateAllSlots()
end

--------------------------------------------------------------------------------
-- Модель персонажа: кнопки поворота
--------------------------------------------------------------------------------

local function skinRotateButtons()
	if not S.HandleRotateButton then return end
	local f = _G.CharacterModelFrame
	local left = _G.CharacterModelFrameRotateLeftButton or (f and f.RotateLeftButton) or _G.PaperDollFrameRotateLeftButton
	local right = _G.CharacterModelFrameRotateRightButton or (f and f.RotateRightButton) or _G.PaperDollFrameRotateRightButton
	if left then S:HandleRotateButton(left) end
	if right then S:HandleRotateButton(right) end

	if _G.PetPaperDollFrame then
		local pl, pr = _G.PetModelFrameRotateLeftButton, _G.PetModelFrameRotateRightButton
		if pl then S:HandleRotateButton(pl) end
		if pr then S:HandleRotateButton(pr) end
	end
end

--------------------------------------------------------------------------------
-- Характеристики
--------------------------------------------------------------------------------

local function skinAttributes()
	local stats = _G.CharacterAttributesFrame
	if not stats then return end
	stats:StripTextures()
	for i = 1, stats:GetNumRegions() do
		local r = select(i, stats:GetRegions())
		if r and r.GetText and r:GetText() then
			local txt = r:GetText()
			if txt:find("Основные") or txt:find("Ближний") or txt:find("General")
				or txt:find("Attributes") or txt:find("Spell") or txt:find("Defense") then
				r:SetTextColor(1, 0.82, 0)
			else
				r:SetTextColor(0.65, 0.9, 0.65)
			end
			if r.FontTemplate then r:FontTemplate(nil, 12) end
		end
	end
end

--------------------------------------------------------------------------------
-- Утопленные панели (инсеты) — прячем стоковые текстуры
--------------------------------------------------------------------------------

local function stripInsets()
	local toStrip = {
		"PaperDollFrame", "CharacterAttributesFrame",
		"PaperDollFrameStrengthenFrame",
		"PaperDollFrameStrengthenScrollBarScrollChildFrame",
		"PaperDollFrameNewPanel", "PaperDollFrameEquipInset", "PaperDollFrameInset",
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
		end
	end
end

--------------------------------------------------------------------------------
-- Менеджер экипировки (GearManagerDialog)
--------------------------------------------------------------------------------

local function skinGearManager()
	if not _G.GearManagerDialog or _G.GearManagerDialog.__nozdorSkinned then return end
	_G.GearManagerDialog.__nozdorSkinned = true

	_G.GearManagerDialog:StripTextures()
	_G.GearManagerDialog:CreateBackdrop("Transparent")
	_G.GearManagerDialog.backdrop:Point("TOPLEFT", 5, -2)
	_G.GearManagerDialog.backdrop:Point("BOTTOMRIGHT", -1, 4)

	for i = 1, 10 do
		local b = _G["GearSetButton" .. i]
		if b then
			b:StripTextures()
			if b.StyleButton then b:StyleButton() end
			b:CreateBackdrop("Default")
			b.backdrop:SetAllPoints()
			local icon = _G["GearSetButton" .. i .. "Icon"]
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
	if _G.GearManagerToggleButton and S.HandleButton then
		S:HandleButton(_G.GearManagerToggleButton)
	end
end

--------------------------------------------------------------------------------
-- Выбор титула
--------------------------------------------------------------------------------

local function skinTitlePicker()
	if _G.PlayerTitleFrame and not _G.PlayerTitleFrame.__nozdorSkinned then
		_G.PlayerTitleFrame.__nozdorSkinned = true
		_G.PlayerTitleFrame:StripTextures()
		_G.PlayerTitleFrame:CreateBackdrop("Default")
		_G.PlayerTitleFrame.backdrop:Point("TOPLEFT", 20, 3)
		_G.PlayerTitleFrame.backdrop:Point("BOTTOMRIGHT", -16, 15)
		_G.PlayerTitleFrame.backdrop:SetFrameLevel(_G.PlayerTitleFrame:GetFrameLevel())
	end

	if _G.PlayerTitleFrameButton and S.HandleNextPrevButton and not _G.PlayerTitleFrameButton.isSkinned then
		S:HandleNextPrevButton(_G.PlayerTitleFrameButton)
		_G.PlayerTitleFrameButton:Size(16)
		if _G.PlayerTitleFrameRight then
			_G.PlayerTitleFrameButton:Point("TOPRIGHT", _G.PlayerTitleFrameRight, "TOPRIGHT", -18, -16)
		end
	end

	if _G.PlayerTitlePickerFrame and not _G.PlayerTitlePickerFrame.__nozdorSkinned then
		_G.PlayerTitlePickerFrame.__nozdorSkinned = true
		_G.PlayerTitlePickerFrame:StripTextures()
		_G.PlayerTitlePickerFrame:CreateBackdrop("Transparent")
		_G.PlayerTitlePickerFrame.backdrop:Point("TOPLEFT", 6, -10)
		_G.PlayerTitlePickerFrame.backdrop:Point("BOTTOMRIGHT", -13, 6)
		_G.PlayerTitlePickerFrame.backdrop:SetFrameLevel(_G.PlayerTitlePickerFrame:GetFrameLevel())
	end

	if _G.PlayerTitlePickerScrollFrame and _G.PlayerTitlePickerScrollFrame.buttons then
		for _, button in ipairs(_G.PlayerTitlePickerScrollFrame.buttons) do
			if button.text and button.text.FontTemplate then button.text:FontTemplate() end
			if S.HandleButtonHighlight then S:HandleButtonHighlight(button) end
		end
	end
end

--------------------------------------------------------------------------------
-- Репутация
--------------------------------------------------------------------------------

local function skinReputationRow(i)
	local row = _G["ReputationBar" .. i]
	if not row or row.__nozdorSkinned then return end

	local name = _G["ReputationBar" .. i .. "FactionName"]
	local sb = _G["ReputationBar" .. i .. "ReputationBar"]
	local btn = _G["ReputationBar" .. i .. "ExpandOrCollapseButton"]
	local warCB = _G["ReputationBar" .. i .. "AtWarCheck"]

	if row.StripTextures then row:StripTextures(true) end

	if sb then
		if sb.StripTextures then sb:StripTextures(true) end
		if sb.SetStatusBarTexture and E.media.normTex then sb:SetStatusBarTexture(E.media.normTex) end
		if not sb.backdrop then
			sb:CreateBackdrop("Default", true)
			sb.backdrop:SetFrameLevel(sb:GetFrameLevel() - 1)
		end
		sb:SetHeight(14)
	end

	if btn and S.HandleCollapseExpandButton then
		S:HandleCollapseExpandButton(btn, "+")
	end
	if warCB and S.HandleCheckBox then S:HandleCheckBox(warCB) end
	if name and btn then
		name:ClearAllPoints()
		name:SetPoint("LEFT", btn, "RIGHT", 4, 0)
	end

	row.__nozdorSkinned = true
end

local function skinReputation()
	if _G.ReputationFrame then _G.ReputationFrame:StripTextures(true) end
	if _G.ReputationFrameInset then
		_G.ReputationFrameInset:StripTextures(true)
		_G.ReputationFrameInset:SetAlpha(0)
	end
	if _G.CharacterFrameInset then
		killTextures(_G.CharacterFrameInset)
		_G.CharacterFrameInset:Hide()
	end

	local sf = _G.ReputationListScrollFrame
	if sf then
		if sf.StripTextures then sf:StripTextures(true) end
		local sb = sf.ScrollBar or _G.ReputationListScrollFrameScrollBar
		if sb and S.HandleScrollBar then
			S:HandleScrollBar(sb)
			sb:ClearAllPoints()
			sb:SetPoint("TOPLEFT", sf, "TOPRIGHT", 1, -14)
			sb:SetPoint("BOTTOMLEFT", sf, "BOTTOMRIGHT", 1, 15)
		end
	end

	local NUM = _G.NUM_FACTIONS_DISPLAYED or 15
	for i = 1, NUM do
		skinReputationRow(i)
		local bg = _G["ReputationBar" .. i .. "Background"]
		if bg then bg:Hide(); bg:SetAlpha(0) end
	end

	local det = _G.ReputationDetailFrame
	if det and not det.__nozdorSkinned then
		det.__nozdorSkinned = true
		det:StripTextures(true)
		det:CreateBackdrop("Transparent")
		if _G.ReputationDetailCloseButton and S.HandleCloseButton then
			S:HandleCloseButton(_G.ReputationDetailCloseButton)
		end
		if S.HandleCheckBox then
			for _, cb in ipairs({
				"ReputationDetailAtWarCheckBox", "ReputationDetailInactiveCheckBox",
				"ReputationDetailMainScreenCheckBox", "ReputationDetailLFGBonusReputationCheckBox",
			}) do
				if _G[cb] then S:HandleCheckBox(_G[cb]) end
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Навыки
--------------------------------------------------------------------------------

local function skinSkillRow(i)
	local name = _G["SkillName" .. i]
	if not name or name.__nozdorSkinned then return end

	local btn = _G["SkillExpandButton" .. i]
	local rank = _G["SkillRankFrame" .. i]
	local border = _G["SkillRankFrame" .. i .. "Border"]

	if btn and S.HandleCollapseExpandButton then S:HandleCollapseExpandButton(btn, "+") end
	if rank then
		if rank.StripTextures then rank:StripTextures(true) end
		if border then border:Hide() end
		if rank.SetStatusBarTexture and E.media.normTex then rank:SetStatusBarTexture(E.media.normTex) end
		rank:SetHeight(12)
		if not rank.backdrop then
			rank:CreateBackdrop("Default", true)
			rank.backdrop:SetFrameLevel(rank:GetFrameLevel() - 1)
		end
	end

	name.__nozdorSkinned = true
end

local function skinSkills()
	if _G.SkillFrame then _G.SkillFrame:StripTextures(true) end
	if _G.CharacterFrameInset then
		_G.CharacterFrameInset:StripTextures(true)
		_G.CharacterFrameInset:SetAlpha(0)
	end

	local list = _G.SkillListScrollFrame
	if list then
		if list.StripTextures then list:StripTextures(true) end
		local sb = list.ScrollBar or _G.SkillListScrollFrameScrollBar
		if sb and S.HandleScrollBar then
			S:HandleScrollBar(sb)
			sb:ClearAllPoints()
			sb:SetPoint("TOPLEFT", list, "TOPRIGHT", 1, -14)
			sb:SetPoint("BOTTOMLEFT", list, "BOTTOMRIGHT", 1, 15)
		end
	end

	if _G.SkillDetailScrollFrame and _G.SkillDetailScrollFrame.StripTextures then
		_G.SkillDetailScrollFrame:StripTextures(true)
	end
	local dSB = _G.SkillDetailScrollFrame and (_G.SkillDetailScrollFrame.ScrollBar or _G.SkillDetailScrollFrameScrollBar)
	if dSB and S.HandleScrollBar then S:HandleScrollBar(dSB) end

	local detailBar = _G.SkillDetailStatusBar or _G.SkillRankFrame
	local detailBorder = _G.SkillDetailStatusBarBorder
	if detailBar then
		if detailBar.StripTextures then detailBar:StripTextures(true) end
		if detailBorder then detailBorder:Hide() end
		if detailBar.SetStatusBarTexture and E.media.normTex then detailBar:SetStatusBarTexture(E.media.normTex) end
		detailBar:SetHeight(12)
		if not detailBar.backdrop then
			detailBar:CreateBackdrop("Default", true)
			detailBar.backdrop:SetFrameLevel(detailBar:GetFrameLevel() - 1)
		end
	end

	if _G.SkillFrameCollapseAllButton and S.HandleCollapseExpandButton then
		S:HandleCollapseExpandButton(_G.SkillFrameCollapseAllButton, "+")
	end
	if _G.SkillFrameFilterCheckButton and S.HandleCheckBox then
		S:HandleCheckBox(_G.SkillFrameFilterCheckButton)
	end

	local NUM = _G.SKILLS_TO_DISPLAY or 12
	for i = 1, NUM do skinSkillRow(i) end
end

--------------------------------------------------------------------------------
-- Валюта (TokenFrame)
--------------------------------------------------------------------------------

local function skinTokenRow(i)
	local row = _G["TokenFrameContainerButton" .. i]
	if not row then return end

	if row.Highlight then row.Highlight:Hide() end
	for _, r in next, { row.CategoryLeft, row.CategoryRight, row.CategoryMiddle, row.Left, row.Right, row.Middle, row.Bg, row.Background } do
		if r and r.Hide then r:Hide() end
	end

	if not row.isHeader then
		local icon = row.icon or row.Icon
		if icon then
			icon:SetDesaturated(false)
			icon:SetVertexColor(1, 1, 1)
			icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			if not icon.backdrop then
				icon:CreateBackdrop("Default")
				icon.backdrop:SetOutside(icon)
			end
		end
		for _, k in next, { "IconBorder", "iconBorder", "DisabledIcon", "disabledIcon" } do
			local t = row[k]
			if t then t:Hide(); t:SetAlpha(0) end
		end
	end
end

local function skinTokenPopup()
	local f = _G.TokenFramePopup
	if not f then return end
	if not f.__nozdorSkinned then
		f.__nozdorSkinned = true
		f:StripTextures(true)
		f:CreateBackdrop("Transparent")
		if _G.TokenFramePopupCloseButton and S.HandleCloseButton then
			S:HandleCloseButton(_G.TokenFramePopupCloseButton)
		end
		if S.HandleCheckBox then
			if _G.TokenFramePopupInactiveCheckBox then S:HandleCheckBox(_G.TokenFramePopupInactiveCheckBox) end
			if _G.TokenFramePopupBackpackCheckBox then S:HandleCheckBox(_G.TokenFramePopupBackpackCheckBox) end
		end
	end
end

local function skinTokenFrame()
	if _G.CharacterFrameInset then
		_G.CharacterFrameInset:StripTextures(true)
		_G.CharacterFrameInset:Hide()
		_G.CharacterFrameInset:SetAlpha(0)
	end
	if _G.TokenFrame then _G.TokenFrame:StripTextures(true) end
	if _G.TokenFrameContainer and _G.TokenFrameContainer.StripTextures then
		_G.TokenFrameContainer:StripTextures(true)
	end
	local sb = (_G.TokenFrameContainer and (_G.TokenFrameContainer.ScrollBar or _G.TokenFrameContainer.Scrollbar)) or _G.TokenFrameContainerScrollBar
	if sb and S.HandleScrollBar then S:HandleScrollBar(sb) end
	for i = 1, 30 do skinTokenRow(i) end
	skinTokenPopup()
end

--------------------------------------------------------------------------------
-- Кастомная панель "Усиление" (NOZDOR): скроллбар
--------------------------------------------------------------------------------

local function skinStrengthenScrollBar()
	local sb = _G.PaperDollFrameStrengthenScrollBarScrollBar
	if not sb or sb.__nozdorSkinned then return end
	sb.__nozdorSkinned = true
	if S.HandleScrollBar then S:HandleScrollBar(sb) end
end

--------------------------------------------------------------------------------
-- Регистрация подкадров: OnShow + hooksecurefunc(CharacterFrame_ShowSubFrame)
--------------------------------------------------------------------------------

local function hookSubFrame(frameName, skinFunc)
	local f = _G[frameName]
	if f and f.HookScript then
		f:HookScript("OnShow", skinFunc)
	end
	if _G.CharacterFrame and _G.CharacterFrame.HookScript then
		_G.CharacterFrame:HookScript("OnShow", function()
			if _G[frameName] and _G[frameName]:IsShown() then skinFunc() end
		end)
	end
end

--------------------------------------------------------------------------------
-- Главная точка входа
--------------------------------------------------------------------------------

local function LoadCharacterSkin()
	if not gated() then return end

	skinPaperDollSlots()
	skinRotateButtons()
	skinAttributes()
	stripInsets()
	skinGearManager()
	skinTitlePicker()
	skinStrengthenScrollBar()

	-- Подкадры вкладок: скиним при показе.
	hookSubFrame("ReputationFrame", skinReputation)
	hookSubFrame("SkillFrame", skinSkills)
	hookSubFrame("TokenFrame", skinTokenFrame)

	if _G.CharacterFrame_ShowSubFrame then
		hooksecurefunc("CharacterFrame_ShowSubFrame", function(name)
			if name == "ReputationFrame" then skinReputation()
			elseif name == "SkillFrame" then skinSkills()
			elseif name == "TokenFrame" then skinTokenFrame() end
		end)
	end

	-- Обновление цветной рамки слотов по качеству при смене экипировки.
	if _G.CharacterFrame and _G.CharacterFrame.HookScript then
		_G.CharacterFrame:HookScript("OnShow", function()
			skinPaperDollSlots()
			updateAllSlots()
		end)
	end
	if hooksecurefunc then
		if _G.PaperDollItemSlotButton_Update then
			hooksecurefunc("PaperDollItemSlotButton_Update", updateAllSlots)
		end
	end

	local ev = CreateFrame("Frame")
	ev:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
	ev:RegisterEvent("UPDATE_INVENTORY_DURABILITY")
	ev:RegisterEvent("PLAYER_ENTERING_WORLD")
	ev:SetScript("OnEvent", function()
		if _G.CharacterFrame and _G.CharacterFrame:IsShown() then updateAllSlots() end
	end)

	-- Отложенно — на случай, если окно уже открыто в момент инициализации.
	if C_Timer and C_Timer.After then
		C_Timer.After(0, function()
			if _G.ReputationFrame and _G.ReputationFrame:IsShown() then skinReputation() end
			if _G.SkillFrame and _G.SkillFrame:IsShown() then skinSkills() end
			if _G.TokenFrame and _G.TokenFrame:IsShown() then skinTokenFrame() end
		end)
	end
end

S:AddCallback("Nozdor_Character", LoadCharacterSkin)
