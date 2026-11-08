---@meta

-- Guidelime 6.017 (CurseForge 327139) publishes these two globals; its current step is the target its arrow
-- points at. Nothing else of Guidelime's addon table is read.

---@class SPFGuidelimeElement
---@field t? string
---@field mapID? integer
---@field x? number percent of the map
---@field y? number percent of the map
---@field title? string
---@field radius? number
---@field completed? boolean
---@field attached? {title: string?, completed: boolean?}
---@field step? {text: string?, active: boolean?, index: integer?}

---@class SPFGuidelimeArrow: Frame
---@field element? SPFGuidelimeElement
---@field texture Texture
---@field text FontString

---@class SPFGuidelimeAddon
---@field registerGuide? fun(guide: table, group: string?)

---@type SPFGuidelimeAddon?
Guidelime = nil

---@type SPFGuidelimeArrow?
GuidelimeArrow = nil
