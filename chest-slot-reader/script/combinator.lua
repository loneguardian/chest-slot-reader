local c = require("constants")
local util = require("util")
local area = require("__flib__.area")

local _M = {}

local no_signal = c.SIGNALS.NO_SIGNAL
local signal_F = c.SIGNALS.SIGNAL_F
local signal_E = c.SIGNALS.SIGNAL_E

---@class CsrState
local mt = {}
local mt_proxy = {__index = mt}

---@param entity LuaEntity
---@return CsrState
function _M.create(entity)
    local uid = entity.unit_number --[[@as uint]]

    ---@class CsrState
    local state = {
        ---@type boolean
        enabled = true,
        uid = uid,
        entity = entity,
        cb = entity.get_or_create_control_behavior() --[[@as LuaConstantCombinatorControlBehavior]],
        ---@type ConstantCombinatorParameters[]
        cb_params = nil,
        ---@type boolean,
        zero_signal = true,
        ---@type LuaEntity|nil
        chest = nil,
        ---@type LuaInventory|nil
        chest_inventory = nil,
        ---@type uint
        chest_inventory_slot = 0
    }
    setmetatable(state, mt_proxy)

    state:init_cb_params()
    state:find_chest()
    global.states[uid] = state
    global.ordered[#global.ordered + 1] = state
    state:update()
    return state
end

---@param chest LuaEntity
function _M.update_chests(chest, is_destroyed, is_picker_dolly)
    local bounding_box = chest.bounding_box
    local search_area = area.expand(bounding_box, is_picker_dolly and 2 or 1)
    local combinators = chest.surface.find_entities_filtered{name = c.CSR_NAME, area = search_area}
    for i=1,#combinators do
        local state = global.states[combinators[i].unit_number]
        if not state then goto next_combinator end
        if is_destroyed then
            if chest == state.chest then
                state:remove_chest()
            end
        else
            state:find_chest()
        end
        ::next_combinator::
    end
end

-- CsrState metamethods

-- chest management

local chest_types = {}
for k in pairs(c.CONTAINER_TYPES) do
    chest_types[#chest_types+1] = k
end
---@param self CsrState
function mt:find_chest()
    local entity = self.entity
    if not entity.valid then self:delete() end

    local entity_position = entity.position
    local search_position = util.moveposition({entity_position.x, entity_position.y}, entity.direction, 1)

    local old_chest = self.chest
    self.chest = entity.surface.find_entities_filtered{position = search_position, type = chest_types}[1]
    if old_chest == self.chest then return end
    if self.chest then
        self.chest_inventory = self.chest.get_inventory(defines.inventory.chest)
        self.chest_inventory_slot = #self.chest_inventory
    else
        self.chest_inventory = nil
        self.chest_inventory_slot = nil
    end
end

function mt:remove_chest()
    self.chest = nil
    self.chest_inventory = nil
    self.chest_inventory_slot = nil
end

-- CsrState lifecycle

---@param self CsrState
function mt:delete()
    local uid = self.uid
    local global_ordered = global.ordered
    global.states[uid] = nil
    for i=1,#global_ordered do
        if global_ordered[i].uid == uid then
            table.remove(global_ordered, i)
            return
        end
    end
end

---@param self CsrState
function mt:update()
    if not self.entity.valid then self:delete() end
    if not self.enabled then return end
    if self.chest then
        if not self.chest.valid then
            self:remove_chest()
            self:reset_params()
            return
        end

        local inventory = self.chest_inventory
        local empty_count = inventory.count_empty_stacks()
        local filled_count = self.chest_inventory_slot - empty_count
        local has_changed = false

        for i=1,#self.cb_params do
            local param = self.cb_params[i]
            local count = (i == 1) and filled_count or empty_count
            if param.count ~= count then
                has_changed = true
                param.count = count
                if count == 0 then
                    param.signal = no_signal
                elseif i == 1 then
                    param.signal = signal_F
                elseif i == 2 then
                    param.signal = signal_E
                end
            end
        end

        self.zero_signal = (filled_count == 0 and empty_count == 0) or false
        if has_changed then self.cb.parameters = self.cb_params end
    else
        if not self.zero_signal then
            self:reset_params()
        end
    end
end

-- params management

---@param self CsrState
function mt:init_cb_params()
    self.cb_params = {
        {
            signal = no_signal,
            count = 0,
            index = 1
        },
        {
            signal = no_signal,
            count = 0,
            index = 2
        }
    }
end

---@param self CsrState
function mt:reset_params()
    for i=1,#self.cb_params do
        self.cb_params[i].signal = no_signal
        self.cb_params[i].count = 0
    end
    self.zero_signal = true
    self.cb.parameters = self.cb_params
end

function mt:handle_decons(event)
    if event.name == defines.events.on_marked_for_deconstruction then
        self.enabled = false
    elseif event.name == defines.events.on_cancelled_deconstruction then
        self.enabled = true
    end
end

function _M.on_load()
    for i=1,#global.ordered do
        setmetatable(global.ordered[i], mt_proxy)
    end
end

return _M