obs = obslua
gversion = 0.5
gdebug = 0

gcur_seconds = 0
gtime_text_source = ""
gprogram_text_source = ""
gpreview_text_source = ""
gnote_target = ""
gspacer = ""
gnote_prefix = ""


----------------------------------------------------------
-- Formatted logging messages
local function logIt(name, msg)

	if msg ~= nil then
		msg = " > " .. tostring(msg)
	else
		msg = ""
	end

	if gdebug == 1 then
		obs.script_log(obs.LOG_gdebug, name .. msg)
	end
end

----------------------------------------------------------
function dumpSortedAttrs(obj, label)
    print("### Dumping " .. label)
    for _, key in pairs(sortedKeys(obj)) do
        print(label .. ":  " .. type(obj[key]) .. ": " .. key .. " = " .. tostring(obj[key]))
    end
end

----------------------------------------------------------
function updateTextSource(editSource, msg_text)
	--logIt('in updateTextSource', msg_text)

	local source = obs.obs_get_source_by_name(editSource)
    --logIt('   editSource', editSource)
    --logIt('   source', source)

	if source ~= nil then
		local settings = obs.obs_data_create()
		obs.obs_data_set_string(settings, "text", msg_text)
		obs.obs_source_update(source, settings)

		obs.obs_data_release(settings)
		obs.obs_source_release(source)
	end

end

----------------------------------------------------------
function getTimeText()
	--logIt('in setTimeText')

	local seconds 			= math.floor(gcur_seconds % 60)
	local total_minutes	= math.floor(gcur_seconds / 60)
	local minutes				= math.floor(total_minutes % 60)
	--local hours					= math.floor(total_minutes / 60)
	local text					= string.format("%02d:%02d", minutes, seconds)
	--local text					= string.format("%02:%02d:%02d", hours, minutes, seconds)

	return text
end

----------------------------------------------------------
function timer_callback()
	--logIt('in timer_callback')

	gcur_seconds = gcur_seconds + 1
	local msg_text = getTimeText()

	updateTextSource(gtime_text_source, msg_text)
end

----------------------------------------------------------
-- Check if the source name starts with the user-defined Note prefix
function noteCheck(str)
   return str:sub(1, #gnote_prefix) == gnote_prefix
end

----------------------------------------------------------
-- Update the user-defined Note Display source
function updateNote()
	--logIt('updateNote', "")
	sleep(.01)
	updateTextSource(gnote_target, "")
	local sources = obs.obs_enum_sources()

	if sources ~= nil then
		for _, source in ipairs(sources) do
			if obs.obs_source_active(source) then
				local name = obs.obs_source_get_name(source)
				logIt('updateNote:name', name)

				if noteCheck(name) then
					source_id = obs.obs_source_get_unversioned_id(source)

					if source_id == "text_gdiplus" or source_id == "text_ft2_source" then
						local settings = obs.obs_source_get_settings(source)
						msg_text = obs.obs_data_get_string(settings, "text")
						updateTextSource(gnote_target, msg_text)
						noteFound = true
						logIt('updateNote:text', msg_text)
						obs.obs_data_release(settings)
						break
					end
				end

			end
		end
	end

	obs.source_list_release(sources)
end

function sleep (a)
    local sec = tonumber(os.clock() + a);
    while (os.clock() < sec) do
    end
end

----------------------------------------------------------
function onFrontendEvent(event)
	logIt('in onFrontendEvent', event)

	if event == obs.OBS_FRONTEND_EVENT_SCENE_CHANGED then --8
		local sceneSrc = obs.obs_frontend_get_current_scene()
		local scene = obs.obs_source_get_name(sceneSrc)
		obs.obs_source_release(sceneSrc)
		logIt('    current_scene', scene)

		gcur_seconds = 0
		local msg_text = getTimeText()
		updateTextSource(gtime_text_source, msg_text)
		updateTextSource(gprogram_text_source, scene)
		updateNote()

	elseif event == obs.OBS_FRONTEND_EVENT_PREVIEW_SCENE_CHANGED then --24
		local sceneSrc = obs.obs_frontend_get_current_preview_scene()
		local scene = obs.obs_source_get_name(sceneSrc)
		obs.obs_source_release(sceneSrc)
		logIt('    preview_scene', scene)

		updateTextSource(gpreview_text_source, scene)
	end

end

----------------------------------------------------------
-- Defines properties that the user can change for the entire script module itself
function script_properties()
	logIt('in script_properties')

	local props = obs.obs_properties_create()
	local time_s = obs.obs_properties_add_list(props, "gtime_text_source", "Timer ", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
	local prog_s = obs.obs_properties_add_list(props, "gprogram_text_source", "Program ", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
	local prev_s = obs.obs_properties_add_list(props, "gpreview_text_source", "Preview ", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
	local prefix_s = obs.obs_properties_add_text(props, "gnote_prefix", "Note Source prefix ", obs.OBS_TEXT_DEFAULT)
	local note_s = obs.obs_properties_add_list(props, "gnote_target", "Note Display ", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)

	local sources = obs.obs_enum_sources()
	if sources ~= nil then
		for _, s in ipairs(sources) do
			source_id = obs.obs_source_get_unversioned_id(s)
			if source_id == "text_gdiplus" or source_id == "text_ft2_source" then
				local name = obs.obs_source_get_name(s)

				obs.obs_property_list_add_string(time_s, name, name)
				obs.obs_property_list_add_string(prog_s, name, name)
				obs.obs_property_list_add_string(prev_s, name, name)
				obs.obs_property_list_add_string(note_s, name, name)
			end
		end
	end

	obs.source_list_release(sources)
	return props
end

-- Define the Description in the Scripts window
function script_description()
	msg = string.format("Set text sources to react when Program or Preview scenes are changed (ver: %s)", tostring(gversion))
	return msg
end

function script_update(settings)
	logIt('in script_update')

	gtime_text_source			= obs.obs_data_get_string(settings, "gtime_text_source")
	gprogram_text_source	= obs.obs_data_get_string(settings, "gprogram_text_source")
	gpreview_text_source	= obs.obs_data_get_string(settings, "gpreview_text_source")
	gnote_prefix					= obs.obs_data_get_string(settings, "gnote_prefix")
	gnote_target					= obs.obs_data_get_string(settings, "gnote_target")
end

function script_load(settings)
	logIt('--------\nin script_load')

	obs.timer_add(timer_callback, 1000)

	obs.obs_frontend_add_event_callback(onFrontendEvent)
	onFrontendEvent(obs.OBS_FRONTEND_EVENT_SCENE_CHANGED)
end

function script_unload()
	timer_remove(timer_callback)
end
