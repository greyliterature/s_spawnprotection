local s_spawnprotection_spawndelay_default_value = 5
if CLIENT then
    hook.Add("OnScreenSizeChanged", "s_spawnprotection", function(_, _, newWidth, newHeight)
        vec_screen = Vector(-newWidth, -newHeight)
        return
    end)

    -- from https://wiki.facepunch.com/gmod/surface.DrawPoly#example
    function draw.Oval(x, y, radiusx, radiusy, seg)
        local cir = {}
        table.insert(cir, {
            x = x,
            y = y,
            u = 0.5,
            v = 0.5
        })

        for i = 0, seg do
            local a = math.rad((i / seg) * -360)
            table.insert(cir, {
                x = x + math.sin(a) * radiusx,
                y = y + math.cos(a) * radiusy,
                u = math.sin(a) / 2 + 0.5,
                v = math.cos(a) / 2 + 0.5
            })
        end

        local a = math.rad(0) -- This is needed for non absolute segment counts
        table.insert(cir, {
            x = x + math.sin(a) * radiusx,
            y = y + math.cos(a) * radiusy,
            u = math.sin(a) / 2 + 0.5,
            v = math.cos(a) / 2 + 0.5
        })

        surface.DrawPoly(cir)
    end

    local Vignette_up = Material("vgui/gradient_up")
    local Vignette_down = Material("vgui/gradient_down")
    local Vignette_left = Material("vgui/gradient-l")
    local Vignette_right = Material("vgui/gradient-r")
    local Vignette = Material("vgui/white_additive_vignette")
    local color_blue = Color(0, 255, 255, 255)
    local color_faded = color_blue:Copy()
    local ratio = 0
    hook.Add("HUDPaint", "s_spawnprotection", function()
        local ShouldCare = false
        if LocalPlayer():GetNW2Float("s_spawnprotection_expiration_date", 0) > CurTime() then
            ShouldCare = true
            LocalPlayer().FadingOut = true
        end

        if LocalPlayer().FadingOut then ShouldCare = true end
        if LocalPlayer().SpawnProtectionExpirationDate and ShouldCare == false then ShouldCare = true end
        if LocalPlayer():Health() <= 0 or LocalPlayer():Alive() == false then ShouldCare = false end
        if ShouldCare == false then return end
        local col = (LocalPlayer().FadingOut == true and color_faded) or color_blue
        surface.SetDrawColor(col)
        local OutMultiply = 0.75
        local OutMultiply_w = 1.1
        -- from https://wiki.facepunch.com/gmod/render_stencils#examplesimple2dmasking 
        render.SetStencilEnable(true)
        render.ClearStencil()
        render.SetStencilTestMask(255)
        render.SetStencilWriteMask(255)
        render.SetStencilPassOperation(STENCILOPERATION_ZERO)
        render.SetStencilZFailOperation(STENCILOPERATION_KEEP)
        render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_NEVER)
        render.SetStencilReferenceValue(9)
        render.SetStencilFailOperation(STENCILOPERATION_REPLACE)
        -- "draw mask"
        draw.Oval(ScrW() * 0.5, ScrH() * 0.5, ScrW() * 0.499, ScrH() * 0.7, 255)
        render.SetStencilPassOperation(STENCILOPERATION_KEEP)
        render.SetStencilFailOperation(STENCILOPERATION_KEEP)
        render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_NOTEQUAL)
        -- "draw content"
        --[[
        surface.SetMaterial(Vignette_up)
        surface.DrawTexturedRect(0, ScrH() * OutMultiply, ScrW(), ScrH())
        surface.SetMaterial(Vignette_down)
        surface.DrawTexturedRect(0, -ScrH() * OutMultiply, ScrW(), ScrH())
        surface.SetMaterial(Vignette_left)
        surface.DrawTexturedRect(-ScrW() * OutMultiply * OutMultiply_w, 0, ScrW(), ScrH())
        surface.SetMaterial(Vignette_right)
        surface.DrawTexturedRect(ScrW() * OutMultiply * OutMultiply_w, 0, ScrW(), ScrH())
        --]]
        render.SetStencilEnable(false)
        surface.SetMaterial(debugwhite)
        surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
        if not LocalPlayer().FadingOut and color_faded.a <= 0 then -- I'm kind of faded, but I feel alright
            color_faded.a = 255
            ratio = 0
        end

        if LocalPlayer().FadingOut == true then -- Thinking about making my move tonight
            ratio = ratio + 0.02
            local Fader = Lerp(ratio, color_faded.a, 0)
            Fader = math.Clamp(Fader, 0, 255)
            print(ratio)
            color_faded.a = Fader
        end
    end)

    LocalPlayer().FadingOut = false
    LocalPlayer().SpawnProtectionExpirationDate = CurTime() + 25
elseif SERVER then
    local s_spawnprotection_spawndelay = CreateConVar("s_spawnprotection_spawndelay", "5", FCVAR_ARCHIVE, "How long spawn protection lasts", 0)
    local s_spawnprotection_spawndelay_value = s_spawnprotection_spawndelay:GetInt()
    SetGlobal2Float("s_spawnprotection_spawndelay", s_spawnprotection_spawndelay_value)
    cvars.AddChangeCallback("s_spawnprotection_spawndelay", function(_, old, new)
        s_spawnprotection_spawndelay_value = tonumber(new)
        SetGlobal2Float("s_spawnprotection_spawndelay", s_spawnprotection_spawndelay_value)
        return
    end, "s_spawnprotection_spawndelay")

    hook.Add("PlayerInitialSpawn", "s_spawnprotection", function(ply, _)
        local SpawnDelay = GetGlobal2Float("s_spawnprotection_spawndelay", s_spawnprotection_spawndelay_default_value)
        local ExpirationDate = CurTime() + SpawnDelay
        ply:SetNW2Float("s_spawnprotection_expiration_date", ExpirationDate)
    end)
end

gameevent.Listen("player_spawn")
hook.Add("player_spawn", "s_spawnprotection", function(data)
    local ply = Player(data.userid)
    local SpawnDelay = GetGlobal2Float("s_spawnprotection_spawndelay", s_spawnprotection_spawndelay_default_value)
    local ExpirationDate = CurTime() + SpawnDelay
    ply.SpawnProtectionExpirationDate = ExpirationDate
    ply.FadingOut = nil
    timer.Simple(SpawnDelay, function()
        if ply.AlreadyDied == true then return end
        print("Removed spawn prot for " .. ply:Nick())
        ply.SpawnProtectionExpirationDate = nil
        ply.AlreadyDied = false
        return
    end)
end)

gameevent.Listen("player_hurt") -- entity_killed isnt reliable enough
hook.Add("player_hurt", "s_spawnprotection", function(data)
    local ply = Player(data.userid)
    if ply.SpawnProtectionExpirationDate then
        ply.SpawnProtectionExpirationDate = nil
        ply.AlreadyDied = true
    end
end)

-- removing spawn protection
hook.Add("EntityFireBullets", "s_spawnprotection", function(ent, data)
    if not data.Attacker:IsPlayer() then return end
    data.Attacker.FadingOut = true -- How's it go? Ha yo faded
    data.Attacker.SpawnProtectionExpirationDate = nil -- this should be set to be at the end of the fadeout, too lazy right now
end)
