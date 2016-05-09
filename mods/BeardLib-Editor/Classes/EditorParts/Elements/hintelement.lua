EditorHint = EditorHint or class(MissionScriptEditor)
function EditorHint:init(unit)
	EditorHint.super.init(self, unit)
end

function EditorHint:create_element()
	self.super.create_element(self)
	self._element.class = "ElementHint"
	self._element.values.hint_id = "none" 
end

function EditorHint:_set_text()
	local hint = managers.hint:hint(self._element.values.hint_id)
	self._text:SetText("Text: " .. (hint and managers.localization:text(hint.text_id) or "none"))
end
function EditorHint:set_element_data(params, ...)
	EditorHint.super.set_element_data(self, params, ...)
	if params.value == "hint_id" then
		self:_set_text()
	end
end
function EditorHint:_build_panel()
	self:_create_panel()
	self:_build_value_combobox("hint_id", table.list_add({"none"}, managers.hint:ids()), "Select a text id from the combobox")
	self._text = self:_build_text("")
	self:_set_text()
end
