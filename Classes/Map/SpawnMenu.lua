SpawnMenu = SpawnMenu or class(EditorPart)
function SpawnMenu:init(parent, menu)
    self.super.init(self, parent, menu, "Spawn Menu", {make_tabs = ClassClbk(self, "make_tabs"), scrollbar = false})
    self._tabs:s_btn("Unit", ClassClbk(self, "open_tab"), {border_bottom = true})
    self._tabs:s_btn("Element", ClassClbk(self, "open_tab"))
    self._tabs:s_btn("Instance", ClassClbk(self, "open_tab"))
    self._tabs:s_btn("Prefab", ClassClbk(self, "open_tab"))
    self._tab_classes = {
        Unit = UnitSpawnList:new(self),
        Element = ElementSpawnList:new(self),
        Instance = InstanceSpawnList:new(self),
        Prefab = PrefabSpawnList:new(self),
    }
    self._tab_classes.Unit:set_visible(true)
end

function SpawnMenu:make_tabs()
    
end

function SpawnMenu:open_tab(item)
    for name, tab in pairs(self._tab_classes) do
        tab:set_visible(name == item.name)
    end
    for _, tab in pairs(self._tabs:Items()) do
        tab:SetBorder({bottom = tab == item})
    end
end

function SpawnMenu:begin_spawning_element(element)
    self._currently_spawning_element = element
    self:begin_spawning("units/mission_element/element")
end

function SpawnMenu:begin_spawning(unit)
    if not PackageManager:has(Idstring("unit"), unit:id()) then
        return
    end
    self._currently_spawning = unit
    self:remove_dummy_unit()
    if self._parent._spawn_position then
        self._dummy_spawn_unit = World:spawn_unit(unit:id(), self._parent._spawn_position)
    end
    self:GetPart("menu"):set_tabs_enabled(false)
    self:SetTitle("Press: LMB to spawn, RMB to cancel")
end

function SpawnMenu:get_dummy_unit()
    return self._dummy_spawn_unit
end

function SpawnMenu:mouse_pressed(button, x, y)
    if not self:enabled() then
        return
    end

    if button == Idstring("0") then
        if self._currently_spawning_element then
            self._do_switch = true
            self._parent:add_element(self._currently_spawning_element)
            return true
        elseif self._currently_spawning then
            self._do_switch = true
            local unit = self._parent:SpawnUnit(self._currently_spawning)
            self:GetPart("undo_handler"):SaveUnitValues({unit}, "spawn")
            return true
        end
    elseif button == Idstring("1") and (self._currently_spawning or self._currently_spawning_element) then
        self:remove_dummy_unit()
        self._currently_spawning = nil
        self._currently_spawning_element = nil
        self:SetTitle()
        self:GetPart("menu"):set_tabs_enabled(true)
        if self._do_switch and self:Val("SelectAndGoToMenu") then
            self:GetPart("static"):Switch()
            self._do_switch = false
        end
        return true
    end
    return false
end

function SpawnMenu:remove_dummy_unit()
    local unit = self._dummy_spawn_unit
    if alive(unit) then
        unit:set_enabled(false)
        unit:set_slot(0)
        World:delete_unit(unit)
    end
end

function SpawnMenu:is_spawning()
    return self._currently_spawning_element or self._currently_spawning
end

function SpawnMenu:update(t, dt)
    self.super.update(self, t, dt)

    if alive(self._dummy_spawn_unit) then
        self._dummy_spawn_unit:set_position(self._parent._spawn_position)
        if self._parent._current_rot then
            self._dummy_spawn_unit:set_rotation(self._parent._current_rot)
        end
        Application:draw_line(self._parent._spawn_position - Vector3(0, 0, 2000), self._parent._spawn_position + Vector3(0, 0, 2000), 0, 1, 0)
        Application:draw_sphere(self._parent._spawn_position, 30, 0, 1, 0)
    end
end

function SpawnMenu:SpawnInstance(instance, instance_data, spawn)
    instance_data = instance_data or {}
    local continent = managers.worlddefinition._continent_definitions[self._parent._current_continent]
    if continent then
        continent.instances = continent.instances or {}
        local instance_name = instance_data.name
        if not instance_name then
            instance_name = Path:GetFileName(Path:GetDirectory(instance)).."_"
            local instance_names = managers.world_instance:instance_names()
            local i = 1
            while(table.contains(instance_names, instance_name .. (i < 10 and "00" or i < 100 and "0" or "") .. i)) do
                i = i + 1
            end
            instance_name = instance_name .. (i < 10 and "00" or i < 100 and "0" or "") .. i
        end

        local module_data = BeardLib.managers.MapFramework._loaded_instances[instance]
        local index_size = module_data and module_data._config.index_size or self:Val("InstanceIndexSize")

        if not managers.mission:script(instance_data.script) then
            instance_data.script = nil
        end

        instance_data.start_index = nil
        local instance = table.merge({
            continent = self._parent._current_continent,
            name = instance_name,
            folder = instance,
            position = self._parent:cam_spawn_pos(),
            rotation = Rotation(),
            script = self._parent._current_script,
            index_size = index_size,
            start_index = managers.world_instance:get_safe_start_index(index_size, self._parent._current_continent)
        }, instance_data)
        table.insert(continent.instances, instance)
        for _, mission in pairs(managers.mission._missions) do
            if mission[instance.script] then
                table.insert(mission[instance.script].instances, instance_name)
                break
            end
        end
        managers.world_instance:add_instance_data(instance)
        managers.worlddefinition:prepare_for_spawn_instance(instance)
        local data = managers.world_instance:get_instance_data_by_name(instance_name)
        local prepare_mission_data = managers.world_instance:prepare_mission_data_by_name(instance_name)
        local script = managers.mission._scripts[instance.script]
        if not data.mission_placed then
            script:create_instance_elements(prepare_mission_data)
        else
            script:_preload_instance_class_elements(prepare_mission_data)
        end

        local unit = FakeObject:new(data, {instance = true})
        if spawn then
            self:GetPart("static"):set_selected_unit(unit)
        end
        return unit
    end

end