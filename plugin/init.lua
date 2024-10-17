local wezterm = require("wezterm")

local M = {}
local State = {}

---@class WindowState
---@field font_weight string
---@field font_size number
---@field is_fullscreen boolean

---@class State
---@field active boolean
---@field prev_state? WindowState
State.default = {
    active = false,
    prev_state = nil,
}

if not wezterm.GLOBAL.presentation_mode then
    wezterm.GLOBAL.presentation_mode = State.default
    wezterm.log_info("state was empty so setting default")
end

---@param win table
State.record_state = function(win)
    local config = win:effective_config()
    wezterm.GLOBAL.presentation_mode.prev_state = {
        font_weight = config.font.font[1].weight,
        font_size = config.font_size,
        is_fullscreen = win:get_dimensions().is_full_screen,
    }
end

---@return WindowState
State.get_prev_state = function() return wezterm.GLOBAL.presentation_mode.prev_state end

---@param value boolean
State.set_active = function(value) wezterm.GLOBAL.presentation_mode.active = value end

---@return boolean
State.get_active = function() return wezterm.GLOBAL.presentation_mode.active end

---@param ... table
---@return table result
local function deep_merge_table(...)
    local tables_to_merge = { ... }
    assert(#tables_to_merge > 1, "There should be at least two tables to merge them")

    local result = {}
    for k, t in ipairs(tables_to_merge) do
        assert(type(t) == "table", string.format("Expected a table as function parameter %d", k))
        for key, value in pairs(t) do
            if type(value) == "table" then
                result[key] = deep_merge_table(result[key] or {}, value or {})
            else
                result[key] = value
            end
        end
    end

    return result
end

---@class PresentationModeOpts
---@field font_weight? string
---@field font_size_multiplier? number
---@field fullscreen? boolean

---@type PresentationModeOpts
local default_opts = {
    font_weight = "DemiBold",
    font_size_multiplier = 1.6,
    fullscreen = false,
}

---@param win table
---@param opts PresentationModeOpts
local function enable(win, opts)
    local overrides = win:get_config_overrides() or {}
    local config = win:effective_config()
    overrides.font = overrides.font or config.font

    State.record_state(win)

    overrides.font.font[1].weight = opts.font_weight
    overrides.font_size = State.get_prev_state().font_size * opts.font_size_multiplier

    if pcall(function() win:set_config_overrides(overrides) end) then
        if opts.fullscreen and not win:get_dimensions().is_full_screen then win:toggle_fullscreen() end
        State.set_active(true)
    else
        wezterm.log_error("Something went wrong when activating presentation mode")
    end
end

---@param win table
local function disable(win)
    if not State.get_active() then
        -- diable can only be called when State.active == true
        wezterm.log_warn("function disable called when State.active was false")
        return
    end

    local overrides = win:get_config_overrides() or {}

    overrides.font.font[1].weight = State.get_prev_state().font_weight
    overrides.font_size = State.get_prev_state().font_size

    if pcall(function() win:set_config_overrides(overrides) end) then
        if win:get_dimensions().is_full_screen ~= State.get_prev_state().is_fullscreen then win:toggle_fullscreen() end
        State.set_active(false)
    else
        wezterm.log_error("Something went wrong when deactivating presentation mode")
    end
end

---@param opts? PresentationModeOpts
M.toggle = function(opts)
    wezterm.log_info("before applying defaults: ")
    wezterm.log_info(opts)

    ---@type PresentationModeOpts
    opts = opts and deep_merge_table(default_opts, opts) or default_opts

    wezterm.log_info("after applying defaults: ")
    wezterm.log_info(opts)

    return wezterm.action_callback(function(win, _)
        wezterm.log_info("this callback was created with opts: { fullscreen = " .. tostring(opts.fullscreen) .. " }")
        if State.get_active() then
            disable(win)
        else
            enable(win, opts)
        end
    end)
end

M.apply_to_config = function(config) end

return M
