--------------------------------------------------------------------------------
-- Codec
--
-- Turns a table of settings into a string a player can copy out of one game and
-- paste into another, and back.
--
-- The one hard requirement is that a string made on any client reads on every
-- other: retail, WoW Forever, Classic Era, Anniversary and Mists. So the table
-- is written out by hand here, in plain Lua, rather than with the client's own
-- CBOR or JSON. Those are whatever each client's build of them happens to be,
-- and a format nobody here controls is a format that can stop round-tripping
-- between two clients without anything in this file changing.
--
-- Compression and base64 are borrowed from C_EncodingUtil when the client has
-- it, because deflate shrinks a settings string several times over and nobody
-- wants to paste 100 KB. Every client this addon loads on has it today. If one
-- ever does not, the string is written as plain base64 instead - longer, and
-- still readable everywhere, which is the part that matters.
--
-- Reading is a parser, never loadstring. The string is something a stranger
-- posted on Discord as often as something the player made, and the only things
-- it can ever turn into are tables, strings, numbers and booleans.
--------------------------------------------------------------------------------

local _, PC = ...

local Codec = {}
PC.Codec = Codec

-- "!PV1z!..." - the version of this framing, then how the body is encoded.
--   z = deflate, then base64
--   b = base64 alone
local PREFIX = "!PV1"
local MAX_DEPTH = 32

local floor, huge = math.floor, math.huge
local byte, char, sub, find, format = string.byte, string.char, string.sub, string.find, string.format
local concat, sort = table.concat, table.sort

--------------------------------------------------------------------------------
-- Serialising
--
--   T / F        true / false
--   i<int>;      an integer
--   n<float>;    any other number, at full precision
--   s<len>:<raw> a string, length-prefixed so it may contain anything
--   { k v ... }  a table: keys and values alternate until the closing brace
--
-- Keys are sorted, so the same settings always make the same string. That makes
-- two exports comparable by eye and makes the tests able to say what they mean.
--------------------------------------------------------------------------------

local KEY_ORDER = { number = 1, string = 2, boolean = 3 }

local function KeyLess(a, b)
    local ta, tb = type(a), type(b)
    if ta ~= tb then return KEY_ORDER[ta] < KEY_ORDER[tb] end
    if ta == "boolean" then return (not a) and b end
    return a < b
end

local function IsFinite(n)
    return n == n and n ~= huge and n ~= -huge
end

-- Whether a value survives the trip at all. Functions, frames and NaN do not;
-- they are left out rather than written as something they are not.
local function Writable(v)
    local t = type(v)
    if t == "string" or t == "boolean" then return true end
    if t == "number" then return IsFinite(v) end
    if t == "table" then
        -- A widget is a table with its userdata at [0]. Settings never are.
        return type(rawget(v, 0)) ~= "userdata"
    end
    return false
end
Codec.Writable = Writable

local function WriteValue(v, out, depth, seen)
    local t = type(v)
    if t == "boolean" then
        out[#out + 1] = v and "T" or "F"
    elseif t == "number" then
        -- %d goes through a C long, which is 32 bits on Windows. Anything wider
        -- is written as a float, which %.17g still carries exactly.
        if v == floor(v) and v > -2^31 and v < 2^31 then
            out[#out + 1] = format("i%d;", v)
        else
            out[#out + 1] = format("n%.17g;", v)
        end
    elseif t == "string" then
        out[#out + 1] = "s" .. #v .. ":" .. v
    elseif t == "table" then
        if depth >= MAX_DEPTH then error("settings nest deeper than " .. MAX_DEPTH .. " tables") end
        if seen[v] then error("settings contain a table inside itself") end
        seen[v] = true

        local keys = {}
        for k, val in pairs(v) do
            if KEY_ORDER[type(k)] and Writable(k) and Writable(val) then
                keys[#keys + 1] = k
            end
        end
        sort(keys, KeyLess)

        out[#out + 1] = "{"
        for i = 1, #keys do
            local k = keys[i]
            WriteValue(k, out, depth + 1, seen)
            WriteValue(v[k], out, depth + 1, seen)
        end
        out[#out + 1] = "}"

        seen[v] = nil
    else
        error("cannot write a " .. t)
    end
end

function Codec.Serialize(value)
    local out = {}
    WriteValue(value, out, 0, {})
    return concat(out)
end

--------------------------------------------------------------------------------
-- Parsing
--------------------------------------------------------------------------------

local ReadValue

local function ReadNumber(s, pos, isInt)
    local stop = find(s, ";", pos, true)
    if not stop then return nil, "a number runs off the end" end
    local text = sub(s, pos, stop - 1)
    local n = tonumber(text)
    if not n or not IsFinite(n) or (isInt and n ~= floor(n)) then
        return nil, "a number is not a number"
    end
    return n, stop + 1
end

ReadValue = function(s, pos, depth)
    local tag = sub(s, pos, pos)
    if tag == "T" then return true, pos + 1 end
    if tag == "F" then return false, pos + 1 end
    if tag == "i" then return ReadNumber(s, pos + 1, true) end
    if tag == "n" then return ReadNumber(s, pos + 1, false) end

    if tag == "s" then
        local colon = find(s, ":", pos + 1, true)
        if not colon then return nil, "a string has no length" end
        local len = tonumber(sub(s, pos + 1, colon - 1))
        if not len or len < 0 or len ~= floor(len) then return nil, "a string has a bad length" end
        local stop = colon + len
        if stop > #s then return nil, "a string runs off the end" end
        return sub(s, colon + 1, stop), stop + 1
    end

    if tag == "{" then
        if depth >= MAX_DEPTH then return nil, "tables nest too deep" end
        local t = {}
        pos = pos + 1
        while true do
            if pos > #s then return nil, "a table is never closed" end
            if sub(s, pos, pos) == "}" then return t, pos + 1 end

            local k, v
            k, pos = ReadValue(s, pos, depth + 1)
            if k == nil then return nil, pos end
            if type(k) == "table" then return nil, "a table is used as a key" end
            v, pos = ReadValue(s, pos, depth + 1)
            if v == nil then return nil, pos end
            if k ~= nil then t[k] = v end
        end
    end

    if tag == "" then return nil, "the string ends too early" end
    return nil, "unexpected '" .. tag .. "'"
end

function Codec.Deserialize(s)
    if type(s) ~= "string" or s == "" then return nil, "nothing to read" end
    local value, pos = ReadValue(s, 1, 0)
    if value == nil then return nil, pos end
    if pos <= #s then return nil, "there is something after the end" end
    return value
end

--------------------------------------------------------------------------------
-- Base64, in Lua, for the client that cannot do it itself. Lua 5.1 has no bit
-- operators, so the bytes are packed with arithmetic.
--------------------------------------------------------------------------------

local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local ENC, DEC = {}, {}
for i = 1, 64 do
    local c = sub(ALPHABET, i, i)
    ENC[i - 1] = c
    DEC[byte(c)] = i - 1
end

function Codec.ToBase64(s)
    local out = {}
    for i = 1, #s, 3 do
        local a, b, c = byte(s, i, i + 2)
        local n = a * 65536 + (b or 0) * 256 + (c or 0)
        local c1 = floor(n / 262144)
        local c2 = floor(n / 4096) % 64
        local c3 = floor(n / 64) % 64
        local c4 = n % 64
        out[#out + 1] = ENC[c1] .. ENC[c2]
            .. (b and ENC[c3] or "=")
            .. (c and ENC[c4] or "=")
    end
    return concat(out)
end

function Codec.FromBase64(s)
    s = s:gsub("[^%w%+/]", "")
    if #s % 4 == 1 then return nil end
    local out = {}
    for i = 1, #s, 4 do
        local q1, q2, q3, q4 = byte(s, i, i + 3)
        local d1, d2 = DEC[q1], DEC[q2]
        local d3, d4 = q3 and DEC[q3], q4 and DEC[q4]
        if not (d1 and d2) then return nil end
        local n = d1 * 262144 + d2 * 4096 + (d3 or 0) * 64 + (d4 or 0)
        local b1 = floor(n / 65536)
        local b2 = floor(n / 256) % 256
        local b3 = n % 256
        out[#out + 1] = char(b1)
        if d3 then out[#out + 1] = char(b2) end
        if d4 then out[#out + 1] = char(b3) end
    end
    return concat(out)
end

--------------------------------------------------------------------------------
-- Framing
--------------------------------------------------------------------------------

local function EncodingUtil()
    local E = _G.C_EncodingUtil
    if type(E) == "table"
        and E.CompressString and E.DecompressString
        and E.EncodeBase64 and E.DecodeBase64 then
        return E
    end
end

local function Deflate()
    return _G.Enum and _G.Enum.CompressionMethod and _G.Enum.CompressionMethod.Deflate
end

--- A table, as a string to share.
function Codec.Encode(value)
    local body = Codec.Serialize(value)

    local E = EncodingUtil()
    if E then
        local ok, packed = pcall(function()
            return E.EncodeBase64(E.CompressString(body, Deflate()))
        end)
        if ok and type(packed) == "string" and packed ~= "" then
            return PREFIX .. "z!" .. packed
        end
    end

    return PREFIX .. "b!" .. Codec.ToBase64(body)
end

--- A shared string, as the table it was made from.
--- @return table|nil value, string|nil err  err is written for a player
function Codec.Decode(text)
    if type(text) ~= "string" then return nil, "There is nothing to read." end

    -- Chat clients and forums break long lines and add spaces. None of it is
    -- part of the string.
    text = text:gsub("%s", "")
    if text == "" then return nil, "Paste a string first." end

    local mode, payload = text:match("^!PV(%d+%a)!(.+)$")
    if not mode then
        return nil, "That is not a Peavers settings string."
    end
    if sub(mode, 1, -2) ~= "1" then
        return nil, "That string is from a newer PeaversConfig. Update it, then try again."
    end
    mode = sub(mode, -1)

    local body
    if mode == "b" then
        body = Codec.FromBase64(payload)
    elseif mode == "z" then
        local E = EncodingUtil()
        if not E then
            return nil, "This client cannot unpack compressed strings. Export again on the other " ..
                "client after updating PeaversConfig there."
        end
        local ok, out = pcall(function()
            return E.DecompressString(E.DecodeBase64(payload), Deflate())
        end)
        body = ok and type(out) == "string" and out or nil
    else
        return nil, "That string uses an encoding this PeaversConfig does not know. Update it."
    end

    if not body or body == "" then
        return nil, "That string is damaged. Copy all of it - it is long, and easy to cut short."
    end

    local value, err = Codec.Deserialize(body)
    if value == nil then
        return nil, "That string is damaged (" .. tostring(err) .. "). Copy all of it and try again."
    end
    if type(value) ~= "table" then
        return nil, "That string holds no settings."
    end
    return value
end

return Codec
