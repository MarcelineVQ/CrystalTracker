-- Name: AutoMana
-- License: LGPL v2.1

local DEBUG_MODE = false

local function debug_print(text)
  if DEBUG_MODE == true then DEFAULT_CHAT_FRAME:AddMessage(text) end
end

local function ct_print(text)
  DEFAULT_CHAT_FRAME:AddMessage(text)
end

local success = true
local failure = nil

-------------------------------------------------

local new_node = false
local arcane_id = 12363
local thorium_id = 10620

local CrystalTracker = CreateFrame("FRAME")

local function gotCrystal(msg)
  debug_print(msg)
  local _,_,itemId,_ = string.find(msg,"item:(%d+):")
  debug_print(itemId)
  return itemId == "12363"
end

local function gotItem(itemid, msg)
  -- debug_print(msg)
  local _,_,itemId,_ = string.find(msg,"item:(%d+):")
  -- debug_print(itemId)
  return itemId == tostring(itemid)
end

function showHistogram()
  ct_print("Hourly data:")
  for i=0,23 do
    local v = Histogram[i]
    if v then
      ct_print(format("Hour %d: %d veins, %d crystals, %.3f rate.", i, v.total, v.crystal, (v.rate*100)))
    else
      ct_print(format("Hour %d:", i))
    end
  end
end

local histo_old = true

local function buildHistogram()
  debug_print("build histo")
  if histo_old then
    debug_print("was old")
    Histogram = {}
    for stamp,val in pairs(CrystalStamps) do
      local p,h,m,c = val.name,val.hour,val.minute,val.crystal
      local hour = tonumber(h)
      if not Histogram[hour] then Histogram[hour] = {total = 0,crystal = 0, rate = 0} end
      -- don't count crystals as strikes
      if c == 0 then Histogram[hour].total = Histogram[hour].total + 1 end
      Histogram[hour].crystal = Histogram[hour].crystal + c
      Histogram[hour].rate = Histogram[hour].crystal / Histogram[hour].total
    end
  end
  histo_old = false
end

local function OnEvent()
  if event == "CHAT_MSG_LOOT" and GetZoneText() == "Zul'Gurub" then
      local now = time()
      local h,m = date("!%H",now),date("!%M",now)
      local row = {name = UnitName("player"),hour = h,minute = m, crystal = 0}
      if gotItem(thorium_id,arg1) then
        debug_print("Got Thorium")
        tinsert(CrystalStamps,time(),row)
        histo_old = true
      elseif gotItem(arcane_id,arg1) then
        debug_print("Got Crystal")
        row.crystal = 1
        tinsert(CrystalStamps,time(),row)
        histo_old = true
      end
  elseif event == "ADDON_LOADED" then
    debug_print("addon loaded")
    CrystalTracker:UnregisterEvent("ADDON_LOADED")
    if not CrystalStamps then CrystalStamps = {} end
    if not StampSize then StampSize = 0 end
    if not Histogram then Histogram = {} for i=0,23 do Histogram[i] = 0 end end

    debug_print("sizing stamps")
    local stamps_size = 0
    for _ in pairs(CrystalStamps) do
      stamps_size = stamps_size + 1
    end
    if stamps_size ~= StampSize then
      debug_print("stamp size differs")
      buildHistogram()
    end
    StampSize = stamps_size
  end
end

CrystalTracker:SetScript("OnEvent", OnEvent)
-- AutoMana:RegisterEvent("BAG_UPDATE")
CrystalTracker:RegisterEvent("CHAT_MSG_LOOT")
-- AutoMana:RegisterEvent("ITEM_PUSH")
CrystalTracker:RegisterEvent("ADDON_LOADED")

local function pairsByKeys (t, f)
  local a = {}
  for n in pairs(t) do table.insert(a, n) end
  table.sort(a, f)
  local i = 0      -- iterator variable
  local iter = function ()   -- iterator function
    i = i + 1
    if a[i] == nil then return nil
    else return a[i], t[a[i]]
    end
  end
  return iter
end

local function handleCommands(msg,editbox)
  local args = {};
  buildHistogram()
  for word in string.gfind(msg,'%S+') do table.insert(args,word) end
  if args[1] == "histo" or args[1] == "histogram" or args[1] == "hourly" then
    showHistogram()
  else
    -- for last hour
    local total_strikes,total_crystals = 0,0
    local h_strikes,h_crystals = 0,0
    local now = time()
    for k,v in pairs(CrystalStamps) do
      local last_hour = now - k < 3600
      -- if it's a crystal stamp it's not a 'strike', strikes are indicated by thorium
      if v.crystal > 0 then
        total_crystals = total_crystals + v.crystal
        if last_hour then h_crystals = h_crystals + v.crystal end
      else
        total_strikes = total_strikes + 1
        if last_hour then h_strikes = h_strikes + 1 end
      end
    end
    if h_strikes > 0 then
      ct_print(format('Tracked this last hour: %d strikes, %d crystals, rate %.3f%%', h_strikes,h_crystals,(h_crystals/h_strikes*100)))
    end
    local c = 0
    for _,v in pairs(Histogram) do c = c + v.crystal end
    -- ct_print(format('Tracked total: %d strikes, %d crystals, rate %.3f%%', StampSize,c,c/StampSize))
    ct_print(format('Tracked total: %d strikes, %d crystals, rate %.3f%%', total_strikes,total_crystals,(total_crystals/total_strikes*100)))
  end
end

SLASH_CRYSTALTRACKER1 = "/crystaltracker";
SlashCmdList["CRYSTALTRACKER"] = handleCommands
