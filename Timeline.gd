extends Control
class_name Timeline

# --- Constants & Configuration ---
const BACKGROUND_COLOR = Color(0.1, 0.1, 0.1, 1.0)
const DATA_BOUNDS_COLOR = Color(0.2, 0.8, 0.2, 0.3)
const TICK_COLOR = Color(0.6, 0.6, 0.6, 1.0)
const CURSOR_COLOR = Color(1.0, 0.8, 0.2, 1.0)
const GHOST_CURSOR_COLOR = Color(1.0, 0.8, 0.2, 0.4)
const TEXT_COLOR = Color(1.0, 1.0, 1.0, 0.8)

# Mode Colors
const COLOR_AUTO = Color(0.0, 0.7, 0.0, 0.2) # Green
const COLOR_TELEOP = Color(0.0, 0.0, 0.8, 0.2) # Blue
const COLOR_TEST = Color(0.6, 0.0, 0.6, 0.2) # Purple
const COLOR_DISABLED = Color(0.5, 0.5, 0.5, 0.0) # Transparent/Gray
const COLOR_ESTOP = Color(1.0, 0.0, 0.0, 0.3) # Red

# Zoom Settings
var MIN_ZOOM = 0.001 # Pixels per second (Zoomed out) - Updated dynamically
const MAX_ZOOM = 5000.0 # Pixels per second (Zoomed in)
const ZOOM_RATE = 1.1

# Playback Settings
const PLAYBACK_SPEED_NORMAL = 1.0
const JUMP_SMALL = 0.1
const JUMP_LARGE = 1.0

# Snapping
const SNAP_THRESHOLD_PX = 10.0

# --- State Variables ---
var current_time: float = 0.0
var zoom_level: float = 100.0
var view_offset: float = 0.0 # Time at x=0
var is_playing: bool = false
var playback_speed: float = 1.0
var tracking_live: bool = false
var dragging_cursor: bool = false
var _has_fitted: bool = false
var view_latched_to_live: bool = true # Sticky scroll behavior

# Cache for Mode Rendering
# List of { "start": t1, "end": t2, "color": Color }
var mode_intervals: Array = []
var _last_mode_update_time: float = -1.0

# Input State
var _hover_time: float = -1.0 # -1 if not hovering
var _last_mouse_pos: Vector2 = Vector2.ZERO

# Dependencies
var nt = null

func _init():
	clip_contents = true # Prevent drawing outside bounds

func _ready():
	_find_nt_instance()
	set_process(true)
	focus_mode = Control.FOCUS_CLICK

func _find_nt_instance():
	if has_node("/root/NT4"):
		nt = get_node("/root/NT4")
		return
	var main = get_tree().current_scene
	if main:
		var tree_view = main.find_child("NTTreeView", true, false)
		if tree_view and "nt" in tree_view:
			nt = tree_view.nt


func _input(event):
	# We use _input to intercept keys BEFORE they trigger UI navigation (like TreeView selection)
	# This ensures timeline keys work "no matter what", unless typing text.
	if not event is InputEventKey: return
	if not event.pressed: return
	
	# Safety: Don't intercept if user is typing in a text box
	var focus_owner = get_viewport().gui_get_focus_owner()
	if focus_owner and (focus_owner is LineEdit or focus_owner is TextEdit):
		return
		
	# DEBUG INPUT
	# print("Timeline Key: %s, Ctrl: %s, Meta: %s, Shift: %s" % [OS.get_keycode_string(event.keycode), event.ctrl_pressed, event.meta_pressed, event.shift_pressed])
	
	var handled = false
	var is_ctrl = event.ctrl_pressed or event.meta_pressed # Meta is Command on Mac
	
	match event.keycode:
		KEY_SPACE:
			is_playing = !is_playing
			tracking_live = false
			handled = true
		KEY_LEFT:
			if is_ctrl:
				# Snap to Start
				var start = nt.get_log_start_time() / 1000000.0
				current_time = start
				tracking_live = false
				_stop_playback()
				print("Snap to start: ", current_time)
			else:
				var step = JUMP_LARGE if event.shift_pressed else JUMP_SMALL
				current_time -= step
				tracking_live = false
			handled = true
		KEY_RIGHT:
			if is_ctrl:
				# Snap to Live
				tracking_live = true
				view_latched_to_live = true
				print("Snap to Live Tracking")
			else:
				var step = JUMP_LARGE if event.shift_pressed else JUMP_SMALL
				current_time += step
				
				# Check if we hit end? 
				var end_t = nt.get_last_timestamp() / 1000000.0
				if current_time >= end_t:
					# Catch up logic: If we hit the end (or go past), switch to live tracking
					current_time = end_t
					tracking_live = true
					view_latched_to_live = true
				else:
					tracking_live = false
			handled = true
			handled = true
			
	if handled:
		# Clamp and Apply
		_validate_time()
		
		if not tracking_live:
			nt.set_replay_cursor(int(current_time * 1000000.0))
			# Auto-scroll if scrubbing with keys
			_ensure_cursor_visible()
			
		queue_redraw()
		
		# Stop event from propagating to UI (fixing "Selection scrolls" bug)
		get_viewport().set_input_as_handled()

func _notification(what):
	if what == NOTIFICATION_MOUSE_EXIT:
		_hover_time = -1.0
		queue_redraw()

func _update_mode_cache():
	if nt == null: return
	mode_intervals.clear()
	
	# Fetch full series with fallbacks
	var enabled_data = _get_series_any(["/AdvantageKit/DriverStation/Enabled", "/DriverStation/Enabled"])
	var auto_data = _get_series_any(["/AdvantageKit/DriverStation/Autonomous", "/DriverStation/Autonomous"])
	var test_data = _get_series_any(["/AdvantageKit/DriverStation/Test", "/DriverStation/Test"])
	var estop_data = _get_series_any(["/AdvantageKit/DriverStation/EmergencyStop", "/DriverStation/EStop"])
	
	var en_count = enabled_data.get("timestamps", []).size()
	if en_count > 0:
		print("Timeline Mode Update: Found %d enabled events. Time range: %s to %s" % [
			en_count,
			enabled_data.get("timestamps")[0],
			enabled_data.get("timestamps")[-1]
		])
	else:
		print("Timeline Mode Update: NO DATA FOUND for enabled topics.")
		return

	# Prepare for Sweep Line
	# Struct: { "ts": [], "vals": [], "idx": 0, "curr": false }
	var series = [
		_prep_series(enabled_data),
		_prep_series(auto_data),
		_prep_series(test_data),
		_prep_series(estop_data)
	]
	
	# Collect all unique timestamps
	var all_ts = []
	for s in series:
		all_ts.append_array(s.ts)
	all_ts.sort()
	
	if all_ts.is_empty(): return
	
	# Deduplicate timestamps
	var unique_ts = []
	var last_seen_t = -2
	for t in all_ts:
		if t != last_seen_t:
			unique_ts.append(t)
			last_seen_t = t
			
	# Sweep
	var last_t = unique_ts[0]
	
	# print("Generating Intervals from %d unique timestamps..." % unique_ts.size())
	
	for t in unique_ts:
		var draw_len = (t - last_t) / 1000000.0
		if draw_len > 0:
			var color = _determine_color(series[0].curr, series[1].curr, series[2].curr, series[3].curr)
			_add_interval(last_t, t, color)
		
		# Update current values for all series matching t
		# IMPORTANT: These values take effect starting at t
		for s in series:
			while s.idx < s.ts.size() and s.ts[s.idx] <= t:
				s.curr = s.vals[s.idx]
				s.idx += 1
		
		last_t = t
		
	# Add final interval
	var final_color = _determine_color(series[0].curr, series[1].curr, series[2].curr, series[3].curr)
	var log_end_micros = nt.get_last_timestamp()
	if log_end_micros > last_t:
		_add_interval(last_t, log_end_micros, final_color)
		
	# print("Generated %d mode intervals." % mode_intervals.size())
	queue_redraw()

func _prep_series(dict: Dictionary) -> Dictionary:
	var ts = dict.get("timestamps", [])
	var vals = dict.get("values", [])
	# IMPORTANT: We assume default state (before first data point) is FALSE.
	return {"ts": ts, "vals": vals, "idx": 0, "curr": false}

func _get_series_any(topics: Array) -> Dictionary:
	for t in topics:
		var d = nt.get_boolean_series(t)
		if not d.is_empty() and not d.get("timestamps", []).is_empty():
			# print("Found data for: %s, events: %d" % [t, d.get("timestamps").size()])
			return d
	return {}

func _determine_color(en: bool, auto: bool, test: bool, estop: bool) -> Color:
	if estop: return COLOR_ESTOP
	if not en: return COLOR_DISABLED
	if auto: return COLOR_AUTO
	if test: return COLOR_TEST
	return COLOR_TELEOP

func _add_interval(start_micros, end_micros, color):
	if start_micros >= end_micros: return
	if not mode_intervals.is_empty() and mode_intervals.back().color == color:
		mode_intervals.back().end = end_micros / 1000000.0
	else:
		mode_intervals.append({
			"start": start_micros / 1000000.0,
			"end": end_micros / 1000000.0,
			"color": color
		})

# --- Drawing ---

func _draw():
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND_COLOR)
	if nt == null: return

	var log_start = nt.get_log_start_time() / 1000000.0
	var log_end = nt.get_last_timestamp() / 1000000.0

	# 1. Draw Mode Backgrounds
	for interval in mode_intervals:
		if interval.end < x_to_time(0) or interval.start > x_to_time(size.x):
			continue # Transformation culling
			
		var sx = time_to_x(interval.start)
		var ex = time_to_x(interval.end)
		var w = max(ex - sx, 1.0)
		
		# Clip to bounds?
		draw_rect(Rect2(sx, 0, w, size.y), interval.color)

	# 2. Draw Ticks
	var target_time_step = 100.0 / zoom_level
	var time_step = _calculate_nice_step(target_time_step)
	
	var visible_start = x_to_time(0)
	var visible_end = x_to_time(size.x)
	var t = floor(visible_start / time_step) * time_step
	var font = get_theme_default_font()
	
	while t <= visible_end + time_step:
		if t >= log_start and t <= log_end + 0.001: # Don't draw ticks past data
			var tx = time_to_x(t)
			draw_line(Vector2(tx, size.y * 0.6), Vector2(tx, size.y), TICK_COLOR, 1.0)
			
			var label = "%.2f" % t
			if time_step >= 1.0: label = str(int(t))
			draw_string(font, Vector2(tx + 4, size.y - 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, TEXT_COLOR)
		else:
			pass
		t += time_step

	# 3. Draw Cursors
	var cursor_x = time_to_x(current_time)
	draw_line(Vector2(cursor_x, 0), Vector2(cursor_x, size.y), CURSOR_COLOR, 2.0)
	
	# Ghost Cursor
	if _hover_time >= 0 and not dragging_cursor:
		var gx = time_to_x(_hover_time)
		draw_line(Vector2(gx, 0), Vector2(gx, size.y), GHOST_CURSOR_COLOR, 1.0, true) # dashed? Godot doesn't do dashed lines easily, use transparency
		
	# Live Indicator
	if tracking_live:
		draw_string(font, Vector2(size.x - 60, 20), "LIVE", HORIZONTAL_ALIGNMENT_RIGHT, -1, 16, Color.RED)


# --- Input Handling ---

func _gui_input(event):
	var handled = false
	
	# Handle Mouse Motion for Ghost Cursor & Drag
	if event is InputEventMouseMotion:
		_last_mouse_pos = event.position
		
		# If user is scrubbing, update scrubbing
		if dragging_cursor:
			_scrub_to_mouse(event.position.x)
			handled = true
		else:
			# Just hovering: Update ghost cursor
			var raw_t = x_to_time(event.position.x)
			_hover_time = _snap_time(raw_t)
			queue_redraw()
			# DO NOT consume event here if just hovering, usually fine
			
	# Handle Mouse Buttons
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging_cursor = true
				grab_focus()
				_scrub_to_mouse(event.position.x)
				handled = true
			else:
				dragging_cursor = false
				handled = true
				
		# Scroll Zoom (Vertical Wheel -> Zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if event.pressed:
				if event.shift_pressed: _pan_view(-1)
				else: _zoom_at(1.0, event.position.x)
				handled = true
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				if event.shift_pressed: _pan_view(1)
				else: _zoom_at(-1.0, event.position.x)
				handled = true
		
		# Horizontal Scroll (Trackpad/Mouse Tilt) -> Pan
		elif event.button_index == MOUSE_BUTTON_WHEEL_LEFT:
			if event.pressed:
				_pan_view(-1)
				handled = true
		elif event.button_index == MOUSE_BUTTON_WHEEL_RIGHT:
			if event.pressed:
				_pan_view(1)
				handled = true
				
	# Handle Trackpad Pan Gesture (Mac)
	# delta.x -> Pan (Timeline is horizontal)
	# delta.y -> Zoom (User request: up/down scroll zooms)
	if event is InputEventPanGesture:
		# Panning (X)
		if abs(event.delta.x) > 0:
			var pan_sens = 500.0 / zoom_level
			view_offset += event.delta.x * pan_sens
			handled = true
			
		# Zooming (Y) - Treat vertical pan as zoom
		if abs(event.delta.y) > 0:
			# Heuristic: Negative Y often means scrolling down (zoom out?), Positive Y scrolling up (zoom in?)
			# Standard mouse wheel up is zoom in.
			var zoom_dir = 1.0 if event.delta.y < 0 else -1.0 # Invert depending on "natural scrolling" settings?
			# Usually delta is proportionate to movement.
			var factor = 1.0 + (abs(event.delta.y) * 0.5)
			if zoom_dir < 0: factor = 1.0 / factor
			
			var mouse_x = _last_mouse_pos.x
			var t = x_to_time(mouse_x)
			zoom_level *= factor
			zoom_level = clamp(zoom_level, MIN_ZOOM, MAX_ZOOM)
			view_offset = t - (mouse_x / zoom_level)
			handled = true
			
		queue_redraw()
		
	if event is InputEventMagnifyGesture:
		var new_zoom = zoom_level * event.factor
		new_zoom = clamp(new_zoom, MIN_ZOOM, MAX_ZOOM)
		var mouse_t = x_to_time(_last_mouse_pos.x)
		zoom_level = new_zoom
		view_offset = mouse_t - (_last_mouse_pos.x / zoom_level)
		queue_redraw()
		handled = true
		
	if handled:
		accept_event()


func _validate_time():
	var start = nt.get_log_start_time() / 1000000.0
	var end = nt.get_last_timestamp() / 1000000.0
	current_time = clamp(current_time, start, end)

# --- Logic Helpers ---

func _process(delta):
	if nt == null: return

	# 1. Update Data Bounds & Live State
	var _log_end = nt.get_last_timestamp() / 1000000.0
	
	# Auto-Fit logic: Ensure MIN_ZOOM is always valid for current data size
	var _dur = max(_log_end - (nt.get_log_start_time() / 1000000.0), 1.0)
	if size.x > 0:
		MIN_ZOOM = size.x / _dur

	# Auto-Fit & Auto-Play on first data detection
	if not _has_fitted and _log_end > 0:
		_has_fitted = true
		fit_to_view()
		_update_mode_cache()
		
		# IMMEDIATE PLAY & TRACK
		tracking_live = true
		is_playing = true

	# Handle Playback
	if is_playing and not dragging_cursor and not tracking_live:
		current_time += delta * playback_speed
		if current_time >= _log_end:
			current_time = _log_end
			is_playing = false
		nt.set_replay_cursor(int(current_time * 1000000.0))
		queue_redraw()

	# Handle Live Tracking
	if tracking_live:
		nt.set_replay_cursor(0) # 0 means "latest"
		var target_time = nt.get_last_timestamp() / 1000000.0
		
		# PLL Smoothing for Live Cursor
		# Use a Phase-Locked Loop to track the incoming data time smoothly
		# Target is latest data time. We move current_time at 1.0x speed + proportional correction.
		var error = target_time - current_time
		
		# If error is huge (e.g. initial sync or major lag), snap.
		if abs(error) > 0.5:
			current_time = target_time
		else:
			# Proportional gain for speed adjustment
			# If we are behind (error > 0), simple speed is 1.0 + (error * kp)
			# kp=5.0 means if we are 0.1s behind, we run at 1.5x speed.
			var speed_adj = 1.0 + (error * 5.0)
			# Clamp speed to reasonable limits to prevent wild overshoots or reverse
			speed_adj = clamp(speed_adj, 0.5, 2.0)
			
			current_time += delta * speed_adj
			
			# Hard clamp to not exceed target (cannot display future)
			if current_time > target_time:
				current_time = target_time
		
		# Auto-scroll view to keep head visible
		# Only if latched
		if view_latched_to_live:
			# Pin logic: Force cursor to stay at right edge (minus margin)
			# This makes the cursor appear static relative to the frame, and ticks slide smoothly.
			var view_width = size.x / zoom_level
			# Pin at 100% (right edge) or slight margin 95%?
			# User said: "just stick to the right side".
			# Let's effectively make the right edge of the screen the current time.
			
			view_offset = current_time - view_width
			
			# _constrain_view will handle if this pushes us past valid bounds?
			# Actually we need _constrain_view to allow this specific case if it's strict.
			
		queue_redraw()

	# Periodic Mode Cache Update (Faster now)
	# Update if log end changed significantly OR if we haven't updated in a while
	var diff = abs(_log_end - _last_mode_update_time)
	if diff > 0.1 or (diff > 0.0 and tracking_live):
		_update_mode_cache()
		_last_mode_update_time = _log_end

# --- Logic Helpers ---

func _scrub_to_mouse(x: float):
	tracking_live = false
	var raw_t = x_to_time(x)
	var snapped_t = _snap_time(raw_t)
	
	# Clamp to valid range (implied by snap usually, but explicit safety)
	var log_start = nt.get_log_start_time() / 1000000.0
	var log_end = nt.get_last_timestamp() / 1000000.0
	current_time = clamp(snapped_t, log_start, log_end)
	
	nt.set_replay_cursor(int(current_time * 1000000.0))
	queue_redraw()

func _snap_time(t: float) -> float:
	# Collect snap points
	var points = []
	points.append(nt.get_log_start_time() / 1000000.0)
	points.append(nt.get_last_timestamp() / 1000000.0)
	
	# Add mode boundaries nearby
	var snap_range = x_to_time(SNAP_THRESHOLD_PX) - x_to_time(0)
	
	# Search recent mode changes - optimize later, for now just scan
	for interval in mode_intervals:
		if abs(interval.start - t) < snap_range: points.append(interval.start)
		if abs(interval.end - t) < snap_range: points.append(interval.end)
		
	# Find closest
	var best_t = t
	var best_dist = snap_range
	
	for p in points:
		var dist = abs(p - t)
		if dist < best_dist:
			best_dist = dist
			best_t = p
			
	return best_t

func _zoom_at(direction: float, mouse_x: float):
	var t = x_to_time(mouse_x)
	if direction > 0: zoom_level *= ZOOM_RATE
	else: zoom_level /= ZOOM_RATE
	
	# Clamp Zoom
	zoom_level = clamp(zoom_level, MIN_ZOOM, MAX_ZOOM)
	
	# Recalculate offset to keep mouse_x time constant
	view_offset = t - (mouse_x / zoom_level)
	
	_constrain_view()
	queue_redraw()

func _pan_view(direction: int):
	# Do NOT disable tracking_live. Just unlatch if panning away.
	var pan_val = (size.x * 0.1) / zoom_level
	view_offset += pan_val * direction
	
	if direction < 0:
		# Panning left (back in time) -> Unlatch
		view_latched_to_live = false
	else:
		# Panning right -> Check if we caught up
		# If view hits the end constraint, re-latch
		var end = nt.get_last_timestamp() / 1000000.0
		var view_duration = size.x / zoom_level
		if view_offset >= end - view_duration - 0.001:
			view_latched_to_live = true
			
	_constrain_view()
	queue_redraw()

func _ensure_cursor_visible():
	# If we are using the new pinning logic in _process, this might be redundant for Live mode.
	# But useful for manual scrubbing.
	var view_width = size.x / zoom_level
	
	# If cursor is off-screen right
	if current_time > view_offset + view_width:
		view_offset = current_time - view_width
	# If cursor is off-screen left
	elif current_time < view_offset:
		view_offset = current_time

func _constrain_view():
	if nt == null: return
	var start = nt.get_log_start_time() / 1000000.0
	var end = nt.get_last_timestamp() / 1000000.0
	var view_duration = size.x / zoom_level
	
	# Don't allow scrolling before start
	if view_offset < start:
		view_offset = start
		
	# Don't allow scrolling past end (Strict)
	# The end of the view (view_offset + view_duration) should not exceed end data time.
	if view_duration < (end - start):
		# Standard case: we have more data than view width
		var max_offset = end - view_duration
		if view_offset > max_offset:
			view_offset = max_offset
	else:
		# Zoomed out case: View is wider than data
		view_offset = start
		
	# Re-check start constraint just in case
	if view_offset < start:
		view_offset = start

func _stop_playback():
	is_playing = false
	nt.set_replay_cursor(int(current_time * 1000000.0))

func fit_to_view():
	if nt == null: return
	var start = nt.get_log_start_time() / 1000000.0
	var end = nt.get_last_timestamp() / 1000000.0
	var dur = max(end - start, 1.0)
	
	if size.x > 0:
		# Calculate MIN_ZOOM so that zoomed out view fits the whole data
		# We want (dur) to fit in size.x
		if dur > 0:
			MIN_ZOOM = size.x / dur
		else:
			MIN_ZOOM = 0.1
			
		# Update zoom level constraint
		if zoom_level < MIN_ZOOM:
			zoom_level = MIN_ZOOM
			
		# Set zoom to fit
		zoom_level = MIN_ZOOM
		view_offset = start - (dur * 0.025)
		queue_redraw()

func time_to_x(t: float) -> float:
	return (t - view_offset) * zoom_level

func x_to_time(x: float) -> float:
	return (x / zoom_level) + view_offset

func _calculate_nice_step(target: float) -> float:
	var magnitude = pow(10, floor(log(target) / log(10)))
	var residual = target / magnitude
	if residual > 5: return 10 * magnitude
	elif residual > 2: return 5 * magnitude
	elif residual > 1: return 2 * magnitude
	else: return 1 * magnitude
