-- PeaversConfig luacheck config. Thin wrapper over the shared Peavers base (../wow-api).
-- The base supplies the lua51+wow standard, ignore/exclude policy, and stds.wow (WoW API:
-- generated from /papidump when present, else curated). allow_defined_top is off, so every
-- global this addon creates must be listed below — that list is its documented _G footprint.
-- Run: ../wow-api/scripts/lint.sh   (override package path with WOW_API_DIR)

local apiDir = (os and os.getenv and os.getenv("WOW_API_DIR")) or "../wow-api"
local base = assert(loadfile(apiDir .. "/config/luacheckrc.base.lua"))(apiDir)

std             = base.std
ignore          = base.ignore
exclude_files   = base.exclude
max_line_length = false
codestyle       = false
allow_defined_top = base.allow_defined_top
stds.wow        = base.wow

-- base.globals (PeaversChangelogs, SlashCmdList, StaticPopupDialogs) + this addon's
-- SavedVariables. PeaversConfig is the config manager, so it also writes the shared
-- PeaversCommonsDB (appearance/support settings) on behalf of the ecosystem.
globals = base.globals
for _, g in ipairs({"PeaversConfigDB", "PeaversCommonsDB"}) do globals[#globals + 1] = g end
