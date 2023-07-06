extends Node

var note_controller: Node2D
var key_controller: Node2D

var indicator_container: Node2D
var guideline_container: Node2D
var note_container: Node2D
var line_center: Node2D

var animations_track: Node2D
var oneshot_sound_track: Node2D
var shutter_track: Node2D

var inc_scale: float
var note_creation_timestamp: float

var marquee_point_a: float = -1
var marquee_point_b: float = -1

func create_note(key: int):
	
	if !Global.project_loaded: return
	if Popups.open: return
	
	if Global.snapping_allowed:
		note_creation_timestamp =  Global.get_timestamp_snapped()
	else:
	
		note_creation_timestamp = Global.get_synced_song_pos()
	# Check Note Exists
	for note in Global.current_chart:
		if snappedf(note['timestamp'], 0.001) == snappedf(note_creation_timestamp, 0.001):
			print('Note already exists at %s' % [Global.get_synced_song_pos()])
			return
	
	# Create New Note
	var new_note_data = {'input_type':key, "note_modifier":0, 'timestamp':note_creation_timestamp }
	Global.current_chart.append(new_note_data)
	Global.current_chart.sort_custom(func(a, b): return a['timestamp'] < b['timestamp'])
	Events.emit_signal("note_created", new_note_data)
	
func delete_note(note: Node2D, idx: int):
	Global.project_saved = false
	print("Deleting note %s at %s (index %s)" % [note, note.data['timestamp'],idx])
	Global.current_chart.remove_at(idx)
	note.queue_free()
	
func delete_keyframe(section: String, node: Node2D, idx: int):
	Global.project_saved = false
	print("Deleting %s %s at %s (index %s)" % [section, node, node.data['timestamp'],idx])
	Save.keyframes[section].remove_at(idx)
	node.queue_free()

func clamp_seek(value):
	Global.music.song_position_raw = clampf(Global.music.song_position_raw + value, 0.0, Global.song_length )
	Global.music.seek(Global.music.song_position_raw)
	Global.music.pause_pos = Global.music.song_position_raw
	
func seek(value):
	Global.music.song_position_raw = value
	Global.music.seek(Global.music.song_position_raw)
	Global.music.pause_pos = Global.music.song_position_raw

func scroll(value):
	Events.emit_signal('update_scrolling', 10*value)

func reset():
	seek(0.0)

func clear_timeline():
	Global.current_chart.clear()
	Global.clear_children(note_container)
	Global.clear_children(animations_track)
	Global.clear_children(oneshot_sound_track)
	Global.clear_children(shutter_track)

func clear_notes_only():
	print('Cleaning Notes Only')
	Global.current_chart.clear()
	for note in note_container.get_children():
		note.queue_free()

func _input(event):
	if Popups.open: return
	
	if event.is_action_pressed("key_0"):
		create_note(Enums.NOTE.Z)	
	if event.is_action_pressed("key_1"):
		create_note(Enums.NOTE.X)	
	if event.is_action_pressed("key_2"):
		create_note(Enums.NOTE.C)	
	if event.is_action_pressed("key_3"):
		create_note(Enums.NOTE.V)
	
	if event is InputEventMouseButton:
		if get_viewport().get_mouse_position().y > 672:
			# Zooming
			if event.is_command_or_control_pressed():
				if event.button_index == MOUSE_BUTTON_WHEEL_UP:
					Global.note_speed = clampf(Global.note_speed + 10, 100, 1000 )
				if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
					Global.note_speed = clampf(Global.note_speed - 10, 100, 1000 )
				
				Events.emit_signal('update_notespeed')
			else:
				if get_viewport().get_mouse_position().y > 872:
					# Seeking
					inc_scale = (Global.song_beats_per_second / 16) if !event.alt_pressed else 0.005
					if event.button_index == MOUSE_BUTTON_WHEEL_UP:
						clamp_seek(inc_scale)
					if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
						clamp_seek(-inc_scale)
					
					if event.pressed:
						match event.button_index:
							MOUSE_BUTTON_LEFT:
								if Global.current_tool == Enums.TOOL.MARQUEE:
									if marquee_point_a < 0:
										marquee_point_a = Global.music.song_position_raw
										line_center.set_default_color(Color(1,1,1,1))
					else:
						match event.button_index:
							MOUSE_BUTTON_LEFT:
								if Global.current_tool == Enums.TOOL.MARQUEE and marquee_point_a >= 0:
									marquee_point_b = Global.music.song_position_raw
									line_center.set_default_color(Color(0.61,0.02,0.26,1))
									Events.emit_signal('update_selection', marquee_point_a, marquee_point_b)
									marquee_point_a = -1
									marquee_point_b = -1
				else:
					if event.button_index == MOUSE_BUTTON_WHEEL_UP:
						scroll(-1)
					if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
						scroll(1)
	
	if event is InputEventPanGesture:
		if get_viewport().get_mouse_position().y > 672:
			# Zooming
			if event.is_command_or_control_pressed():
				Global.note_speed = clampf(Global.note_speed + (10 * event.delta.y), 100, 1000 )
				Events.emit_signal('update_notespeed')
			else:
				# Seeking
				inc_scale = (Global.song_beats_per_second / 8) if !event.alt_pressed else 0.005
				clamp_seek(inc_scale * event.delta.x)
				scroll(-event.delta.y)
	
	if event is InputEventKey:
		# Speed up / Slow down song	
		if event.is_action_pressed("ui_up"):
			Global.music.pitch_scale = clampf(Global.music.pitch_scale + 0.1, 0.5, 2.0 )
		if event.is_action_pressed("ui_down"):
			Global.music.pitch_scale = clampf(Global.music.pitch_scale - 0.1, 0.5, 2.0 )
		
		# Seek to beginning / End
		if OS.get_name() == "macOS":
			if event.is_action_pressed("ui_end"):
				reset()
		else:
			if event.is_action_pressed("ui_home"):
				reset()
		if OS.get_name() == "macOS":
			if event.is_action_pressed("ui_home"):
				seek(Global.song_length)
		else:
			if event.is_action_pressed("ui_end"):
				seek(Global.song_length)
		
		# Fast Seek +5 AND Seek to beginning / End
		if event.is_action_pressed("ui_right"):
			if OS.get_name() == "macOS" and event.is_meta_pressed():
				reset()
			else:
				clamp_seek(-5.0)
		if event.is_action_pressed("ui_left"):
			if OS.get_name() == "macOS" and event.is_meta_pressed():
				seek(Global.song_length)
			else:
				clamp_seek(5.0)
