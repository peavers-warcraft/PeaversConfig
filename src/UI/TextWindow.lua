--------------------------------------------------------------------------------
-- TextWindow
--
-- A window with a long string in it: either one to copy out, already selected
-- so Ctrl+C works at once, or an empty box to paste one into.
--
-- An addon cannot reach the system clipboard. A focused EditBox with its text
-- highlighted is the only thing that has ever worked, which is why every addon
-- that shares a string looks like this.
--
-- One frame, reused for both. There is never a reason to have two open.
--------------------------------------------------------------------------------

local _, PC = ...

local TextWindow = {}
PC.TextWindow = TextWindow

local Style = PC.Style
local W = PC.Widgets
local C = W and W.Colors or {}

local WIDTH, HEIGHT = 580, 320
local PAD = 18

local frame, editBox, titleText, hintText, errorText, primaryBtn, secondaryBtn
local mode, onSubmit

local function Color(c, fallback)
    c = c or fallback
    return c[1], c[2], c[3], c[4] or 1
end

local function Build()
    frame = CreateFrame("Frame", "PeaversConfigTextWindow", UIParent, "BackdropTemplate") --[[@as Frame]]
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetPoint("CENTER")
    -- Above the settings window it is opened from, which is DIALOG.
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(Color(C.bgBase, { 0.086, 0.086, 0.086 }))
    frame:SetBackdropBorderColor(Color(C.border, { 0.176, 0.176, 0.176 }))

    table.insert(UISpecialFrames, "PeaversConfigTextWindow")

    titleText = Style.Label(frame, "", Style.Size.hero, Style.Alpha.primary)
    titleText:SetPoint("TOPLEFT", PAD, -PAD)

    hintText = Style.Label(frame, "", Style.Size.value, Style.Alpha.secondary,
        { width = WIDTH - PAD * 2, wrap = true })
    hintText:SetPoint("TOPLEFT", PAD, -(PAD + Style.Size.hero + 10))

    local box = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    box:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    box:SetBackdropColor(Color(C.bgInput, { 0.110, 0.110, 0.110 }))
    box:SetBackdropBorderColor(Color(C.border, { 0.176, 0.176, 0.176 }))
    box:SetPoint("TOPLEFT", PAD, -96)
    box:SetPoint("BOTTOMRIGHT", -PAD, 64)
    box:EnableMouse(true)
    box:SetScript("OnMouseDown", function() editBox:SetFocus() end)

    -- A scroll frame, because a settings string is thousands of characters and
    -- a plain EditBox would draw it as one line off the side of the window.
    local scroll = CreateFrame("ScrollFrame", "PeaversConfigTextWindowScroll", box, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", -28, 8)

    editBox = CreateFrame("EditBox", nil, scroll)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    -- No cap. The default is 255, which would cut every string short - and a
    -- string cut short only fails on the other side, with no clue why.
    editBox:SetMaxLetters(0)
    editBox:SetFontObject("GameFontHighlightSmall")
    editBox:SetWidth(WIDTH - PAD * 2 - 44)
    editBox:SetScript("OnEscapePressed", function() frame:Hide() end)
    editBox:SetScript("OnTextChanged", function(self, userInput)
        if not userInput then return end
        if mode == "copy" then
            -- Read-only in the only way the client allows: let the change
            -- happen, then put the original back. Selecting still works.
            self:SetText(self.peaversText or "")
            self:HighlightText()
        elseif errorText:IsShown() then
            errorText:Hide()
        end
    end)
    scroll:SetScrollChild(editBox)

    errorText = Style.Label(frame, "", Style.Size.value, Style.Alpha.primary,
        { width = WIDTH - PAD * 2 - 260, wrap = true, color = C.danger or { 0.90, 0.30, 0.30 } })
    errorText:SetPoint("BOTTOMLEFT", PAD, 22)
    errorText:Hide()

    primaryBtn = Style.Button(frame, "", {
        variant = "primary", width = 130,
        onClick = function()
            if mode == "copy" then
                editBox:SetFocus()
                editBox:HighlightText()
            elseif onSubmit then
                local ok, err = onSubmit(editBox:GetText())
                if ok then
                    frame:Hide()
                else
                    errorText:SetText(err or "That did not work.")
                    errorText:Show()
                end
            end
        end,
    })
    primaryBtn:SetPoint("BOTTOMRIGHT", -PAD, PAD)

    secondaryBtn = Style.Button(frame, "Close", {
        variant = "secondary", width = 100,
        onClick = function() frame:Hide() end,
    })
    secondaryBtn:SetPoint("RIGHT", primaryBtn, "LEFT", -Style.Pad.gap, 0)

    frame:SetScript("OnHide", function()
        editBox:ClearFocus()
        onSubmit = nil
    end)

    frame:Hide()
end

local function Open(newMode, title, hint, text, primaryLabel, secondaryLabel)
    if not frame then Build() end
    mode = newMode

    titleText:SetText(title or "")
    hintText:SetText(hint or "")
    errorText:Hide()
    primaryBtn:SetLabel(primaryLabel)
    secondaryBtn:SetLabel(secondaryLabel)

    editBox.peaversText = text
    editBox:SetText(text or "")

    frame:Show()
    frame:Raise()

    -- Focus after the frame is up: highlighting a hidden EditBox does nothing,
    -- and the point is that Ctrl+C (or Ctrl+V) works without a click.
    editBox:SetFocus()
    if text then editBox:HighlightText() end
end

--- Show a string, selected and ready to copy.
function TextWindow.ShowCopy(_, title, text, hint)
    Open("copy", title, hint or "Ctrl+C to copy.", text or "", "Select all", "Close")
end

--- An empty box to paste into. `submit(text)` returns true to close the
--- window, or false and a message to show under the box.
function TextWindow.ShowPaste(_, title, hint, submit)
    Open("paste", title, hint or "Ctrl+V to paste.", nil, "Continue", "Cancel")
    onSubmit = submit
end

function TextWindow.Hide(_)
    if frame then frame:Hide() end
end

return TextWindow
