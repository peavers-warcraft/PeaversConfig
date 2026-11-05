--------------------------------------------------------------------------------
-- SettingsTransfer
--
-- Every Peavers addon's settings as one string, and that string back into
-- settings on another client: retail to WoW Forever, one PC to the next, or a
-- friend's setup into yours.
--
-- WHAT TRAVELS
--
-- Each registered addon's current profile, as the settings that differ from
-- its defaults, plus Global Appearance. Not the whole saved file: history,
-- caches and per-character records live outside the profile and stay where
-- they are. A few keys inside a profile record what happened on one install
-- rather than how somebody likes things - a notice already shown, a version
-- already installed - and those stay too (NEVER below, or `exportExclude` on
-- an addon's ConfigRegistry entry).
--
-- WHAT IMPORTING MEANS
--
-- Replace, not merge. For every addon ticked, its current profile goes back to
-- the defaults and the string's settings go on top, so it ends up set exactly
-- as it was where the string was made. A merge would leave behind whatever this
-- client had changed that the other had not, and "make it like mine" would
-- quietly mean "make it partly like mine".
--
-- Then the UI reloads. Every addon reads its settings at load, through its own
-- migrations and checks, and that is the one path guaranteed to handle a
-- string from an older or newer version of it. Poking values into running
-- addons would trust each of them to notice.
--
-- What each addon had before is kept, once, so the import can be undone.
--------------------------------------------------------------------------------

local _, PC = ...

local Transfer = {}
PC.SettingsTransfer = Transfer

local Codec = PC.Codec

local FORMAT = 1
Transfer.APPEARANCE = "GlobalAppearance"

-- Keys that describe this install, not a preference. Leaving them out keeps a
-- one-time notice one-time and a first-run wizard first-run on the other side.
local NEVER = {
    installedVersion = true,
    secureNoticeShown = true,
    DEBUG_ENABLED = true,
    debugMode = true,
}

-- Addons left out entirely, and why.
local SKIP = {
    -- The installer. What it set up lives in each module's own settings, which
    -- travel with them. What is left in its own config is a record of its runs,
    -- crash-recovery state from a layout preview, and profile strings captured
    -- from third-party addons on this machine - none of it belongs elsewhere.
    PeaversUI = true,
}

-- A flat config keeps its machinery on the same table as its settings.
local FLAT_RESERVED = { addon = true, dbName = true, defaults = true, settingsKey = true }

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function DeepCopy(v)
    if type(v) ~= "table" then return v end
    local copy = {}
    for k, val in pairs(v) do copy[DeepCopy(k)] = DeepCopy(val) end
    return copy
end

local function DeepEqual(a, b)
    if a == b then return true end
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    for k, v in pairs(a) do
        if not DeepEqual(v, b[k]) then return false end
    end
    for k in pairs(b) do
        if a[k] == nil then return false end
    end
    return true
end

local function Count(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

local function Commons() return _G.PeaversCommons end

local function AddonVersion(name)
    local getter = C_AddOns and C_AddOns.GetAddOnMetadata or _G.GetAddOnMetadata
    return getter and getter(name, "Version") or nil
end

local function DB()
    if not _G.PeaversConfigDB then _G.PeaversConfigDB = {} end
    return _G.PeaversConfigDB
end

--------------------------------------------------------------------------------
-- Adapters
--
-- Two kinds of config are in use. One is AceDB-backed: settings live in
-- db.profile. The other is flat: settings are fields on the config table
-- itself, written to disk by Save. Each adapter answers the same two
-- questions - what is set now, and set it to this - so nothing above them
-- cares which is which.
--------------------------------------------------------------------------------

local function ProfileAdapter(db)
    return {
        Read = function() return db.profile end,
        Write = function(values, keep)
            -- No children (namespaces are not settings this knows about) and no
            -- callbacks: the addons are about to be reloaded, and a refresh
            -- halfway through a replace would only draw the defaults.
            db:ResetProfile(true, true)
            for k, v in pairs(keep) do db.profile[k] = v end
            for k, v in pairs(values) do db.profile[k] = DeepCopy(v) end
        end,
    }
end

local function FlatAdapter(config)
    local function IsSetting(k, v)
        return not FLAT_RESERVED[k] and type(v) ~= "function" and Codec.Writable(v)
    end

    return {
        Read = function()
            local t = {}
            for k, v in pairs(config) do
                if IsSetting(k, v) then t[k] = v end
            end
            return t
        end,
        Write = function(values, keep)
            for k, v in pairs(config) do
                if IsSetting(k, v) then config[k] = nil end
            end
            for k, v in pairs(config.defaults) do config[k] = DeepCopy(v) end
            for k, v in pairs(keep) do config[k] = v end
            for k, v in pairs(values) do config[k] = DeepCopy(v) end
            -- A flat config's font has no default until Initialize picks one for
            -- the locale. The reload is a moment away, but a bar redrawn before
            -- it would ask for a nil font.
            if config.fontFace == nil then
                local CM = _G.PeaversCommons and _G.PeaversCommons.ConfigManager
                if CM and CM.GetDefaultFont then config.fontFace = CM.GetDefaultFont() end
            end
            -- Save drops from disk what is now nil, so a key that the import
            -- does not set does not come back from the old file at load.
            config:Save()
        end,
    }
end

local function AdapterFor(config)
    if type(config) ~= "table" or type(rawget(config, "defaults")) ~= "table" then return nil end

    -- An AceDB config marks itself with profileType, set before it has a db.
    -- Until Initialize has run there is nothing to read, and treating it as
    -- flat would read the wrong table entirely.
    if rawget(config, "profileType") ~= nil then
        local db = rawget(config, "db")
        if type(db) == "table" and type(db.profile) == "table" and type(db.ResetProfile) == "function" then
            return ProfileAdapter(db)
        end
        return nil
    end

    if type(config.Save) == "function" then
        return FlatAdapter(config)
    end
end

local function AppearanceEntry()
    local GA = Commons() and Commons().GlobalAppearance
    if not (GA and GA.Get and GA.GetDefaults and GA.Reset and GA.SetMultiple) then return nil end

    return {
        key = Transfer.APPEARANCE,
        label = "Global Appearance",
        defaults = GA:GetDefaults(),
        exclude = {},
        adapter = {
            Read = function() return GA:Get() or {} end,
            Write = function(values)
                GA:Reset()
                GA:SetMultiple(values)
            end,
        },
    }
end

local function Exclusions(info)
    local set = {}
    for k in pairs(NEVER) do set[k] = true end
    local extra = info and info.exportExclude
    if type(extra) == "table" then
        for k, v in pairs(extra) do
            if type(k) == "number" then set[v] = true else set[k] = true end
        end
    end
    return set
end

--------------------------------------------------------------------------------
-- What can be moved
--------------------------------------------------------------------------------

--- Every addon whose settings can travel, in sidebar order, then Global
--- Appearance last.
--- @return table[] entries { key, label, version, defaults, exclude, adapter }
function Transfer:GetEntries()
    local entries = {}

    local registry = Commons() and Commons().ConfigRegistry
    if registry then
        for _, info in ipairs(registry:GetSortedAddons()) do
            local adapter = not SKIP[info.name] and info.exportable ~= false and AdapterFor(info.config)
            if adapter then
                entries[#entries + 1] = {
                    key = info.name,
                    label = info.displayName or info.name,
                    version = AddonVersion(info.name),
                    defaults = rawget(info.config, "defaults"),
                    exclude = Exclusions(info),
                    adapter = adapter,
                }
            end
        end
    end

    local appearance = AppearanceEntry()
    if appearance then entries[#entries + 1] = appearance end

    return entries
end

function Transfer:GetEntry(key)
    for _, entry in ipairs(self:GetEntries()) do
        if entry.key == key then return entry end
    end
end

-- The settings that differ from the defaults, ready to write out.
local function Changed(entry)
    local out = {}
    for k, v in pairs(entry.adapter.Read()) do
        if not entry.exclude[k] and Codec.Writable(v) and not DeepEqual(v, entry.defaults[k]) then
            out[k] = DeepCopy(v)
        end
    end
    return out
end

-- Everything that is set, defaults included: what an undo has to put back.
local function Everything(entry)
    local out = {}
    for k, v in pairs(entry.adapter.Read()) do
        if not entry.exclude[k] and Codec.Writable(v) then
            out[k] = DeepCopy(v)
        end
    end
    return out
end

--- How many settings an addon has moved away from its defaults.
function Transfer.CountChanged(_, entry)
    return Count(Changed(entry))
end

--------------------------------------------------------------------------------
-- Export
--------------------------------------------------------------------------------

local function ClientInfo()
    local Client = Commons() and Commons().Client
    return Client and Client.key or "unknown", Client and Client.label or "World of Warcraft"
end

--- @param selected table<string, boolean>|nil  keys to include; nil for all
--- @return string text, number addonCount
function Transfer:Export(selected)
    local clientKey, clientLabel = ClientInfo()
    local payload = {
        format = FORMAT,
        client = clientKey,
        clientLabel = clientLabel,
        made = time and time() or 0,
        addons = {},
    }

    local n = 0
    for _, entry in ipairs(self:GetEntries()) do
        if not selected or selected[entry.key] then
            payload.addons[entry.key] = {
                label = entry.label,
                version = entry.version,
                settings = Changed(entry),
            }
            n = n + 1
        end
    end

    return Codec.Encode(payload), n
end

--------------------------------------------------------------------------------
-- Import
--------------------------------------------------------------------------------

--- Read a pasted string without changing anything.
--- @return table|nil import, string|nil err
function Transfer.Read(_, text)
    local payload, err = Codec.Decode(text)
    if not payload then return nil, err end

    if type(payload.format) ~= "number" or type(payload.addons) ~= "table" then
        return nil, "That string holds no Peavers settings."
    end
    if payload.format > FORMAT then
        return nil, "That string is from a newer PeaversConfig. Update it, then try again."
    end

    for key, block in pairs(payload.addons) do
        if type(key) ~= "string" or type(block) ~= "table" or type(block.settings) ~= "table" then
            payload.addons[key] = nil
        end
    end
    if next(payload.addons) == nil then
        return nil, "That string holds no addon settings."
    end

    return payload
end

--- One line per addon in a string: whether it is here to receive it, and how
--- much it carries. Installed ones come first, in sidebar order.
--- @return table[] rows { key, label, installed, count, version, sourceVersion }
function Transfer:Preview(payload)
    local rows, seen = {}, {}

    for _, entry in ipairs(self:GetEntries()) do
        local block = payload.addons[entry.key]
        if block then
            seen[entry.key] = true
            rows[#rows + 1] = {
                key = entry.key,
                label = entry.label,
                installed = true,
                count = Count(block.settings),
                version = entry.version,
                sourceVersion = type(block.version) == "string" and block.version or nil,
            }
        end
    end

    local missing = {}
    for key, block in pairs(payload.addons) do
        if not seen[key] then
            missing[#missing + 1] = {
                key = key,
                label = type(block.label) == "string" and block.label or key,
                installed = false,
                count = Count(block.settings),
            }
        end
    end
    table.sort(missing, function(a, b) return a.label < b.label end)
    for _, row in ipairs(missing) do rows[#rows + 1] = row end

    return rows
end

-- A key is a font setting if it is called that, or if its default is a font.
-- Likewise textures. A face or fill that is not installed here draws nothing at
-- all - invisible text, empty bars - so those stay at the default instead.
local function MediaCheck()
    local CM = Commons() and Commons().ConfigManager
    local fonts = CM and CM.GetFonts and CM.GetFonts() or nil
    local textures = CM and CM.GetBarTextures and CM.GetBarTextures() or nil

    return function(k, v, default)
        if fonts and (k == "fontFace" or (type(default) == "string" and fonts[default])) then
            return type(v) == "string" and fonts[v] ~= nil, "font not installed here"
        end
        if textures and (k == "barTexture" or (type(default) == "string" and textures[default])) then
            return type(v) == "string" and textures[v] ~= nil, "texture not installed here"
        end
        return true
    end
end

-- What of an addon's imported settings can be used here, and what cannot.
local function Sanitize(entry, settings, mediaOk)
    local clean, dropped = {}, {}
    for k, v in pairs(settings) do
        if entry.exclude[k] then
            -- Not ours to set, silently: it was never meant to travel.
        elseif type(k) ~= "string" and type(k) ~= "number" then
            dropped[#dropped + 1] = tostring(k) .. " (not a setting)"
        else
            local default = entry.defaults[k]
            if default ~= nil and type(default) ~= type(v) then
                dropped[#dropped + 1] = tostring(k) .. " (wrong kind of value)"
            else
                local ok, why = mediaOk(k, v, default)
                if ok then
                    clean[k] = v
                else
                    dropped[#dropped + 1] = tostring(k) .. " (" .. why .. ")"
                end
            end
        end
    end
    table.sort(dropped)
    return clean, dropped
end

-- Replace one addon's settings, keeping its never-travel keys as they are.
local function Replace(entry, settings)
    local keep = {}
    local current = entry.adapter.Read()
    for k in pairs(entry.exclude) do
        if current[k] ~= nil then keep[k] = DeepCopy(current[k]) end
    end
    entry.adapter.Write(settings, keep)
end

--- Apply an import. Nothing is checked twice: call Read first.
--- @param payload table from Read
--- @param selected table<string, boolean> keys to apply
--- @return table|nil report, string|nil err
function Transfer:Apply(payload, selected)
    if InCombatLockdown and InCombatLockdown() then
        return nil, "Leave combat first. Importing reloads the UI."
    end

    local mediaOk = MediaCheck()
    local undo = { made = time and time() or 0, addons = {} }
    local report = {
        from = type(payload.clientLabel) == "string" and payload.clientLabel or nil,
        applied = {},
    }

    for _, entry in ipairs(self:GetEntries()) do
        local block = payload.addons[entry.key]
        if block and selected[entry.key] then
            local clean, dropped = Sanitize(entry, block.settings, mediaOk)
            undo.addons[entry.key] = Everything(entry)

            local ok, err = pcall(Replace, entry, clean)
            report.applied[#report.applied + 1] = {
                label = entry.label,
                count = Count(clean),
                dropped = dropped,
                failed = not ok and tostring(err) or nil,
            }
        end
    end

    if #report.applied == 0 then
        return nil, "Nothing was selected."
    end

    DB().transferUndo = undo
    DB().transferReport = report
    return report
end

--- Whether there is an import to undo, and when it was made.
function Transfer.GetUndo(_)
    local undo = DB().transferUndo
    if type(undo) == "table" and type(undo.addons) == "table" and next(undo.addons) then
        return undo
    end
end

--- Put back what the last import replaced.
function Transfer:Undo()
    if InCombatLockdown and InCombatLockdown() then
        return nil, "Leave combat first. Undoing reloads the UI."
    end

    local undo = self:GetUndo()
    if not undo then return nil, "There is no import to undo." end

    local report = { undo = true, applied = {} }
    for _, entry in ipairs(self:GetEntries()) do
        local settings = undo.addons[entry.key]
        if type(settings) == "table" then
            local ok, err = pcall(Replace, entry, settings)
            report.applied[#report.applied + 1] = {
                label = entry.label,
                count = Count(settings),
                dropped = {},
                failed = not ok and tostring(err) or nil,
            }
        end
    end

    DB().transferUndo = nil
    DB().transferReport = report
    return report
end

--------------------------------------------------------------------------------
-- After the reload
--
-- The import ends in a reload, which clears the chat frame, so what happened is
-- kept until the next load and said then.
--------------------------------------------------------------------------------

local TAG = "|cff3abdf7PeaversConfig:|r "

function Transfer.AnnounceLastImport(_)
    local db = _G.PeaversConfigDB
    local report = db and db.transferReport
    if type(report) ~= "table" then return end
    db.transferReport = nil

    local applied = type(report.applied) == "table" and report.applied or {}
    if report.undo then
        print(TAG .. "Undid the last import for " .. #applied .. " addon(s).")
    else
        print(TAG .. "Imported settings for " .. #applied .. " addon(s)"
            .. (report.from and (" from " .. report.from) or "") .. ". /peavers import to undo.")
    end

    for _, line in ipairs(applied) do
        if line.failed then
            print(TAG .. "  " .. tostring(line.label) .. " could not be changed: " .. line.failed)
        elseif type(line.dropped) == "table" and #line.dropped > 0 then
            print(TAG .. "  " .. tostring(line.label) .. " kept its default for: "
                .. table.concat(line.dropped, ", "))
        end
    end
end

return Transfer
