# Spawn protection
I made this because I thought the other spawn protection scripts / addons didn't follow good visual design.  <br/>
<br/>
# Features 
## Players:
I added two convars for customization of the HUD color and the material of other players.  <br/>
### "s_spawnprotection_color" (def. "0 255 255 100")
Color for spawn protection. Only changes the HUD, use s_spawnprotection_jellyfish for player material.  <br/>
### "s_spawnprotection_jellyfish" (def. "vgui/black effects/advisor_fx_003 1")
Sets spawn protection material of other players, "basetexture gradienttexture pulserate" <br/>
Example:  <br/>
s_spawnprotection_jellyfish "sprites/blueglow1 effects/com_shield002b 0.5" <br/>

## Server owners:
Currently, the addon only accounts for Kyle's buildmode ULX godmode, and GMod godmode. Make a issue post with the buildmode addon you use (or pull request this) so that I can add it. <br/>
There are a lot of buildmode addons so I can't account for all of them, so I will (eventually) add your requests. <br/>
<br/>
I added a few convars for controlling different player scenarios: <br/>
### "s_spawnprotection_spawndelay" (def. 5)
How long spawn protection lasts  <br/>
### "s_spawnprotection_spawndelay_initialspawn" (def. 300)
How long spawn protection lasts for a newly joining player <br/>
### "s_spawnprotection_spawndelay_movement" (def. "2") 
How long spawn protection lasts after a player moves <br/>
### "s_spawnprotection_spawndelay_notifyplayers" (def. "0")
Whether or not to inform players why their spawn protection was revoked <br/>
### "s_spawnprotection_spawndelay_switchweapon" (def. "0.5")
How long spawn protection lasts after switching weapons  <br/>

## Developers:
I added a couple hooks that I thought would be useful for outside developers. Make an issue post if you need any others (or, you could detour the functions fairly easily). <br/>
<br/>
All of the hooks are serverside. I did not see a use for any clientside hooks, so I did not add any. <br/>
Hooks: <br/>
### s_spawnprotection_expiration_date_changed (ply, ExpirationDate)
Run every time a player's expiration date for their spawn protection is changed (or set). <br/>
Where: <br/>
```
ExpirationDate = CurTime() + SpawnDelay <br/>
SpawnDelay = ExpirationDate - CurTime() <br/>
```
```lua
    hook.Add("s_spawnprotection_expiration_date_changed", "s_spawnprotection_debug", function(ply, ExpirationDate)
        print("Set expiration for " .. ply:Nick() .. " to " .. ExpirationDate - CurTime() .. " seconds from now")
        return
    end)
```
### s_spawnprotection_rewarded (ply)
Run every time a player dies when they are rewarded spawn protection for the next life. <br/>
```lua
    hook.Add("s_spawnprotection_rewarded", "s_spawnprotection_debug", function(ply)
        print("Rewarded " .. ply:Nick() .. " with spawn protection next life")
        return
    end)
```
### s_spawnprotection_deserved (ply)
Queried every time a player dies to ask if the player should be rewarded spawnprotection when they respawn. <br/>
```lua
    hook.Add("s_spawnprotection_deserved", "s_spawnprotection_debug", function(ply)
        print(ply:Nick() .. " will not earn spawn protection next life")
        return false --
    end)
```
### s_spawnprotection_removed (ply)
Run every time that spawnprotection is removed with ply:RemoveSpawnProtection(). <br/>
```lua
    hook.Add("s_spawnprotection_removed", "s_spawnprotection_debug", function(ply)
        print("Removed spawn protection for " .. ply:Nick())
        return
    end)
```
