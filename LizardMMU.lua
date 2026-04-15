local AddonPrefix = "LizardMMU"

LizardMMU = {}
LizardMMU_Saved = LizardMMU_Saved or { favorites = {}, position = nil }

-- Retry system
LizardMMU.retrying = false
LizardMMU.retryAttempts = 0
LizardMMU.maxRetries = 5

-- Find mount
function LizardMMU:FindMountExact(name)
   for i = 1, GetNumCompanions("MOUNT") do
      local _, mountName = GetCompanionInfo("MOUNT", i)
      if mountName == name then
         return i, mountName
      end
   end
end

-- Current mount
function LizardMMU:GetCurrentMountName()
   for i = 1, 40 do
      local buff = UnitBuff("player", i)
      if not buff then break end

      for j = 1, GetNumCompanions("MOUNT") do
         local _, mountName = GetCompanionInfo("MOUNT", j)
         if buff == mountName then
            return mountName
         end
      end
   end
end

-- Check if favorite
function LizardMMU:IsFavorite(name)
   for _, v in ipairs(LizardMMU_Saved.favorites) do
      if v == name then return true end
   end
end

-- Add
function LizardMMU:Add(name)
   local id, mountName = self:FindMountExact(name)
   if not id then
      print("|cff00ff00LizardMMU:|r Mount not found.")
      return
   end

   if self:IsFavorite(mountName) then return end

   table.insert(LizardMMU_Saved.favorites, mountName)
   print("|cff00ff00LizardMMU:|r Added:", mountName)
end

-- Remove
function LizardMMU:Remove(name)
   for i = #LizardMMU_Saved.favorites, 1, -1 do
      if LizardMMU_Saved.favorites[i] == name then
         table.remove(LizardMMU_Saved.favorites, i)
         print("|cff00ff00LizardMMU:|r Removed:", name)
         return true
      end
   end
end

-- Clear
function LizardMMU:Clear()
   wipe(LizardMMU_Saved.favorites)
   print("|cff00ff00LizardMMU:|r Favorites cleared.")
end

-- List
function LizardMMU:List()
   print("|cff00ff00LizardMMU Favorites:|r")
   if #LizardMMU_Saved.favorites == 0 then
      print(" - (empty)")
      return
   end
   for _, name in ipairs(LizardMMU_Saved.favorites) do
      print(" - "..name)
   end
end

-- Try mount
function LizardMMU:TryMount()
   if self.retryAttempts >= self.maxRetries then
      self.retrying = false
      return
   end

   self.retryAttempts = self.retryAttempts + 1

   local name = LizardMMU_Saved.favorites[math.random(#LizardMMU_Saved.favorites)]
   local id = self:FindMountExact(name)

   if id then
      CallCompanion("MOUNT", id)
   else
      self:TryMount()
   end
end

-- Summon
function LizardMMU:Summon()
   if IsMounted() then
      Dismount()
      return
   end

   if #LizardMMU_Saved.favorites == 0 then return end

   self.retrying = true
   self.retryAttempts = 0
   self:TryMount()
end

-- Retry event
local f = CreateFrame("Frame")
f:RegisterEvent("UI_ERROR_MESSAGE")

f:SetScript("OnEvent", function(_, _, _, msg)
   if LizardMMU.retrying then
      LizardMMU:TryMount()
   end
end)

-- BUTTON
function LizardMMU:CreateButton()
   local btn = CreateFrame("Button", "LizardMMU_Button", UIParent)
   btn:SetSize(36, 36)
   btn:SetPoint("CENTER", 0, 0)
   btn:SetFrameStrata("HIGH")

   btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

-- Background (clean base)
local bg = btn:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()
bg:SetTexture("Interface\\Buttons\\UI-Quickslot2")

-- Icon (brighter, properly framed)
local icon = btn:CreateTexture(nil, "ARTWORK")
icon:ClearAllPoints()
icon:SetPoint("TOPLEFT", 5, -5)
icon:SetPoint("BOTTOMRIGHT", -5, 5)
icon:SetTexture("Interface\\Icons\\achievement_bg_kill_on_mount")
icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

-- Border (controlled glow, not nuclear)
local border = btn:CreateTexture(nil, "OVERLAY")
border:SetAllPoints()
border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
border:SetBlendMode("ADD")
border:SetAlpha(0.4)  -- 🔥 key: reduces the ugly glow

-- Highlight (subtle)
local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
highlight:SetAllPoints()
highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
highlight:SetBlendMode("ADD")
highlight:SetAlpha(0.25)

   -- Drag
   btn:SetMovable(true)
   btn:EnableMouse(true)
   btn:RegisterForDrag("LeftButton")

   btn:SetScript("OnDragStart", function(self)
      if not IsShiftKeyDown() then
         self:StartMoving()
      end
   end)

   btn:SetScript("OnDragStop", function(self)
      self:StopMovingOrSizing()
      local p, _, rp, x, y = self:GetPoint()
      LizardMMU_Saved.position = {p, rp, x, y}
   end)

   -- Clicks (TOGGLE logic added)
   btn:SetScript("OnClick", function(self, button)
      if IsShiftKeyDown() then
         local name = LizardMMU:GetCurrentMountName()
         if name then
            if LizardMMU:IsFavorite(name) then
               LizardMMU:Remove(name)
            else
               LizardMMU:Add(name)
            end
         end
         return
      end

      if button == "RightButton" then
         LizardMMU:List()
         return
      end

      LizardMMU:Summon()
   end)

   -- Tooltip
   btn:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText("|cff00ff00LizardMMU|r")
      GameTooltip:AddLine("Left Click: Summon", 1,1,1)
      GameTooltip:AddLine("Right Click: List favorites", 0.8,0.8,0.8)
      GameTooltip:AddLine("Shift + Click: Toggle current mount", 0.6,0.6,0.6)
      GameTooltip:AddLine("Drag: Move", 0.6,0.6,0.6)
      GameTooltip:Show()
   end)

   btn:SetScript("OnLeave", function()
      GameTooltip:Hide()
   end)

   self.button = btn
end

function LizardMMU:LoadButtonPosition()
   if not self.button then return end
   local pos = LizardMMU_Saved.position
   if pos then
      self.button:ClearAllPoints()
      self.button:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
   end
end

-- Init
LizardMMU:CreateButton()
LizardMMU:LoadButtonPosition()

-- Slash
SLASH_LIZARDMMU1 = "/lmmu"
SlashCmdList["LIZARDMMU"] = function(msg)
   local cmd, arg = msg:match("^(%S*)%s*(.-)$")

   if cmd == "list" then
      LizardMMU:List()
   elseif cmd == "add" then
      LizardMMU:Add(arg)
   elseif cmd == "remove" then
      LizardMMU:Remove(arg)
   elseif cmd == "clear" then
      LizardMMU:Clear()
   else
      LizardMMU:Summon()
   end
end