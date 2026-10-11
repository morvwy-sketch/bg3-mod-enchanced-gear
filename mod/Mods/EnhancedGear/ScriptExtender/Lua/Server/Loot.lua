-- Where materials come from: starter kit, first visit of a region, bosses, enemy corpses.
-- Every one-time source is recorded in the campaign data, so reloading never pays twice.
EG = EG or {}
local Ids = EG.Ids
local R = EG.Rules
local L = EG.Logic
local U = EG.Util
local Game = EG.Game
local Data = EG.Data
local Config = EG.Config
local Economy = EG.Economy
local I18N = EG.I18N
local Lo = {}

Lo.Random = math.random

function Lo.GrantStarterKit()
    if not Config.Get("GrantStarterKit") then return false end
    local d = Data.Get()
    if d.kitGranted then return false end
    local host = Game.Host()
    if not host then return false end
    local given = false
    if not Economy.PartyHasKit() then
        Economy.Grant(host, R.Loot.starter, true)
        local rest = U.Copy(R.Loot.starter)
        rest.kit = nil
        Game.Notify(host, I18N.T("note.starter", I18N.Bundle(rest), Config.Get("ToggleKey")))
        given = true
    end
    Data.Update(function(dd) dd.kitGranted = true end)
    return given
end

-- Technology never decreases; each region pays once per campaign.
function Lo.OnLevelStarted(level)
    Game.Log("level %s started", tostring(level))
    local host = Game.Host()
    local reward = nil
    Data.Update(function(d)
        local tier = L.TechForLevel(level)
        if tier > d.techTier then
            d.techTier = tier
            Game.Log("forge technology raised to %d", tier)
        end
        local r = R.Loot.regions[level or ""]
        if r and Config.Get("RegionRewards") and not d.regions[level] and host then
            d.regions[level] = true
            reward = r
        end
    end)
    if reward and not U.BundleEmpty(reward) then
        Economy.Grant(host, reward, false)
        Game.Notify(host, I18N.T("note.region", I18N.Bundle(reward)))
    end
    Lo.GrantStarterKit()
    return reward
end

-- Enemies hostile to the host that are neither party members nor summons.
function Lo.OnDied(char)
    if not char or Game.IsPartyMember(char) or Game.IsSummon(char) or not Game.IsEnemyOfHost(char) then return nil end
    local host = Game.Host()
    local boss, corpse = nil, nil
    Data.Update(function(d)
        if Game.IsBoss(char) and Config.Get("BossRewards") and not d.bosses[char] then
            d.bosses[char] = true
            boss = R.Loot.boss
        end
        if Config.Get("KillLoot") and not d.killed[char] then
            d.killed[char] = true
            corpse = L.RollKillLoot(Game.Level(char), Config.Get("KillLootMultiplier"), Lo.Random)
        end
    end)
    if boss and host then
        Economy.Grant(host, boss, false)
        Game.Notify(host, I18N.T("note.boss", I18N.Bundle(boss)))
    end
    if corpse and not U.BundleEmpty(corpse) then
        -- Into the corpse: the player has to loot it.
        for _, res in ipairs(Ids.Materials) do
            local n = corpse[res]
            if n and n > 0 then Game.AddTemplate(char, Economy.Template(res), n, false) end
        end
    end
    return boss, corpse
end

EG.Loot = Lo
return Lo
