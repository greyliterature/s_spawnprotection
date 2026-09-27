-- do not change these values unless you know what you're doing or want to potentially break the script
local s_spawnprotection_spawndelay_default_value = 5
local s_spawnprotection_spawndelay_default_movement_value = 2
local s_spawnprotection_spawndelay_default_switchweapon_value = 0.5
--[[--------------------------------
    Rest
----------------------------------]]
local function HasSpawnProt(ply)
    local NW = ply:GetNW2Float("s_spawnprotection_expiration_date", -1)
    if NW == -1 then return false end
    local Expiration = ply.SpawnProtectionExpirationDate or NW
    return Expiration > CurTime()
end

local function SpawnPrint(ply)
    print("Removed spawn prot for " .. ply:Nick())
    --debug.Trace()
end

if CLIENT then
    local Vignette = Material("vgui/white_additive_vignette")
    local color_blue = Color(0, 255, 255, 100)
    local color_faded = color_blue:Copy()
    local function ExpDecay(a, b, decay, dt) -- from styledstrike glide github, cant get link because writing by hand
        return b + (a - b) * math.exp(-decay * dt)
    end

    hook.Add("HUDPaint", "s_spawnprotection", function()
        local ShouldCare = false
        local ply = LocalPlayer()
        if ply:GetNW2Float("s_spawnprotection_expiration_date", 0) > CurTime() then
            ShouldCare = true
            ply.FadingOut = true
        end

        if ply.FadingOut then ShouldCare = true end
        if ply.SpawnProtectionExpirationDate and ShouldCare == false then ShouldCare = true end
        if ply.SpawnProtectionExpirationDate and ply.SpawnProtectionExpirationDate > CurTime() then --
            ply.FadingOut = true
        end

        if ply:Health() <= 0 or ply:Alive() == false then ShouldCare = false end
        if ply:ShouldDrawLocalPlayer() == true then ShouldCare = false end
        if ShouldCare == false then return end
        local timeleft = (ply.SpawnProtectionExpirationDate or ply:GetNW2Float("s_spawnprotection_expiration_date", 0)) - CurTime()
        local col = color_faded
        surface.SetDrawColor(col)
        surface.SetMaterial(Vignette)
        surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
        if ply.FadingOut == true then
            local target = (timeleft <= 0.5) and 0 or color_blue.a
            color_faded.a = ExpDecay(color_faded.a, target, 7, FrameTime())
            color_faded.a = math.Clamp(color_faded.a, 0, color_blue.a)
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
        local ExpirationDate = ply.SpawnProtectionExpirationDate or ply:GetNW2Float("s_spawnprotection_expiration_date", 0)
        if ExpirationDate < CurTime() then --
            return true
        end
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

    --[[--------------------------------
        Server specific stuff (can't really predict these)
    ----------------------------------]]
    hook.Add("PlayerInitialSpawn", "s_spawnprotection", function(ply, _)
        local SpawnDelay = GetGlobal2Float("s_spawnprotection_spawndelay", s_spawnprotection_spawndelay_default_value)
        local ExpirationDate = CurTime() + SpawnDelay
        ply:SetNW2Float("s_spawnprotection_expiration_date", ExpirationDate)
    end)

    hook.Add("EntityTakeDamage", "s_spawnprotection", function(target, dmg)
        if not target:IsPlayer() then return end
        if not target.SpawnProtectionExpirationDate then return end
        if target.SpawnProtectionExpirationDate > CurTime() then --
            return true
        end
    end)

    hook.Add("OnPhysgunPickup", "s_spawnprotection", function(ply, ent)
        if HasSpawnProt(ply) == false then return end
        SpawnPrint(ply)
        ply.SpawnProtectionExpirationDate = nil
        ply:SetNW2Float("s_spawnprotection_expiration_date", -1) -- basically nilling it
    end)

    hook.Add("GravGunOnPickedUp", "s_spawnprotection", function(ply, ent)
        if HasSpawnProt(ply) == false then return end
        SpawnPrint(ply)
        ply.SpawnProtectionExpirationDate = nil
        ply:SetNW2Float("s_spawnprotection_expiration_date", -1) -- basically nilling it
    end)
end

JustSpawned = {}
gameevent.Listen("player_spawn")
hook.Add("player_spawn", "s_spawnprotection", function(data)
    local ply = Player(data.userid)
    JustSpawned[ply] = CurTime()
    local SpawnDelay = GetGlobal2Float("s_spawnprotection_spawndelay", s_spawnprotection_spawndelay_default_value)
    local ExpirationDate = CurTime() + SpawnDelay
    ply.SpawnProtectionExpirationDate = ExpirationDate
    ply.FadingOut = nil
    ply.MovementDecay = nil
    if SERVER then -- unnil the physgunpickup 
        ply:SetNW2Float("s_spawnprotection_expiration_date", 0)
    end

    timer.Create("s_spawnprotection_spawndelay" .. data.userid, SpawnDelay, 1, function()
        if not IsValid(ply) then return end
        if not ply.SpawnProtectionExpirationDate then return end
        SpawnPrint(ply)
        ply.SpawnProtectionExpirationDate = nil
        return
    end)
end)

gameevent.Listen("player_hurt") -- entity_killed isnt reliable enough
hook.Add("player_hurt", "s_spawnprotection", function(data)
    local ply = Player(data.userid)
    if ply:Health() > 0 or ply:Alive() == true then return end
    if ply.SpawnProtectionExpirationDate then
        timer.Remove("s_spawnprotection_spawndelay" .. data.userid)
        SpawnPrint(ply)
        ply.SpawnProtectionExpirationDate = nil
    end
end)

local AttackAnims = {
    [PLAYERANIMEVENT_ATTACK_SECONDARY] = true,
    [PLAYERANIMEVENT_ATTACK_PRIMARY] = true,
    [PLAYERANIMEVENT_RELOAD] = true, -- crossbow doesnt run attack_primary but it does reload instantly, so this is a workaround
}

hook.Add("DoAnimationEvent", "s_spawnprotection", function(ply, event, data)
    -- handle attack anims
    if HasSpawnProt(ply) == false then return end
    if AttackAnims[event] then
        SpawnPrint(ply)
        ply.FadingOut = true
        ply:SetNW2Float("s_spawnprotection_expiration_date", -1)
        ply.SpawnProtectionExpirationDate = nil
    end
end)

local JustSpawnedThreshold = 0.1
hook.Add("PlayerSwitchWeapon", "s_spawnprotection", function(ply, _, _)
    firstprint = true
    if JustSpawned[ply] and CurTime() < JustSpawned[ply] + JustSpawnedThreshold then -- a player runs PlayerSwitchWeapon multiple times on server when spawning, but not on client, this syncs it better
        return
    end

    if HasSpawnProt(ply) == false then return end
    local ExpirationDate = CurTime() + GetGlobal2Float("s_spawnprotection_spawndelay_switchweapon", s_spawnprotection_spawndelay_switchweapon_value)
    print("Decaying " .. ply:Nick() .. " in " .. ExpirationDate - CurTime() .. " seconds")
    ply.FadingOut = true
    ply.SpawnProtectionExpirationDate = ExpirationDate
    ply:SetNW2Float("s_spawnprotection_expiration_date", ExpirationDate)
    timer.Adjust("s_spawnprotection_spawndelay" .. ply:UserID(), ExpirationDate - CurTime())
    return
end)

local MoveActivitys = {
    [ACT_MP_RUN] = true,
    [ACT_MP_WALK] = true,
    [ACT_MP_JUMP] = true,
    [ACT_GMOD_NOCLIP_LAYER] = true, -- player would be able to bypass spawn protection by noclipping (noclipping makes you not have any anims, so i have to get when the noclip STARTS)
}

hook.Add("TranslateActivity", "s_spawnprotection", function(ply, act)
    -- the wiki says "Isn't called when CalcMainActivity returns a valid override sequence id", i hope this doesnt break with pac or anything
    if HasSpawnProt(ply) == false then return end
    if JustSpawned[ply] and CurTime() < JustSpawned[ply] + JustSpawnedThreshold then -- the player runs ACT_MP_JUMP on spawn, so there has to be a window
        return
    end

    if MoveActivitys[act] and not ply.MovementDecay then
        local ExpirationDate = CurTime() + GetGlobal2Float("s_spawnprotection_spawndelay_movement", s_spawnprotection_spawndelay_movement_value)
        ExpirationDate = math.Clamp(ExpirationDate, 0, ply.SpawnProtectionExpirationDate or ply:GetNW2Float("s_spawnprotection_expiration_date", 0))
        print("Decaying " .. ply:Nick() .. " in " .. ExpirationDate - CurTime() .. " seconds")
        ply.MovementDecay = true
        ply.SpawnProtectionExpirationDate = ExpirationDate
        ply:SetNW2Float("s_spawnprotection_expiration_date", ExpirationDate)
        timer.Adjust("s_spawnprotection_spawndelay" .. ply:UserID(), ExpirationDate - CurTime())
    end
end)
