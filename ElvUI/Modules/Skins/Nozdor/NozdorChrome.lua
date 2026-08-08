-- NozdorChrome — авто-скин "хрома" retail-подобных окон NOZDOR.
--
-- Архитектура (ГИБРИД): рамка окна = авто. Мы ОДИН раз хукаем глобальную
-- MetalFrame2X_Rebuild (см. Interface/FrameXML/Custom_UITemplate2X). Как только
-- любое текущее ИЛИ будущее окно перестраивает себя в металлический стиль, этот
-- пост-хук приводит его к тёмному плоскому виду ElvUI:
--   * гасит металлическую рамку MetalFrameBorder2X (углы/края) и мраморную
--     подложку, которую кладёт сам Rebuild;
--   * прячет стоковый хром Blizzard-портретных окон (Bg / TopTileStreaks /
--     портрет / старые углы-бордеры), т.к. фоном становится ElvUI-шаблон;
--   * ставит frame:SetTemplate("Transparent");
--   * приводит крестик к S:HandleCloseButton;
--   * скинит finder-табы (NozdorFinderTabButtonTemplate) через S:HandleTab.
--
-- Контент каждого окна (слоты, статы, вкладки, кнопки) скинится отдельными
-- файлами Nozdor<Window>.lua — здесь только общий "хром".

local E, L, V, P, G = unpack(select(2, ...)) --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local S = E:GetModule("Skins")

local _G = _G
local ipairs = ipairs
local type = type
local hooksecurefunc = hooksecurefunc
local C_Timer = C_Timer

-- Части металлической рамки MetalFrameBorder2X (parentKey на frame.MetalBorder),
-- которые гасим. TitleText НЕ трогаем — заголовок остаётся на плоской шапке.
local METAL_PARTS = {
	"CornerTopLeft", "CornerTopRight", "CornerBottomLeft", "CornerBottomRight",
	"BorderTop", "BorderBottom", "BorderLeft", "BorderRight",
}

-- Суффиксы стоковых регионов Blizzard-портретных окон ($parent...), которые
-- прячем: фон/тень/портрет и любые остатки золотой рамки ButtonFrameTemplate.
-- Rock-фон, который окна выставляют ПОСЛЕ Rebuild, тоже уходит — его заменяет
-- тёмный ElvUI-шаблон.
local BLIZZ_CHROME_SUFFIX = {
	"Bg", "Background", "TopTileStreaks", "TitleBg",
	"Portrait", "PortraitFrame",
	"TopLeftCorner", "TopRightCorner", "BotLeftCorner", "BotRightCorner",
	"TopBorder", "BottomBorder", "LeftBorder", "RightBorder",
}

local function hideRegion(r)
	if not r then return end
	if r.SetAlpha then r:SetAlpha(0) end
	if r.Hide then r:Hide() end
end

-- Гасим металлическую рамку + мраморную подложку самого Rebuild.
local function neutralizeMetal(frame)
	local mb = frame.MetalBorder
	if mb then
		for _, key in ipairs(METAL_PARTS) do
			hideRegion(mb[key])
		end
	end
	hideRegion(frame._metalBg)
end

-- Прячем стоковый хром окна (по имени фрейма) + ring-портрет.
local function neutralizeBlizz(frame)
	local name = frame.GetName and frame:GetName()
	if name then
		for _, suffix in ipairs(BLIZZ_CHROME_SUFFIX) do
			hideRegion(_G[name .. suffix])
		end
	end
	hideRegion(frame.ringPortrait)
	hideRegion(frame.portrait)
	hideRegion(frame.PortraitFrame)
end

-- Финдер-таб — это NozdorFinderTabButtonTemplate: у него есть парные текстуры
-- Left/Middle/Right + *Disabled (выбранное состояние). По ним же его и опознаём.
local function isFinderTab(tab)
	return tab and tab.LeftDisabled and tab.MiddleDisabled and tab.RightDisabled
end

local function skinFinderTab(tab)
	if not isFinderTab(tab) or tab.__nozdorTab then return end
	tab.__nozdorTab = true
	if S.HandleTab then S:HandleTab(tab) end
end

-- Ищем finder-табы: среди прямых детей фрейма и по имени $parentTab1..N.
local function skinFinderTabs(frame)
	if frame.GetChildren then
		for _, child in ipairs({ frame:GetChildren() }) do
			skinFinderTab(child)
		end
	end
	local name = frame.GetName and frame:GetName()
	if name then
		for i = 1, 12 do
			skinFinderTab(_G[name .. "Tab" .. i])
		end
	end
end

-- Приведение крестика к стилю ElvUI: крестик, который создаёт MetalFrame2X.
local function skinCloseButton(frame)
	local close = frame.CloseButton
	if not close or close.__nozdorClose then return end
	if not S.HandleCloseButton then return end
	close.__nozdorClose = true
	S:HandleCloseButton(close)
	close:ClearAllPoints()
	close:Point("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
end

-- Основное применение "хрома" к перестроенному окну.
local function applyChrome(frame)
	if not frame or frame.__nozdorChrome then return end
	if E.private.skins.blizzard.enable ~= true then return end
	frame.__nozdorChrome = true

	-- Тёмный плоский фон ElvUI вместо металла.
	if frame.SetTemplate then
		frame:SetTemplate("Transparent")
	end

	-- Металл гасим сразу — окно его больше не показывает.
	neutralizeMetal(frame)
	skinCloseButton(frame)

	-- Стоковый хром/фон окна выставляется ПОСЛЕ Rebuild (в том же OnShow),
	-- поэтому гасим его отложенно и повторяем на каждом показе (апдейты окна
	-- умеют ре-шоуить фон/тень).
	local function rehide()
		neutralizeMetal(frame)
		neutralizeBlizz(frame)
		skinFinderTabs(frame)
	end
	rehide()
	if C_Timer and C_Timer.After then
		C_Timer.After(0, rehide)
	end
	if frame.HookScript then
		frame:HookScript("OnShow", function()
			if C_Timer and C_Timer.After then
				C_Timer.After(0, rehide)
			else
				rehide()
			end
		end)
	end
end

-- Публичные хелперы для контентных файлов Nozdor<Window>.lua.
S.NozdorApplyChrome = applyChrome
S.NozdorNeutralizeBlizzChrome = neutralizeBlizz
S.NozdorSkinFinderTabs = skinFinderTabs

local function installHook()
	if S.__nozdorChromeHooked then return end
	if E.private.skins.blizzard.enable ~= true then return end
	if type(_G.MetalFrame2X_Rebuild) ~= "function" then
		-- UITemplate2X ещё не загрузился — попробуем чуть позже.
		if C_Timer and C_Timer.After then
			C_Timer.After(1, installHook)
		end
		return
	end
	S.__nozdorChromeHooked = true
	hooksecurefunc("MetalFrame2X_Rebuild", function(frame)
		applyChrome(frame)
	end)
end

S:AddCallback("Nozdor_Chrome", installHook)
