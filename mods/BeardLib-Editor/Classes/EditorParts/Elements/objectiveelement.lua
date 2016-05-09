EditorObjective = EditorObjective or class(MissionScriptEditor)
EditorObjective.INSTANCE_VAR_NAMES = {
	{type = "objective", value = "objective"},
	{type = "number", value = "amount"}
}
function EditorObjective:init(unit)
	EditorObjective.super.init(self, unit)
end

function EditorObjective:create_element()
	self.super.create_element(self)
	self._element.class = "ElementObjective"
	self._element.values.state = "complete_and_activate"
	self._element.values.objective = "none"
	self._element.values.sub_objective = "none"
	self._element.values.amount = 0	
end

function EditorObjective:update_sub_objectives()
	local sub_objectives = table.list_add({"none"}, managers.objectives:sub_objectives_by_name(self._element.values.objective))
	self._element.values.sub_objective = "none"
	self._sub_objective:SetItems(sub_objectives)
	self._sub_objective:SetValue(table.get_key(sub_objective ,self._element.values.sub_objective))
end
function EditorObjective:set_element_data(params, ...)
	EditorObjective.super.set_element_data(self, params, ...)
	if params.value == "objective" then
		self:update_sub_objectives()
	end
end
function EditorObjective:_build_panel()
	self:_create_panel()
	self:_build_value_combobox("state", {
		"activate",
		"complete",
		"update",
		"remove",
		"complete_and_activate",
		"remove_and_activate"
	})
	self:_build_value_combobox("objective", table.list_add({"none"}, managers.objectives:objectives_by_name()))
	local options = self._element.values.objective ~= "none" and managers.objectives:sub_objectives_by_name(self._element.values.objective) or {}
	self._sub_objective = self:_build_value_combobox("sub_objective", table.list_add({"none"}, options), "Select a sub objective from the combobox (if availible)")
	self:_build_value_number("amount", {
		min = 0,
		max = 100
	}, "Overrides objective amount counter with this value.")
	self:add_help_text("State complete_and_activate will complete any previous objective and activate the selected objective. Note that it might not function well with objectives using amount")
end
