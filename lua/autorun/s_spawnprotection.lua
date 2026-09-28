-- do not change these values unless you know what you're doing or want to potentially break the script
local s_spawnprotection_spawndelay_default_value = 5
local s_spawnprotection_spawndelay_default_movement_value = 2
local s_spawnprotection_spawndelay_default_switchweapon_value = 0.5
local InitialSpawns = nil
local s_spawnprotection_spawndelay_notifyplayers_value = nil
--[[--------------------------------
    Rest
----------------------------------]]
local Words = {
    -- We use words like honor, code, loyalty!
    ["DEFAULT"] = 0, -- just default for nw2floats, don't really use it currently
    ["EXPIRED"] = -1, -- the nilled 
}

-- Chat prints (cfc does something like this)
local Notifications = {
    ["PICKED_UP"] = "Spawn protection revoked because you used an object",
    ["PHYSGUN_PICKED_UP"] = "Spawn protection revoked because you physgunned an object",
    ["GRAVGUN_PICKED_UP"] = "Spawn protection revoked because you gravgunned an object",
    ["SWITCHED_WEAPON"] = "Spawn protection will be removed because you swapped weapons",
    ["PLAYER_ATTACKED"] = "Spawn protection revoked because you fired", -- wording on this is a bit awkward
    ["PLAYER_MOVED"] = "Spawn protection will be removed because you moved",
}

--[[--------------------------------
        Meta functions
    ----------------------------------]]
local PLAYERMETA = FindMetaTable("Player")
function PLAYERMETA:SetExpirationDate(ExpirationDate, NOTIFYCODE)
    if NOTIFYCODE and s_spawnprotection_spawndelay_notifyplayers_value == 1 then --
        self:ColoredChatPrint(NOTIFYCODE)
    end

    hook.Run("s_spawnprotection_expiration_date_changed", self, ExpirationDate)
    self:SetNW2Float("s_spawnprotection_expiration_date", ExpirationDate)
end

function PLAYERMETA:DeservesSpawnProtection()
    local DeservesSpawnProtection = hook.Run("s_spawnprotection_deserved", self)
    if DeservesSpawnProtection == false then return false end
    --local NW2 = self:GetNW2Float("s_spawnprotection_expiration_date", Words["EARNED"])
    --return NW2 ~= Words["UNDESERVED"]
    return true
end

function PLAYERMETA:RewardSpawnProtection()
    --if self:DeservesSpawnProtection() == false then return end
    hook.Run("s_spawnprotection_rewarded", self)
    self:SetNW2Float("s_spawnprotection_expiration_date", Words["EARNED"])
end

function PLAYERMETA:GetExpirationDate()
    return self:GetNW2Float("s_spawnprotection_expiration_date", 0)
end

if SERVER then util.AddNetworkString("s_coloredchatprint") end
function PLAYERMETA:ColoredChatPrint(NOTIFYCODE)
    net.Start("s_coloredchatprint")
    net.WriteString(NOTIFYCODE) -- we have a shared static table, so the client can just read off of that
    net.Send(self)
end

function PLAYERMETA:RemoveSpawnProtection(NOTIFYCODE)
    if SERVER and s_spawnprotection_spawndelay_notifyplayers_value == 1 then --
        self:ColoredChatPrint(NOTIFYCODE)
    end

    hook.Run("s_spawnprotection_removed", self)
    self:SetNW2Float("s_spawnprotection_expiration_date", Words["EXPIRED"])
end

local function HasSpawnProt(ply)
    local ExpirationDate = ply:GetNW2Float("s_spawnprotection_expiration_date", 0)
    if ExpirationDate == Words["EXPIRED"] then return false end
    return ExpirationDate > CurTime()
end

if CLIENT then
    local Vignette = Material("vgui/white_additive_vignette")
    local color_main = Color(0, 255, 255, 100)
    local color_faded = color_main:Copy()
    color_faded.a = HasSpawnProt(LocalPlayer()) and color_main.a or 0
    local function SetSpawnColor(color)
        color_main = (IsColor(color) and color) or ColorRand()
        color_faded = color:Copy()
        color_faded.a = HasSpawnProt(LocalPlayer()) and color_main.a or 0
    end

    local s_spawnprotection_color = CreateClientConVar("s_spawnprotection_color", "0 255 255 100", true, false, "Color for spawn protection. Only the HUD, sadly.")
    SetSpawnColor(string.ToColor(s_spawnprotection_color:GetString()))
    cvars.AddChangeCallback("s_spawnprotection_color", function(_, old, new)
        SetSpawnColor(string.ToColor(new))
        return
    end, "s_spawnprotection_color")

    local function ExpDecay(a, b, decay, dt) -- from styledstrike glide github, cant get link because writing by hand
        return b + (a - b) * math.exp(-decay * dt)
    end

    hook.Add("HUDPaint", "s_spawnprotection", function()
        local ply = LocalPlayer()
        if HasSpawnProt(ply) == false then
            ply.FadingOut = true
        elseif ply.FadingOut == nil then
            color_faded.a = color_main.a
        end

        if ply:Health() <= 0 or ply:Alive() == false then return end
        if ply:ShouldDrawLocalPlayer() == true then return end
        local timeleft = ply:GetExpirationDate() - CurTime()
        local col = color_faded
        surface.SetDrawColor(col)
        surface.SetMaterial(Vignette)
        surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
        if ply.FadingOut == true then
            local target = (timeleft <= 0.5) and 0 or color_main.a
            color_faded.a = ExpDecay(color_faded.a, target, 7, FrameTime())
            color_faded.a = math.Clamp(color_faded.a, 0, color_main.a)
            if color_faded.a <= 0.1 then ply.FadingOut = nil end
        end
    end)

    local Jellyfish = CreateMaterial("s_spawnprotection_jellyfish_" .. math.random(1, 9999), "JellyFish", {
        ["$basetexture"] = "vgui/black",
        ["$gradienttexture"] = "effects/advisor_fx_003",
        ["$model"] = 1,
        ["$pulserate"] = 1,
        ["$translucent"] = 1,
        ["$vertexalpha"] = 1,
        ["$vertexcolor"] = 1
    })

    local PlayersOverlayed = {}
    hook.Add("PostPlayerDraw", "s_spawnprotection", function(ply)
        if PlayersOverlayed[ply] then return end
        if HasSpawnProt(ply) == false then return end
        PlayersOverlayed[ply] = true
        render.ModelMaterialOverride(Jellyfish)
        ply:DrawModel()
        render.ModelMaterialOverride(nil)
        PlayersOverlayed[ply] = nil
    end)

    hook.Add("ScalePlayerDamage", "s_spawnprotection", function(ply, _, _)
        if HasSpawnProt(ply) then --
            return true
        end
    end)

    net.Receive("s_coloredchatprint", function(_, _)
        local NOTIFYCODE = net.ReadString()
        chat.AddText(Notifications[NOTIFYCODE])
    end)
elseif SERVER then
    --[[--------------------------------
        Convars
    ----------------------------------]]
    local s_spawnprotection_spawndelay = CreateConVar("s_spawnprotection_spawndelay", s_spawnprotection_spawndelay_default_value, FCVAR_ARCHIVE, "How long spawn protection lasts", 0)
    local s_spawnprotection_spawndelay_value = s_spawnprotection_spawndelay:GetInt()
    SetGlobal2Float("s_spawnprotection_spawndelay", s_spawnprotection_spawndelay_value)
    cvars.AddChangeCallback("s_spawnprotection_spawndelay", function(_, old, new)
        s_spawnprotection_spawndelay_value = tonumber(new)
        SetGlobal2Float("s_spawnprotection_spawndelay", s_spawnprotection_spawndelay_value)
        return
    end, "s_spawnprotection_spawndelay")

    local s_spawnprotection_spawndelay_movement = CreateConVar("s_spawnprotection_spawndelay_movement", s_spawnprotection_spawndelay_default_movement_value, FCVAR_ARCHIVE, "How long spawn protection lasts after moving", 0)
    local s_spawnprotection_spawndelay_movement_value = s_spawnprotection_spawndelay_movement:GetInt()
    SetGlobal2Float("s_spawnprotection_spawndelay_movement", s_spawnprotection_spawndelay_movement_value)
    cvars.AddChangeCallback("s_spawnprotection_spawndelay_movement", function(_, old, new)
        s_spawnprotection_spawndelay_movement_value = tonumber(new)
        SetGlobal2Float("s_spawnprotection_spawndelay_movement", s_spawnprotection_spawndelay_movement_value)
        return
    end, "s_spawnprotection_spawndelay_movement")

    local s_spawnprotection_spawndelay_switchweapon = CreateConVar("s_spawnprotection_spawndelay_switchweapon", s_spawnprotection_spawndelay_default_switchweapon_value, FCVAR_ARCHIVE, "How long spawn protection lasts after switching weapons", 0)
    local s_spawnprotection_spawndelay_switchweapon_value = s_spawnprotection_spawndelay_switchweapon:GetInt()
    SetGlobal2Float("s_spawnprotection_spawndelay_switchweapon", s_spawnprotection_spawndelay_switchweapon_value)
    cvars.AddChangeCallback("s_spawnprotection_spawndelay_switchweapon", function(_, old, new)
        s_spawnprotection_spawndelay_switchweapon_value = tonumber(new)
        SetGlobal2Float("s_spawnprotection_spawndelay_switchweapon", s_spawnprotection_spawndelay_switchweapon_value)
        return
    end, "s_spawnprotection_spawndelay_switchweapon")

    local s_spawnprotection_spawndelay_initialspawn = CreateConVar("s_spawnprotection_spawndelay_initialspawn", "300", FCVAR_ARCHIVE, "How long spawn protection lasts for newly joining players", 0)
    local s_spawnprotection_spawndelay_initialspawn_value = s_spawnprotection_spawndelay_initialspawn:GetInt()
    -- this doesn't need to be predicted with a default value, hopefully
    SetGlobal2Float("s_spawnprotection_spawndelay_initialspawn", s_spawnprotection_spawndelay_initialspawn_value)
    cvars.AddChangeCallback("s_spawnprotection_spawndelay_initialspawn", function(_, old, new)
        s_spawnprotection_spawndelay_initialspawn_value = tonumber(new)
        SetGlobal2Float("s_spawnprotection_spawndelay_initialspawn", s_spawnprotection_spawndelay_initialspawn_value)
        return
    end, "s_spawnprotection_spawndelay_initialspawn")

    local s_spawnprotection_spawndelay_notifyplayers = CreateConVar("s_spawnprotection_spawndelay_notifyplayers", "0", FCVAR_ARCHIVE, "Whether or no to inform players why their spawn protection was revoked", 0)
    s_spawnprotection_spawndelay_notifyplayers_value = s_spawnprotection_spawndelay_notifyplayers:GetInt()
    -- this doesn't need to be predicted with a default value, hopefully
    SetGlobal2Float("s_spawnprotection_spawndelay_notifyplayers", s_spawnprotection_spawndelay_notifyplayers_value)
    cvars.AddChangeCallback("s_spawnprotection_spawndelay_initialspawn", function(_, old, new)
        s_spawnprotection_spawndelay_notifyplayers_value = tonumber(new)
        SetGlobal2Float("s_spawnprotection_spawndelay_notifyplayers", s_spawnprotection_spawndelay_notifyplayers_value)
        return
    end, "s_spawnprotection_spawndelay_notifyplayers")

    --[[--------------------------------
        Server specific stuff (can't really predict these)
    ----------------------------------]]
    --[[
    hook.Add("PlayerInitialSpawn", "s_spawnprotection", function(ply, _)
        ply.InitialSpawn = true
        local SpawnDelay = s_spawnprotection_spawndelay_initialspawn_value
        local ExpirationDate = CurTime() + SpawnDelay
        ply:SetExpirationDate(ExpirationDate)
        timer.Create("s_spawnprotection_spawndelay" .. ply:UserID(), SpawnDelay, 1, function()
            if not IsValid(ply) then return end
            if HasSpawnProt(ply) == false then return end
            SpawnPrint(ply)
            ply:RemoveSpawnProtection()
        end)
    end)
    --]]
    InitialSpawns = {}
    gameevent.Listen("player_connect_client")
    hook.Add("player_connect_client", "s_spawnprotection", function(data)
        InitialSpawns[data.networkid] = CurTime()
        return
    end)

    gameevent.Listen("player_disconnect")
    hook.Add("player_disconnect", "player_disconnect_example", function(data)
        InitialSpawns[data.networkid] = nil
        return
    end)

    hook.Add("PlayerInitialSpawn", "s_spawnprotection", function(ply, _)
        ply:SetExpirationDate(CurTime() + GetGlobal2Float("s_spawnprotection_spawndelay_initialspawn", s_spawnprotection_spawndelay_default_initialspawn_value))
        return
    end)

    hook.Add("EntityTakeDamage", "s_spawnprotection", function(target, dmg)
        if not target:IsPlayer() then return end
        if HasSpawnProt(target) == true then --
            return true
        end
    end)

    hook.Add("OnPhysgunPickup", "s_spawnprotection", function(ply, ent)
        if HasSpawnProt(ply) == false then return end
        ply:RemoveSpawnProtection("PHYSGUN_PICKED_UP")
    end)

    hook.Add("GravGunOnPickedUp", "s_spawnprotection", function(ply, ent)
        if HasSpawnProt(ply) == false then return end
        ply:RemoveSpawnProtection("GRAVGUN_PICKED_UP")
    end)

    hook.Add("PlayerDeath", "s_spawnprotection", function(victim, _, attacker)
        if victim:DeservesSpawnProtection() == false then return end
        victim:RewardSpawnProtection() -- Thanks Phatso https://github.com/CFC-Servers/cfc_spawn_protection/blob/61d822f7013f35984118093a90a05ef08d5500e6/lua/autorun/server/sv_spawn_protection.lua#L185
        return
    end)

    local UsedThisLife = {}
    hook.Add("PlayerSpawn", "s_spawnprotection", function(ply, _)
        UsedThisLife[ply] = nil
        return
    end)

    hook.Add("PlayerUse", "s_spawnprotection", function(ply, ent)
        if UsedThisLife[ply] then
            -- i feel like allowing players to spam this hook constantly is 
            -- a bad idea, so this should rate limit them  
            return
        end

        if HasSpawnProt(ply) == false then --
            return
        end

        UsedThisLife[ply] = true
        ply:RemoveSpawnProtection()
    end)
end

local JustSpawned = {}
gameevent.Listen("player_spawn")
hook.Add("player_spawn", "s_spawnprotection", function(data)
    local ply = Player(data.userid)
    if CLIENT and not IsValid(ply) then -- initial spawns
        return
    end

    if ply:DeservesSpawnProtection() == false then return end
    JustSpawned[ply] = CurTime()
    local SpawnDelay = GetGlobal2Float("s_spawnprotection_spawndelay", s_spawnprotection_spawndelay_default_value)
    local ExpirationDate = CurTime() + SpawnDelay
    ply:SetExpirationDate(ExpirationDate)
    ply.FadingOut = nil
    ply.MovementDecay = nil
    timer.Create("s_spawnprotection_spawndelay" .. data.userid, SpawnDelay, 1, function()
        if not IsValid(ply) then return end
        if HasSpawnProt(ply) == false then return end
        ply:RemoveSpawnProtection()
    end)
end)

gameevent.Listen("player_hurt") -- entity_killed isnt reliable enough
hook.Add("player_hurt", "s_spawnprotection", function(data)
    local ply = Player(data.userid)
    if ply:Health() > 0 or ply:Alive() == true then return end
    if HasSpawnProt(ply) then
        timer.Remove("s_spawnprotection_spawndelay" .. data.userid)
        ply:RemoveSpawnProtection()
    end
end)

--[[
-- better to just do this all in startcommand
local AttackAnims = {
    [PLAYERANIMEVENT_ATTACK_SECONDARY] = true,
    [PLAYERANIMEVENT_ATTACK_PRIMARY] = true,
    [PLAYERANIMEVENT_RELOAD] = true, -- crossbow doesnt run attack_primary but it does reload instantly, so this is a workaround
}

hook.Add("DoAnimationEvent", "s_spawnprotection", function(ply, event, data)
    -- handle attack anims
    if HasSpawnProt(ply) == false then return end
    if AttackAnims[event] then
        ply.FadingOut = true
        ply:RemoveSpawnProtection()
    end
end)
--]]
local JustSpawnedThreshold = 0.1
local InitialSpawnedThreshold = 2
hook.Add("PlayerSwitchWeapon", "s_spawnprotection", function(ply, _, _)
    if InitialSpawns and InitialSpawns[ply:SteamID()] then
        if CurTime() < InitialSpawns[ply:SteamID()] + InitialSpawnedThreshold then --
            return
        end

        InitialSpawns[ply:SteamID()] = nil
    end

    if JustSpawned[ply] and CurTime() < JustSpawned[ply] + JustSpawnedThreshold then -- a player runs PlayerSwitchWeapon multiple times on server when spawning, but not on client, this syncs it better
        return
    end

    if HasSpawnProt(ply) == false then return end
    local ExpirationDate = CurTime() + GetGlobal2Float("s_spawnprotection_spawndelay_switchweapon", s_spawnprotection_spawndelay_switchweapon_value)
    ExpirationDate = math.Clamp(ExpirationDate, 0, ply:GetExpirationDate())
    --print("Decaying " .. ply:Nick() .. " in " .. ExpirationDate - CurTime() .. " seconds")
    ply.FadingOut = true
    ply:SetExpirationDate(ExpirationDate, "SWITCHED_WEAPON")
    timer.Adjust("s_spawnprotection_spawndelay" .. ply:UserID(), ExpirationDate - CurTime())
    return
end)

--[[
local MoveActivitys = {
    [ACT_MP_RUN] = true,
    [ACT_MP_WALK] = true,
    [ACT_MP_JUMP] = true,
    [ACT_GMOD_NOCLIP_LAYER] = true, -- player would be able to bypass spawn protection by noclipping (noclipping makes you not have any anims, so i have to get when the noclip STARTS)
}

hook.Add("TranslateActivity", "s_spawnprotection", function(ply, act)
    -- the wiki says "Isn't called when CalcMainActivity returns a valid override sequence id", i hope this doesnt break with pac or anything
    if InitialSpawns and InitialSpawns[ply:SteamID()] then
        if CurTime() < InitialSpawns[ply:SteamID()] + InitialSpawnedThreshold then return end
        InitialSpawns[ply:UserID()] = nil
    end

    if HasSpawnProt(ply) == false then return end
    if JustSpawned[ply] and CurTime() < JustSpawned[ply] + JustSpawnedThreshold then -- the player runs ACT_MP_JUMP on spawn, so there has to be a window
        return
    end

    if MoveActivitys[act] and not ply.MovementDecay then
        local ExpirationDate = CurTime() + GetGlobal2Float("s_spawnprotection_spawndelay_movement", s_spawnprotection_spawndelay_movement_value)
        ExpirationDate = math.Clamp(ExpirationDate, 0, ply:GetExpirationDate())
        print("Decaying " .. ply:Nick() .. " in " .. ExpirationDate - CurTime() .. " seconds")
        ply.MovementDecay = true
        ply:SetExpirationDate(ExpirationDate)
        timer.Adjust("s_spawnprotection_spawndelay" .. ply:UserID(), ExpirationDate - CurTime())
    end
end)
--]]
local MovementKeys = IN_FORWARD + IN_BACK + IN_MOVERIGHT + IN_MOVELEFT -- + IN_JUMP -- IN_JUMP is a bad idea, sets off right on spawn
local AttackKeys = IN_ATTACK + IN_ATTACK2 + IN_RELOAD + IN_GRENADE1 + IN_GRENADE2 -- surely IN_GRENADE does something in some addon?
local WeaponWhitelist = {
    -- some of the same stuff as cfc's
    ["weapon_physgun"] = true,
    ["gmod_camera"] = true,
    ["none"] = true,
    ["laserpointer"] = true,
}

local JustSpawnedThreshold_StartCommand = 0.1 -- give player change to player let go of the attack key after spawning
hook.Add("StartCommand", "s_spawnprotection", function(ply, ucmd)
    -- track movement and attacks, translateactivity and doanimationevent was a bad idea apparently
    if JustSpawned[ply] and CurTime() < JustSpawned[ply] + JustSpawnedThreshold_StartCommand then --  too early
        return
    end

    if bit.band(ucmd:GetButtons(), bit.bor(MovementKeys)) ~= 0 and HasSpawnProt(ply) == true and not ply.MovementDecay then --
        local ExpirationDate = CurTime() + GetGlobal2Float("s_spawnprotection_spawndelay_movement", s_spawnprotection_spawndelay_movement_value)
        ExpirationDate = math.Clamp(ExpirationDate, 0, ply:GetExpirationDate())
        --print("Decaying " .. ply:Nick() .. " in " .. ExpirationDate - CurTime() .. " seconds")
        ply.MovementDecay = true
        ply:SetExpirationDate(ExpirationDate, "PLAYER_MOVED")
        timer.Adjust("s_spawnprotection_spawndelay" .. ply:UserID(), ExpirationDate - CurTime())
    elseif bit.band(ucmd:GetButtons(), bit.bor(AttackKeys)) ~= 0 and HasSpawnProt(ply) == true then
        local weap = ply:GetActiveWeapon()
        if IsValid(weap) and WeaponWhitelist[weap:GetClass()] then return end
        ply.FadingOut = true
        ply:RemoveSpawnProtection("PLAYER_ATTACKED")
    end
end)

--[[--------------------------------
    Hooks
----------------------------------]]
if SERVER then
    --[[
    -- just debug / example stuff
    hook.Add("s_spawnprotection_expiration_date_changed", "s_spawnprotection_debug", function(ply, ExpirationDate)
        print("Set expiration for " .. ply:Nick() .. " to " .. ExpirationDate - CurTime() .. " seconds from now")
        return
    end)

    hook.Add("s_spawnprotection_rewarded", "s_spawnprotection_debug", function(ply)
        print("Rewarded " .. ply:Nick() .. " with spawn protection next life")
        return
    end)

    hook.Add("s_spawnprotection_deserved", "s_spawnprotection_debug", function(ply)
        print(ply:Nick() .. " will not earn spawn protection next life")
        return false --
    end)

    hook.Add("s_spawnprotection_removed", "s_spawnprotection_debug", function(ply)
        print("Removed spawn protection for " .. ply:Nick())
        return
    end)
    --]]
    --
    -- accounting for buildmode addons
    hook.Add("s_spawnprotection_deserved", "s_spawnprotection_debug", function(ply)
        if ply:GetNWBool("_Kyle_Buildmode", false) then --
            return false
        end
    end)
end
