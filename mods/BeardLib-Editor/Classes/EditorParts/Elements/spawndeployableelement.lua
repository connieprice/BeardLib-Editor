EditorSpawnDeployable = EditorSpawnDeployable or class(MissionScriptEditor)
function EditorSpawnDeployable:init(unit)
	MissionScriptEditor.init(self, unit)
end
function EditorSpawnDeployable:create_element()
	self.super.create_element(self)
	self._element.class = "ElementSpawnDeployable"
	self._element.values.deployable_id = "none"
end
function EditorSpawnDeployable:_build_panel()
	self:_create_panel()
	self:_build_value_combobox("deployable_id", {
		"none",
		"doctor_bag",
		"ammo_bag",
		"grenade_crate",
		"bodybags_bag"
	}, "Select a deployable_id to be spawned.")
end
