local BLE = BeardLibEditor
local BeardLib = BeardLib
local Utils = BLE.Utils

core:module("CoreWorldDefinition")

if not Global.editor_mode or WorldDefinition.is_editor then
	return
end

local WorldDef = class(WorldDefinition)
WorldDefinition = WorldDef
WorldDef.is_editor = true
--blacklist hopefully won't cause issues
function WorldDef:init(params, ...)
	BLE:SetLoadingText("Initializing World Definition")
	self._needed_to_spawn = {}
	self._world_unit_ids = {}
	self._unit_ids = {}
	self._start_id = 100000
	self._name_ids = {}
	self._all_names = {}
	self._statics = {}

	WorldDef.super.init(self, params, ...)
	self._world_data = self:_serialize_to_script(params.file_type, params.file_path)
	self:create("ai")
end

function WorldDef:create(layer, offset)
	local return_data = WorldDef.super.create(self, layer, offset)
	if layer == "statics" or layer == "all" then
		self:spawn_quick(return_data, offset)
	end
	return return_data
end

function WorldDef:spawn_quick(return_data, offset)
	offset = offset or Vector3()
	if self._needed_to_spawn then
		for _, values in ipairs(self._needed_to_spawn) do
			local unit_data = values.unit_data
			if unit_data.delayed_load then
				self._delayed_units[unit_data.unit_id] = {
					unit_data,
					offset,
					return_data
				}
			else
				self:_create_statics_unit(values, offset)
				if unit and return_data then
					table.insert(return_data, unit)
				end
			end
		end
		self._needed_to_spawn = nil
	end
end

function WorldDef:is_world_unit(unit)
	return unit:wire_data() or unit:ai_editor_data()
end

local patrol_point_unit = "core/units/patrol_point/patrol_point"
function WorldDef:set_unit(unit_id, unit, old_continent, new_continent)
	if not unit_id or unit_id <= 0 then
		return
	end

	local statics
	local new_statics
	local move
	local ud = unit:unit_data()
	local wd = unit:wire_data()
	local ad = unit:ai_editor_data()
	if wd then
		statics = managers.worlddefinition._world_data.wires
	elseif ad or unit:name() == patrol_point_unit:id() then
		statics = managers.worlddefinition._world_data.ai
	elseif not ud.instance then
		statics = self._continent_definitions[old_continent]
		new_statics = self._continent_definitions[new_continent]
		if statics then
			statics = statics.statics
		end
		if new_statics then
			new_statics = new_statics.statics
			move = (old_continent ~= new_continent)
		end
	end
	
	local function set_unit(static, statics, key)
		static.unit_data = ud
		static.wire_data = wd
		static.ai_editor_data = ad
		BeardLib.Utils:RemoveAllNumberIndexes(static, true)
		if move then
			--statics[key] = nil
			table.remove(statics, key)
			table.insert(new_statics, static)
		end
	end

	if statics then
		for k, static in pairs(statics) do
			if type(static) == "table" then
				if static.unit_data.unit_id == unit_id or static.unit_data.unit_id == ud.unit_id  then
					set_unit(static, statics, k)
					return
				end
			end
		end
	end
	
	--Failed to find it, now let's go through the slow way.
	managers.editor:Log("Could not find the unit %s, attempting to search for it..", tostring(unit_id))
	local static, statics, key = self:find_unit_slow(unit_id)
	if static then
		managers.editor:Log("Found unit %s", tostring(unit_id))
		set_unit(static, statics, key)
	else
		managers.editor:Error("Unit %s was not found in the continents.", tostring(unit_id))
	end
end

function WorldDef:find_unit_slow(unit_id)
	for _, c in pairs(self._continent_definitions) do
		if c.statics then
			for k, static in pairs(c.statics) do
				if type(static) == "table" and static.unit_data and static.unit_data.unit_id == unit_id then
					return static, c.statics, k
				end
			end
		end
	end
	return nil
end

function WorldDef:get_continent_of_static(unit)
	local ud = unit:unit_data()
	if ud and not unit:wire_data() and not unit:ai_editor_data() then
		return self._continent_definitions[ud.continent]
	end
	return false
end

function WorldDef:insert_name_id(unit)
	local name = unit:unit_data().name
	self._name_ids[name] = self._name_ids[name] or {}
	local name_id = unit:unit_data().name_id
	self._name_ids[name][name_id] = (self._name_ids[name][name_id] or 0) + 1
end

function WorldDef:set_up_name_id(unit)
	local ud = unit:unit_data()
	if ud.name_id ~= "none" then
		self:insert_name_id(unit)
	else
		ud.name_id = self:get_name_id(unit)
	end
	self:set_unit(ud.unit_id, unit, ud.continent, ud.continent)
end

function WorldDef:get_name_id(unit, name)
	local u_name = unit:unit_data().name
	local start_number = 1
	if name then
		local sub_name = name
		for i = string.len(name), 0, -1 do
			local sub = string.sub(name, i, string.len(name))
			sub_name = string.sub(name, 0, i)
			if tonumber(sub) and tonumber(sub) < 10000 then
				start_number = tonumber(sub)
			else
				break
			end
		end
		name = sub_name
	else
		local reverse = string.reverse(u_name)
		local i = string.find(reverse, "/")
		name = string.reverse(string.sub(reverse, 0, i - 1))
		name = name .. "_"
	end
	self._name_ids[u_name] = self._name_ids[u_name] or {}
	local t = self._name_ids[u_name]
	for i = start_number, 10000 do
		i = (i < 10 and "00" or i < 100 and "0" or "") .. i
		local name_id = name .. i
		if not t[name_id] then
			t[name_id] = 1
			return name_id
		end
	end
end

function WorldDef:remove_name_id(unit)
	local unit_name = unit:unit_data().name
	local name_id = unit:unit_data().name_id
	if self._name_ids[unit_name] and self._name_ids[unit_name][name_id] then
		self._name_ids[unit_name][name_id] = self._name_ids[unit_name][name_id] - 1
		if self._name_ids[unit_name][name_id] == 0 then
			self._name_ids[unit_name][name_id] = nil
		end
	end
end

function WorldDef:set_name_id(unit, name_id)
	local unit_name = unit:unit_data().name
	if self._name_ids[unit_name] then
		self:remove_name_id(unit)
		self._name_ids[unit_name][name_id] = (self._name_ids[unit_name][name_id] or 0) + 1
		unit:unit_data().name_id = name_id
	end
end

function WorldDef:get_unit_number(name)
	local i = 1
	for _, unit in pairs(World:find_units_quick("all")) do
		if unit:unit_data() and unit:unit_data().name == name then
			i = i + 1
		end
	end
	return i
end

function WorldDef:init_done()
	managers.editor:load_continents(self._continent_definitions)
	local i = 1 
	for continent, data in pairs(self._continent_definitions) do
		if self._continents[continent].base_id then
			i = math.max(self._start_id / self._continents[continent].base_id)
		end
	end
	for continent, data in pairs(self._continent_definitions) do
		if not self._continents[continent].base_id then
			self._continents[continent].base_id = self._start_id * i
			i = i + 1			
		end
	end
	BLE:SetLoadingText("Done Initializing World Definition")
	self._init_done = true
end

--currently I'm not sure if to check using world or world defintion for assets manager.
function WorldDef:check_names()
	local names = {}
	for _, unit in pairs(World:find_units_quick("all")) do
		local ud = unit:unit_data()
		local name = ud and ud.name
		if name then
			names[name] = names[name] or 0
			names[name] = names[name] + 1
		end
	end
	
	self._all_names = names
end

function WorldDef:delete_unit(unit, keep_links)
	if not unit then
		return
	end
	
	local ud = unit:unit_data()
	local unit_id = ud.unit_id
	
	if not unit_id then
		return
	end

	if unit_id <= 0 then
		managers.editor:Error("Attempted to delete a unit with invalid unit id")
		return
	end
	
	
	local name_id = ud.name_id
	local continent_name = ud.continent
	local statics
	if unit:wire_data() then
		statics = self._world_data.wires
	elseif unit:ai_editor_data() or unit == patrol_point_unit:id() then
		statics = self._world_data.ai
	elseif not ud.instance then
		statics = self._continent_definitions[continent_name]
		statics = statics and statics.statics
	end
	if not keep_links then
		self:remove_name_id(unit)
		self:RemoveUnitID(unit, continent_name)
		managers.mission:delete_links(unit_id, Utils.LinkTypes.Unit)
		for _, portal in pairs(_G.clone(managers.portal:unit_groups())) do
			portal._ids[unit_id] = nil
		end
	end

	if statics then
		for k, static in pairs(statics) do
			if static.unit_data and (static.unit_data.unit_id == unit_id) then
				table.remove(statics, k)
				return
			end
		end
	else
		managers.editor:Error("Attempted to delete a unit that doesn't belong to any continent!")
	end

	managers.editor:Log("Could not find the unit %s, attempting to search for it..", tostring(unit_id))

	local static, statics, key = self:find_unit_slow(unit_id)
	if static then
		managers.editor:Log("Found unit %s, deleting...", tostring(unit_id))
		table.remove(statics, key)
	end

	Utils:GetLayer("portal"):refresh()
end

function WorldDef:add_unit(unit)
	local statics
	local ud = unit:unit_data()
	if unit:wire_data() then
		managers.worlddefinition._world_data.wires = managers.worlddefinition._world_data.wires or {}
		statics = managers.worlddefinition._world_data.wires
	elseif unit:ai_editor_data() or unit:name() == patrol_point_unit:id() then
		managers.worlddefinition._world_data.ai = managers.worlddefinition._world_data.ai or {}
		statics = managers.worlddefinition._world_data.ai
	else
		statics = self._continent_definitions[ud.continent].statics
	end
	if statics then
		local static = {
			unit_data = unit:unit_data(),
			wire_data = unit:wire_data(),
			ai_editor_data = unit:ai_editor_data(),
		}
		self._statics[unit:key()] = static
		table.insert(statics, static)
	end
end

function WorldDef:_set_only_visible_in_editor(unit, data)
	if unit:unit_data().only_visible_in_editor or unit:unit_data().only_exists_in_editor then
		unit:set_visible(BLE.Options:GetOption("Map/EditorUnits").value)
	end
end

function WorldDef:_setup_disable_on_ai_graph(unit, data)
	if not data.disable_on_ai_graph then
		return
	end
	unit:unit_data().disable_on_ai_graph = data.disable_on_ai_graph
end

function WorldDef:_create_ai_editor_unit(data, offset)
	local unit = self:_create_statics_unit(data, offset)
	if unit and data.ai_editor_data then
		for name, value in pairs(data.ai_editor_data) do
			unit:ai_editor_data()[name] = value
		end
	end
	return unit
end

function WorldDef:create_unit(data, type)		
	local offset = Vector3()
	local unit 
	if type == Idstring("wire") then
		unit = self:_create_wires_unit(data, offset)
	elseif type == Idstring("ai") then
		unit = self:_create_ai_editor_unit(data, offset)
	else
		unit = self:_create_statics_unit(data, offset)
	end 
	if unit then
		self:add_unit(unit)
	end
	return unit
end

function WorldDef:_setup_editor_unit_data(unit, data)		
	local ud = unit:unit_data()
	ud.name_id = data.name_id
	ud.name = data.name

	ud.continent = data.continent
	ud.position = unit:position()
	ud.rotation = unit:rotation()
	ud.local_pos = data.local_pos or Vector3()
	ud.local_rot = data.local_rot or Rotation()

	if not data.brush_unit then
		data.projection_light = data.projection_light or BLE.Utils:HasAnyProjectionLight(unit)
		data.lights = data.lights or BLE.Utils:LightData(unit)
		data.triggers = data.triggers or BLE.Utils:TriggersData(unit)
		data.editable_gui = data.editable_gui or BLE.Utils:EditableGuiData(unit)
		data.ladder = data.ladder or BLE.Utils:LadderData(unit)
		data.zipline = data.zipline or BLE.Utils:ZiplineData(unit)
		data.cubemap = data.cubemap or BLE.Utils:CubemapData(unit)
	
		BeardLib.Utils:RemoveAllNumberIndexes(ud, true)
		ud.projection_lights = data.projection_lights
		ud.projection_textures = data.projection_textures
		ud.lights = data.lights
		ud.triggers = data.triggers
		ud.editable_gui = data.editable_gui	
		ud.ladder = data.ladder
		ud.zipline = data.zipline
		ud.hide_on_projection_light = data.hide_on_projection_light
		ud.disable_on_ai_graph = data.disable_on_ai_graph
		ud.disable_shadows = data.disable_shadows
		ud.disable_collision = data.disable_collision
		ud.hide_on_projection_light = data.hide_on_projection_light
		ud.override_texture = data.override_texture
		ud.cubemap = data.cubemap
		ud.material_variation = data.material_variation

		local wd = unit:wire_data()
		if wd then
			local target = unit:get_object(Idstring("a_target"))
			wd.target_pos = target:position()
			wd.target_rot = target:rotation()
		end
	else
		ud.brush_unit = true
	end

	self:set_up_name_id(unit)
end

function WorldDef:make_unit(data, offset)
	local name = data.name
	if table.has(self._replace_names, name) then
		name = self._replace_names[name]
	end
	if not name then
		return nil
	end
	if not is_editor and not Network:is_server() then
		local network_sync = PackageManager:unit_data(name:id()):network_sync()
		if network_sync ~= "none" and network_sync ~= "client" then
			return
		end
	end
	local unit
	if not Global.editor_safe_mode then
		if Global.editor_log_on_spawn then
			log("Attempt spawn - " .. tostring(name))
		end

		if MassUnitManager:can_spawn_unit(Idstring(name)) then
			unit = MassUnitManager:spawn_unit(Idstring(name), data.position + offset, data.rotation)
		else
			unit = CoreUnit.safe_spawn_unit(name, data.position, data.rotation)		
		end
	end
	local not_allowed = {
		["core/units/nav_surface/nav_surface"] = true,
		["units/dev_tools/level_tools/ai_coverpoint"] = true
	}
	if not data.instance and not not_allowed[name] then
		self._all_names[name] = self._all_names[name] or 0
		self._all_names[name] = self._all_names[name] + 1
	end
	if alive(unit) then	
		self:assign_unit_data(unit, data)
		self._statics[unit:key()] = data
	end
	return unit
end

function WorldDef:assign_unit_data(unit, data)
	if not unit:unit_data() then
		BLE:log("Unit with name " .. tostring(unit:name()) .. " doesn't have Unit Data!")
		return 
	end

	unit:unit_data().instance = data.instance
	self:_setup_editor_unit_data(unit, data)
	self:_setup_unit_id(unit, data)
	if unit:unit_data().helper_type and unit:unit_data().helper_type ~= "none" then
		managers.helper_unit:add_unit(unit, unit:unit_data().helper_type)
	end
	self:_setup_lights(unit, data)
	self:_setup_variations(unit, data)
	self:_setup_editable_gui(unit, data)
	self:add_trigger_sequence(unit, data.triggers)
	self:_set_only_visible_in_editor(unit, data)
	self:_setup_cutscene_actor(unit, data)
	self:_setup_disable_shadow(unit, data)
	self:_setup_hide_on_projection_light(unit, data)
	self:_setup_disable_on_ai_graph(unit, data)
	self:_add_to_portal(unit, data)
	self:_setup_projection_light(unit, data)
	self:_setup_ladder(unit, data)
	self:_setup_zipline(unit, data)
	self:_project_assign_unit_data(unit, data)
	self:_setup_cubemaps(unit, data)
end

function WorldDef:_setup_unit_id(unit, data)
	local ud = unit:unit_data()
	ud.unit_id = tonumber(data.unit_id)
	unit:set_editor_id(ud.unit_id)
	self._all_units[ud.unit_id] = unit
	if self:is_world_unit(unit) then
		self._world_unit_ids[ud.unit_id] = true
	elseif data.continent then
		self._unit_ids[data.continent] = self._unit_ids[data.continent] or {}
		self._unit_ids[data.continent][ud.unit_id] = true
		self:use_me(unit, Application:editor())
	end
end

function WorldDef:ResetUnitID(unit, continent_name)
	local ud = unit:unit_data()
	self:RemoveUnitID(unit, continent_name or ud.continent)
	local is_world = self:is_world_unit(unit)
	local continent = ud.continent
	local unit_id = self:GetNewUnitID(continent, nil, is_world)
	
	for _, link in pairs(managers.mission:get_links_paths_new(ud.unit_id, Utils.LinkTypes.Unit)) do
		link.tbl[link.key] = unit_id
	end

	for _, portal in pairs(_G.clone(managers.portal:unit_groups())) do
		if portal._ids[ud.unit_id] then
			portal._ids[ud.unit_id] = nil
			portal._ids[unit_id] = true
		end
	end
	
	ud.unit_id = tonumber(unit_id)
	unit:set_editor_id(unit_id)
	
	if is_world then
		self._world_unit_ids[unit_id] = true
	elseif continent then
		self._unit_ids[continent] = self._unit_ids[continent] or {}
		self._unit_ids[continent][unit_id] = true
	end
	self._all_units[unit_id] = unit
	Utils:GetLayer("portal"):refresh()
end

function WorldDef:RemoveUnitID(unit, continent_name)
	local unit_id = unit:unit_data().unit_id
	if self:is_world_unit(unit) then
		self._world_unit_ids[unit_id] = nil
	elseif continent_name then
		self._unit_ids[continent_name][unit_id] = nil
	end
	self._all_units[unit_id] = nil
end

function WorldDef:GetNewUnitID(continent, t, is_world)
    if continent then       
        self._unit_ids[continent] = self._unit_ids[continent] or {}
        local tbl = self._unit_ids[continent]
        local i = self._continents[continent] and self._continents[continent].base_id
        if is_world or t and (t:id() == Idstring("wire") or t:id() == Idstring("ai")) then
            tbl = self._world_unit_ids
            i = 1
        end
        if not i then
            BLE:log("[ERROR] Something went wrong in GetNewUnitID...")
        end
        i = i or 1
        while tbl[i] do
            i = i + 1
        end
        tbl[i] = true
        return i
    else
        BLE:log("[ERROR] continent needed for unit id")
    end
end

Hooks:PostHook(WorldDef, "_create_sounds", "EditorCreateSounds", function(self, data)
	local ext, path = "world_sounds", self:world_dir() .. data.file
	self._sound_data = DB:has(ext, path) and self:_serialize_to_script(ext, path) or {}
end)

Hooks:PostHook(WorldDef, "_create_world_cameras", "EditorCreateWorldCamera", function(self, data)
	local ext, path = "world_cameras", self:world_dir() .. data.file
	self._world_cameras_data = DB:has(ext, path) and self:_serialize_to_script(ext, path) or {}
end)

function WorldDef:_continent_editor_only(data) return false end

function WorldDef:parse_continents(node, t)
	local path = self:world_dir() .. self._definition.world_data.continents_file
	if not DB:has("continents", path) then
		Application:error("Continent file didn't exist " .. path .. ").")
		return
	end
	self._continents = self:_serialize_to_script("continents", path)
	self._continents._meta = nil
	local s = "Loading Package: %s (%d/%d)"
	local i = 1
	BLE:SetLoadingText("Loading Packages")
	local total = table.size(self._continents)
	for name, data in pairs(self._continents) do
		if not self:_continent_editor_only(data) then
			if not self._excluded_continents[name] then
				local init_path = self:world_dir() .. name .. "/" .. name .. "_init"
				local path = self:world_dir() .. name .. "/" .. name
				BLE:SetLoadingText(string.format(s, path, i, total))
				self:_load_continent_init_package(init_path)
				self:_load_continent_package(path)
				if DB:has("continent", path) then
					self._continent_definitions[name] = self:_serialize_to_script("continent", path)
				else
					Application:error("Continent file " .. path .. ".continent doesnt exist.")
				end
			end
		else
			self._excluded_continents[name] = true
		end
		i = i + 1
	end
	BLE:SetLoadingText(string.format(s, "Done", total, total))
	self:_insert_instances()
end

function WorldDef:prepare_for_spawn_instance(instance)
	self:try_loading_custom_instance(instance.folder)
	local package_data = managers.world_instance:packages_by_instance(instance)
	if self._init_done then
		PackageManager:set_resource_loaded_clbk(Idstring("unit"), nil)
	else
		local s = "Loading Instance Package: %s"
		BLE:SetLoadingText(string.format(s, package_data.package))
	end
	self:_load_continent_init_package(package_data.init_package)
	self:_load_continent_package(package_data.package)
	
	local prepared_unit_data = managers.world_instance:prepare_unit_data(instance, self._continents[instance.continent])
	if prepared_unit_data.statics then
		self._needed_to_spawn = self._needed_to_spawn or {}
		for _, static in ipairs(prepared_unit_data.statics) do
			table.insert(self._needed_to_spawn, static)
		end
	end
 
	if self._init_done then
		self:spawn_quick()
		PackageManager:set_resource_loaded_clbk(Idstring("unit"), _G.ClassClbk(managers.sequence, "clbk_pkg_manager_unit_loaded"))
	end
end

function WorldDef:_insert_instances()
	BLE:SetLoadingText("Loading Instances Packages")
	for name, data in pairs(self._continent_definitions) do
		if data.instances then
			for i, instance in ipairs(data.instances) do
				self:prepare_for_spawn_instance(instance)
			end
		end
	end
end

if Unit then
	--Hacky but should work..
	local unit_datas = {}
	local orig = Unit.unit_data
	function Unit:unit_data(...)
		local data = orig(self, ...)
		if not data and unit_datas[self:key()] then
			return unit_datas[self:key()]
		end
		return data
	end
	
	function Unit:force_add_unit_data(...)
		if self:unit_data() then
			return
		end
		unit_data[self:key()] = unit_data[self:key()] or {}
	end
end