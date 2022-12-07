local c = require("constants")
local combinator = require("script/combinator")

local max_update_per_tick = settings.global[c.UPDATE_RATE_NAME].value

-- upvalues
local global_ordered, total, cached_total, interval, upper_bound

---@param event EventData.on_tick
local function on_tick(event)
    total = #global_ordered
    if total == 0 then return end
    if total ~= cached_total then
        cached_total = total
        upper_bound = math.min(total, max_update_per_tick)
        if upper_bound > 1 then
            interval = math.floor(total / upper_bound)
        else
            interval = 0
        end
    end
    for i = 1, upper_bound do
        global_ordered[(event.tick + interval * i) % total + 1]:update()
    end
end
script.on_event(defines.events.on_tick, on_tick)

local function on_load()
    combinator.on_load()
    global_ordered = global.ordered

    if remote.interfaces["PickerDollies"] then
        script.on_event(remote.call('PickerDollies', 'dolly_moved_entity_id'), function(event)
            local entity = event.moved_entity
            if not entity.valid then return end
            if entity.name == c.CSR_NAME then
                local state = global.states[entity.unit_number]
                state:find_chest()
            elseif c.CONTAINER_TYPES[entity.type] then
                combinator.update_chests(entity, nil, true)
            end
        end)
    end
end
script.on_load(on_load)
script.on_init(function()
    global.states = {}
    global.ordered = {}
    on_load()
end)
script.on_configuration_changed(function()
    for _, force in pairs(game.forces) do
		if force.technologies['circuit-network'].researched then
			force.recipes[c.CSR_NAME].enabled = true
		end
	end
end)

---@param event EventData.on_built_entity | EventData.on_robot_built_entity | EventData.on_entity_cloned | EventData.script_raised_built | EventData.script_raised_revive
local function on_built(event)
    local entity = event.created_entity or event.destination or event.entity
    if not entity then return end
    if entity.name == c.CSR_NAME then
        local state = combinator.create(entity)
        local is_blueprint = event.stack and event.stack.is_blueprint
        if is_blueprint then
            state:reset_params()
        end
    elseif c.CONTAINER_TYPES[entity.type] then
        combinator.update_chests(entity)
    end
end

local built_destroy_filter = {{filter = "name", name = c.CSR_NAME}}
for k in pairs(c.CONTAINER_TYPES) do
    table.insert(built_destroy_filter, {filter = "type", type = k})
end
script.on_event(defines.events.on_built_entity, on_built, built_destroy_filter)
script.on_event(defines.events.on_robot_built_entity, on_built, built_destroy_filter)
script.on_event(defines.events.on_entity_cloned, on_built, built_destroy_filter)
script.on_event(defines.events.script_raised_built, on_built, built_destroy_filter)
script.on_event(defines.events.script_raised_revive, on_built, built_destroy_filter)

---@param event EventData.on_entity_died | EventData.on_player_mined_entity | EventData.on_robot_mined_entity | EventData.script_raised_destroy
local function on_destroy(event)
    local entity = event.entity
	if not (entity and entity.valid) then return end
    if entity.name == c.CSR_NAME then
        local state = global.states[entity.unit_number] --[[@as CsrState]]
        if state then state:delete() end
    elseif c.CONTAINER_TYPES[entity.type] then
        combinator.update_chests(entity, true)
    end
end
script.on_event(defines.events.on_entity_died, on_destroy, built_destroy_filter)
script.on_event(defines.events.on_player_mined_entity, on_destroy, built_destroy_filter)
script.on_event(defines.events.on_robot_mined_entity, on_destroy, built_destroy_filter)
script.on_event(defines.events.script_raised_destroy, on_destroy, built_destroy_filter)

---@param event EventData.on_player_rotated_entity
local function on_rotate_combinator(event)
    local entity = event.entity
    if not (entity and entity.valid) then return end
    if entity.name == c.CSR_NAME then
        local state = global.states[entity.unit_number]
        if state then state:find_chest() end
    end
end
script.on_event(defines.events.on_player_rotated_entity, on_rotate_combinator)

---@param event EventData.on_marked_for_deconstruction | EventData.on_cancelled_deconstruction
local function handle_decons(event)
    local entity = event.entity
    if not (entity and entity.valid) then return end
    if entity.name == c.CSR_NAME then
        local state = global.states[entity.unit_number]
        if state then state:handle_decons(event) end
    end
end
script.on_event(defines.events.on_marked_for_deconstruction, handle_decons, {{filter = "name", name = c.CSR_NAME}})
script.on_event(defines.events.on_cancelled_deconstruction, handle_decons, {{filter = "name", name = c.CSR_NAME}})

script.on_event(defines.events.on_runtime_mod_setting_changed, function(event)
	if event.setting == c.UPDATE_RATE_NAME then
		max_update_per_tick = settings.global[c.UPDATE_RATE_NAME].value
        cached_total = -1
    end
end)