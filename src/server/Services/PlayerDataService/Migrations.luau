--!strict
-- Schema migrations. Each entry upgrades a profile FROM that version to the
-- next one. Only renames and reshapes need one: a brand-new field is filled in
-- by Reconcile() from the template.
--
-- To add one: write steps[N] (N -> N+1), then bump Config.Data.SchemaVersion.
-- Steps must cope with missing sections (very old or hand-edited profiles).

local Migrations = {}

local steps: { [number]: (data: any) -> () } = {
	-- 1 -> 2: the Mobility upgrade "Sprint recovery" became "Stun recovery"
	-- (Josh's call, 2026-09-21: the docs have no sprint). Bought ranks keep
	-- their place under the new name.
	[1] = function(data)
		local gear = data.Gear
		local mobility = type(gear) == "table" and type(gear.Upgrades) == "table" and gear.Upgrades.Mobility
		if type(mobility) ~= "table" then
			return
		end
		for rank = 1, 3 do
			if mobility[`SprintRecovery{rank}`] then
				mobility[`SprintRecovery{rank}`] = nil
				mobility[`StunRecovery{rank}`] = true
			end
		end
	end,
}

-- Upgrades `data` in place to `target`. Returns (ok, reason). Callers pass a
-- copy, so a failed migration never leaves a half-changed profile behind.
function Migrations.run(data: any, target: number): (boolean, string?)
	local meta = data.Meta
	local version = if type(meta) == "table" and type(meta.Version) == "number" then meta.Version else 1

	-- A profile saved by NEWER code (e.g. an old server still running after an
	-- update). Loading it here could drop fields it doesn't know about.
	if version > target then
		return false, `profile is schema v{version}, this server only knows v{target}`
	end

	while version < target do
		local step = steps[version]
		if not step then
			return false, `no migration from v{version}`
		end
		step(data)
		version += 1
	end

	if type(data.Meta) ~= "table" then
		data.Meta = {}
	end
	data.Meta.Version = target
	return true, nil
end

return Migrations
