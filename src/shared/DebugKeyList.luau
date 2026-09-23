--!strict
-- Studio-only debug keys: the one list both DebugKeys.client (the keys) and
-- the Bag's Debug tab (the cheat sheet) read, so the sheet can't go stale.
-- Command = a DebugService command name, or "" for a client-only action.
-- Nothing here does anything outside Studio: DebugKeys doesn't run there,
-- and DebugService refuses commands on live servers.

export type Entry = { Key: Enum.KeyCode, Label: string, Command: string, Text: string, Group: string }

local DebugKeyList: { Entry } = {
	-- Resources + progress
	{ Key = Enum.KeyCode.F, Label = "F", Command = "GrantExposedResources", Text = "+Stone/Ore/Riftsalt (Exposed)", Group = "Resources" },
	{ Key = Enum.KeyCode.G, Label = "G", Command = "GrantScrap", Text = "+Scrap", Group = "Resources" },
	{ Key = Enum.KeyCode.C, Label = "C", Command = "GrantCredits", Text = "+Credits", Group = "Resources" },
	{ Key = Enum.KeyCode.X, Label = "X", Command = "GrantMinerXP", Text = "+Miner XP", Group = "Resources" },
	{ Key = Enum.KeyCode.V, Label = "V", Command = "ForceVaultborn", Text = "next hit is Vaultborn", Group = "Resources" },
	{ Key = Enum.KeyCode.T, Label = "T", Command = "NextVaultTier", Text = "next Vault tier", Group = "Resources" },
	-- Gear + items
	{ Key = Enum.KeyCode.K, Label = "K", Command = "NextPickaxeTier", Text = "next pickaxe tier", Group = "Gear" },
	{ Key = Enum.KeyCode.U, Label = "U", Command = "GrantArmor", Text = "+armor piece", Group = "Gear" },
	{ Key = Enum.KeyCode.J, Label = "J", Command = "GrantGadgets", Text = "+1 of every gadget", Group = "Gear" },
	{ Key = Enum.KeyCode.Seven, Label = "7", Command = "GrantSkin", Text = "+Captain's Cleaver skin", Group = "Gear" },
	{ Key = Enum.KeyCode.Nine, Label = "9", Command = "GrantLockpicks", Text = "+5 lockpicks", Group = "Gear" },
	{ Key = Enum.KeyCode.Zero, Label = "0", Command = "GrantSprintSerum", Text = "999 Sprint Serum (every player)", Group = "Gear" },
	-- Raids + waves
	{ Key = Enum.KeyCode.Y, Label = "Y", Command = "TogglePvpProtection", Text = "toggle PvP protection", Group = "Raids" },
	{ Key = Enum.KeyCode.Eight, Label = "8", Command = "FillOfflineBases", Text = "fill free plots with offline bases", Group = "Raids" },
	{ Key = Enum.KeyCode.Q, Label = "Q", Command = "StartWave", Text = "Scav Wave on your base", Group = "Raids" },
	{ Key = Enum.KeyCode.Six, Label = "6", Command = "StartCaptainWave", Text = "wave led by a Scav Captain", Group = "Raids" },
	{ Key = Enum.KeyCode.Z, Label = "Z", Command = "FloodWaves", Text = "queue many waves (cap test)", Group = "Raids" },
	-- Checks + prints (results in Output)
	{ Key = Enum.KeyCode.P, Label = "P", Command = "PrintProfile", Text = "print your profile", Group = "Checks" },
	{ Key = Enum.KeyCode.L, Label = "L", Command = "PrintPresence", Text = "print presence", Group = "Checks" },
	{ Key = Enum.KeyCode.N, Label = "N", Command = "PrintBand", Text = "print raid band", Group = "Checks" },
	{ Key = Enum.KeyCode.B, Label = "B", Command = "BroadcastTest", Text = "test broadcast queue", Group = "Checks" },
	{ Key = Enum.KeyCode.H, Label = "H", Command = "ToggleMeter", Text = "toggle vault meter", Group = "Checks" },
	{ Key = Enum.KeyCode.M, Label = "M", Command = "", Text = "spam the mine remote (rate-limit test)", Group = "Checks" },
}

return DebugKeyList
