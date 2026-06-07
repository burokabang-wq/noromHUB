--[[
    ╔═══════════════════════════════════════════════════════════╗
    ║              norom HUB v1.2 — Premium Edition              ║
    ║       Advanced Smart Farming for Kick A Lucky Block      ║
    ║          Engineered for Performance & Reliability         ║
    ║                    June 2026 • Stable                     ║
    ╚═══════════════════════════════════════════════════════════╝
]]

-- ══════════════════════════════════════════════════════════════
-- ANTI-DUPLICATE
-- ══════════════════════════════════════════════════════════════
local genv = (getgenv and getgenv()) or _G
if genv.noromHUB_Active then
    pcall(function() game:GetService("StarterGui"):SetCore("SendNotification", {Title="norom HUB", Text="Already running! Press RightShift to toggle UI.", Duration=3}) end)
    return
end
genv.noromHUB_Active = true

if not game:IsLoaded() then game.Loaded:Wait() end
task.wait(0.5)

-- ══════════════════════════════════════════════════════════════
-- SERVICES
-- ══════════════════════════════════════════════════════════════
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local WS = game:GetService("Workspace")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")

local LP = Players.LocalPlayer
while not LP do LP = Players.LocalPlayer; task.wait(0.1) end

-- ══════════════════════════════════════════════════════════════
-- STATE MANAGEMENT
-- ══════════════════════════════════════════════════════════════
local S = {
    Running = true,
    Conns = {},
    SessionStart = os.time(),
    -- Smart Farm
    SmartFarm = false,
    TargetCPS = 5000,
    RarityFilter = "Off", -- "Off" = only CPS check, or specific rarity names
    Status = "Idle",
    LastRoll = "---",
    LastCPS = "---",
    GoodCount = 0,
    BadCount = 0,
    -- Farm
    KickPower = 100,
    AutoCollect = false,
    AutoRebirth = false,
    AutoUpgrade = false,
    AutoBuySpeed = false,
    AutoBaseUpgrade = false,
    AutoFavorite = false,
    AutoSell = false,
    AutoPlaceBest = false,
    AutoPlotUpgrade = false,
    MinFavCPS = 1000,
    MinUnfavCPS = 100,
    AutoPlaceBestGlobal = false,
    -- Train (Weight Lifting)
    AutoTrain = false,
    AutoTrainCollect = false,
    Auto2xBonus = false,
    AutoBuyWeight = false,
    TargetWeight = "None",

    -- Player
    GodMode = false,
    AntiAFK = true,
    FPSBoost = false,
    -- Discord Webhook
    WebhookEnabled = false,
    WebhookURL = "",
    -- Good Roll History (last 3)
    GoodRollHistory = {}, -- {name, mutation, cps, rarity, reason, timestamp}
}

-- ══════════════════════════════════════════════════════════════
-- SETTINGS SAVE/LOAD (Persistent Config)
-- ══════════════════════════════════════════════════════════════
local CONFIG_FILE = "noromHUB_Config.json"

-- Keys to save (exclude runtime-only state)
local SAVE_KEYS = {
    "TargetCPS", "RarityFilter", "KickPower",
    "AutoCollect", "AutoRebirth", "AutoUpgrade", "AutoBuySpeed",
    "AutoBaseUpgrade", "AutoFavorite", "AutoSell", "AutoPlaceBest", "AutoPlotUpgrade",
    "MinFavCPS", "MinUnfavCPS", "AutoPlaceBestGlobal",
    "AutoTrain", "AutoTrainCollect", "Auto2xBonus", "AutoBuyWeight", "TargetWeight",
    "GodMode", "AntiAFK", "FPSBoost",
    "WebhookEnabled", "WebhookURL"
}

local function SaveConfig()
    pcall(function()
        if not writefile then return end
        local data = {}
        for _, key in ipairs(SAVE_KEYS) do
            data[key] = S[key]
        end
        local json = game:GetService("HttpService"):JSONEncode(data)
        writefile(CONFIG_FILE, json)
    end)
end

local function LoadConfig()
    pcall(function()
        if not readfile or not isfile then return end
        if not isfile(CONFIG_FILE) then return end
        local json = readfile(CONFIG_FILE)
        local data = game:GetService("HttpService"):JSONDecode(json)
        if type(data) == "table" then
            for _, key in ipairs(SAVE_KEYS) do
                if data[key] ~= nil then
                    S[key] = data[key]
                end
            end
        end
    end)
end

-- Load saved config on startup
LoadConfig()

-- Auto-save config every 10 seconds
task.spawn(function()
    while S.Running do
        task.wait(10)
        SaveConfig()
    end
end)

local function AddC(c) if c then table.insert(S.Conns, c) end end
local function Notify(t, m, d) pcall(function() StarterGui:SetCore("SendNotification", {Title=t or "norom HUB", Text=m or "", Duration=d or 3}) end) end

-- Forward declarations
local SendWebhook
local AddGoodRollHistory

-- ══════════════════════════════════════════════════════════════
-- DISCORD WEBHOOK
-- ══════════════════════════════════════════════════════════════
local HttpService = game:GetService("HttpService")

SendWebhook = function(brName, brMutation, brCPS, brRarity, reason)
    if not S.WebhookEnabled or S.WebhookURL == "" then return end
    
    pcall(function()
        -- Number formatter
        local function FormatCPS(n)
            if type(n) ~= "number" then return tostring(n or 0) end
            if n < 1000 then return tostring(math.floor(n)) end
            local suffixes = {"K","M","B","T","Q","Qi","Sx","Sp","Oc","No","Dc"}
            local i = math.floor(math.log10(n) / 3)
            if i < 1 then return tostring(math.floor(n)) end
            local sf = suffixes[i] or ("e"..i*3)
            return string.format("%.1f%s", n / (10^(i*3)), sf)
        end
        
        -- Mutation display
        local mutText = (brMutation and brMutation ~= "None" and brMutation ~= "") and brMutation or "None"
        
        -- CPS formatted
        local cpsText = FormatCPS(brCPS) .. "/s"
        
        -- Player info
        local playerName = LP.DisplayName .. " (@" .. LP.Name .. ")"
        
        -- Reason text
        local reasonText = reason or ("CPS " .. FormatCPS(brCPS) .. "/s >= Target")
        
        -- GMT+7 time
        local wibTime = os.time() + (7 * 3600)
        local timeText = os.date("!%d/%m/%Y %H:%M:%S WIB", wibTime)
        
        -- Color based on rarity
        local rarColors = {
            Common = 11842740, Rare = 1997055, Epic = 10696166, Legendary = 16753920,
            Mythic = 16711780, Godly = 16766720, Secret = 65480, Divine = 16777060,
            Hacked = 65280, OG = 16737535, Celestial = 9882879, Exclusive = 16732240,
            Eternal = 13148415
        }
        local embedColor = rarColors[brRarity] or 5793266
        
        -- Get Roblox avatar URL via HTTP API (works on Delta)
        local playerAvatar = ""
        pcall(function()
            local httpReqAvatar = request or http_request or (syn and syn.request) or (http and http.request)
            if httpReqAvatar then
                local response = httpReqAvatar({
                    Url = "https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds=" .. tostring(LP.UserId) .. "&size=420x420&format=Png&isCircular=false",
                    Method = "GET"
                })
                if response and response.Body then
                    local imageUrl = string.match(response.Body, '"imageUrl":"([^"]+)"')
                    if imageUrl and imageUrl ~= "" then
                        playerAvatar = imageUrl
                    end
                end
            end
        end)
        -- Fallback: try GetUserThumbnailAsync
        if playerAvatar == "" then
            pcall(function()
                local content, isReady = game:GetService("Players"):GetUserThumbnailAsync(
                    LP.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420
                )
                if content and content ~= "" and isReady then
                    playerAvatar = content
                end
            end)
        end
        
        -- Get brainrot image URL for Discord
        -- NOTE: GetBrainrotImage is defined later, so we inline the logic here
        local brainrotImage = ""
        pcall(function()
            local rawImageId = ""
            
            -- Method 1: From CPSLookup (already defined at this point)
            if CPSLookup and brName then
                local d = CPSLookup[brName]
                if d and d.image and d.image ~= "" then
                    rawImageId = d.image
                end
                -- Case-insensitive fallback
                if rawImageId == "" then
                    for k, v in pairs(CPSLookup) do
                        if string.lower(k) == string.lower(brName) then
                            if v.image and v.image ~= "" then
                                rawImageId = v.image
                                break
                            end
                        end
                    end
                end
            end
            
            -- Method 2: From EntitiesData directly
            if rawImageId == "" and EntitiesData and EntitiesData.Brainrots and brName then
                local data = EntitiesData.Brainrots[brName]
                if data then
                    local img = data.Image or data.Icon or data.Thumbnail or data.ImageId or data.IconId
                    if img then
                        if type(img) == "number" then rawImageId = "rbxassetid://" .. img end
                        if type(img) == "string" and img ~= "" then rawImageId = img end
                    end
                end
            end
            
            -- Method 3: From Tool in Backpack/Character
            if rawImageId == "" then
                local tool = nil
                if LP.Backpack then tool = LP.Backpack:FindFirstChild(brName) end
                if not tool and LP.Character then tool = LP.Character:FindFirstChild(brName) end
                if tool then
                    if tool.TextureId and tool.TextureId ~= "" then
                        rawImageId = tool.TextureId
                    else
                        for _, desc in ipairs(tool:GetDescendants()) do
                            if desc:IsA("Decal") and desc.Texture and desc.Texture ~= "" then
                                rawImageId = desc.Texture
                                break
                            end
                        end
                    end
                end
            end
            
            print("[norom HUB] Brainrot image raw: " .. tostring(rawImageId))
            
            if rawImageId == "" then
                print("[norom HUB] No image found for: " .. tostring(brName))
                return
            end
            
            -- Extract numeric asset ID
            local assetId = string.match(rawImageId, "%d+")
            if not assetId then return end
            
            print("[norom HUB] Using assetId: " .. assetId)
            
            -- Try InsertService to convert Decal ID to Image ID
            local imageAssetId = assetId
            pcall(function()
                local model = game:GetService("InsertService"):LoadAsset(tonumber(assetId))
                if model then
                    local decal = model:FindFirstChildWhichIsA("Decal", true)
                    if decal and decal.Texture and decal.Texture ~= "" then
                        local realId = string.match(decal.Texture, "%d+")
                        if realId then
                            imageAssetId = realId
                            print("[norom HUB] Converted decal->image: " .. realId)
                        end
                    end
                    model:Destroy()
                end
            end)
            
            -- Use game:HttpGet to get CDN URL (proven to work on Delta)
            local thumbUrl = "https://thumbnails.roblox.com/v1/assets?assetIds=" .. imageAssetId .. "&returnPolicy=PlaceHolder&size=420x420&format=Png&isCircular=false"
            local respBody = nil
            pcall(function()
                respBody = game:HttpGet(thumbUrl)
            end)
            
            if respBody then
                local imgUrl = string.match(respBody, '"imageUrl":"([^"]+)"')
                if imgUrl and imgUrl ~= "" then
                    brainrotImage = imgUrl
                    print("[norom HUB] Got brainrot CDN: " .. imgUrl)
                    return
                end
            end
            
            -- Fallback: request()
            local httpReqImg = request or http_request or (syn and syn.request) or (http and http.request)
            if httpReqImg then
                local resp = httpReqImg({ Url = thumbUrl, Method = "GET" })
                if resp and resp.Body then
                    local imgUrl = string.match(resp.Body, '"imageUrl":"([^"]+)"')
                    if imgUrl and imgUrl ~= "" then
                        brainrotImage = imgUrl
                        print("[norom HUB] Got brainrot CDN (req): " .. imgUrl)
                    end
                end
            end
        end)
        
        -- Build embed
        local embed = {
            title = "GOOD ROLL!",
            description = "A valuable brainrot has been collected!",
            color = embedColor,
            fields = {
                {name = "Brainrot", value = tostring(brName or "Unknown"), inline = true},
                {name = "Rarity", value = tostring(brRarity or "Unknown"), inline = true},
                {name = "Mutation", value = mutText, inline = true},
                {name = "CPS", value = cpsText, inline = false},
                {name = "Reason", value = reasonText, inline = false},
                {name = "Player", value = playerName, inline = true},
                {name = "Stats", value = "Good: " .. S.GoodCount .. " | Bad: " .. S.BadCount, inline = true},
                {name = "Waktu (WIB)", value = timeText, inline = false},
            },
            footer = {text = "norom HUB v1.2 | Smart Farm"}
        }
        
        -- Add brainrot image as thumbnail if available
        if brainrotImage ~= "" then
            embed.thumbnail = {url = brainrotImage}
        end
        
        -- Add avatar as author icon if available
        if playerAvatar ~= "" then
            embed.author = {name = playerName, icon_url = playerAvatar}
        end
        
        -- Build payload with avatar
        local payloadTable = {embeds = {embed}}
        if playerAvatar ~= "" then
            payloadTable.avatar_url = playerAvatar
        end
        
        local payload = HttpService:JSONEncode(payloadTable)
        
        -- Send HTTP request
        local httpReq = request or http_request or (syn and syn.request) or (http and http.request) or fluxus_request
        if httpReq then
            httpReq({
                Url = S.WebhookURL,
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = payload
            })
            print("[norom HUB] Webhook sent successfully!")
        end
    end)
end

-- ══════════════════════════════════════════════════════════════
-- DISCONNECT / ERROR WEBHOOK NOTIFICATION
-- ══════════════════════════════════════════════════════════════
local SendDisconnectWebhook
SendDisconnectWebhook = function(disconnectReason)
    if not S.WebhookEnabled or S.WebhookURL == "" then return end
    
    -- STRICT single-send guard using getgenv (persists across all scopes)
    local genv = (getgenv and getgenv()) or _G
    if genv._noromHUB_DisconnectSent then
        print("[norom HUB] Disconnect webhook already sent, skipping.")
        return
    end
    genv._noromHUB_DisconnectSent = true
    
    pcall(function()
        local playerName = LP.DisplayName .. " (@" .. LP.Name .. ")"
        local wibTime = os.time() + (7 * 3600)
        local timeText = os.date("!%d/%m/%Y %H:%M:%S WIB", wibTime)
        
        local sessionTime = "?"
        pcall(function()
            local elapsed = os.time() - (S.SessionStart or os.time())
            local hrs = math.floor(elapsed / 3600)
            local mins = math.floor((elapsed % 3600) / 60)
            sessionTime = string.format("%dh %dm", hrs, mins)
        end)
        
        local embed = {
            title = "DISCONNECTED!",
            description = "Player telah terputus dari game.",
            color = 16711680,
            fields = {
                {name = "Alasan", value = tostring(disconnectReason or "Unknown"), inline = false},
                {name = "Player", value = playerName, inline = true},
                {name = "Durasi", value = sessionTime, inline = true},
                {name = "Stats", value = "Good: " .. S.GoodCount .. " | Bad: " .. S.BadCount, inline = true},
                {name = "Waktu (WIB)", value = timeText, inline = false},
            },
            footer = {text = "norom HUB v1.2 | Disconnect Alert"}
        }
        
        local payload = HttpService:JSONEncode({
            embeds = {embed}
        })
        
        local httpReq = request or http_request or (syn and syn.request) or (http and http.request) or fluxus_request
        if httpReq then
            httpReq({
                Url = S.WebhookURL,
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = payload
            })
            print("[norom HUB] Disconnect webhook sent! (1x only)")
        end
    end)
end

-- ══════════════════════════════════════════════════════════════
-- GOOD ROLL HISTORY (Last 3)
-- ══════════════════════════════════════════════════════════════
AddGoodRollHistory = function(brName, brMutation, brCPS, brRarity, reason)
    table.insert(S.GoodRollHistory, 1, {
        name = brName or "Unknown",
        mutation = brMutation or "None",
        cps = brCPS or 0,
        rarity = brRarity or "Unknown",
        reason = reason or "",
        time = os.date("%H:%M:%S")
    })
    -- Keep only last 3
    while #S.GoodRollHistory > 3 do
        table.remove(S.GoodRollHistory)
    end
end

-- ══════════════════════════════════════════════════════════════
-- CHARACTER HELPERS
-- ══════════════════════════════════════════════════════════════
local function GetChar() return LP.Character end
local function GetHRP() local c = GetChar(); return c and c:FindFirstChild("HumanoidRootPart") end
local function GetHum() local c = GetChar(); return c and c:FindFirstChildOfClass("Humanoid") end
local function IsAlive() local h = GetHum(); return h and h.Health > 0 end

-- ══════════════════════════════════════════════════════════════
-- KICK ZONE: workspace.Areas.KickReady
-- ══════════════════════════════════════════════════════════════
local function GetKickReady()
    local areas = WS:FindFirstChild("Areas")
    if areas then return areas:FindFirstChild("KickReady") end
    return nil
end

local function CanKick()
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then return false end
    local hud = pg:FindFirstChild("HUD")
    if not hud then return false end
    local kb = hud:FindFirstChild("KickButton")
    return kb and kb.Visible
end

local function TeleportToKickZone()
    local kr = GetKickReady()
    if not kr then return false end
    local hrp = GetHRP()
    if not hrp then return false end
    hrp.CFrame = kr.CFrame * CFrame.new(0, 3, 0)
    return true
end

-- ══════════════════════════════════════════════════════════════
-- REMOTE FINDER
-- ══════════════════════════════════════════════════════════════
local NetworkModule = nil
pcall(function() NetworkModule = require(RS.Shared.Packages.Network) end)

local function FindRemote(name)
    local r = nil
    pcall(function()
        local nf = RS:FindFirstChild("Shared") and RS.Shared:FindFirstChild("Packages") and RS.Shared.Packages:FindFirstChild("Network")
        if nf then r = nf:FindFirstChild(name) end
    end)
    if not r then pcall(function() r = RS:FindFirstChild(name, true) end) end
    return r
end

local R = {}
pcall(function()
    R.Kick = FindRemote("rev_KickEvent")
    R.Collect = FindRemote("rev_B_Collect")
    R.Upgrade = FindRemote("rev_B_Upgrade")
    R.SpeedUpgrade = FindRemote("rev_SPEED_UPGRADE")
    R.ShopBuy = FindRemote("rev_Shop_Buy")
    R.WeightEquip = FindRemote("rev_WeightEquip")
    R.SellAll = FindRemote("ref_B_SellAll")
    R.Rebirth = FindRemote("rev_RebirthRequest")
    R.BaseUpgrade = FindRemote("rev_bs_upgrade")
    R.Interact = FindRemote("rev_S_Interact")
    R.SummonEvent = FindRemote("rev_sbe")
    R.ToggleFav = FindRemote("rev_ToggleFav")
    R.UsePotion = FindRemote("rev_UsePotion")
end)

-- ══════════════════════════════════════════════════════════════
-- ENTITIES DATA & CPS
-- ══════════════════════════════════════════════════════════════
local EntitiesData = nil
local CPSLookup = {}

-- Parse CPS value from EntitiesData format
-- Can be: number, or table {First=X, Second=Y} or {[1]=X, [2]=Y} meaning X * 10^Y
local function ParseCPSValue(v)
    if type(v) == "number" then return v end
    if type(v) == "table" then
        local base = v.First or v.first or v[1] or 0
        local exp = v.Second or v.second or v[2] or 0
        return tonumber(base) * (10 ^ tonumber(exp))
    end
    return tonumber(v) or 0
end

-- Try multiple paths to find EntitiesData
pcall(function()
    -- Path 1: RS.Shared.Data.EntitiesData (most common)
    local d = RS:FindFirstChild("Shared")
    if d then
        local data = d:FindFirstChild("Data")
        if data then
            local ed = data:FindFirstChild("EntitiesData")
            if ed then EntitiesData = require(ed) end
        end
    end
end)

if not EntitiesData then
    pcall(function()
        -- Path 2: RS.Modules.Data.EntitiesData
        local m = RS:FindFirstChild("Modules")
        if m then
            local data = m:FindFirstChild("Data")
            if data then
                local ed = data:FindFirstChild("EntitiesData")
                if ed then EntitiesData = require(ed) end
            end
        end
    end)
end

if not EntitiesData then
    pcall(function()
        -- Path 3: Search recursively
        local ed = RS:FindFirstChild("EntitiesData", true)
        if ed then EntitiesData = require(ed) end
    end)
end

-- Build CPS lookup table
if EntitiesData and EntitiesData.Brainrots then
    for name, data in pairs(EntitiesData.Brainrots) do
        pcall(function()
            if data.CPS then
                local cps = ParseCPSValue(data.CPS)
                local imgId = data.Image or data.Icon or data.Thumbnail or data.ImageId or data.IconId or ""
                if type(imgId) == "number" then imgId = "rbxassetid://" .. imgId end
                CPSLookup[name] = {cps = cps, rarity = data.Rarity or "Unknown", image = imgId or ""}
            end
        end)
    end
end

local MutMult = {
    None=1, Golden=1.5, Diamond=2, Plasma=4, Molten=6, Radioactive=8,
    Void=10, Shadow=12, Electrified=16, Rainbow=30, Virus=10, Wet=16,
    Alien=20, Bacon=30, Enchanted=12, Phantom=35, Astral=35, Volcanic=35
}

local RarOrder = {
    Common=1, Rare=2, Epic=3, Legendary=4, Mythic=5, Godly=6,
    Secret=7, Divine=8, Hacked=9, OG=10, Celestial=11, Exclusive=12, Eternal=13
}

local function CalcCPS(name, mutation)
    local d = CPSLookup[name]
    local base = d and d.cps or 0
    
    -- If not found by exact name, try case-insensitive match
    if base == 0 and name then
        for k, v in pairs(CPSLookup) do
            if string.lower(k) == string.lower(name) then
                base = v.cps or 0
                break
            end
        end
    end
    
    -- If still 0, try to read CPS from the actual brainrot tool/model in game
    if base == 0 and name then
        pcall(function()
            -- Check backpack tools
            local backpack = LP:FindFirstChild("Backpack")
            if backpack then
                for _, tool in ipairs(backpack:GetChildren()) do
                    if tool:IsA("Tool") and tool.Name == name then
                        local cpsAttr = tool:GetAttribute("CPS") or tool:GetAttribute("CashPerSecond")
                        if cpsAttr then base = tonumber(cpsAttr) or 0 end
                    end
                end
            end
            -- Check character equipped tool
            local char = LP.Character
            if char and base == 0 then
                local tool = char:FindFirstChildOfClass("Tool")
                if tool and tool.Name == name then
                    local cpsAttr = tool:GetAttribute("CPS") or tool:GetAttribute("CashPerSecond")
                    if cpsAttr then base = tonumber(cpsAttr) or 0 end
                end
            end
        end)
    end
    
    -- If still 0, try to find it in EntitiesData with partial match
    if base == 0 and name and EntitiesData and EntitiesData.Brainrots then
        pcall(function()
            for k, v in pairs(EntitiesData.Brainrots) do
                if string.find(string.lower(k), string.lower(name), 1, true) or
                   string.find(string.lower(name), string.lower(k), 1, true) then
                    if v.CPS then
                        base = ParseCPSValue(v.CPS)
                        break
                    end
                end
            end
        end)
    end
    
    local mult = MutMult[mutation or "None"] or 1
    return base * mult
end

local function GetRarity(name)
    local d = CPSLookup[name]
    if d then return d.rarity or "Unknown" end
    -- Case-insensitive fallback
    if name then
        for k, v in pairs(CPSLookup) do
            if string.lower(k) == string.lower(name) then
                return v.rarity or "Unknown"
            end
        end
    end
    return "Unknown"
end

local function FmtNum(n)
    if n < 1000 then return tostring(math.floor(n)) end
    local s = {"K","M","B","T","Q","Qi","Sx","Sp","Oc","No","Dc"}
    local i = math.floor(math.log10(n) / 3)
    if i < 1 then return tostring(math.floor(n)) end
    local sf = s[i] or ("e"..i*3)
    return string.format("%.1f%s", n / (10^(i*3)), sf)
end

-- ══════════════════════════════════════════════════════════════
-- PLOT FINDER
-- ══════════════════════════════════════════════════════════════
local _cachedPlot = nil
local function GetPlot()
    -- Return cached if still valid
    if _cachedPlot and _cachedPlot.Parent then return _cachedPlot end
    
    -- Method 1: ClientPlotService (most reliable)
    pcall(function()
        local cps = require(RS.Modules.ServicesLoader.ClientPlotService)
        if cps and cps.Model then _cachedPlot = cps.Model end
    end)
    if _cachedPlot then return _cachedPlot end
    
    -- Method 2: Scan Workspace.Plots with multiple attribute checks
    local plots = WS:FindFirstChild("Plots") or WS:FindFirstChild("Plot")
    if not plots then return nil end
    for _, p in ipairs(plots:GetChildren()) do
        local owner = p:GetAttribute("Owner") or ""
        local ownerId = p:GetAttribute("OwnerId") or p:GetAttribute("PlayerId") or ""
        local player = p:GetAttribute("Player") or ""
        if tostring(owner) == LP.Name or tostring(owner) == LP.DisplayName
            or tostring(owner) == tostring(LP.UserId)
            or tostring(ownerId) == tostring(LP.UserId)
            or tostring(player) == LP.Name
            or tostring(player) == tostring(LP.UserId) then
            _cachedPlot = p
            return p
        end
    end
    return nil
end

-- ══════════════════════════════════════════════════════════════
-- CORE ACTIONS
-- ══════════════════════════════════════════════════════════════
local function DoKick()
    pcall(function()
        if R.Kick then
            local acc = 0.98
            local pwr = (S.KickPower or 100) / 100
            -- When Smart Farm is active, spoof kick power to 50B for maximum distance
            if S.Active then
                pwr = 50000000000 -- 50B power bypass
            end
            R.Kick:FireServer(acc, pwr)
        end
    end)
end

local function DoCollect()
    pcall(function()
        local plot = GetPlot()
        if not plot then return end
        local buttons = plot:FindFirstChild("Buttons")
        if not buttons then return end
        local hrp = GetHRP()
        if not hrp then return end
        for _, btn in ipairs(buttons:GetChildren()) do
            if btn:IsA("BasePart") then
                local slotNum = tonumber(string.match(btn.Name, "%d+"))
                if slotNum then
                    pcall(function()
                        if firetouchinterest then
                            firetouchinterest(hrp, btn, 0)
                            firetouchinterest(hrp, btn, 1)
                        end
                    end)
                    pcall(function() if R.Collect then R.Collect:FireServer(slotNum) end end)
                    task.wait(0.05)
                end
            end
        end
    end)
end

local function DoSellAll()
    pcall(function() if R.SellAll then R.SellAll:InvokeServer() end end)
end

local function DoRebirth()
    pcall(function() if R.Rebirth then R.Rebirth:FireServer() end end)
end

local function DoUpgrade()
    pcall(function()
        local plot = GetPlot()
        if not plot then return end
        local slots = plot:FindFirstChild("Slots")
        if not slots then return end
        for _, slot in ipairs(slots:GetChildren()) do
            local idx = tonumber(string.match(slot.Name, "%d+"))
            if idx and R.Upgrade then R.Upgrade:FireServer(idx); task.wait(0.05) end
        end
    end)
end

local function DoBuySpeed()
    pcall(function() if R.SpeedUpgrade then for _, l in ipairs({3,2,1}) do R.SpeedUpgrade:FireServer(l); task.wait(0.1) end end end)
end

local function DoBuyWeight()
    pcall(function()
        if R.ShopBuy and S.TargetWeight and S.TargetWeight ~= "None" then
            R.ShopBuy:FireServer("WeightShop", S.TargetWeight)
        end
    end)
end

local function DoTrain()
    pcall(function()
        -- Equip the best WEIGHT tool from backpack (NOT brainrot tools)
        local char = LP.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        
        -- Get list of valid weight names from WeightModels
        local weightNames = {}
        pcall(function()
            local wm = RS:FindFirstChild("Objects") and RS.Objects:FindFirstChild("WeightModels")
            if wm then
                for _, w in ipairs(wm:GetChildren()) do
                    weightNames[w.Name] = true
                end
            end
        end)
        
        -- Collect all tools from backpack + equipped
        local allTools = {}
        for _, tool in ipairs(LP.Backpack:GetChildren()) do
            if tool:IsA("Tool") then table.insert(allTools, tool) end
        end
        local equipped = char:FindFirstChildOfClass("Tool")
        if equipped then table.insert(allTools, equipped) end
        
        -- Find best weight tool (only tools whose name matches a weight model)
        local bestWeight = nil
        for _, tool in ipairs(allTools) do
            if weightNames[tool.Name] then
                bestWeight = tool
            end
        end
        
        -- If no WeightModels found, skip (don't equip random tools)
        if not bestWeight then return end
        
        -- Check if already equipped
        local currentTool = char:FindFirstChildOfClass("Tool")
        if currentTool and currentTool.Name == bestWeight.Name then return end
        
        -- Fire WeightEquip remote
        if R.WeightEquip then
            pcall(function() R.WeightEquip:FireServer(bestWeight.Name) end)
        end
        -- Equip the tool if it's in backpack
        if bestWeight.Parent == LP.Backpack then
            hum:EquipTool(bestWeight)
        end
    end)
end

local function DoTrainCollect()
    pcall(function()
        -- Collect cash from plot buttons during training
        local plot = GetPlot()
        if not plot then return end
        local buttons = plot:FindFirstChild("Buttons")
        if not buttons then return end
        local hrp = GetHRP()
        if not hrp then return end
        for _, btn in ipairs(buttons:GetChildren()) do
            if btn:IsA("BasePart") then
                local slotNum = tonumber(string.match(btn.Name, "%d+"))
                if slotNum then
                    pcall(function()
                        if firetouchinterest then
                            firetouchinterest(hrp, btn, 0)
                            firetouchinterest(hrp, btn, 1)
                        end
                    end)
                    pcall(function() if R.Collect then R.Collect:FireServer(slotNum) end end)
                    task.wait(0.05)
                end
            end
        end
    end)
end

-- 2x Bonus Click System - Event-based + Polling hybrid
-- Button spawns at random positions and gets recreated each time
local _bonus2xConn = nil
local _bonus2xDescConn = nil

local function ClickButton(btn)
    if not btn then return end
    pcall(function()
        -- Method 1: getconnections + Fire
        if getconnections then
            local conns = getconnections(btn.MouseButton1Click)
            for _, c in ipairs(conns) do pcall(function() c:Fire() end) end
            local actConns = getconnections(btn.Activated)
            for _, c in ipairs(actConns) do pcall(function() c:Fire() end) end
        end
    end)
    -- Method 2: firesignal
    pcall(function()
        if firesignal then
            firesignal(btn.MouseButton1Click)
            firesignal(btn.Activated)
        end
    end)
    -- Method 3: VirtualInputManager click at button position
    pcall(function()
        local VIM = game:GetService("VirtualInputManager")
        local pos = btn.AbsolutePosition
        local size = btn.AbsoluteSize
        local cx = pos.X + size.X / 2
        local cy = pos.Y + size.Y / 2
        VIM:SendMouseButtonEvent(cx, cy, 0, true, game, 1)
        task.delay(0.03, function()
            VIM:SendMouseButtonEvent(cx, cy, 0, false, game, 1)
        end)
    end)
    -- Method 4: fireclick
    pcall(function() if fireclick then fireclick(btn) end end)
    -- Method 5: Direct fire events
    pcall(function() btn.MouseButton1Click:Fire() end)
    pcall(function() btn.Activated:Fire() end)
end

local function IsBonusButton(obj)
    if not (obj:IsA("TextButton") or obj:IsA("ImageButton") or obj:IsA("Frame")) then
        return false
    end
    local nm = obj.Name:lower()
    if nm:find("bonus") or nm == "bonus" then return true end
    if obj:IsA("TextButton") then
        local txt = ""
        pcall(function() txt = (obj.Text or ""):lower() end)
        if txt:find("2x") or txt:find("x2") then return true end
    end
    return false
end

local function GetClickableFromBonus(obj)
    -- If obj itself is clickable, return it
    if obj:IsA("TextButton") or obj:IsA("ImageButton") then
        return obj
    end
    -- If it's a Frame, find first clickable child
    for _, child in ipairs(obj:GetDescendants()) do
        if child:IsA("TextButton") or child:IsA("ImageButton") then
            return child
        end
    end
    return nil
end

local function HandleBonusAppeared(obj)
    if not S.Auto2xBonus then return end
    if not IsBonusButton(obj) then return end
    local btn = GetClickableFromBonus(obj)
    if btn then
        task.defer(function() ClickButton(btn) end)
    end
end

local function StartBonus2xListener()
    -- Stop previous listener
    if _bonus2xConn then pcall(function() _bonus2xConn:Disconnect() end) end
    if _bonus2xDescConn then pcall(function() _bonus2xDescConn:Disconnect() end) end
    
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then return end
    
    -- Listen for ANY new descendant added to PlayerGui
    _bonus2xDescConn = pg.DescendantAdded:Connect(function(obj)
        if not S.Auto2xBonus then return end
        task.defer(function()
            pcall(function()
                if IsBonusButton(obj) then
                    local btn = GetClickableFromBonus(obj)
                    if btn then ClickButton(btn) end
                elseif (obj:IsA("TextButton") or obj:IsA("ImageButton")) then
                    -- Check if parent is Bonus
                    local parent = obj.Parent
                    if parent and parent.Name:lower():find("bonus") then
                        ClickButton(obj)
                    end
                end
            end)
        end)
    end)
    
    -- Also listen specifically on KickUpgrades if it exists
    local ku = pg:FindFirstChild("KickUpgrades")
    if ku then
        _bonus2xConn = ku.ChildAdded:Connect(function(child)
            if not S.Auto2xBonus then return end
            task.defer(function()
                pcall(function()
                    if IsBonusButton(child) then
                        local btn = GetClickableFromBonus(child)
                        if btn then ClickButton(btn) end
                    end
                end)
            end)
        end)
    end
end

local function StopBonus2xListener()
    if _bonus2xConn then pcall(function() _bonus2xConn:Disconnect() end); _bonus2xConn = nil end
    if _bonus2xDescConn then pcall(function() _bonus2xDescConn:Disconnect() end); _bonus2xDescConn = nil end
end

-- Polling fallback: also scan every 0.5s in case event missed it
local function Do2xBonus()
    pcall(function()
        local pg = LP:FindFirstChild("PlayerGui")
        if not pg then return end
        for _, desc in ipairs(pg:GetDescendants()) do
            if IsBonusButton(desc) then
                local btn = GetClickableFromBonus(desc)
                if btn then
                    local vis = true
                    pcall(function() vis = btn.Visible end)
                    if vis then ClickButton(btn) end
                end
            end
        end
    end)
end

local function DoBaseUpgrade()
    pcall(function() if R.BaseUpgrade then R.BaseUpgrade:FireServer() end end)
end

local function DoPlaceBest()
    pcall(function() if R.Interact then R.Interact:FireServer("PlaceBest") end end)
end

-- ══════════════════════════════════════════════════════════════
-- FAVORITE SYSTEM (uses GUID from Tools, not slot numbers)
-- ══════════════════════════════════════════════════════════════

-- Get all brainrot Tools from inventory (Backpack + Character)
local function GetAllTools()
    local tools = {}
    pcall(function()
        if LP.Backpack then
            for _, t in ipairs(LP.Backpack:GetChildren()) do
                if t:IsA("Tool") then table.insert(tools, t) end
            end
        end
        local char = LP.Character
        if char then
            for _, t in ipairs(char:GetChildren()) do
                if t:IsA("Tool") then table.insert(tools, t) end
            end
        end
    end)
    return tools
end

-- Fire ToggleFav with GUID (correct method from game analysis)
local function DoToggleFav(guid)
    pcall(function()
        -- Method 1: Network module FireServer (preferred - same as Luxy)
        if NetworkModule and NetworkModule.FireServer then
            NetworkModule.FireServer("ToggleFav", guid)
            return
        end
        -- Method 2: Direct remote event
        if R.ToggleFav then
            R.ToggleFav:FireServer(guid)
            return
        end
        -- Method 3: Fresh require Network
        local net = require(RS.Shared.Packages.Network)
        if net and net.FireServer then
            net.FireServer("ToggleFav", guid)
        end
    end)
end

-- Auto Favorite: favorite brainrot jika CPS >= MinFavCPS
-- Auto Unfavorite: unfavorite brainrot jika CPS < MinUnfavCPS
local function DoAutoFav()
    pcall(function()
        local tools = GetAllTools()
        for _, tool in ipairs(tools) do
            local guid = tool:GetAttribute("GUID")
            if not guid then continue end
            
            local name = tool.Name
            local mut = tool:GetAttribute("Mutation") or "None"
            local isFav = tool:GetAttribute("Favorite") == true
            local cps = CalcCPS(name, mut)
            
            -- Auto Favorite: CPS di atas threshold → favorite
            if cps >= S.MinFavCPS and not isFav then
                DoToggleFav(guid)
                print("[noromHUB] Favorited: " .. name .. " (CPS: " .. tostring(cps) .. ")")
                task.wait(0.6)
            -- Auto Unfavorite: CPS di bawah threshold → unfavorite
            elseif cps < S.MinUnfavCPS and isFav then
                DoToggleFav(guid)
                print("[noromHUB] Unfavorited: " .. name .. " (CPS: " .. tostring(cps) .. ")")
                task.wait(0.6)
            end
        end
    end)
end

-- ══════════════════════════════════════════════════════════════
-- REMOVE ALL FROM BASE (unequip all placed brainrots)
-- ══════════════════════════════════════════════════════════════
local function FindBrainrotInSlot(slot)
    local pp = slot:FindFirstChild("PlacedPart")
    if pp then
        local m = pp:FindFirstChildOfClass("Model")
        if m then return m end
        for _, child in ipairs(pp:GetChildren()) do
            if child:IsA("Model") or child:IsA("MeshPart") then return child end
        end
    end
    local m = slot:FindFirstChildOfClass("Model")
    if m then return m end
    return nil
end

local function DoRemoveAll()
    pcall(function()
        local plot = GetPlot()
        if not plot then print("[noromHUB] Remove: Plot not found") return end
        local slots = plot:FindFirstChild("Slots")
        if not slots then print("[noromHUB] Remove: Slots not found") return end
        
        local interactRemote = R.Interact
        if not interactRemote then
            -- Try fresh lookup
            pcall(function()
                local nf = RS:FindFirstChild("Shared") and RS.Shared:FindFirstChild("Packages") and RS.Shared.Packages:FindFirstChild("Network")
                if nf then interactRemote = nf:FindFirstChild("rev_S_Interact") end
            end)
        end
        if not interactRemote then print("[noromHUB] Remove: rev_S_Interact not found") return end
        
        local removed = 0
        for _, slot in ipairs(slots:GetChildren()) do
            local hasBrainrot = FindBrainrotInSlot(slot)
            if hasBrainrot then
                local sn = tonumber(string.match(slot.Name, "%d+"))
                if sn then
                    -- Based on Luxy's place/remove mechanism, placing empty tool or firing empty slot removes it
                    -- Another known method is NetworkModule.FireServer("RemoveBrainrot", sn) or ("Remove", sn)
                    pcall(function() 
                        if NetworkModule and NetworkModule.FireServer then
                            NetworkModule.FireServer("Remove", sn)
                        end
                    end)
                    pcall(function() interactRemote:FireServer("Remove", sn) end)
                    
                    -- Second attempt if first fails
                    pcall(function() 
                        if NetworkModule and NetworkModule.FireServer then
                            NetworkModule.FireServer("Unequip", sn)
                        end
                    end)
                    pcall(function() interactRemote:FireServer("Unequip", sn) end)
                    
                    removed = removed + 1
                    task.wait(0.4)
                end
            end
        end
        print("[noromHUB] Remove: Attempted to remove " .. removed .. " brainrots")
    end)
end

-- ══════════════════════════════════════════════════════════════
-- PLACE BEST (Global CPS Lv1) - Equip tool then fire Interact
-- ══════════════════════════════════════════════════════════════
local function DoPlaceBestGlobal()
    pcall(function()
        local plot = GetPlot()
        if not plot then print("[noromHUB] PlaceBest: Plot not found") return end
        local slots = plot:FindFirstChild("Slots")
        if not slots then print("[noromHUB] PlaceBest: Slots not found") return end
        
        local interactRemote = R.Interact
        if not interactRemote then
            pcall(function()
                local nf = RS:FindFirstChild("Shared") and RS.Shared:FindFirstChild("Packages") and RS.Shared.Packages:FindFirstChild("Network")
                if nf then interactRemote = nf:FindFirstChild("rev_S_Interact") end
            end)
        end
        if not interactRemote then print("[noromHUB] PlaceBest: rev_S_Interact not found") return end
        
        -- 1. Get all tools from inventory and sort by Base CPS (Lv1)
        local tools = GetAllTools()
        local sortedTools = {}
        for _, tool in ipairs(tools) do
            local name = tool.Name
            local mut = tool:GetAttribute("Mutation") or "None"
            local lookup = CPSLookup[name]
            local baseCPS = lookup and lookup.cps or 0
            local mutMult = MutMult[mut] or 1
            local globalCPS = baseCPS * mutMult -- CPS at Lv1 with mutation
            table.insert(sortedTools, {tool = tool, cps = globalCPS, name = name})
        end
        table.sort(sortedTools, function(a, b) return a.cps > b.cps end)
        
        -- 2. Find empty slots
        local emptySlots = {}
        for _, slot in ipairs(slots:GetChildren()) do
            local sn = tonumber(string.match(slot.Name, "%d+"))
            if sn then
                local hasBrainrot = FindBrainrotInSlot(slot)
                if not hasBrainrot then
                    table.insert(emptySlots, sn)
                end
            end
        end
        table.sort(emptySlots)
        
        -- 3. Place best tools into empty slots
        local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
        if not hum then print("[noromHUB] PlaceBest: No humanoid") return end
        
        local placed = 0
        for i, slotNum in ipairs(emptySlots) do
            if i > #sortedTools then break end
            local entry = sortedTools[i]
            if entry.cps <= 0 then break end
            
            -- Equip the tool
            pcall(function() hum:EquipTool(entry.tool) end)
            task.wait(0.3)
            
            -- Fire interact to place in slot
            pcall(function() interactRemote:FireServer(slotNum) end)
            placed = placed + 1
            task.wait(0.4)
            
            -- Unequip
            pcall(function() hum:UnequipTools() end)
            task.wait(0.2)
        end
        print("[noromHUB] PlaceBest: Placed " .. placed .. " brainrots")
    end)
end

-- ══════════════════════════════════════════════════════════════
-- SMART FARM SYSTEM
-- ══════════════════════════════════════════════════════════════

-- Parse InGame attribute: "Name1, Mut1, Name2, Mut2, ..."
local function ParseInGame()
    local results = {}
    pcall(function()
        local raw = LP:GetAttribute("InGame") or ""
        if raw == "" then return end
        local parts = string.split(raw, ",")
        for i = 1, #parts, 2 do
            local name = parts[i] and string.gsub(parts[i], "^%s*(.-)%s*$", "%1")
            local mut = parts[i+1] and string.gsub(parts[i+1], "^%s*(.-)%s*$", "%1") or "None"
            if mut == "" then mut = "None" end
            if name and name ~= "" then
                table.insert(results, {name = name, mutation = mut})
            end
        end
    end)
    return results
end

-- Check if any brainrot meets target (Rarity Priority + CPS)
local function CheckMeetsTarget(brainrots)
    -- STEP 1: Check RARITY PRIORITY first (if enabled)
    -- If rarity filter is active and brainrot matches, auto-accept regardless of CPS
    if S.RarityFilter and S.RarityFilter ~= "Off" then
        local selectedRars = {}
        for rar in string.gmatch(S.RarityFilter, "[^,]+") do
            selectedRars[rar] = true
        end
        
        for _, br in ipairs(brainrots) do
            local brRarity = GetRarity(br.name)
            if selectedRars[brRarity] then
                -- RARITY MATCH! Auto-accept regardless of CPS
                local cps = CalcCPS(br.name, br.mutation)
                if cps == 0 and br.name and br.name ~= "" then cps = 1 end
                return true, br, cps, "RARITY"
            end
        end
    end
    
    -- STEP 2: Standard CPS check
    for _, br in ipairs(brainrots) do
        local cps = CalcCPS(br.name, br.mutation)
        
        -- If CPS database returned 0 (brainrot not found in data),
        -- try reading CPS from the brainrot's attribute directly
        if cps == 0 then
            pcall(function()
                -- Check if the brainrot model in workspace has a CPS attribute
                local plot = WS:FindFirstChild("Plots")
                if plot then
                    for _, p in ipairs(plot:GetChildren()) do
                        local slots = p:FindFirstChild("Slots")
                        if slots then
                            for _, slot in ipairs(slots:GetChildren()) do
                                local placed = slot:FindFirstChild("PlacedPart")
                                if placed then
                                    local model = placed:FindFirstChildOfClass("Model")
                                    if model and model.Name == br.name then
                                        local attrCPS = model:GetAttribute("CPS") or model:GetAttribute("CashPerSecond")
                                        if attrCPS then cps = tonumber(attrCPS) or 0 end
                                    end
                                end
                            end
                        end
                    end
                end
            end)
        end
        
        -- FALLBACK: If CPS is still 0 but brainrot EXISTS (name is not empty),
        -- assume it has at least CPS = 1 so that a target of 1 will always pass
        -- This handles cases where EntitiesData failed to load
        if cps == 0 and br.name and br.name ~= "" and br.name ~= "Unknown" then
            cps = 1
        end
        
        -- CPS check
        if cps >= S.TargetCPS then
            return true, br, cps, "CPS"
        end
    end
    -- Return the best CPS found even if it didn't meet target (for display purposes)
    local bestFoundCPS = 0
    for _, br in ipairs(brainrots) do
        local c = CalcCPS(br.name, br.mutation)
        if c == 0 and br.name and br.name ~= "" and br.name ~= "Unknown" then c = 1 end
        if c > bestFoundCPS then bestFoundCPS = c end
    end
    return false, nil, bestFoundCPS, nil
end

-- Wait for respawn
local function WaitRespawn()
    local c = LP.Character
    if c then
        local h = c:FindFirstChildOfClass("Humanoid")
        if h and h.Health > 0 then return true end
    end
    LP.CharacterAdded:Wait()
    task.wait(1.5)
    return true
end

-- God Mode System (hookfunction on TakeDamage - same method as Luxy Hub)
local _godHooked = false
local _godOriginalTakeDamage = nil
local _godHealthConn = nil

local function SetupGodHook()
    if _godHooked then return end
    pcall(function()
        if hookfunction then
            local dummyHum = Instance.new("Humanoid")
            _godOriginalTakeDamage = hookfunction(dummyHum.TakeDamage, function(self, ...)
                if S.GodMode then
                    local char = LP.Character
                    if char and self == char:FindFirstChildOfClass("Humanoid") then
                        return nil -- Block all damage
                    end
                end
                if _godOriginalTakeDamage then
                    return _godOriginalTakeDamage(self, ...)
                end
            end)
            dummyHum:Destroy()
            _godHooked = true
        end
    end)
end

local function GodOn()
    S.GodMode = true
    -- Setup hook if not already done
    SetupGodHook()
    -- Also set health to huge as backup
    pcall(function()
        local h = GetHum()
        if h then
            h.MaxHealth = math.huge
            h.Health = math.huge
        end
    end)
    -- Connect HealthChanged to keep health at max
    pcall(function()
        if _godHealthConn then _godHealthConn:Disconnect() end
        local h = GetHum()
        if h then
            _godHealthConn = h.HealthChanged:Connect(function(newHealth)
                if S.GodMode and h and h.Parent then
                    h.Health = h.MaxHealth
                end
            end)
        end
    end)
end

-- God Mode off
local function GodOff()
    S.GodMode = false
    pcall(function()
        if _godHealthConn then _godHealthConn:Disconnect(); _godHealthConn = nil end
        local h = GetHum()
        if h then h.MaxHealth = 100; h.Health = 100 end
    end)
end

-- Teleport to plot (safe zone - waves don't reach here)
local function TeleportToPlot()
    local plot = GetPlot()
    if not plot then return false end
    local hrp = GetHRP()
    if not hrp then return false end
    -- Try to find the plot's primary part or center
    local target = plot:FindFirstChild("Base") or plot:FindFirstChild("Platform") or plot.PrimaryPart
    if target then
        hrp.CFrame = target.CFrame * CFrame.new(0, 5, 0)
    else
        -- Fallback: use plot position + offset up
        local pos = plot:GetBoundingBox()
        hrp.CFrame = pos * CFrame.new(0, 5, 0)
    end
    return true
end

-- Wait until character dies (from wave naturally)
-- Captures the CURRENT character/humanoid reference so a fast respawn doesn't confuse it
local function WaitUntilDead()
    local char = LP.Character
    if not char then return true end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return true end
    -- Watch THIS specific humanoid (not whatever LP.Character points to later)
    local timeout = tick() + 120
    while S.SmartFarm and S.Running and tick() < timeout do
        if hum.Health <= 0 then return true end
        if LP.Character ~= char then return true end -- character already swapped = we died
        task.wait(0.2)
    end
    return true
end

-- Wait for character to fully respawn and be ready to use
local function WaitForRespawn()
    -- If already alive with a valid HRP, we're good
    local char = LP.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hum and hrp and hum.Health > 0 then return true end
    end
    -- Wait for a NEW character to be added (with timeout for background scenarios)
    local newChar = nil
    local waitStart = tick()
    while not newChar and tick() - waitStart < 30 do
        newChar = LP.Character
        if newChar then
            local h = newChar:FindFirstChildOfClass("Humanoid")
            local r = newChar:FindFirstChild("HumanoidRootPart")
            if h and r and h.Health > 0 then break end
            newChar = nil
        end
        -- Try CharacterAdded with short timeout
        local conn
        local got = false
        conn = LP.CharacterAdded:Connect(function(c)
            newChar = c
            got = true
        end)
        task.wait(2)
        conn:Disconnect()
        if got then break end
    end
    -- Wait for essential parts to load
    if newChar then
        newChar:WaitForChild("HumanoidRootPart", 15)
        newChar:WaitForChild("Humanoid", 15)
    end
    -- Extra wait to make sure everything is fully loaded
    task.wait(2)
    return true
end


-- ══════════════════════════════════════════════════════════════
-- SPEED BOOST BYPASS (Integrated into Smart Farm)
-- Auto-activates on Good Roll, auto-deactivates near Kick Zone
-- ══════════════════════════════════════════════════════════════
local _origSpeedData = {}
local _speedBoostConnections = {}
local _disabledScripts = {}
local _speedBoostActive = false
local _speedTargetPos = nil -- Player position at kick zone (target for brainrot to run to)

local function ActivateSpeedBoost()
    if _speedBoostActive then return end -- Already active
    _speedBoostActive = true
    
    local targetSpeed = 190 -- Target WalkSpeed
    
    -- Wait for character to be fully ready (retry up to 3 seconds - character should already exist)
    local char, hum, hrp
    local waitStart = tick()
    while tick() - waitStart < 3 do
        char = LP.Character
        if char then
            hum = char:FindFirstChildOfClass("Humanoid")
            hrp = char:FindFirstChild("HumanoidRootPart")
            if hum and hrp and hum.Health > 0 then
                break
            end
        end
        task.wait(0.1)
    end
    
    if not char or not hum or not hrp then
        print("[noromHUB] Speed Boost: Character not ready after 3s, aborting")
        _speedBoostActive = false
        return
    end
    
    print("[noromHUB] Speed Boost: ACTIVATING (Good Roll detected)...")
    
    -- Save original WalkSpeed before any modifications
    _origSpeedData._origWalkSpeed = hum.WalkSpeed
    print("[noromHUB] Speed Boost: Original WalkSpeed saved: " .. tostring(hum.WalkSpeed))
    
    -- ═══ TECHNIQUE 1: Disable WalkSpeed monitor connections ═══
    pcall(function()
        if getconnections then
            local signal = hum:GetPropertyChangedSignal("WalkSpeed")
            local conns = getconnections(signal)
            for _, conn in pairs(conns) do
                pcall(function()
                    conn:Disable()
                end)
            end
            print("[noromHUB] Speed Boost: Disabled " .. #conns .. " WalkSpeed connections")
        end
    end)
    
    -- ═══ TECHNIQUE 2: Disable LocalScripts that control speed ═══
    pcall(function()
        for _, obj in pairs(char:GetChildren()) do
            if obj:IsA("LocalScript") and obj.Enabled then
                local shouldDisable = false
                pcall(function()
                    if debug and debug.getconstants then
                        local constants = debug.getconstants(obj)
                        for _, c in pairs(constants) do
                            if type(c) == "string" and (c == "WalkSpeed" or c == "SpeedData" or c == "GetSpeedFromLevel") then
                                shouldDisable = true
                            end
                        end
                    end
                end)
                if shouldDisable then
                    obj.Disabled = true
                    table.insert(_disabledScripts, obj)
                    print("[noromHUB] Speed Boost: Disabled script: " .. obj.Name)
                end
            end
        end
        local PS = LP:FindFirstChild("PlayerScripts")
        if PS then
            for _, obj in pairs(PS:GetDescendants()) do
                if obj:IsA("LocalScript") and obj.Enabled then
                    local shouldDisable = false
                    pcall(function()
                        if debug and debug.getconstants then
                            local constants = debug.getconstants(obj)
                            for _, c in pairs(constants) do
                                if type(c) == "string" and (c == "WalkSpeed" or c == "GetSpeedFromLevel") then
                                    shouldDisable = true
                                end
                            end
                        end
                    end)
                    if shouldDisable then
                        obj.Disabled = true
                        table.insert(_disabledScripts, obj)
                        print("[noromHUB] Speed Boost: Disabled PlayerScript: " .. obj:GetFullName())
                    end
                end
            end
        end
    end)
    
    -- ═══ TECHNIQUE 3: Modify SpeedData module ═══
    pcall(function()
        local RS = game:GetService("ReplicatedStorage")
        local SpeedData = require(RS.Shared.Data.SpeedData)
        _origSpeedData.SPEED_INCREMENT = SpeedData.SPEED_INCREMENT
        _origSpeedData.BASE_SPEED = SpeedData.BASE_SPEED
        SpeedData.SPEED_INCREMENT = SpeedData.SPEED_INCREMENT * 2
        if SpeedData.cachedSpeeds then
            for k, _ in pairs(SpeedData.cachedSpeeds) do
                SpeedData.cachedSpeeds[k] = nil
            end
        end
        if SpeedData.GetSpeedFromLevel then
            _origSpeedData.GetSpeedFromLevel = SpeedData.GetSpeedFromLevel
            SpeedData.GetSpeedFromLevel = function(level)
                return _origSpeedData.GetSpeedFromLevel(level) * 2
            end
        end
        print("[noromHUB] Speed Boost: Modified SpeedData (x2)")
    end)
    
    -- ═══ TECHNIQUE 4: Metatable spoof (anti-cheat evasion) ═══
    pcall(function()
        if getrawmetatable and setreadonly and newcclosure then
            local mt = getrawmetatable(game)
            setreadonly(mt, false)
            local oldIndex = mt.__index
            _origSpeedData._oldIndex = oldIndex
            mt.__index = newcclosure(function(self, prop)
                if self == hum and prop == "WalkSpeed" then
                    return 22 -- Spoof normal speed to anti-cheat
                end
                return oldIndex(self, prop)
            end)
            print("[noromHUB] Speed Boost: Metatable hook applied (spoof as 22)")
        end
    end)
    
    -- ═══ TECHNIQUE 5: Force WalkSpeed + maintain loop ═══
    hum.WalkSpeed = targetSpeed
    print("[noromHUB] Speed Boost ACTIVATED! WalkSpeed = " .. targetSpeed)
    -- Internal loop to keep forcing speed while active
    -- Deactivates at dist < 100 from kick zone (inline)
    task.spawn(function()
        local spawnRecorded = false
        while _speedBoostActive and S.Running do
            pcall(function()
                local c = LP.Character
                if c then
                    local h = c:FindFirstChildOfClass("Humanoid")
                    local r = c:FindFirstChild("HumanoidRootPart")
                    if h and h.Health > 0 then
                        h.WalkSpeed = targetSpeed
                        if r and _speedTargetPos then
                            local dist = (r.Position - _speedTargetPos).Magnitude
                            -- Wait until brainrot is actually far from kick zone
                            if not spawnRecorded then
                                if dist > 100 then
                                    spawnRecorded = true
                                    print("[noromHUB] Speed: Spawn recorded, dist=" .. math.floor(dist) .. ", will deactivate at dist < 100")
                                end
                                return
                            end
                            -- Deactivate when close to kick zone
                            if dist < 100 then
                                print("[noromHUB] Speed auto-OFF: dist=" .. math.floor(dist))
                                _speedBoostActive = false
                                pcall(function()
                                    if _origSpeedData._oldIndex and getrawmetatable and setreadonly then
                                        local mt = getrawmetatable(game)
                                        setreadonly(mt, false)
                                        mt.__index = _origSpeedData._oldIndex
                                    end
                                end)
                                pcall(function()
                                    local RS = game:GetService("ReplicatedStorage")
                                    local SpeedData = require(RS.Shared.Data.SpeedData)
                                    if _origSpeedData.SPEED_INCREMENT then SpeedData.SPEED_INCREMENT = _origSpeedData.SPEED_INCREMENT end
                                    if _origSpeedData.BASE_SPEED then SpeedData.BASE_SPEED = _origSpeedData.BASE_SPEED end
                                    if _origSpeedData.GetSpeedFromLevel then SpeedData.GetSpeedFromLevel = _origSpeedData.GetSpeedFromLevel end
                                    if SpeedData.cachedSpeeds then
                                        for k, _ in pairs(SpeedData.cachedSpeeds) do SpeedData.cachedSpeeds[k] = nil end
                                    end
                                end)
                                pcall(function()
                                    for _, s in pairs(_disabledScripts) do pcall(function() s.Disabled = false end) end
                                    _disabledScripts = {}
                                end)
                                pcall(function()
                                    local c2 = LP.Character
                                    if c2 then
                                        local h2 = c2:FindFirstChildOfClass("Humanoid")
                                        if h2 then h2.WalkSpeed = 22 end
                                    end
                                end)
                                _origSpeedData = {}
                                print("[noromHUB] Speed Boost DEACTIVATED - WalkSpeed = 22")
                                return
                            end
                        end
                    end
                end
            end)
            task.wait(0.05)
        end
    end)
end

local function DeactivateSpeedBoost()
    -- Always run cleanup regardless of _speedBoostActive state
    _speedBoostActive = false
    print("[noromHUB] Speed Boost: DEACTIVATING...")
    -- ═══ CLEANUP: Restore everything ═══
    pcall(function()
        -- Restore metatable
        if _origSpeedData._oldIndex and getrawmetatable and setreadonly then
            local mt = getrawmetatable(game)
            setreadonly(mt, false)
            mt.__index = _origSpeedData._oldIndex
        end
    end)
    pcall(function()
        -- Restore SpeedData
        local RS = game:GetService("ReplicatedStorage")
        local SpeedData = require(RS.Shared.Data.SpeedData)
        if _origSpeedData.SPEED_INCREMENT then
            SpeedData.SPEED_INCREMENT = _origSpeedData.SPEED_INCREMENT
        end
        if _origSpeedData.BASE_SPEED then
            SpeedData.BASE_SPEED = _origSpeedData.BASE_SPEED
        end
        if _origSpeedData.GetSpeedFromLevel then
            SpeedData.GetSpeedFromLevel = _origSpeedData.GetSpeedFromLevel
        end
        if SpeedData.cachedSpeeds then
            for k, _ in pairs(SpeedData.cachedSpeeds) do
                SpeedData.cachedSpeeds[k] = nil
            end
        end
    end)
    pcall(function()
        -- Re-enable disabled scripts
        for _, script in pairs(_disabledScripts) do
            pcall(function() script.Disabled = false end)
        end
        _disabledScripts = {}
    end)
    pcall(function()
        -- Restore WalkSpeed to normal
        local c = LP.Character
        if c then
            local h = c:FindFirstChildOfClass("Humanoid")
            if h then h.WalkSpeed = 22 end
        end
    end)
    _origSpeedData = {}
    print("[noromHUB] Speed Boost DEACTIVATED - Normal speed restored")
end

-- Forward declaration for notification function (defined later with UI)
local ShowRollNotification

-- ═══ THE MAIN SMART FARM LOOP ═══
local function SmartFarmLoop()
    while S.SmartFarm and S.Running do
        local ok, err = pcall(function()
            
            -- STEP 1: Make sure we are alive, if not wait for respawn
            if not IsAlive() then
                S.Status = "Waiting for respawn..."
                WaitForRespawn()
            end
            
            -- Double-check we're actually alive now
            if not IsAlive() then
                S.Status = "Still not alive, waiting..."
                task.wait(2)
                return
            end
            
            -- STEP 2: Check if we're still a brainrot (InGame set) - if so, skip teleport
            local inGameCheck = LP:GetAttribute("InGame") or ""
            if inGameCheck ~= "" then
                -- Still a brainrot! Don't teleport - wait until we die or get collected
                S.Status = "Still brainrot, waiting..."
                WaitUntilDead()
                S.Status = "Died! Waiting respawn..."
                WaitForRespawn()
                return
            end
            
            -- STEP 2b: Teleport to kick zone (CFrame - works in background)
            S.Status = "Going to kick zone..."
            local teleported = false
            for attempt = 1, 5 do
                teleported = TeleportToKickZone()
                if teleported then break end
                task.wait(1)
            end
            if not teleported then
                S.Status = "ERROR: KickReady not found!"
                task.wait(3)
                return
            end
            task.wait(1)
            
            -- STEP 3: Wait until KickButton is visible (confirms ready to kick)
            S.Status = "Waiting kick ready..."
            local kickTimeout = tick() + 15
            while not CanKick() and tick() < kickTimeout and S.SmartFarm and S.Running do
                -- Keep teleporting to kick zone (CFrame based, no MoveTo)
                TeleportToKickZone()
                task.wait(1)
            end
            
            if not CanKick() then
                S.Status = "Kick not ready, retrying..."
                task.wait(2)
                return
            end
            
            -- STEP 4: Kick the block!
            -- Save player position and character BEFORE becoming brainrot
            local _playerKickPos = nil
            local _preKickChar = LP.Character
            pcall(function()
                local h = GetHRP()
                if h then _playerKickPos = h.Position end
            end)
            
            S.Status = "Kicking block..."
            DoKick()
            task.wait(3) -- Wait for kick animation to play before block starts flying
            
            -- STEP 5: Wait for the ENTIRE kick animation to finish
            -- IMPORTANT: After kick, our character stays at kick zone!
            -- The block flying is just a visual/camera animation.
            -- We detect animation end by: camera stops moving (stabilizes)
            -- Only AFTER animation ends does the brainrot actually spawn far away.
            S.Status = "Waiting for block to land..."
            
            -- Phase 1: Wait for InGame to be set (brainrot assigned)
            local fullAnimTimeout = tick() + 30
            while S.SmartFarm and S.Running and tick() < fullAnimTimeout do
                local inGame = LP:GetAttribute("InGame") or ""
                if inGame ~= "" then
                    print("[noromHUB] InGame set: " .. inGame)
                    break
                end
                task.wait(0.3)
            end
            
            -- Phase 2: Wait for camera to STOP moving (animation finished)
            -- During kick animation, camera follows the flying block
            -- When block lands and becomes brainrot, camera stabilizes
            S.Status = "Block flying, waiting for camera to stabilize..."
            local WS = game:GetService("Workspace")
            local cam = WS.CurrentCamera or WS:FindFirstChildOfClass("Camera")
            local camStableFrames = 0
            local lastCamPos = cam and cam.CFrame.Position or Vector3.new(0,0,0)
            local camTimeout = tick() + 25
            
            while S.SmartFarm and S.Running and tick() < camTimeout do
                task.wait(0.3)
                if cam then
                    local curCamPos = cam.CFrame.Position
                    local camMoved = (curCamPos - lastCamPos).Magnitude
                    lastCamPos = curCamPos
                    
                    if camMoved < 1 then
                        -- Camera barely moved
                        camStableFrames = camStableFrames + 1
                    else
                        camStableFrames = 0
                    end
                    
                    -- Camera stable for 5 frames (1.5s) = animation done
                    if camStableFrames >= 5 then
                        print("[noromHUB] Camera stabilized! Animation done.")
                        break
                    end
                end
            end
            
            -- Phase 3: Wait for character position to UPDATE (teleport to brainrot location)
            -- After animation, game teleports our character to where block landed
            -- We wait until our HRP position is FAR from kick zone (position updated)
            S.Status = "Waiting for position update..."
            if _playerKickPos then
                local posUpdateTimeout = tick() + 15
                while S.SmartFarm and S.Running and tick() < posUpdateTimeout do
                    local curChar = LP.Character
                    if curChar then
                        local curHrp = curChar:FindFirstChild("HumanoidRootPart")
                        if curHrp then
                            local distFromKick = (curHrp.Position - _playerKickPos).Magnitude
                            print("[noromHUB] Pos update check... dist from kick: " .. math.floor(distFromKick))
                            if distFromKick > 30 then
                                print("[noromHUB] Position updated! Brainrot is now far from kick zone.")
                                break
                            end
                        end
                    end
                    task.wait(0.5)
                end
            end
            
            task.wait(1) -- Extra settle time
            print("[noromHUB] Block landed, proceeding to check brainrot...")
            
            -- STEP 6: Parse brainrot from InGame attribute
            S.Status = "Checking brainrot..."
            local brainrots = ParseInGame()
            
            if #brainrots == 0 then
                S.Status = "No brainrot detected, waiting..."
                S.LastRoll = "None"
                S.LastCPS = "0"
                WaitUntilDead()
                return
            end
            
            -- STEP 7: Check CPS - does it meet our target?
            local best = brainrots[1]
            local meets, goodBr, goodCPS, matchType = CheckMeetsTarget(brainrots)
            
            local displayCPS = goodCPS or CalcCPS(best.name, best.mutation)
            S.LastRoll = best.name .. " [" .. best.mutation .. "]"
            S.LastCPS = FmtNum(displayCPS) .. "/s"
            
            if not meets then
                -- ═══ BAD ROLL - CPS not enough & rarity not matched ═══
                S.BadCount = S.BadCount + 1
                local badDetail = "CPS " .. FmtNum(displayCPS) .. "/s < Target " .. FmtNum(S.TargetCPS) .. "/s"
                if S.RarityFilter ~= "Off" then
                    local brRarity = GetRarity(best.name)
                    badDetail = badDetail .. " | Rarity: " .. brRarity .. " (not in filter)"
                end
                S.Status = "BAD: " .. best.name .. " (" .. FmtNum(displayCPS) .. "/s) - Running to wave..."
                
                -- Show professional notification (non-blocking)
                task.spawn(function() pcall(function() ShowRollNotification(false, best.name, best.mutation, displayCPS, badDetail) end) end)
                
                -- BAD ROLL - Wait for wave to naturally catch us
                WaitUntilDead()
                
                S.Status = "Died! Waiting respawn..."
                WaitForRespawn()
                
            else
                -- ═══ GOOD ROLL - CPS meets target! ═══
                S.GoodCount = S.GoodCount + 1
                S.Status = "GOOD! " .. goodBr.name .. " (" .. FmtNum(goodCPS) .. "/s) - Running to kick zone!"
                
                -- Show professional notification
                local goodReason
                if matchType == "RARITY" then
                    local brRarity = GetRarity(goodBr.name)
                    goodReason = "Rarity Match: " .. brRarity .. " (auto-collected)"
                else
                    goodReason = "CPS " .. FmtNum(goodCPS) .. "/s >= Target " .. FmtNum(S.TargetCPS) .. "/s"
                end
                task.spawn(function() pcall(function() ShowRollNotification(true, goodBr.name, goodBr.mutation, goodCPS, goodReason) end) end)
                
                -- Send Discord webhook notification (non-blocking - runs in background)
                local goodRarity = GetRarity(goodBr.name)
                task.spawn(function() pcall(function() SendWebhook(goodBr.name, goodBr.mutation, goodCPS, goodRarity, goodReason) end) end)
                
                -- Add to good roll history (last 3)
                pcall(function() AddGoodRollHistory(goodBr.name, goodBr.mutation, goodCPS, goodRarity, goodReason) end)
                
                -- NOW we are the brainrot - GOOD ROLL!
                -- Speed boost DISABLED. Using MoveTo with normal game speed only.
                -- No CFrame, no teleport, no speed hack - just MoveTo direction.
                
                S.Status = "GOOD! Running to kick zone..."
                
                -- Wait for brainrot character to be fully ready
                local startChar = LP.Character
                local hum, hrp
                local charWait = tick() + 5
                while tick() < charWait do
                    startChar = LP.Character
                    if startChar then
                        hum = startChar:FindFirstChildOfClass("Humanoid")
                        hrp = startChar:FindFirstChild("HumanoidRootPart")
                        if hum and hrp and hum.Health > 0 then
                            break
                        end
                    end
                    task.wait(0.1)
                end
                
                print("[noromHUB] Good Roll refs: hum=" .. tostring(hum ~= nil) .. " hrp=" .. tostring(hrp ~= nil) .. " kickPos=" .. tostring(_playerKickPos ~= nil))
                
                if hum and hrp and _playerKickPos then
                    local targetPos = _playerKickPos + Vector3.new(0, 3, 0)
                    print("[noromHUB] MoveTo target (no speed): " .. tostring(targetPos))
                    
                    -- Check initial distance - brainrot should be FAR from kick zone
                    local initDist = (hrp.Position - targetPos).Magnitude
                    print("[noromHUB] Initial dist from kick zone: " .. math.floor(initDist))
                    
                    -- If brainrot is still near kick zone, it hasn't moved yet
                    -- Wait until it's actually far away (block has truly landed far)
                    if initDist < 30 then
                        print("[noromHUB] Brainrot still near kick zone, waiting for real position...")
                        local posWait = tick() + 20
                        while tick() < posWait and S.SmartFarm and S.Running do
                            task.wait(0.5)
                            local c = LP.Character
                            if c then
                                local h = c:FindFirstChild("HumanoidRootPart")
                                if h then
                                    initDist = (h.Position - targetPos).Magnitude
                                    print("[noromHUB] Waiting... dist: " .. math.floor(initDist))
                                    if initDist > 30 then
                                        hrp = h
                                        hum = c:FindFirstChildOfClass("Humanoid")
                                        break
                                    end
                                end
                            end
                        end
                    end
                    
                    -- Now brainrot is far from kick zone - activate speed boost and MoveTo
                    print("[noromHUB] Starting MoveTo! dist=" .. math.floor(initDist))
                    _speedTargetPos = targetPos -- Set target for speed loop deactivation
                    pcall(ActivateSpeedBoost)
                    pcall(function() hum:MoveTo(targetPos) end)
                    
                    local moveTimeout = tick() + 300 -- 5 min max
                    local lastPos = hrp.Position
                    local stuckFrames = 0
                    local wasEverFar = (initDist > 30) -- Must have been far before allowing arrival
                    
                    while S.SmartFarm and S.Running and tick() < moveTimeout do
                        task.wait(0.5)
                        
                        local curChar = LP.Character
                        if not curChar then break end
                        
                        -- Character changed = brainrot was collected
                        if curChar ~= startChar then
                            print("[noromHUB] Character changed - brainrot collected!")
                            break
                        end
                        
                        local curHrp = curChar:FindFirstChild("HumanoidRootPart")
                        local curHum = curChar:FindFirstChildOfClass("Humanoid")
                        if not curHrp or not curHum then break end
                        if curHum.Health <= 0 then
                            S.Status = "Wave caught us, respawning..."
                            WaitForRespawn()
                            break
                        end
                        
                        -- Check distance
                        local dist = (curHrp.Position - targetPos).Magnitude
                        S.Status = "GOOD! Running... (" .. math.floor(dist) .. " studs)"
                        
                        -- Track if brainrot was ever far from kick zone
                        if dist > 30 then wasEverFar = true end
                        
                        -- Speed management handled by force loop in ActivateSpeedBoost
                        
                        -- Only allow arrival if brainrot was previously far (actually walked)
                        if wasEverFar and dist < 8 then
                            print("[noromHUB] Arrived at kick zone!")
                            break
                        end
                        
                        -- Detect stuck and re-issue MoveTo
                        local moved = (curHrp.Position - lastPos).Magnitude
                        lastPos = curHrp.Position
                        
                        if moved < 0.5 then
                            stuckFrames = stuckFrames + 1
                        else
                            stuckFrames = 0
                        end
                        
                        -- Re-issue MoveTo every iteration (game cancels after ~8s)
                        pcall(function() curHum:MoveTo(targetPos) end)
                        
                        -- If stuck for too long, just wait to die
                        if stuckFrames >= 20 then
                            S.Status = "Stuck! Waiting for wave..."
                            WaitUntilDead()
                            S.Status = "Died! Waiting respawn..."
                            WaitForRespawn()
                            break
                        end
                    end
                else
                    -- Refs failed, wait to die naturally
                    print("[noromHUB] MoveTo refs nil, waiting to die...")
                    WaitUntilDead()
                    S.Status = "Died! Waiting respawn..."
                    WaitForRespawn()
                end
                
                -- Wait for InGame attribute to clear before restarting loop
                local clearWait = tick() + 15
                while tick() < clearWait do
                    local ig = LP:GetAttribute("InGame") or ""
                    if ig == "" then break end
                    task.wait(0.5)
                end
                print("[noromHUB] InGame cleared, restarting loop")
                return
            end
        end)
        
        if not ok then
            S.Status = "Error: " .. tostring(err):sub(1, 40)
            task.wait(3)
        end
        
        task.wait(0.5)
    end
    pcall(DeactivateSpeedBoost) -- Ensure speed is off when Smart Farm stops
    S.Status = "Idle"
end

-- ══════════════════════════════════════════════════════════════
-- BASIC LOOPS
-- ══════════════════════════════════════════════════════════════

local function LoopCollect() while S.AutoCollect and S.Running do DoCollect(); task.wait(3) end end
local function LoopRebirth() while S.AutoRebirth and S.Running do DoRebirth(); task.wait(2) end end
local function LoopUpgrade() while S.AutoUpgrade and S.Running do DoUpgrade(); task.wait(5) end end
local function LoopBuySpeed() while S.AutoBuySpeed and S.Running do DoBuySpeed(); task.wait(3) end end
local function LoopBaseUpgrade() while S.AutoBaseUpgrade and S.Running do DoBaseUpgrade(); task.wait(3) end end
local function LoopTrain() while S.AutoTrain and S.Running do DoTrain(); task.wait(1) end end
local function LoopTrainCollect() while S.AutoTrainCollect and S.Running do DoTrainCollect(); task.wait(20) end end
local function Loop2xBonus()
    StartBonus2xListener()
    while S.Auto2xBonus and S.Running do
        Do2xBonus()
        task.wait(0.5)
    end
    StopBonus2xListener()
end
local function LoopBuyWeight() while S.AutoBuyWeight and S.Running do DoBuyWeight(); task.wait(5) end end
-- Auto Fav listener for new brainrots entering inventory
local _autoFavConn = nil
local function StartAutoFavListener()
    if _autoFavConn then pcall(function() _autoFavConn:Disconnect() end) end
    _autoFavConn = LP.Backpack.ChildAdded:Connect(function(tool)
        if not S.AutoFavorite or not S.Running then return end
        if not tool:IsA("Tool") then return end
        -- Wait briefly for attributes to be set by the server
        task.wait(0.5)
        pcall(function()
            local guid = tool:GetAttribute("GUID")
            if not guid then return end
            local name = tool.Name
            local mut = tool:GetAttribute("Mutation") or "None"
            local isFav = tool:GetAttribute("Favorite") == true
            local cps = CalcCPS(name, mut)
            
            -- Auto Favorite: CPS >= threshold and not yet favorited
            if cps >= S.MinFavCPS and not isFav then
                DoToggleFav(guid)
                print("[noromHUB] Auto-Fav NEW: " .. name .. " (CPS: " .. tostring(cps) .. ")")
            -- Auto Unfavorite: CPS < threshold and currently favorited
            elseif cps < S.MinUnfavCPS and isFav then
                DoToggleFav(guid)
                print("[noromHUB] Auto-Unfav NEW: " .. name .. " (CPS: " .. tostring(cps) .. ")")
            end
        end)
    end)
end

local function StopAutoFavListener()
    if _autoFavConn then pcall(function() _autoFavConn:Disconnect() end); _autoFavConn = nil end
end

local function LoopFav()
    StartAutoFavListener()
    while S.AutoFavorite and S.Running do
        DoAutoFav()
        task.wait(5)
    end
    StopAutoFavListener()
end
local function LoopSell() while S.AutoSell and S.Running do DoSellAll(); task.wait(15) end end
local function LoopPlaceBest() while S.AutoPlaceBest and S.Running do DoPlaceBest(); task.wait(3) end end
local function LoopPlaceBestGlobal() while S.AutoPlaceBestGlobal and S.Running do DoPlaceBestGlobal(); task.wait(30) end end
local function LoopPlotUpgrade() while S.AutoPlotUpgrade and S.Running do pcall(function() if R.Interact then R.Interact:FireServer("PlotUpgrade") end end); task.wait(3) end end
local function LoopGod()
    SetupGodHook()
    while S.GodMode and S.Running do
        pcall(function()
            local h = GetHum()
            if h then
                h.MaxHealth = math.huge
                h.Health = math.huge
                -- Reconnect HealthChanged if disconnected
                if not _godHealthConn or not _godHealthConn.Connected then
                    _godHealthConn = h.HealthChanged:Connect(function()
                        if S.GodMode and h and h.Parent then
                            h.Health = h.MaxHealth
                        end
                    end)
                end
            end
        end)
        task.wait(0.5)
    end
    GodOff()
end


-- ══════════════════════════════════════════════════════════════
-- UI DESIGN
-- ══════════════════════════════════════════════════════════════
local Color = {
    Bg       = Color3.fromRGB(15, 15, 22),
    Surface  = Color3.fromRGB(24, 24, 36),
    Card     = Color3.fromRGB(32, 32, 48),
    Primary  = Color3.fromRGB(99, 102, 241),  -- Indigo
    Success  = Color3.fromRGB(34, 197, 94),
    Danger   = Color3.fromRGB(239, 68, 68),
    Warning  = Color3.fromRGB(245, 158, 11),
    Text     = Color3.fromRGB(240, 240, 250),
    TextDim  = Color3.fromRGB(148, 148, 168),
    Border   = Color3.fromRGB(55, 55, 75),
    ToggleOn = Color3.fromRGB(34, 197, 94),
    ToggleOff= Color3.fromRGB(55, 55, 75),
    Input    = Color3.fromRGB(20, 20, 32),
}

-- Remove old UI
pcall(function() for _, g in ipairs(game:GetService("CoreGui"):GetChildren()) do if g.Name == "noromHUB" then g:Destroy() end end end)
pcall(function() local pg = LP:FindFirstChild("PlayerGui"); if pg then for _, g in ipairs(pg:GetChildren()) do if g.Name == "noromHUB" then g:Destroy() end end end end)

local SG = Instance.new("ScreenGui")
SG.Name = "noromHUB"; SG.ResetOnSpawn = false
SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; SG.DisplayOrder = 9999

local parented = false
pcall(function() if syn and syn.protect_gui then syn.protect_gui(SG) end; SG.Parent = game:GetService("CoreGui"); parented = true end)
if not parented then pcall(function() SG.Parent = game:GetService("CoreGui"); parented = true end) end
if not parented then pcall(function() if gethui then SG.Parent = gethui(); parented = true end end) end
if not parented then pcall(function() local pg = LP:FindFirstChild("PlayerGui") or LP:WaitForChild("PlayerGui", 3); if pg then SG.Parent = pg; parented = true end end) end
if not parented then warn("[noromHUB] UI failed"); genv.noromHUB_Active = false; return end

-- ══════════════════════════════════════════════════════════════
-- ROLL NOTIFICATION SYSTEM (Bottom-Right Professional Toast)
-- ══════════════════════════════════════════════════════════════
local NotifContainer = Instance.new("Frame", SG)
NotifContainer.Name = "NotifContainer"
NotifContainer.Size = UDim2.new(0, 320, 1, -20)
NotifContainer.Position = UDim2.new(1, -330, 0, 10)
NotifContainer.BackgroundTransparency = 1
NotifContainer.ClipsDescendants = false
local notifLayout = Instance.new("UIListLayout", NotifContainer)
notifLayout.Padding = UDim.new(0, 8)
notifLayout.SortOrder = Enum.SortOrder.LayoutOrder
notifLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
notifLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right

-- Rarity color mapping
local RarityColors = {
    Common = Color3.fromRGB(180, 180, 180),
    Rare = Color3.fromRGB(30, 144, 255),
    Epic = Color3.fromRGB(163, 53, 238),
    Legendary = Color3.fromRGB(255, 165, 0),
    Mythic = Color3.fromRGB(255, 0, 100),
    Godly = Color3.fromRGB(255, 215, 0),
    Secret = Color3.fromRGB(0, 255, 200),
    Divine = Color3.fromRGB(255, 255, 100),
    Hacked = Color3.fromRGB(0, 255, 0),
    OG = Color3.fromRGB(255, 100, 255),
    Celestial = Color3.fromRGB(150, 200, 255),
    Exclusive = Color3.fromRGB(255, 80, 80),
    Eternal = Color3.fromRGB(200, 150, 255),
    Unknown = Color3.fromRGB(148, 148, 168),
}

-- Mutation color mapping
local MutationColors = {
    None = Color3.fromRGB(148, 148, 168),
    Golden = Color3.fromRGB(255, 215, 0),
    Diamond = Color3.fromRGB(185, 242, 255),
    Plasma = Color3.fromRGB(0, 200, 255),
    Molten = Color3.fromRGB(255, 100, 0),
    Radioactive = Color3.fromRGB(0, 255, 50),
    Void = Color3.fromRGB(80, 0, 120),
    Shadow = Color3.fromRGB(40, 0, 60),
    Electrified = Color3.fromRGB(255, 255, 0),
    Rainbow = Color3.fromRGB(255, 100, 200),
    Virus = Color3.fromRGB(0, 200, 0),
    Wet = Color3.fromRGB(0, 150, 255),
    Alien = Color3.fromRGB(100, 255, 100),
    Bacon = Color3.fromRGB(200, 100, 50),
    Enchanted = Color3.fromRGB(200, 150, 255),
    Phantom = Color3.fromRGB(180, 200, 255),
    Astral = Color3.fromRGB(100, 150, 255),
    Volcanic = Color3.fromRGB(255, 60, 0),
}

local function GetBrainrotImage(name)
    -- Try CPSLookup first
    local d = CPSLookup[name]
    if d and d.image and d.image ~= "" then return d.image end
    -- Case-insensitive
    if name then
        for k, v in pairs(CPSLookup) do
            if string.lower(k) == string.lower(name) then
                if v.image and v.image ~= "" then return v.image end
            end
        end
    end
    -- Try EntitiesData directly
    if EntitiesData and EntitiesData.Brainrots and name then
        local data = EntitiesData.Brainrots[name]
        if data then
            local img = data.Image or data.Icon or data.Thumbnail or data.ImageId or data.IconId
            if img then
                if type(img) == "number" then return "rbxassetid://" .. img end
                if type(img) == "string" and img ~= "" then return img end
            end
        end
    end
    return ""
end

ShowRollNotification = function(isGood, brName, mutation, cps, reason)
    local notif = Instance.new("Frame")
    notif.Name = "RollNotif"
    notif.Size = UDim2.new(1, 0, 0, 110)
    notif.BackgroundColor3 = Color.Surface
    notif.BorderSizePixel = 0
    notif.BackgroundTransparency = 1
    notif.Parent = NotifContainer
    Instance.new("UICorner", notif).CornerRadius = UDim.new(0, 10)
    
    local stroke = Instance.new("UIStroke", notif)
    stroke.Color = isGood and Color.Success or Color.Danger
    stroke.Thickness = 1.5
    stroke.Transparency = 1
    
    -- Inner padding
    local pad = Instance.new("UIPadding", notif)
    pad.PaddingLeft = UDim.new(0, 12); pad.PaddingRight = UDim.new(0, 12)
    pad.PaddingTop = UDim.new(0, 10); pad.PaddingBottom = UDim.new(0, 10)
    
    -- Status bar (top color accent)
    local accent = Instance.new("Frame", notif)
    accent.Name = "Accent"
    accent.Size = UDim2.new(1, 24, 0, 3)
    accent.Position = UDim2.new(0, -12, 0, -10)
    accent.BackgroundColor3 = isGood and Color.Success or Color.Danger
    accent.BorderSizePixel = 0
    accent.BackgroundTransparency = 1
    local accentCorner = Instance.new("UICorner", accent)
    accentCorner.CornerRadius = UDim.new(0, 10)
    
    -- Brainrot image
    local imgFrame = Instance.new("Frame", notif)
    imgFrame.Name = "ImgFrame"
    imgFrame.Size = UDim2.new(0, 60, 0, 60)
    imgFrame.Position = UDim2.new(0, 0, 0, 18)
    imgFrame.BackgroundColor3 = Color.Card
    imgFrame.BorderSizePixel = 0
    imgFrame.BackgroundTransparency = 1
    Instance.new("UICorner", imgFrame).CornerRadius = UDim.new(0, 8)
    
    local brImage = Instance.new("ImageLabel", imgFrame)
    brImage.Name = "BrImage"
    brImage.Size = UDim2.new(1, -8, 1, -8)
    brImage.Position = UDim2.new(0, 4, 0, 4)
    brImage.BackgroundTransparency = 1
    brImage.ScaleType = Enum.ScaleType.Fit
    brImage.ImageTransparency = 1
    local imageId = GetBrainrotImage(brName)
    if imageId ~= "" then brImage.Image = imageId end
    
    -- Right side info
    -- Title (GOOD ROLL / BAD ROLL)
    local title = Instance.new("TextLabel", notif)
    title.Name = "Title"
    title.Size = UDim2.new(1, -75, 0, 18)
    title.Position = UDim2.new(0, 72, 0, 14)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.TextColor3 = isGood and Color.Success or Color.Danger
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = isGood and "GOOD ROLL" or "BAD ROLL"
    title.TextTransparency = 1
    
    -- Brainrot name + mutation
    local rarity = GetRarity(brName)
    local rarColor = RarityColors[rarity] or RarityColors.Unknown
    local mutColor = MutationColors[mutation] or MutationColors.None
    
    local nameLabel = Instance.new("TextLabel", notif)
    nameLabel.Name = "BrName"
    nameLabel.Size = UDim2.new(1, -75, 0, 16)
    nameLabel.Position = UDim2.new(0, 72, 0, 34)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Font = Enum.Font.GothamSemibold
    nameLabel.TextSize = 13
    nameLabel.TextColor3 = rarColor
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Text = brName
    nameLabel.TextTransparency = 1
    
    -- Mutation line
    local mutLabel = Instance.new("TextLabel", notif)
    mutLabel.Name = "Mutation"
    mutLabel.Size = UDim2.new(1, -75, 0, 14)
    mutLabel.Position = UDim2.new(0, 72, 0, 52)
    mutLabel.BackgroundTransparency = 1
    mutLabel.Font = Enum.Font.Gotham
    mutLabel.TextSize = 11
    mutLabel.TextColor3 = mutColor
    mutLabel.TextXAlignment = Enum.TextXAlignment.Left
    mutLabel.Text = (mutation ~= "None" and mutation ~= "") and ("Mutation: " .. mutation) or "No Mutation"
    mutLabel.TextTransparency = 1
    
    -- CPS line
    local cpsLabel = Instance.new("TextLabel", notif)
    cpsLabel.Name = "CPS"
    cpsLabel.Size = UDim2.new(1, -75, 0, 14)
    cpsLabel.Position = UDim2.new(0, 72, 0, 67)
    cpsLabel.BackgroundTransparency = 1
    cpsLabel.Font = Enum.Font.GothamSemibold
    cpsLabel.TextSize = 12
    cpsLabel.TextColor3 = Color.Text
    cpsLabel.TextXAlignment = Enum.TextXAlignment.Left
    cpsLabel.Text = "CPS: " .. FmtNum(cps) .. "/s"
    cpsLabel.TextTransparency = 1
    
    -- Reason line
    local reasonLabel = Instance.new("TextLabel", notif)
    reasonLabel.Name = "Reason"
    reasonLabel.Size = UDim2.new(1, -75, 0, 14)
    reasonLabel.Position = UDim2.new(0, 72, 0, 83)
    reasonLabel.BackgroundTransparency = 1
    reasonLabel.Font = Enum.Font.Gotham
    reasonLabel.TextSize = 10
    reasonLabel.TextColor3 = Color.TextDim
    reasonLabel.TextXAlignment = Enum.TextXAlignment.Left
    reasonLabel.Text = reason
    reasonLabel.TextTransparency = 1
    reasonLabel.TextTruncate = Enum.TextTruncate.AtEnd
    
    -- Animate in
    task.defer(function()
        local tweenInfo = TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
        
        -- Fade in background
        TweenService:Create(notif, tweenInfo, {BackgroundTransparency = 0.05}):Play()
        TweenService:Create(stroke, tweenInfo, {Transparency = 0}):Play()
        TweenService:Create(accent, tweenInfo, {BackgroundTransparency = 0}):Play()
        TweenService:Create(imgFrame, tweenInfo, {BackgroundTransparency = 0}):Play()
        
        -- Fade in text
        TweenService:Create(title, tweenInfo, {TextTransparency = 0}):Play()
        TweenService:Create(nameLabel, tweenInfo, {TextTransparency = 0}):Play()
        TweenService:Create(mutLabel, tweenInfo, {TextTransparency = 0}):Play()
        TweenService:Create(cpsLabel, tweenInfo, {TextTransparency = 0}):Play()
        TweenService:Create(reasonLabel, tweenInfo, {TextTransparency = 0}):Play()
        TweenService:Create(brImage, tweenInfo, {ImageTransparency = 0}):Play()
        
        -- Auto dismiss after 6 seconds
        task.wait(6)
        
        local fadeOut = TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
        TweenService:Create(notif, fadeOut, {BackgroundTransparency = 1}):Play()
        TweenService:Create(stroke, fadeOut, {Transparency = 1}):Play()
        TweenService:Create(accent, fadeOut, {BackgroundTransparency = 1}):Play()
        TweenService:Create(imgFrame, fadeOut, {BackgroundTransparency = 1}):Play()
        TweenService:Create(title, fadeOut, {TextTransparency = 1}):Play()
        TweenService:Create(nameLabel, fadeOut, {TextTransparency = 1}):Play()
        TweenService:Create(mutLabel, fadeOut, {TextTransparency = 1}):Play()
        TweenService:Create(cpsLabel, fadeOut, {TextTransparency = 1}):Play()
        TweenService:Create(reasonLabel, fadeOut, {TextTransparency = 1}):Play()
        TweenService:Create(brImage, fadeOut, {ImageTransparency = 1}):Play()
        
        task.wait(0.6)
        notif:Destroy()
    end)
end

-- Main Window
local Win = Instance.new("Frame", SG)
Win.Name = "Win"; Win.Size = UDim2.new(0, 380, 0, 520)
Win.Position = UDim2.new(0.5, -190, 0.5, -260)
Win.BackgroundColor3 = Color.Bg; Win.BorderSizePixel = 0
Instance.new("UICorner", Win).CornerRadius = UDim.new(0, 12)
Instance.new("UIStroke", Win).Color = Color.Border

-- Shadow
local Shadow = Instance.new("ImageLabel", Win)
Shadow.Size = UDim2.new(1, 30, 1, 30); Shadow.Position = UDim2.new(0, -15, 0, -15)
Shadow.BackgroundTransparency = 1; Shadow.Image = "rbxassetid://6015897843"
Shadow.ImageColor3 = Color3.new(0,0,0); Shadow.ImageTransparency = 0.5
Shadow.ScaleType = Enum.ScaleType.Slice; Shadow.SliceCenter = Rect.new(49,49,450,450)
Shadow.ZIndex = -1

-- Header
local Header = Instance.new("Frame", Win)
Header.Size = UDim2.new(1, 0, 0, 44); Header.BackgroundColor3 = Color.Surface; Header.BorderSizePixel = 0
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 12)
local hFix = Instance.new("Frame", Header); hFix.Size = UDim2.new(1,0,0,12); hFix.Position = UDim2.new(0,0,1,-12); hFix.BackgroundColor3 = Color.Surface; hFix.BorderSizePixel = 0

local Title = Instance.new("TextLabel", Header)
Title.Size = UDim2.new(1, -90, 1, 0); Title.Position = UDim2.new(0, 16, 0, 0)
Title.BackgroundTransparency = 1; Title.Text = "norom HUB"
Title.TextColor3 = Color.Text; Title.Font = Enum.Font.GothamBlack; Title.TextSize = 15
Title.TextXAlignment = Enum.TextXAlignment.Left

local VerLbl = Instance.new("TextLabel", Header)
VerLbl.Size = UDim2.new(0, 40, 0, 16); VerLbl.Position = UDim2.new(0, 110, 0.5, -8)
VerLbl.BackgroundColor3 = Color.Primary; VerLbl.BorderSizePixel = 0
VerLbl.Text = "v1.2"; VerLbl.TextColor3 = Color.Text; VerLbl.Font = Enum.Font.GothamBold; VerLbl.TextSize = 9
Instance.new("UICorner", VerLbl).CornerRadius = UDim.new(0, 4)

local CloseBtn = Instance.new("TextButton", Header)
CloseBtn.Size = UDim2.new(0, 28, 0, 28); CloseBtn.Position = UDim2.new(1, -36, 0.5, -14)
CloseBtn.BackgroundColor3 = Color.Danger; CloseBtn.BorderSizePixel = 0; CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color.Text; CloseBtn.Font = Enum.Font.GothamBold; CloseBtn.TextSize = 12
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)

local MinBtn = Instance.new("TextButton", Header)
MinBtn.Size = UDim2.new(0, 28, 0, 28); MinBtn.Position = UDim2.new(1, -68, 0.5, -14)
MinBtn.BackgroundColor3 = Color.Warning; MinBtn.BorderSizePixel = 0; MinBtn.Text = "-"
MinBtn.TextColor3 = Color.Text; MinBtn.Font = Enum.Font.GothamBold; MinBtn.TextSize = 14
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 6)

-- Player Profile Card
local ProfileCard = Instance.new("Frame", Win)
ProfileCard.Name = "ProfileCard"
ProfileCard.Size = UDim2.new(1, -16, 0, 56)
ProfileCard.Position = UDim2.new(0, 8, 0, 48)
ProfileCard.BackgroundColor3 = Color.Surface
ProfileCard.BorderSizePixel = 0
Instance.new("UICorner", ProfileCard).CornerRadius = UDim.new(0, 8)

-- Avatar Image (circular)
local AvatarFrame = Instance.new("Frame", ProfileCard)
AvatarFrame.Name = "AvatarFrame"
AvatarFrame.Size = UDim2.new(0, 40, 0, 40)
AvatarFrame.Position = UDim2.new(0, 8, 0.5, -20)
AvatarFrame.BackgroundColor3 = Color.Card
AvatarFrame.BorderSizePixel = 0
Instance.new("UICorner", AvatarFrame).CornerRadius = UDim.new(1, 0) -- Circle

local AvatarImg = Instance.new("ImageLabel", AvatarFrame)
AvatarImg.Name = "Avatar"
AvatarImg.Size = UDim2.new(1, -4, 1, -4)
AvatarImg.Position = UDim2.new(0, 2, 0, 2)
AvatarImg.BackgroundTransparency = 1
AvatarImg.ScaleType = Enum.ScaleType.Fit
-- Load avatar in background (non-blocking so UI appears instantly)
task.defer(function()
    pcall(function()
        local thumbType = Enum.ThumbnailType.HeadShot
        local thumbSize = Enum.ThumbnailSize.Size150x150
        local content, isReady = Players:GetUserThumbnailAsync(LP.UserId, thumbType, thumbSize)
        AvatarImg.Image = content
    end)
end)
local avatarCorner = Instance.new("UICorner", AvatarImg)
avatarCorner.CornerRadius = UDim.new(1, 0)

-- Online indicator (green dot)
local OnlineDot = Instance.new("Frame", AvatarFrame)
OnlineDot.Name = "OnlineDot"
OnlineDot.Size = UDim2.new(0, 10, 0, 10)
OnlineDot.Position = UDim2.new(1, -10, 1, -10)
OnlineDot.BackgroundColor3 = Color.Success
OnlineDot.BorderSizePixel = 0
Instance.new("UICorner", OnlineDot).CornerRadius = UDim.new(1, 0)
local dotStroke = Instance.new("UIStroke", OnlineDot)
dotStroke.Color = Color.Surface; dotStroke.Thickness = 2

-- Display Name
local DisplayName = Instance.new("TextLabel", ProfileCard)
DisplayName.Name = "DisplayName"
DisplayName.Size = UDim2.new(1, -120, 0, 18)
DisplayName.Position = UDim2.new(0, 56, 0, 10)
DisplayName.BackgroundTransparency = 1
DisplayName.Font = Enum.Font.GothamBold
DisplayName.TextSize = 13
DisplayName.TextColor3 = Color.Text
DisplayName.TextXAlignment = Enum.TextXAlignment.Left
DisplayName.TextTruncate = Enum.TextTruncate.AtEnd
pcall(function() DisplayName.Text = LP.DisplayName or LP.Name end)

-- Username
local Username = Instance.new("TextLabel", ProfileCard)
Username.Name = "Username"
Username.Size = UDim2.new(1, -120, 0, 14)
Username.Position = UDim2.new(0, 56, 0, 30)
Username.BackgroundTransparency = 1
Username.Font = Enum.Font.Gotham
Username.TextSize = 10
Username.TextColor3 = Color.TextDim
Username.TextXAlignment = Enum.TextXAlignment.Left
Username.TextTruncate = Enum.TextTruncate.AtEnd
pcall(function() Username.Text = "@" .. LP.Name end)

-- Status badge (right side)
local StatusBadge = Instance.new("Frame", ProfileCard)
StatusBadge.Name = "StatusBadge"
StatusBadge.Size = UDim2.new(0, 55, 0, 20)
StatusBadge.Position = UDim2.new(1, -63, 0.5, -10)
StatusBadge.BackgroundColor3 = Color.Success
StatusBadge.BorderSizePixel = 0
Instance.new("UICorner", StatusBadge).CornerRadius = UDim.new(0, 4)

local StatusText = Instance.new("TextLabel", StatusBadge)
StatusText.Name = "StatusText"
StatusText.Size = UDim2.new(1, 0, 1, 0)
StatusText.BackgroundTransparency = 1
StatusText.Font = Enum.Font.GothamBold
StatusText.TextSize = 9
StatusText.TextColor3 = Color3.fromRGB(255, 255, 255)
StatusText.Text = "ACTIVE"

-- Tab Bar
local TabFrame = Instance.new("Frame", Win)
TabFrame.Size = UDim2.new(1, -16, 0, 28); TabFrame.Position = UDim2.new(0, 8, 0, 108)
TabFrame.BackgroundColor3 = Color.Surface; TabFrame.BorderSizePixel = 0
Instance.new("UICorner", TabFrame).CornerRadius = UDim.new(0, 6)
local tabLayout = Instance.new("UIListLayout", TabFrame)
tabLayout.FillDirection = Enum.FillDirection.Horizontal; tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.Padding = UDim.new(0, 2)
Instance.new("UIPadding", TabFrame).PaddingLeft = UDim.new(0, 2)

-- Content Area
local ContentFrame = Instance.new("Frame", Win)
ContentFrame.Size = UDim2.new(1, -16, 1, -144); ContentFrame.Position = UDim2.new(0, 8, 0, 140)
ContentFrame.BackgroundTransparency = 1; ContentFrame.ClipsDescendants = true

-- ══════════════════════════════════════════════════════════════
-- UI BUILDER
-- ══════════════════════════════════════════════════════════════
local Pages, TabBtns = {}, {}
local ActiveTab = nil

local function SwitchTab(name)
    for n, btn in pairs(TabBtns) do
        btn.BackgroundColor3 = n == name and Color.Primary or Color3.new(0,0,0)
        btn.BackgroundTransparency = n == name and 0 or 1
        btn.TextColor3 = n == name and Color.Text or Color.TextDim
    end
    for n, page in pairs(Pages) do page.Visible = (n == name) end
    ActiveTab = name
end

local function CreateTab(name, order)
    local btn = Instance.new("TextButton", TabFrame)
    btn.Size = UDim2.new(0, 48, 0, 24); btn.Position = UDim2.new(0, 0, 0, 2)
    btn.BackgroundTransparency = 1; btn.BackgroundColor3 = Color.Primary; btn.BorderSizePixel = 0
    btn.Text = name; btn.TextColor3 = Color.TextDim
    btn.Font = Enum.Font.GothamBold; btn.TextSize = 10; btn.LayoutOrder = order
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
    
    local page = Instance.new("ScrollingFrame", ContentFrame)
    page.Size = UDim2.new(1, 0, 1, 0); page.BackgroundTransparency = 1
    page.ScrollBarThickness = 2; page.ScrollBarImageColor3 = Color.Primary
    page.BorderSizePixel = 0; page.Visible = false
    page.CanvasSize = UDim2.new(0, 0, 0, 0); page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    local ly = Instance.new("UIListLayout", page); ly.Padding = UDim.new(0, 5); ly.SortOrder = Enum.SortOrder.LayoutOrder
    Instance.new("UIPadding", page).PaddingTop = UDim.new(0, 2)
    
    Pages[name] = page; TabBtns[name] = btn
    btn.MouseButton1Click:Connect(function() SwitchTab(name) end)
    return page
end

local function Section(parent, text, order)
    local lbl = Instance.new("TextLabel", parent)
    lbl.Size = UDim2.new(1, 0, 0, 18); lbl.BackgroundTransparency = 1
    lbl.Text = string.upper(text); lbl.TextColor3 = Color.Primary
    lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 9
    lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.LayoutOrder = order
end

local function Toggle(parent, text, key, cb, order)
    local row = Instance.new("Frame", parent)
    row.Size = UDim2.new(1, 0, 0, 32); row.BackgroundColor3 = Color.Card; row.BorderSizePixel = 0; row.LayoutOrder = order
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)
    
    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(1, -80, 1, 0); lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1; lbl.Text = text
    lbl.TextColor3 = Color.Text; lbl.Font = Enum.Font.GothamMedium; lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.TextTruncate = Enum.TextTruncate.AtEnd
    
    local on = S[key] or false
    
    local pill = Instance.new("Frame", row)
    pill.Size = UDim2.new(0, 40, 0, 20); pill.Position = UDim2.new(1, -52, 0.5, -10)
    pill.BackgroundColor3 = on and Color.ToggleOn or Color.ToggleOff; pill.BorderSizePixel = 0
    Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)
    
    local circle = Instance.new("Frame", pill)
    circle.Size = UDim2.new(0, 16, 0, 16)
    circle.Position = on and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
    circle.BackgroundColor3 = Color.Text; circle.BorderSizePixel = 0
    Instance.new("UICorner", circle).CornerRadius = UDim.new(1, 0)
    
    local hitbox = Instance.new("TextButton", row)
    hitbox.Size = UDim2.new(1, 0, 1, 0); hitbox.BackgroundTransparency = 1; hitbox.Text = ""
    
    hitbox.MouseButton1Click:Connect(function()
        on = not on; S[key] = on
        TweenService:Create(pill, TweenInfo.new(0.2), {BackgroundColor3 = on and Color.ToggleOn or Color.ToggleOff}):Play()
        TweenService:Create(circle, TweenInfo.new(0.2), {Position = on and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)}):Play()
        if cb then pcall(cb, on) end
    end)
end

local function NumInput(parent, text, key, placeholder, order)
    local row = Instance.new("Frame", parent)
    row.Size = UDim2.new(1, 0, 0, 32); row.BackgroundColor3 = Color.Card; row.BorderSizePixel = 0; row.LayoutOrder = order
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)
    
    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(0.55, 0, 1, 0); lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1; lbl.Text = text
    lbl.TextColor3 = Color.Text; lbl.Font = Enum.Font.GothamMedium; lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    
    local box = Instance.new("TextBox", row)
    box.Size = UDim2.new(0.38, 0, 0, 22); box.Position = UDim2.new(0.58, 0, 0.5, -11)
    box.BackgroundColor3 = Color.Input; box.BorderSizePixel = 0
    box.Text = tostring(S[key] or ""); box.PlaceholderText = placeholder or "Enter number"
    box.TextColor3 = Color.Primary; box.PlaceholderColor3 = Color.TextDim
    box.Font = Enum.Font.GothamBold; box.TextSize = 11; box.ClearTextOnFocus = false
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 4)
    Instance.new("UIStroke", box).Color = Color.Border
    
    box.FocusLost:Connect(function()
        local num = tonumber(box.Text)
        if num then
            num = math.floor(num)
            -- Clamp KickPower to 1-100
            if key == "KickPower" then num = math.clamp(num, 1, 100) end
            S[key] = num
            box.Text = tostring(num)
        else
            box.Text = tostring(S[key] or 0)
        end
        pcall(SaveConfig)
    end)
    
    return box
end

local function Dropdown(parent, text, options, key, order)
    local row = Instance.new("Frame", parent)
    row.Size = UDim2.new(1, 0, 0, 32); row.BackgroundColor3 = Color.Card; row.BorderSizePixel = 0; row.LayoutOrder = order
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)
    
    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(0.5, 0, 1, 0); lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1; lbl.Text = text
    lbl.TextColor3 = Color.Text; lbl.Font = Enum.Font.GothamMedium; lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    
    local idx = 1
    for i, o in ipairs(options) do if o == S[key] then idx = i; break end end
    
    local btn = Instance.new("TextButton", row)
    btn.Size = UDim2.new(0.42, 0, 0, 22); btn.Position = UDim2.new(0.54, 0, 0.5, -11)
    btn.BackgroundColor3 = Color.Input; btn.BorderSizePixel = 0
    btn.Text = "  " .. options[idx] .. "  >"; btn.TextColor3 = Color.Primary
    btn.Font = Enum.Font.GothamMedium; btn.TextSize = 10
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
    Instance.new("UIStroke", btn).Color = Color.Border
    
    btn.MouseButton1Click:Connect(function()
        idx = idx + 1; if idx > #options then idx = 1 end
        S[key] = options[idx]
        btn.Text = "  " .. options[idx] .. "  >"
    end)
end

local function Slider(parent, text, min, max, key, order)
    local row = Instance.new("Frame", parent)
    row.Size = UDim2.new(1, 0, 0, 38); row.BackgroundColor3 = Color.Card; row.BorderSizePixel = 0; row.LayoutOrder = order
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)
    
    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(0.6, 0, 0, 16); lbl.Position = UDim2.new(0, 12, 0, 2)
    lbl.BackgroundTransparency = 1; lbl.Text = text
    lbl.TextColor3 = Color.Text; lbl.Font = Enum.Font.GothamMedium; lbl.TextSize = 10
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    
    local val = S[key] or min
    local vLbl = Instance.new("TextLabel", row)
    vLbl.Size = UDim2.new(0.35, 0, 0, 16); vLbl.Position = UDim2.new(0.6, 0, 0, 2)
    vLbl.BackgroundTransparency = 1; vLbl.Text = tostring(val)
    vLbl.TextColor3 = Color.Primary; vLbl.Font = Enum.Font.GothamBold; vLbl.TextSize = 10
    vLbl.TextXAlignment = Enum.TextXAlignment.Right
    
    local track = Instance.new("Frame", row)
    track.Size = UDim2.new(1, -24, 0, 4); track.Position = UDim2.new(0, 12, 0, 26)
    track.BackgroundColor3 = Color.ToggleOff; track.BorderSizePixel = 0
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)
    
    local pct = math.clamp((val - min) / math.max(max - min, 1), 0, 1)
    local fill = Instance.new("Frame", track)
    fill.Size = UDim2.new(pct, 0, 1, 0); fill.BackgroundColor3 = Color.Primary; fill.BorderSizePixel = 0
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
    
    local knob = Instance.new("Frame", track)
    knob.Size = UDim2.new(0, 12, 0, 12); knob.Position = UDim2.new(pct, -6, 0.5, -6)
    knob.BackgroundColor3 = Color.Text; knob.BorderSizePixel = 0
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
    
    local dragging = false
    local hitbox = Instance.new("TextButton", row)
    hitbox.Size = UDim2.new(1, 0, 0, 18); hitbox.Position = UDim2.new(0, 0, 0, 18)
    hitbox.BackgroundTransparency = 1; hitbox.Text = ""
    
    local function Update(input)
        local tX = track.AbsolutePosition.X; local tW = track.AbsoluteSize.X
        if tW == 0 then return end
        local p = math.clamp((input.Position.X - tX) / tW, 0, 1)
        local v = math.floor(min + (max - min) * p)
        fill.Size = UDim2.new(p, 0, 1, 0); knob.Position = UDim2.new(p, -6, 0.5, -6)
        vLbl.Text = tostring(v); S[key] = v
    end
    hitbox.MouseButton1Down:Connect(function() dragging = true end)
    AddC(UIS.InputChanged:Connect(function(i) if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then Update(i) end end))
    AddC(UIS.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end))
end

local function Button(parent, text, cb, order)
    local btn = Instance.new("TextButton", parent)
    btn.Size = UDim2.new(1, 0, 0, 28); btn.BackgroundColor3 = Color.Card; btn.BorderSizePixel = 0
    btn.Text = "  " .. text; btn.TextColor3 = Color.Primary
    btn.Font = Enum.Font.GothamMedium; btn.TextSize = 11
    btn.TextXAlignment = Enum.TextXAlignment.Left; btn.LayoutOrder = order
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    btn.MouseButton1Click:Connect(function()
        if cb then pcall(cb) end
        local orig = btn.Text; btn.Text = "  Done!"; btn.TextColor3 = Color.Success
        task.delay(1, function() btn.Text = orig; btn.TextColor3 = Color.Primary end)
    end)
end

local function InfoLabel(parent, text, order)
    local lbl = Instance.new("TextLabel", parent)
    lbl.Size = UDim2.new(1, 0, 0, 14); lbl.BackgroundTransparency = 1
    lbl.Text = text; lbl.TextColor3 = Color.TextDim
    lbl.Font = Enum.Font.Gotham; lbl.TextSize = 9
    lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.LayoutOrder = order
    return lbl
end

-- ══════════════════════════════════════════════════════════════
-- BUILD TABS
-- ══════════════════════════════════════════════════════════════
local P_Smart = CreateTab("Smart", 1)
local P_Farm = CreateTab("Farm", 2)
local P_Base = CreateTab("Base", 3)
local P_Upgrade = CreateTab("Upgrade", 4)
local P_Train = CreateTab("Train", 5)
local P_Webhook = CreateTab("Hook", 6)
local P_Settings = CreateTab("Config", 7)

-- ═══════════════ SMART TAB ═══════════════
Section(P_Smart, "SMART FARM", 1)
InfoLabel(P_Smart, "Auto Kick > Analyze CPS > Filter & Collect Best Rolls", 2)

Toggle(P_Smart, "Smart Farm", "SmartFarm", function(v) if v then task.spawn(SmartFarmLoop) end end, 3)

Section(P_Smart, "SETTINGS", 4)
NumInput(P_Smart, "Min CPS Target", "TargetCPS", "e.g. 5000", 5)
NumInput(P_Smart, "Kick Power %", "KickPower", "1-100", 6)

Section(P_Smart, "RARITY PRIORITY", 7)
InfoLabel(P_Smart, "Select rarity to auto-collect regardless of CPS:", 8)
InfoLabel(P_Smart, "(If matched, brainrot is collected instantly without CPS check)", 9)

-- Rarity multi-select using checkboxes
local RarityOptions = {"Off", "Common", "Rare", "Epic", "Legendary", "Mythic", "Godly", "Secret", "Divine", "Hacked", "OG", "Celestial", "Exclusive", "Eternal"}
local SelectedRarities = {} -- table of selected rarities

-- Create a scrollable rarity selector
local rarFrame = Instance.new("Frame", P_Smart)
rarFrame.Name = "RaritySelector"
rarFrame.Size = UDim2.new(1, 0, 0, 120)
rarFrame.BackgroundColor3 = Color.Card
rarFrame.BorderSizePixel = 0
rarFrame.LayoutOrder = 10
Instance.new("UICorner", rarFrame).CornerRadius = UDim.new(0, 8)

local rarScroll = Instance.new("ScrollingFrame", rarFrame)
rarScroll.Size = UDim2.new(1, -8, 1, -8)
rarScroll.Position = UDim2.new(0, 4, 0, 4)
rarScroll.BackgroundTransparency = 1
rarScroll.ScrollBarThickness = 2
rarScroll.ScrollBarImageColor3 = Color.Primary
rarScroll.BorderSizePixel = 0
rarScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
rarScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
local rarLayout = Instance.new("UIListLayout", rarScroll)
rarLayout.Padding = UDim.new(0, 3)
rarLayout.SortOrder = Enum.SortOrder.LayoutOrder

local rarCheckboxes = {}

local function UpdateRarityState()
    -- Build the selected rarities string for display
    local selected = {}
    for _, name in ipairs(RarityOptions) do
        if name ~= "Off" and SelectedRarities[name] then
            table.insert(selected, name)
        end
    end
    if #selected == 0 then
        S.RarityFilter = "Off"
    else
        S.RarityFilter = table.concat(selected, ",")
    end
end

for i, rarName in ipairs(RarityOptions) do
    local row = Instance.new("Frame", rarScroll)
    row.Size = UDim2.new(1, 0, 0, 22)
    row.BackgroundTransparency = 1
    row.LayoutOrder = i
    
    -- Checkbox
    local check = Instance.new("Frame", row)
    check.Size = UDim2.new(0, 16, 0, 16)
    check.Position = UDim2.new(0, 4, 0.5, -8)
    check.BackgroundColor3 = Color.Input
    check.BorderSizePixel = 0
    Instance.new("UICorner", check).CornerRadius = UDim.new(0, 4)
    Instance.new("UIStroke", check).Color = Color.Border
    
    local checkMark = Instance.new("TextLabel", check)
    checkMark.Size = UDim2.new(1, 0, 1, 0)
    checkMark.BackgroundTransparency = 1
    checkMark.Text = ""
    checkMark.TextColor3 = Color.Success
    checkMark.Font = Enum.Font.GothamBold
    checkMark.TextSize = 12
    
    -- Label
    local rarLbl = Instance.new("TextLabel", row)
    rarLbl.Size = UDim2.new(1, -30, 1, 0)
    rarLbl.Position = UDim2.new(0, 26, 0, 0)
    rarLbl.BackgroundTransparency = 1
    rarLbl.Font = Enum.Font.GothamMedium
    rarLbl.TextSize = 10
    rarLbl.TextXAlignment = Enum.TextXAlignment.Left
    
    if rarName == "Off" then
        rarLbl.Text = "Off (CPS check only)"
        rarLbl.TextColor3 = Color.TextDim
    else
        local rarCol = RarityColors and RarityColors[rarName] or Color.Text
        rarLbl.Text = rarName
        rarLbl.TextColor3 = rarCol
    end
    
    -- Default: Off is selected
    local isOn = (rarName == "Off")
    if isOn then
        checkMark.Text = "\226\156\147"
        check.BackgroundColor3 = Color.Success
    end
    
    rarCheckboxes[rarName] = {check = check, mark = checkMark, on = isOn}
    
    -- Click handler
    local hitbox = Instance.new("TextButton", row)
    hitbox.Size = UDim2.new(1, 0, 1, 0)
    hitbox.BackgroundTransparency = 1
    hitbox.Text = ""
    
    hitbox.MouseButton1Click:Connect(function()
        if rarName == "Off" then
            -- Turn off all others, turn on Off
            for name, data in pairs(rarCheckboxes) do
                if name == "Off" then
                    data.on = true
                    data.mark.Text = "\226\156\147"
                    data.check.BackgroundColor3 = Color.Success
                else
                    data.on = false
                    data.mark.Text = ""
                    data.check.BackgroundColor3 = Color.Input
                end
            end
            SelectedRarities = {}
        else
            -- Toggle this rarity
            local data = rarCheckboxes[rarName]
            data.on = not data.on
            if data.on then
                data.mark.Text = "\226\156\147"
                data.check.BackgroundColor3 = Color.Success
                SelectedRarities[rarName] = true
                -- Uncheck "Off"
                rarCheckboxes["Off"].on = false
                rarCheckboxes["Off"].mark.Text = ""
                rarCheckboxes["Off"].check.BackgroundColor3 = Color.Input
            else
                data.mark.Text = ""
                data.check.BackgroundColor3 = Color.Input
                SelectedRarities[rarName] = nil
                -- If nothing selected, re-enable Off
                local anyOn = false
                for name, d in pairs(rarCheckboxes) do
                    if name ~= "Off" and d.on then anyOn = true; break end
                end
                if not anyOn then
                    rarCheckboxes["Off"].on = true
                    rarCheckboxes["Off"].mark.Text = "\226\156\147"
                    rarCheckboxes["Off"].check.BackgroundColor3 = Color.Success
                end
            end
        end
        UpdateRarityState()
    end)
end

-- Initialize rarity checkboxes from loaded config
if S.RarityFilter and S.RarityFilter ~= "Off" then
    -- Parse saved rarity filter and check the boxes
    for rarName in string.gmatch(S.RarityFilter, "[^,]+") do
        rarName = rarName:match("^%s*(.-)%s*$") -- trim
        if rarCheckboxes[rarName] then
            rarCheckboxes[rarName].on = true
            rarCheckboxes[rarName].mark.Text = "\226\156\147"
            rarCheckboxes[rarName].check.BackgroundColor3 = Color.Success
            SelectedRarities[rarName] = true
        end
    end
    -- Uncheck "Off"
    if next(SelectedRarities) then
        rarCheckboxes["Off"].on = false
        rarCheckboxes["Off"].mark.Text = ""
        rarCheckboxes["Off"].check.BackgroundColor3 = Color.Input
    end
end

Section(P_Smart, "LIVE STATUS", 11)
local stLbl = InfoLabel(P_Smart, "Status: Idle", 12)
local rollLbl = InfoLabel(P_Smart, "Last: ---", 13)
local cpsLbl = InfoLabel(P_Smart, "CPS: ---", 14)
local countLbl = InfoLabel(P_Smart, "Good: 0 | Bad: 0", 15)

-- Status updater
task.spawn(function()
    while S.Running do
        pcall(function()
            stLbl.Text = "Status: " .. S.Status
            stLbl.TextColor3 = S.Status:find("GOOD") and Color.Success or (S.Status:find("BAD") and Color.Danger or Color.TextDim)
            rollLbl.Text = "Last: " .. S.LastRoll
            cpsLbl.Text = "CPS: " .. S.LastCPS
            countLbl.Text = "Good: " .. S.GoodCount .. " | Bad: " .. S.BadCount
        end)
        task.wait(0.3)
    end
end)

-- ═══════════════ FARM TAB ═══════════════
Section(P_Farm, "COLLECT & REBIRTH", 1)
Toggle(P_Farm, "Auto Collect", "AutoCollect", function(v) if v then task.spawn(LoopCollect) end end, 2)
Toggle(P_Farm, "Auto Rebirth", "AutoRebirth", function(v) if v then task.spawn(LoopRebirth) end end, 3)

Section(P_Farm, "SELL", 4)
Toggle(P_Farm, "Auto Sell (Non-Fav)", "AutoSell", function(v) if v then task.spawn(LoopSell) end end, 5)

-- ═══════════════ BASE TAB ═══════════════
Section(P_Base, "AUTO FAVORITE / UNFAVORITE", 1)
InfoLabel(P_Base, "Scan semua brainrot di inventory (Backpack)", 2)
InfoLabel(P_Base, "Brainrot CPS >= Min Fav = otomatis di-FAVORITE", 3)
InfoLabel(P_Base, "Brainrot CPS < Min Unfav = otomatis di-UNFAVORITE", 4)
Toggle(P_Base, "Auto Favorite & Unfavorite", "AutoFavorite", function(v) if v then task.spawn(LoopFav) end end, 5)
NumInput(P_Base, "Min CPS Favorite (di atas = fav)", "MinFavCPS", "1000", 6)
NumInput(P_Base, "Min CPS Unfavorite (di bawah = unfav)", "MinUnfavCPS", "100", 7)

Section(P_Base, "REMOVE & PLACE", 8)
InfoLabel(P_Base, "Remove All = cabut semua brainrot dari base 1 per 1", 9)
Button(P_Base, "Remove All Brainrot dari Base", function() DoRemoveAll(); Notify("norom HUB", "Removing all brainrots...", 3) end, 10)
InfoLabel(P_Base, "Place Best = pasang brainrot terkuat (CPS Lv1 database)", 11)
InfoLabel(P_Base, "Urutan: CPS tertinggi di slot pertama, dst.", 12)
Button(P_Base, "Place Best Brainrot (CPS Lv1)", function() DoPlaceBestGlobal(); Notify("norom HUB", "Placing best brainrots...", 3) end, 13)
Toggle(P_Base, "Auto Place Best (Loop)", "AutoPlaceBestGlobal", function(v) if v then task.spawn(LoopPlaceBestGlobal) end end, 14)

Section(P_Base, "PLOT UPGRADE", 15)
Toggle(P_Base, "Auto Plot Upgrade", "AutoPlotUpgrade", function(v) if v then task.spawn(LoopPlotUpgrade) end end, 16)

-- ═══════════════ UPGRADE TAB ═══════════════
Section(P_Upgrade, "BRAINROT UPGRADE", 1)
InfoLabel(P_Upgrade, "Upgrade brainrot yang terpasang di base", 2)
Toggle(P_Upgrade, "Auto Upgrade Brainrot", "AutoUpgrade", function(v) if v then task.spawn(LoopUpgrade) end end, 3)

Section(P_Upgrade, "SPEED & BASE", 4)
Toggle(P_Upgrade, "Auto Buy Speed", "AutoBuySpeed", function(v) if v then task.spawn(LoopBuySpeed) end end, 5)
Toggle(P_Upgrade, "Auto Base Upgrade", "AutoBaseUpgrade", function(v) if v then task.spawn(LoopBaseUpgrade) end end, 6)


-- ═══════════════ TRAIN TAB (WEIGHT LIFTING) ═══════════════
Section(P_Train, "WEIGHT TRAINING", 1)
Toggle(P_Train, "Auto Train (Equip Weight)", "AutoTrain", function(v) if v then task.spawn(LoopTrain) end end, 2)
Toggle(P_Train, "Auto Collect Train Cash", "AutoTrainCollect", function(v) if v then task.spawn(LoopTrainCollect) end end, 3)
Toggle(P_Train, "Auto Claim 2x Bonus", "Auto2xBonus", function(v)
    if v then
        task.spawn(Loop2xBonus)
    else
        StopBonus2xListener()
    end
end, 4)

Section(P_Train, "WEIGHT SHOP", 5)

-- Build weight list dynamically from game
local WeightList = {"None"}
pcall(function()
    local wm = RS:FindFirstChild("Objects") and RS.Objects:FindFirstChild("WeightModels")
    if wm then
        for _, w in ipairs(wm:GetChildren()) do
            table.insert(WeightList, w.Name)
        end
    end
    -- Fallback: try WeightsData module
    if #WeightList <= 1 then
        local wd = RS:FindFirstChild("WeightsData", true)
        if wd then
            local data = require(wd)
            if data and data.Weights then
                for name, _ in pairs(data.Weights) do
                    table.insert(WeightList, name)
                end
            end
        end
    end
end)

Dropdown(P_Train, "Select Weight", WeightList, "TargetWeight", 6)
Toggle(P_Train, "Auto Buy Weight", "AutoBuyWeight", function(v) if v then task.spawn(LoopBuyWeight) end end, 7)

-- ═══════════════ WEBHOOK TAB ═══════════════
Section(P_Webhook, "DISCORD INTEGRATION", 1)
InfoLabel(P_Webhook, "Send GOOD ROLL notifications to your Discord channel via webhook.", 2)
InfoLabel(P_Webhook, "Only good rolls are sent. Bad rolls are not notified.", 3)

Section(P_Webhook, "WEBHOOK SETTINGS", 4)
Toggle(P_Webhook, "Enable Webhook", "WebhookEnabled", nil, 5)

-- Webhook URL input
local webhookRow = Instance.new("Frame", P_Webhook)
webhookRow.Size = UDim2.new(1, 0, 0, 32); webhookRow.BackgroundColor3 = Color.Card; webhookRow.BorderSizePixel = 0; webhookRow.LayoutOrder = 6
Instance.new("UICorner", webhookRow).CornerRadius = UDim.new(0, 8)

local webhookLbl = Instance.new("TextLabel", webhookRow)
webhookLbl.Size = UDim2.new(0, 70, 1, 0); webhookLbl.Position = UDim2.new(0, 12, 0, 0)
webhookLbl.BackgroundTransparency = 1; webhookLbl.Text = "URL:"
webhookLbl.TextColor3 = Color.Text; webhookLbl.Font = Enum.Font.GothamMedium; webhookLbl.TextSize = 10
webhookLbl.TextXAlignment = Enum.TextXAlignment.Left

local webhookBox = Instance.new("TextBox", webhookRow)
webhookBox.Size = UDim2.new(1, -90, 0, 22); webhookBox.Position = UDim2.new(0, 78, 0.5, -11)
webhookBox.BackgroundColor3 = Color.Input; webhookBox.BorderSizePixel = 0
webhookBox.Text = S.WebhookURL; webhookBox.PlaceholderText = "Paste Discord webhook URL here"
webhookBox.TextColor3 = Color.Primary; webhookBox.PlaceholderColor3 = Color.TextDim
webhookBox.Font = Enum.Font.Gotham; webhookBox.TextSize = 9; webhookBox.ClearTextOnFocus = false
webhookBox.TextTruncate = Enum.TextTruncate.AtEnd
Instance.new("UICorner", webhookBox).CornerRadius = UDim.new(0, 4)
Instance.new("UIStroke", webhookBox).Color = Color.Border

webhookBox.FocusLost:Connect(function()
    S.WebhookURL = webhookBox.Text
    if S.WebhookURL ~= "" and S.WebhookEnabled then
        Notify("norom HUB", "Webhook configured! Good rolls will be sent to Discord.", 3)
    end
end)

Section(P_Webhook, "TEST & VERIFY", 7)
InfoLabel(P_Webhook, "Press the button below to send a test notification to your Discord.", 8)
Button(P_Webhook, "Send Test Notification", function()
    if S.WebhookURL == "" then
        Notify("norom HUB", "Please enter a webhook URL first!", 3)
        return
    end
    print("[norom HUB] Sending test webhook to: " .. string.sub(S.WebhookURL, 1, 50) .. "...")
    print("[norom HUB] Checking HTTP functions...")
    print("[norom HUB] request: " .. tostring(request))
    print("[norom HUB] http_request: " .. tostring(http_request))
    print("[norom HUB] syn: " .. tostring(syn))
    print("[norom HUB] http: " .. tostring(http))
    print("[norom HUB] fluxus_request: " .. tostring(fluxus_request))
    local origEnabled = S.WebhookEnabled
    S.WebhookEnabled = true
    SendWebhook("Test Brainrot", "Golden", 999999, "Legendary", "Webhook Test - Connection OK!")
    S.WebhookEnabled = origEnabled
    Notify("norom HUB", "Test sent! Check F9 console for debug info.", 3)
end, 9)

Section(P_Webhook, "LAST 3 GOOD ROLLS", 10)
InfoLabel(P_Webhook, "Recent valuable rolls collected this session:", 11)

local historyLabels = {}
for i = 1, 3 do
    local histRow = Instance.new("Frame", P_Webhook)
    histRow.Size = UDim2.new(1, 0, 0, 36); histRow.BackgroundColor3 = Color.Card; histRow.BorderSizePixel = 0; histRow.LayoutOrder = 11 + i
    Instance.new("UICorner", histRow).CornerRadius = UDim.new(0, 8)
    
    local numLbl = Instance.new("TextLabel", histRow)
    numLbl.Size = UDim2.new(0, 20, 1, 0); numLbl.Position = UDim2.new(0, 8, 0, 0)
    numLbl.BackgroundTransparency = 1; numLbl.Text = "#" .. i
    numLbl.TextColor3 = Color.Primary; numLbl.Font = Enum.Font.GothamBold; numLbl.TextSize = 10
    numLbl.TextXAlignment = Enum.TextXAlignment.Left
    
    local nameLbl = Instance.new("TextLabel", histRow)
    nameLbl.Name = "NameLbl"
    nameLbl.Size = UDim2.new(0.55, 0, 0, 14); nameLbl.Position = UDim2.new(0, 30, 0, 3)
    nameLbl.BackgroundTransparency = 1; nameLbl.Text = "---"
    nameLbl.TextColor3 = Color.Text; nameLbl.Font = Enum.Font.GothamMedium; nameLbl.TextSize = 9
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left; nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
    
    local detailLbl = Instance.new("TextLabel", histRow)
    detailLbl.Name = "DetailLbl"
    detailLbl.Size = UDim2.new(0.85, 0, 0, 12); detailLbl.Position = UDim2.new(0, 30, 0, 18)
    detailLbl.BackgroundTransparency = 1; detailLbl.Text = ""
    detailLbl.TextColor3 = Color.TextDim; detailLbl.Font = Enum.Font.Gotham; detailLbl.TextSize = 8
    detailLbl.TextXAlignment = Enum.TextXAlignment.Left; detailLbl.TextTruncate = Enum.TextTruncate.AtEnd
    
    local cpsHistLbl = Instance.new("TextLabel", histRow)
    cpsHistLbl.Name = "CPSLbl"
    cpsHistLbl.Size = UDim2.new(0.3, 0, 1, 0); cpsHistLbl.Position = UDim2.new(0.68, 0, 0, 0)
    cpsHistLbl.BackgroundTransparency = 1; cpsHistLbl.Text = ""
    cpsHistLbl.TextColor3 = Color.Success; cpsHistLbl.Font = Enum.Font.GothamBold; cpsHistLbl.TextSize = 9
    cpsHistLbl.TextXAlignment = Enum.TextXAlignment.Right
    
    historyLabels[i] = {name = nameLbl, detail = detailLbl, cps = cpsHistLbl}
end

-- History updater
task.spawn(function()
    while S.Running do
        pcall(function()
            for i = 1, 3 do
                local entry = S.GoodRollHistory[i]
                if entry then
                    historyLabels[i].name.Text = entry.name
                    local mutStr = (entry.mutation ~= "None" and entry.mutation ~= "") and (" [" .. entry.mutation .. "]") or ""
                    historyLabels[i].detail.Text = entry.rarity .. mutStr .. " | " .. entry.time
                    historyLabels[i].cps.Text = FmtNum(entry.cps) .. "/s"
                else
                    historyLabels[i].name.Text = "---"
                    historyLabels[i].detail.Text = ""
                    historyLabels[i].cps.Text = ""
                end
            end
        end)
        task.wait(1)
    end
end)

-- ═══════════════ SETTINGS TAB ═══════════════
Section(P_Settings, "PLAYER PROTECTION", 1)
InfoLabel(P_Settings, "Protect your character from damage and AFK kicks.", 2)
Toggle(P_Settings, "God Mode", "GodMode", function(v) if v then task.spawn(LoopGod) end end, 3)
Toggle(P_Settings, "Anti-AFK", "AntiAFK", function(v)
    if v then task.spawn(function()
        while S.AntiAFK and S.Running do
            pcall(function() game:GetService("VirtualUser"):CaptureController(); game:GetService("VirtualUser"):ClickButton2(Vector2.new()) end)
            task.wait(60)
        end
    end) end
end, 4)

Section(P_Settings, "PERFORMANCE", 5)
InfoLabel(P_Settings, "Optimize game performance for smoother farming.", 6)
Toggle(P_Settings, "FPS Boost", "FPSBoost", function(v)
    pcall(function()
        if v then
            settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
            for _, x in ipairs(WS:GetDescendants()) do
                if x:IsA("ParticleEmitter") or x:IsA("Trail") then x.Enabled = false end
            end
        else settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic end
    end)
end, 7)

Section(P_Settings, "QUICK ACTIONS", 8)
InfoLabel(P_Settings, "Manual one-click actions for quick use.", 9)
Button(P_Settings, "Teleport to Kick Zone", function() TeleportToKickZone(); Notify("norom HUB", "Teleported!", 2) end, 10)
Button(P_Settings, "Kick Now", function() DoKick(); Notify("norom HUB", "Kicked!", 2) end, 11)
Button(P_Settings, "Collect All", function() DoCollect(); Notify("norom HUB", "Collected!", 2) end, 12)
Button(P_Settings, "Sell All", function() DoSellAll(); Notify("norom HUB", "Sold!", 2) end, 13)
Button(P_Settings, "Rebirth", function() DoRebirth(); Notify("norom HUB", "Rebirthed!", 2) end, 14)
Button(P_Settings, "Upgrade All", function() DoUpgrade(); Notify("norom HUB", "Upgraded!", 2) end, 15)
Button(P_Settings, "Favorite Rare+", function() DoAutoFav(); Notify("norom HUB", "Favorited!", 2) end, 16)
Button(P_Settings, "Place Best", function() DoPlaceBest(); Notify("norom HUB", "Placed!", 2) end, 17)

Section(P_Settings, "DEBUG (F9 Console)", 18)
InfoLabel(P_Settings, "Advanced debug tools. Output shown in F9 console.", 19)
Button(P_Settings, "Print Remotes", function()
    local c = 0
    for k, v in pairs(R) do if v then c = c + 1; print("[noromHUB] " .. k .. " = " .. v.Name) end end
    Notify("norom HUB", c .. " remotes found", 3)
end, 20)
Button(P_Settings, "Print KickReady Info", function()
    local kr = GetKickReady()
    if kr then Notify("norom HUB", "KickReady: " .. kr:GetFullName(), 3); print("[noromHUB] KickReady:", kr:GetFullName(), kr.Position)
    else Notify("norom HUB", "KickReady NOT FOUND!", 3) end
end, 21)
Button(P_Settings, "Print InGame Attr", function()
    local raw = LP:GetAttribute("InGame") or ""
    Notify("norom HUB", "InGame: " .. (raw ~= "" and raw or "(empty)"), 4)
    print("[noromHUB] InGame:", raw)
end, 22)
Button(P_Settings, "Print CPS Database", function()
    local c = 0; for _ in pairs(CPSLookup) do c = c + 1 end
    Notify("norom HUB", c .. " brainrots loaded", 3)
end, 23)
Button(P_Settings, "Test Can Kick", function()
    Notify("norom HUB", "CanKick: " .. tostring(CanKick()), 3)
end, 24)
Button(P_Settings, "Debug 2x Bonus", function()
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then print("[noromHUB] PlayerGui not found") return end
    local ku = pg:FindFirstChild("KickUpgrades")
    print("[noromHUB] KickUpgrades ScreenGui: " .. tostring(ku ~= nil))
    if ku then
        print("[noromHUB] KickUpgrades children:")
        for _, c in ipairs(ku:GetChildren()) do
            print("  -> " .. c.Name .. " [" .. c.ClassName .. "] Visible:" .. tostring(pcall(function() return c.Visible end) and c.Visible or "?"))
        end
        local bonus = ku:FindFirstChild("Bonus", true)
        print("[noromHUB] Bonus found in KickUpgrades: " .. tostring(bonus ~= nil))
        if bonus then
            print("[noromHUB] Bonus class: " .. bonus.ClassName .. " Visible: " .. tostring(bonus.Visible))
            print("[noromHUB] Bonus AbsPos: " .. tostring(bonus.AbsolutePosition) .. " AbsSize: " .. tostring(bonus.AbsoluteSize))
        end
    end
    local found = pg:FindFirstChild("Bonus", true)
    print("[noromHUB] Bonus anywhere in PlayerGui: " .. tostring(found ~= nil))
    if found then
        print("[noromHUB] Found at: " .. found:GetFullName() .. " Class: " .. found.ClassName)
    end
    local x2found = false
    for _, desc in ipairs(pg:GetDescendants()) do
        if (desc:IsA("TextButton") or desc:IsA("ImageButton")) then
            local txt = ""
            pcall(function() txt = desc.Text or "" end)
            local nm = desc.Name:lower()
            if txt:find("2x") or txt:find("x2") or nm:find("bonus") or nm:find("2x") then
                print("[noromHUB] x2 Button: " .. desc:GetFullName() .. " Class:" .. desc.ClassName .. " Vis:" .. tostring(desc.Visible) .. " Text:" .. txt)
                x2found = true
            end
        end
    end
    if not x2found then print("[noromHUB] No x2/bonus buttons found in PlayerGui") end
    Notify("norom HUB", "Check F9 console for bonus debug info", 3)
end, 25)

-- ══════════════════════════════════════════════════════════════
-- DRAGGING
-- ══════════════════════════════════════════════════════════════
local dragging, dragInput, dragStart, startPos = false, nil, nil, nil
Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true; dragStart = input.Position; startPos = Win.Position
        input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
    end
end)
Header.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
end)
AddC(UIS.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local d = input.Position - dragStart
        Win.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end))

-- ══════════════════════════════════════════════════════════════
-- CONTROLS
-- ══════════════════════════════════════════════════════════════
-- Mini Avatar Button (shown when minimized)
local MiniAvatar = Instance.new("ImageButton", SG)
MiniAvatar.Name = "MiniAvatar"
MiniAvatar.Size = UDim2.new(0, 50, 0, 50)
MiniAvatar.Position = UDim2.new(0, 16, 0.5, -25)
MiniAvatar.BackgroundColor3 = Color.Surface
MiniAvatar.BorderSizePixel = 0
MiniAvatar.Visible = false
MiniAvatar.ScaleType = Enum.ScaleType.Fit
MiniAvatar.ImageTransparency = 0
Instance.new("UICorner", MiniAvatar).CornerRadius = UDim.new(1, 0)
local miniStroke = Instance.new("UIStroke", MiniAvatar)
miniStroke.Color = Color.Primary; miniStroke.Thickness = 2.5

-- Set avatar image on mini button (non-blocking)
task.defer(function()
    pcall(function()
        local thumbType = Enum.ThumbnailType.HeadShot
        local thumbSize = Enum.ThumbnailSize.Size150x150
        local content, isReady = Players:GetUserThumbnailAsync(LP.UserId, thumbType, thumbSize)
        MiniAvatar.Image = content
    end)
end)

-- Online pulse ring effect
local PulseRing = Instance.new("Frame", MiniAvatar)
PulseRing.Name = "PulseRing"
PulseRing.Size = UDim2.new(1, 6, 1, 6)
PulseRing.Position = UDim2.new(0, -3, 0, -3)
PulseRing.BackgroundTransparency = 1
PulseRing.BorderSizePixel = 0
Instance.new("UICorner", PulseRing).CornerRadius = UDim.new(1, 0)
local pulseStroke = Instance.new("UIStroke", PulseRing)
pulseStroke.Color = Color.Success; pulseStroke.Thickness = 1.5; pulseStroke.Transparency = 0.5

-- Make mini avatar draggable
local miniDragging = false
local miniDragStart, miniStartPos
MiniAvatar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        miniDragging = true
        miniDragStart = input.Position
        miniStartPos = MiniAvatar.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then miniDragging = false end
        end)
    end
end)
MiniAvatar.InputChanged:Connect(function(input)
    if miniDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - miniDragStart
        MiniAvatar.Position = UDim2.new(miniStartPos.X.Scale, miniStartPos.X.Offset + delta.X, miniStartPos.Y.Scale, miniStartPos.Y.Offset + delta.Y)
    end
end)

local minimized = false

-- Minimize: hide window, show avatar circle
MinBtn.MouseButton1Click:Connect(function()
    minimized = true
    Win.Visible = false
    MiniAvatar.Visible = true
end)

-- Restore: click avatar to reopen window
MiniAvatar.MouseButton1Click:Connect(function()
    if not miniDragging then
        minimized = false
        Win.Visible = true
        MiniAvatar.Visible = false
    end
end)

CloseBtn.MouseButton1Click:Connect(function()
    SaveConfig() -- Save settings before unload
    S.Running = false; genv.noromHUB_Active = false
    for _, c in ipairs(S.Conns) do pcall(function() c:Disconnect() end) end
    pcall(function() local h = GetHum(); if h then h.WalkSpeed = 16; h.MaxHealth = 100; h.Health = 100 end end)
    SG:Destroy(); Notify("norom HUB", "Settings saved! Unloaded.", 2)
end)

AddC(UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.RightShift then Win.Visible = not Win.Visible end
end))

-- ══════════════════════════════════════════════════════════════
-- STARTUP
-- ══════════════════════════════════════════════════════════════
SwitchTab("Smart")

pcall(function() AddC(LP.Idled:Connect(function() game:GetService("VirtualUser"):CaptureController(); game:GetService("VirtualUser"):ClickButton2(Vector2.new()) end)) end)

task.defer(function()
    local rc = 0; for _, v in pairs(R) do if v then rc = rc + 1 end end
    local cc = 0; for _ in pairs(CPSLookup) do cc = cc + 1 end
    local kr = GetKickReady()
    Notify("norom HUB v1.2", rc .. " remotes | " .. cc .. " CPS data | KickReady: " .. (kr and "OK" or "NOT FOUND"), 5)
    print("═══════════════════════════════════════")
    print("  norom HUB v1.2 - Premium Edition")
    print("  Remotes: " .. rc)
    print("  CPS Database: " .. cc .. " brainrots")
    print("  KickReady: " .. (kr and kr:GetFullName() or "NOT FOUND"))
    print("  Press RightShift to toggle UI")
    print("═══════════════════════════════════════")
end)

-- ══════════════════════════════════════════════════════════════
-- DISCONNECT DETECTION & NOTIFICATION
-- ══════════════════════════════════════════════════════════════
-- Method 1: game.Close (fires when game window closes / teleport / kick)
pcall(function()
    game:BindToClose(function()
        SendDisconnectWebhook("Game Closing / Teleport")
        task.wait(2) -- Give time for webhook to send
    end)
end)

-- Method 2: Monitor NetworkClient for disconnect
pcall(function()
    local nc = game:GetService("NetworkClient")
    if nc then
        nc.ChildRemoved:Connect(function()
            SendDisconnectWebhook("Network Connection Lost")
        end)
    end
end)

-- Method 3: Heartbeat watchdog - detect if game stops responding
task.spawn(function()
    local lastHeartbeat = tick()
    game:GetService("RunService").Heartbeat:Connect(function()
        lastHeartbeat = tick()
    end)
    while S.Running do
        task.wait(10)
        if (tick() - lastHeartbeat) > 15 then
            SendDisconnectWebhook("Game Freeze / Not Responding")
            break
        end
    end
end)

-- Method 4: Player removing (kicked from server)
pcall(function()
    game:GetService("Players").PlayerRemoving:Connect(function(plr)
        if plr == LP then
            SendDisconnectWebhook("Kicked from Server")
        end
    end)
end)

-- Method 5: CoreGui error screen detection (Roblox disconnect popup)
task.spawn(function()
    pcall(function()
        local coreGui = game:GetService("CoreGui")
        local function checkDisconnectUI()
            -- Roblox shows ErrorPrompt when disconnected
            for _, desc in ipairs(coreGui:GetDescendants()) do
                if desc.Name == "ErrorPrompt" or desc.Name == "ErrorMessage" then
                    if desc:IsA("GuiObject") and desc.Visible then
                        local reason = "Disconnected (Error Prompt Detected)"
                        pcall(function()
                            local msgLabel = desc:FindFirstChild("MessageArea") or desc:FindFirstChild("ErrorMessage")
                            if msgLabel then
                                local txt = msgLabel:FindFirstChildOfClass("TextLabel")
                                if txt and txt.Text ~= "" then
                                    reason = txt.Text
                                end
                            end
                        end)
                        SendDisconnectWebhook(reason)
                        return true
                    end
                end
            end
            return false
        end
        
        -- Monitor for disconnect UI appearing
        coreGui.DescendantAdded:Connect(function(desc)
            if desc.Name == "ErrorPrompt" or desc.Name == "ErrorMessage" then
                task.wait(0.5)
                checkDisconnectUI()
            end
        end)
    end)
end)
