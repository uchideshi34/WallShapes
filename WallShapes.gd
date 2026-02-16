# Mod to make wall shaoes for squares or circles
var script_class = "tool"

var last_node_id = -1
var ui_config
var preview_line = {"WallTool": null, "PathTool": null}
var preview_path = {"WallTool": null, "PathTool": null}
var initial_mouse_position = null
var block_preview = false
var store_shape_type = ""
var store_path_preview_points

var _lib_mod_config

# Logging Functions
const ENABLE_LOGGING = true
var logging_level = 0
const TYPE_LOOKUP = {"ObjectTool": "objects","ScatterTool": "objects", "PathTool": "paths", "PatternShapeTool": "pattern_shapes", "WallTool": "walls", "PortalTool": "portals"}
const SYMMETRICAL_SHAPE_BUTTONS = ["hexagon_button","octagon_button","pentagon_button","pentagram_button","spiral_button"]

#########################################################################################################
##
## UTILITY FUNCTIONS
##
#########################################################################################################

func outputlog(msg,level=0):
	if ENABLE_LOGGING:
		if level <= logging_level:
			printraw("(%d) <WallShapes>: " % OS.get_ticks_msec())
			print(msg)
	else:
		pass

# Make a button and return it
func make_button(parent_node, icon_path: String, hint_tooltip: String, toggle_mode: bool) -> Button:

	outputlog("make_button: " + str(icon_path),2)

	var button = Button.new()
	button.toggle_mode = toggle_mode
	button.icon = load_image_texture(icon_path)
	button.hint_tooltip = hint_tooltip
	parent_node.add_child(button)
	return button

# Function to look at resource string and return the texture
func load_image_texture(texture_path: String):

	var image = Image.new()
	var texture = ImageTexture.new()

	# If it isn't an internal resource
	if not "res://" in texture_path:
		image.load(Global.Root + texture_path)
		texture.create_from_image(image)
	# If it is an internal resource then just use the ResourceLoader
	else:
		texture = ResourceLoader.load(texture_path)
	
	return texture

# Function to look at a node and determine what type it is based on its properties
func get_node_type(node):

	if node.get("WallID") != null:
		return "portals"

	# Note this is also true of portals but we caught those with WallID
	elif node.get("Sprite") != null:
		return "objects"
	elif node.get("FadeIn") != null:
		return "paths"
	elif node.get("HasOutline") != null:
		return "pattern_shapes"
	elif node.get("Joint") != null:
		return "walls"

	return null

# A simplefunction to create a label and return its reference
func make_label(section: Container, text: String,index: int = -1):
	var mylabel = Label.new()
	mylabel.text = text
	section.add_child(mylabel)
	if index > -1:
		section.move_child(mylabel,index)
	return mylabel

#########################################################################################################
##
## UI FUNCTIONS
##
#########################################################################################################

# Function to make the UI for the wall shapes
func make_wall_shapes_ui(tool_type: String):

	outputlog("make_wall_shapes_ui: " + str(tool_type))

	var vbox = Global.Editor.Toolset.GetToolPanel(tool_type).Align

	if not ui_config.has(tool_type):
		ui_config[tool_type] = {}

	var hbox = HBoxContainer.new()
	var label = Label.new()
	label.text = "Shape"
	hbox.add_child(label)
	hbox.size_flags_horizontal = 3

	var freeshape_button = make_button(hbox, "res://ui/icons/buttons/polygon.png", "Select to draw a wall/path as normal.", true)
	freeshape_button.connect("toggled", self, "_on_shape_button_toggled",[freeshape_button, tool_type])
	var circle_button = make_button(hbox, "res://ui/icons/buttons/circle.png", "Select to draw an elliptical wall/path starting at the top left.", true)
	circle_button.connect("toggled", self, "_on_shape_button_toggled",[circle_button,tool_type])
	var circle_centre_button = make_button(hbox, "icons/white-circle-centre-icon.png", "Select to draw an elliptical wall/path centred at the first point.", true)
	circle_centre_button.connect("toggled", self, "_on_shape_button_toggled",[circle_centre_button,tool_type])
	var rectangle_button = make_button(hbox, "res://ui/icons/buttons/rectangle.png", "Select to draw a rectangular wall/path.", true)
	rectangle_button.connect("toggled", self, "_on_shape_button_toggled",[rectangle_button,tool_type])
	var reverse_button = make_button(hbox, "icons/reverse-icon.png", "Select to reverse the drawing direction.", true)
	reverse_button.set_anchors_preset(6,false)
	var more_shapes_button = make_button(hbox, "icons/down-arrow.png", "Click to see more shapes.", true)
	more_shapes_button.connect("toggled", self, "_on_more_shapes_button_toggled",[tool_type])

	ui_config[tool_type]["freeshape_button"] = freeshape_button
	ui_config[tool_type]["circle_button"] = circle_button
	ui_config[tool_type]["circle_centre_button"] = circle_centre_button
	ui_config[tool_type]["rectangle_button"] = rectangle_button
	ui_config[tool_type]["reverse_button"] = reverse_button

	vbox.add_child(hbox)

	# Get the location of EditPoints button
	var index = Global.Editor.Tools[tool_type].get_EditPoints().get_index()
	# Move the shapes just after the EditPoints button
	if index != null:
		vbox.move_child(hbox, min(vbox.get_child_count()-1, index+1))
	
	ui_config[tool_type]["more_shapes_hbox"] = HBoxContainer.new()
	ui_config[tool_type]["more_shapes_hbox"].size_flags_horizontal = 3
	vbox.add_child(ui_config[tool_type]["more_shapes_hbox"])
	vbox.move_child(ui_config[tool_type]["more_shapes_hbox"],hbox.get_index()+1)

	ui_config[tool_type]["hexagon_button"] = make_button(ui_config[tool_type]["more_shapes_hbox"], "icons/hex_icon_vertical.png", "Select to draw a hexagon as a wall/path.", true)
	ui_config[tool_type]["hexagon_button"].connect("toggled", self, "_on_shape_button_toggled",[ui_config[tool_type]["hexagon_button"],tool_type])

	ui_config[tool_type]["octagon_button"] = make_button(ui_config[tool_type]["more_shapes_hbox"], "icons/octagon-icon.png", "Select to draw an octagon as a wall/path.", true)
	ui_config[tool_type]["octagon_button"].connect("toggled", self, "_on_shape_button_toggled",[ui_config[tool_type]["octagon_button"],tool_type])

	ui_config[tool_type]["pentagon_button"] = make_button(ui_config[tool_type]["more_shapes_hbox"], "icons/pentagon-icon.png", "Select to draw a pentagon as a wall/path.", true)
	ui_config[tool_type]["pentagon_button"].connect("toggled", self, "_on_shape_button_toggled",[ui_config[tool_type]["pentagon_button"],tool_type])

	ui_config[tool_type]["pentagram_button"] = make_button(ui_config[tool_type]["more_shapes_hbox"], "icons/pentagram-icon.png", "Select to draw a pentagram as a wall/path.", true)
	ui_config[tool_type]["pentagram_button"].connect("toggled", self, "_on_shape_button_toggled",[ui_config[tool_type]["pentagram_button"],tool_type])

	ui_config[tool_type]["spiral_button"] = make_button(ui_config[tool_type]["more_shapes_hbox"], "icons/spiral-icon.png", "Select to draw a spiral as a wall/path.", true)
	ui_config[tool_type]["spiral_button"].connect("toggled", self, "_on_shape_button_toggled",[ui_config[tool_type]["spiral_button"],tool_type])

	make_spiral_ui(vbox, ui_config[tool_type]["more_shapes_hbox"].get_index()+1, tool_type)
	ui_config[tool_type]["more_shapes_hbox"].visible = false

	# Set the initial state correctly.
	freeshape_button.pressed = true
	more_shapes_button.pressed = false

# Make the spiral ui
func make_spiral_ui(vbox: Container, index: int, tool_type: String):

	var NewHSlider = ResourceLoader.load(Global.Root + "NewHSlider.gd", "GDScript", true)

	ui_config[tool_type]["spiral_vbox"] = VBoxContainer.new()

	vbox.add_child(ui_config[tool_type]["spiral_vbox"])
	vbox.move_child(ui_config[tool_type]["spiral_vbox"], index)

	ui_config[tool_type]["reverse_spiral_button"] = make_button(ui_config[tool_type]["spiral_vbox"], "icons/reverse-icon.png", "Enable to draw spiral clockwise.", true)
	ui_config[tool_type]["reverse_spiral_button"].text = "Reverse Direction"
	
	#NewHSlider.new(ui_config[tool_type]["spiral_vbox"], default: float = 0.0, minimum: float = 0.0, maximum: float = 1.0, step: float = 0.1, exp_edit: bool = false)

	make_label(ui_config[tool_type]["spiral_vbox"], "Inner Radius")
	ui_config[tool_type]["spiral_inner_radius_slider"] = NewHSlider.new(ui_config[tool_type]["spiral_vbox"], 256.0, 0.0, 256*20, 16, true)
	
	make_label(ui_config[tool_type]["spiral_vbox"], "Circulation")
	ui_config[tool_type]["spiral_circulation_slider"] = NewHSlider.new(ui_config[tool_type]["spiral_vbox"], 120, 10, 300, 5, true)
	
	make_label(ui_config[tool_type]["spiral_vbox"], "Radial Speed")
	ui_config[tool_type]["spiral_radial_speed_slider"] = NewHSlider.new(ui_config[tool_type]["spiral_vbox"], 5, 1, 20, 1, true)
	
	make_label(ui_config[tool_type]["spiral_vbox"], "Spacing")
	ui_config[tool_type]["spiral_spacing_slider"] = NewHSlider.new(ui_config[tool_type]["spiral_vbox"], 64, 4, 512, 1, true)


func get_spiral_config(tool_type: String):

	return {
		"reverse": ui_config[tool_type]["reverse_spiral_button"].pressed,
		"inner_radius": ui_config[tool_type]["spiral_inner_radius_slider"].value,
		"circulation": ui_config[tool_type]["spiral_circulation_slider"].value,
		"radial_speed": ui_config[tool_type]["spiral_radial_speed_slider"].value,
		"spacing": ui_config[tool_type]["spiral_spacing_slider"].value
	}

#########################################################################################################
##
## UI DRIVEN FUNCTIONS
##
#########################################################################################################

# When the more shapes button is toggled
func _on_more_shapes_button_toggled(pressed: bool, tool_type: String):

	ui_config[tool_type]["more_shapes_hbox"].visible = pressed

	# if we have toggled it off and one of the more shapes is selected, switch back to freeshape
	if not pressed:
		for button_name in SYMMETRICAL_SHAPE_BUTTONS:
			if ui_config[tool_type][button_name].pressed:
				ui_config[tool_type]["freeshape_button"].pressed = true
				break


# Function for when wall shape option is changed
func _on_shape_button_toggled(pressed: bool, source_button: Button, tool_type: String):

	outputlog("_on_shape_button_toggled",2)
	var button
	var button_list = ["freeshape_button","circle_button","circle_centre_button","rectangle_button"]
	button_list.append_array(SYMMETRICAL_SHAPE_BUTTONS)

	# For each button in the list
	for button_name in button_list:
		button = ui_config[tool_type][button_name]
		if button == null:
			outputlog("button is null: " + str(button_name),2)
			continue
		button.set_block_signals(true)
		if button != source_button:
			button.pressed = false
		else:
			outputlog(button_name + " now active.",2)
			button.pressed = true
		button.set_block_signals(false)
	
	# If we are in the middle of actively drawing, then block preview until we stop drawing and hide the current preview
	if Global.Editor.Tools[tool_type].isDrawing:
		# If we have pressed the button so triggered an actual change or simply the freeshape button has been pressed
		if pressed || source_button == ui_config[tool_type]["freeshape_button"]:
			block_preview = true
			hide_preview(tool_type)
	
	# If it is a spiral button
	show_hide_spiral_ui(tool_type, source_button == ui_config[tool_type]["spiral_button"])

# Function to show or hide the spiral ui
func show_hide_spiral_ui(tool_type: String, make_visible: bool):

	ui_config[tool_type]["spiral_vbox"].visible = make_visible

#########################################################################################################
##
## DRAW PREVIEW FUNCTIONS
##
#########################################################################################################

# Function to create a dotted line texture
func create_dotted_texture(width: int, height: int, dotted_height: int, dotted_spacing: int, dotted_length: int) -> Texture:
	var img = Image.new()
	img.create(width, height, false, Image.FORMAT_RGBA8)
	img.lock()

	# Fill the background transparent
	img.fill(Color(1, 1, 1, 0))  # Transparent white background
	var data = img.get_data()
	var index

	# Draw horizontal dots (actually tiny rectangles)
	for x in range(0, width, dotted_spacing + dotted_length):
		for i in range(dotted_length):
			if (x + i) >= width:
				break
			for y in range(height / 2 - dotted_height / 2, height / 2 + dotted_height / 2):
				if y >= 0 and y < height:
					index = (y * width + (x+i)) * 4 + 3
					data[index] = 255

	img.unlock()
	img.create_from_data(width, height, false, Image.FORMAT_RGBA8, data)
	
	var tex = ImageTexture.new()
	tex.create_from_image(img)
	return tex

# Function to create a return a line2d 
func make_preview_line2d(is_arc: bool = false):

	outputlog("make_preview_line2d",2)

	var line2d = Line2D.new()
	#var texture := load_image_texture(dotted_line_texture_path)
	var texture := create_dotted_texture(256, 16, 8, 64, 64) 
	texture.flags = 2
	line2d.texture = texture
	line2d.default_color = Color("ffd700")
	if is_arc:
		line2d.default_color = Color.red
	line2d.texture_mode = Line2D.LINE_TEXTURE_TILE
	line2d.width = 8
	line2d.z_index = 1000
	return line2d

# Generate a vortex with even spacing
func generate_vortex_even_spacing(
		center: Vector2,
		outer_radius: float,
		inner_radius: float,
		circulation: float = 90.0,
		radial_speed: float = 20.0,
		spacing: float = 8.0,
		clockwise: bool = true
	) -> Array:

	var points := []
	var r := outer_radius

	# Direction multiplier
	var dir := -1.0 if clockwise else 1.0

	var prev_point := center + Vector2(outer_radius, 0)

	while r > inner_radius:

		# Angle based on vortex equation
		var theta := dir * (circulation / radial_speed) * log(outer_radius / r)

		var p := center + Vector2(
			cos(theta),
			sin(theta)
		) * r

		# Add point only if spacing threshold met
		if prev_point.distance_to(p) >= spacing:
			points.append(p)
			prev_point = p

		# radial contraction step
		r -= radial_speed * (r / outer_radius) * 0.02

		if r <= inner_radius:
			break

	return points


func generate_elliptical_vortex(
		center: Vector2,
		outer_a: float, outer_b: float,     # outer ellipse radii (x,y)
		inner_a: float, inner_b: float,     # inner ellipse radii (x,y)
		circulation: float = 90.0,
		radial_speed: float = 20.0,
		spacing: float = 8.0                # desired point spacing
	) -> Array:

	var points := []

	# Parametric angle on the ellipse (theta)
	var theta := 0.0

	# Progress from outer ellipse toward inner ellipse (0 → 1)
	var t := 0.0  

	# Previous point for spacing control
	var prev_point := center + Vector2(outer_a, 0)

	while t < 1.0:

		# Current ellipse radii by interpolation
		var a := lerp(outer_a, inner_a, t)
		var b := lerp(outer_b, inner_b, t)

		# Compute point on ellipse
		var p := center + Vector2(
			a * cos(theta),
			b * sin(theta)
		)

		# Enforce minimum spacing
		if prev_point.distance_to(p) >= spacing:
			points.append(p)
			prev_point = p

		# Spiral acceleration inward
		# Faster as it approaches inner ellipse
		t += radial_speed * (0.02 + t * 0.1)

		# Increase rotation faster near center
		theta += circulation * (0.01 + t * 0.2)

	return points


# Function to create an ellipse
func generate_ellipse_points(a: float, b: float, num_points: int) -> PoolVector2Array:
	var points = PoolVector2Array()
	for i in range(num_points):
		var theta = (PI * 2.0) * float(i) / float(num_points)
		var x = a * cos(theta)
		var y = b * sin(theta)
		points.append(Vector2(x, y))
	return points

# Function to create an ellipse in world space
func create_ellipse(start: Vector2, end: Vector2, draw_from_centre: bool = false, draw_circle: bool = false) -> PoolVector2Array:

	outputlog("create_ellipse",3)

	var points = PoolVector2Array()
	var num_per_square = 10
	var size
	var centre

	# If we are forcing the ellipse to be a circle
	if draw_circle:
		size = min(end.y - start.y, end.x - start.x) * Vector2.ONE
	else:
		size = (end - start).abs()

	# If we are drawing from the top left as the start
	if not draw_from_centre:
		# The mid point of the circle is midway between start and end
		centre = start + size * 0.5
	# If start is the centre
	else:
		# Size is now double as we are drawing from the centre
		size = size * 2
		# mid_point is now the start point
		centre = start

	var num_points = max(int(max(size.x, size.y) * num_per_square / 256.0),40)

	points = generate_ellipse_points(size.x * 0.5, size.y * 0.5, num_points)
	for _i in points.size():
		points[_i] += centre
	
	points.append(points[0])
	return points

# Create a rectangle of points
func create_rectangle(start: Vector2, end: Vector2, draw_sqaure: bool = false):

	outputlog("create_rectangle",3)

	# If we are drawing a square then change the start and end points
	if draw_sqaure:
		var side = min(end.y - start.y, end.x - start.x)
		end = start + side * Vector2.ONE

	return [start, Vector2(end.x,start.y), end, Vector2(start.x,end.y), start]

# Create a symmetrical shape based off a square
func create_symmetrical_shape(start: Vector2, end: Vector2, type: String) -> PoolVector2Array:

	var points = PoolVector2Array()
	var side = min(end.y - start.y, end.x - start.x)

	match type:
		"hexagon":
			points = create_hexagon(start, side)
		"octagon":
			points = create_octagon(start, side)
		"pentagon":
			points = create_pentagon(start, side)
		"pentagram":
			points = create_pentagram(start, side)
		"spiral":
			var spiral_config = get_spiral_config(Global.Editor.ActiveToolName)
			points = generate_vortex_even_spacing(start, side, spiral_config["inner_radius"], spiral_config["circulation"], spiral_config["radial_speed"], spiral_config["spacing"], not spiral_config["reverse"])
		_:
			pass

	return points

# Function to create a hexagon
func create_hexagon(start: Vector2, side: float) -> PoolVector2Array:

	outputlog("create_hexagon",3)
	var points = PoolVector2Array()

	points.append(Vector2(start.x + side * 0.25, start.y))          # top-left
	points.append(Vector2(start.x + side * 0.75, start.y))          # top-right
	points.append(Vector2(start.x + side, start.y + side * 0.5))    # right
	points.append(Vector2(start.x + side * 0.75, start.y + side))   # bottom-right
	points.append(Vector2(start.x + side * 0.25, start.y + side))   # bottom-left
	points.append(Vector2(start.x, start.y + side * 0.5))           # left
	
	points.append(points[0])

	return points 

# Function to create an octagon
func create_octagon(start: Vector2, side: float) -> PoolVector2Array:

	outputlog("create_octagon",3)
	var points = PoolVector2Array()
	var a = side / (2 + sqrt(2))   # offset from corner

	# Top edge
	points.append(Vector2(start.x + a, start.y))                # top-left
	points.append(Vector2(start.x + side - a, start.y))         # top-right

	# Right edge
	points.append(Vector2(start.x + side, start.y + a))         # right-top
	points.append(Vector2(start.x + side, start.y + side - a))  # right-bottom

	# Bottom edge
	points.append(Vector2(start.x + side - a, start.y + side))  # bottom-right
	points.append(Vector2(start.x + a, start.y + side))         # bottom-left

	# Left edge
	points.append(Vector2(start.x, start.y + side - a))         # left-bottom
	points.append(Vector2(start.x, start.y + a))                # left-top

	points.append(points[0])
	return points

func create_pentagon(start: Vector2, side: float) -> PoolVector2Array:

	outputlog("create_pentagon",3)
	var points = PoolVector2Array()
	var centre = start + Vector2(side/2, side/2)
	var radius = side/2

	# Rotate so one vertex is at the top (pointy-top)
	var start_angle = -PI/2

	for i in range(5):
		var angle = start_angle + i * (2 * PI / 5.0)
		var x = centre.x + radius * cos(angle)
		var y = centre.y + radius * sin(angle)
		points.append(Vector2(x, y))

	points.append(points[0])
	return points

func create_pentagram(start: Vector2, side: float) -> PoolVector2Array:
	outputlog("create_pentagram",3)
	var points = PoolVector2Array()
	var centre = start + Vector2(side/2, side/2)
	var R = side/2                             # outer radius
	var r = R * cos(deg2rad(72)) / cos(deg2rad(36))  # inner radius

	# Start angle so top vertex is upward
	var start_angle = -PI/2

	for i in range(10): # 5 outer + 5 inner = 10 points
		var is_outer = i % 2 == 0
		var angle = start_angle + i * (PI / 5.0)  # 36° per step
		var rad = R if is_outer else r
		var x = centre.x + rad * cos(angle)
		var y = centre.y + rad * sin(angle)
		points.append(Vector2(x, y))
	points.append(points[0])
	return points


# Function to make a circle arc based on a centre, start point and proposed end point. Note we take the actual end to be point on the circle that is in the direction of the end
func create_circle_arc(centre: Vector2, start: Vector2, end: Vector2, is_clockwise: bool) -> PoolVector2Array:

	outputlog("create_circle_arc: centre: " + str(centre) + " start: " + str(start) + " end: " + str(end),3)

	var points = PoolVector2Array()
	var radius = centre.distance_to(start)
	var num_per_square = 10
	
	var angle_amount = (start - centre).angle_to(end - centre)
	angle_amount = wrapf(angle_amount, 0, TAU)
	if not is_clockwise:
		angle_amount -= TAU

	var num_points = int(abs(angle_amount)/TAU * max(2 * radius * num_per_square / 256.0,40))

	for _i in range(num_points):
		var theta = angle_amount * float(_i) / float(num_points) + (start-centre).angle()
		points.append(radius * Vector2.RIGHT.rotated(theta) + centre)
	
	points.append(centre + radius * (end-centre).normalized())

	return points

# Function to show or update the preview
func show_update_preview(mouseposition: Vector2, tool_type: String):

	outputlog("show_update_preview",3)

	var points = PoolVector2Array()
	var force_regular = false

	if block_preview:
		return
	
	# If this is the start of a drawing event, set the initial mouse position
	if initial_mouse_position == null:
		initial_mouse_position = mouseposition

	# If the free draw option is active then hide the preview and do no more
	if ui_config[tool_type]["freeshape_button"].pressed:
		if Input.is_key_pressed(KEY_ALT):
			# If lib is installed then look for the shortcut action
			if Engine.has_signal("_lib_register_mod"):
				points = make_circle_arc_preview_points(tool_type, mouseposition, not Input.is_action_pressed("reverse_circle_arc"))
			# Otherwise just check for KEY_A being pressed.
			else:
				points = make_circle_arc_preview_points(tool_type, mouseposition, not Input.is_key_pressed(KEY_A))
			store_shape_type = "circle_arc"
		else:
			hide_all_previews()
			return

	# If the force regular key is pressed
	if Input.is_key_pressed(KEY_ALT):
		force_regular = true
	
	# Check if the rectangle is pressed
	if ui_config[tool_type]["rectangle_button"].pressed:
		points = create_rectangle(initial_mouse_position, mouseposition, force_regular)
		store_shape_type = "rectangle"
	# If it is a circle
	elif ui_config[tool_type]["circle_button"].pressed:
		points = create_ellipse(initial_mouse_position, mouseposition, false, force_regular)
		store_shape_type = "ellipse"
	# If the circle is drawn from the centre rather than the top left edge
	elif ui_config[tool_type]["circle_centre_button"].pressed:
		points = create_ellipse(initial_mouse_position, mouseposition, true, force_regular)
		store_shape_type = "ellipse"
	elif ui_config[tool_type]["hexagon_button"].pressed:
		points = create_symmetrical_shape(initial_mouse_position, mouseposition, "hexagon")
		store_shape_type = "hexagon"
	elif ui_config[tool_type]["octagon_button"].pressed:
		points = create_symmetrical_shape(initial_mouse_position, mouseposition, "octagon")
		store_shape_type = "octagon"
	elif ui_config[tool_type]["pentagon_button"].pressed:
		points = create_symmetrical_shape(initial_mouse_position, mouseposition, "pentagon")
		store_shape_type = "pentagon"
	elif ui_config[tool_type]["pentagram_button"].pressed:
		points = create_symmetrical_shape(initial_mouse_position, mouseposition, "pentagram")
		store_shape_type = "pentagram"
	elif ui_config[tool_type]["spiral_button"].pressed:
		points = create_symmetrical_shape(initial_mouse_position, mouseposition, "spiral")
		store_shape_type = "spiral"
	
	# Use the points to set up the preview_line
	match tool_type:
		"WallTool":
			update_line_preview(tool_type, points)
		
		"PathTool":
			update_path_preview(points)
			
# Make the preview points for a circle arc
func make_circle_arc_preview_points(tool_type: String, mouseposition: Vector2, is_clockwise: bool) -> PoolVector2Array:

	outputlog("make_circle_arc_preview_points: tool_type: " + str(tool_type),2)

	var points = PoolVector2Array()
	var drawn_points

	match tool_type:
		"WallTool":
			drawn_points = Global.WorldUI.GetArcPolyline()
		"PathTool":
			drawn_points = Global.Editor.Tools["PathTool"].ActivePath.GlobalEditPoints
			# Trim the last point so it acts like the wall does
			if drawn_points.size() > 0:
				drawn_points.remove(drawn_points.size()-1)
		_:
			return points
	
	# If there are no points then do nothing and return an empty array
	if drawn_points.size() == 0:
		return points
	# If there are only two points, then don't try and make an arc, but mark the line and catch it in the draw path preview function
	elif drawn_points.size() < 2:
		points.append(drawn_points[0])
		points.append(mouseposition)
	# If we have three points, then we make an arc
	elif drawn_points.size() == 2:
		# Create the arc
		points = create_circle_arc(drawn_points[0],drawn_points[1],mouseposition,is_clockwise)
		# Add the initial point
		points.insert(0, drawn_points[0])
		# Add it again at the end to create a segment
		points.push_back(drawn_points[0])
	# If there are more than 3 points, this is invalid so exit
	elif drawn_points.size() > 2:
		return points

	return points

# Function to update the wall preview
func update_line_preview(tool_type: String, points: PoolVector2Array):

	# If there isn't a preview line node then make one
	if preview_line[tool_type] == null:
		preview_line[tool_type] = make_preview_line2d()
		Global.World.GetCurrentLevel().add_child(preview_line[tool_type])
			
	# If we have changed levels then reset
	elif preview_line[tool_type].get_parent() != Global.World.GetCurrentLevel():
		hide_preview(tool_type)
		return
			
	preview_line[tool_type].points = points
	preview_line[tool_type].visible = true

# Function to update the path preview
func update_path_preview(points: PoolVector2Array):

	outputlog("update_path_preview: " + str(points),3)

	var tool_type = "PathTool"

	# If this is not a circle arc, then check we have enough data to draw
	if store_shape_type != "circle_arc":
		if points.size() < 3:
			return
		# Remove the final points which is a duplicate of the first as we don't need it in the path tool as we are not drawing our own line2d
		points.remove(points.size()-1)
	else:
		# If we have started the draw but only placed a single point the centre, we want to hide the normal preview and draw the line preview
		match points.size():
			0,1:
				return
			2:
				pass
			_:
				# Remove the start point as we don't need it
				points.remove(points.size()-1)

	if preview_path[tool_type] == null:
		preview_path[tool_type] = Global.Editor.Tools["PathTool"].ActivePath
	
	preview_path[tool_type].Loop = true
	# For rectangles
	match store_shape_type:
		"rectangle", "hexagon", "octagon", "pentagon", "pentagram":
			points = update_polygon_points_to_add_extra_corner_points(points)
			preview_path[tool_type].Smoothness = 0
		"circle_arc":
			update_line_preview(tool_type, trim_points_to_line_preview(points))
			# If we are starting the draw of the line but not the arc then hide the activepath and just show the preview line
			if points.size() == 2:
				preview_path[tool_type].visible = false
			else:
				preview_path[tool_type].visible = true
				# Remove the first point which is the centre of the circle. Note that we don't need to do this for a start of a draw as above
				points.remove(0)
			preview_path[tool_type].Loop = false
		"spiral":
			preview_path[tool_type].Loop = false
	
	if ui_config["PathTool"]["reverse_button"].pressed:
		points.invert()
	store_path_preview_points = points

	# If the result is less than two points this is invalid so don't update. Only an error case for circle_arc as this would otherwise be caught earlier.
	if not points.size() < 2:
		preview_path[tool_type].SetEditPoints(points)	
		preview_path[tool_type].Smooth()

# Function to remove all but the first edge and last edge of the an arc points list 
func trim_points_to_line_preview(points: PoolVector2Array) -> PoolVector2Array:

	outputlog("trim_points_to_line_preview: " + str(points),2)

	var new_points = PoolVector2Array()

	# If the list is too small return empty array, effectively a do nothing prompt
	if points.size() < 2:
		new_points = []
	# If it is less that three points we haven't started an arc so just return the first vertex for drawing a preview line particularly for paths
	elif points.size() < 3:
		new_points.append(points[1])
		new_points.append(points[0])
	# Otherwise return the segment from the edge of the circle to the centre
	else:
		new_points.append(points[1])
		new_points.append(points[0])
		new_points.append(points[-1])
	
	return new_points

# Function to update the latest wall 
func update_shape_points_to_preview_points(tool_type: String, shape_type: String):

	outputlog("update_shape_points_to_preview_points: " + str(tool_type),2)

	var node_id = Global.World.nextNodeID-1

	# If the it is a valid node
	if Global.World.HasNodeID(node_id):
		# If the node is indeed a wall
		var node = Global.World.GetNodeByID(node_id)
		if get_node_type(node) == TYPE_LOOKUP[tool_type]:
			
			match tool_type:
				"WallTool":
					update_wall_to_preview_points(node, shape_type)
				"PathTool":
					update_path_to_preview_points(node, shape_type)

# Update wall to the preview points
func update_wall_to_preview_points(wall: Node2D, shape_type: String):

	var is_loop = true

	# If preview_line is not null
	if preview_line["WallTool"] != null:
		# Check the preview_line points exist
		if preview_line["WallTool"].points.size() > 0:
			# Check the preview points
			var points = preview_line["WallTool"].points
			# Remove the start point as we don't need it (unlike to draw the line)
			points.remove(points.size()-1)

			if polygon_area(points) < 0.001: return
			
			# if this is an arc, set the loop as false and trim the first point
			match shape_type:
				"circle_arc":
					is_loop = false
					points.remove(0)
				"spiral":
					is_loop = false
			
			# Invert if needed
			if ui_config["WallTool"]["reverse_button"].pressed:
				points.invert()
			
			wall.Set(points, wall.Texture, wall.Color, is_loop, wall.HasShadow, wall.Type, wall.Joint, true)
			# Redraw the wall to update shadows in particular
			wall.RemakeLines()
			outputlog("Wall has been updated. Points: " + str(points),2)
	
	# Hide the preview line
	hide_preview("WallTool")

# Update wall to the preview points
func update_path_to_preview_points(path: Node2D, shape_type: String):

	if preview_path["PathTool"] == null: return

	var points = store_path_preview_points

	if polygon_area(points) < 0.001: return

	# Set the new points of the wall and setting loop as true
	path.Loop = true
	match shape_type:
		"rectangle","hexagon","octagon","pentagon","pentagram":
			path.Smoothness = 0
		"circle_arc", "spiral":
			path.Loop = false
	
	path.SetEditPoints(points)
	# Redraw the wall to update shadows in particular
	path.Smooth()
	path.visible = true
	outputlog("Path has been updated. Points: " + str(points),2)

# Function to add extra points to the corners
func update_polygon_points_to_add_extra_corner_points(points: PoolVector2Array):

	outputlog("update_polygon_points_to_add_extra_corner_points",3)

	var offset = 0.1 * 256

	if Engine.has_signal("_lib_register_mod"):
		offset = _lib_mod_config.rectangle_offset_slider * 256
	
	var new_points = PoolVector2Array()

	# For each of the original points
	for _i in points.size():

		# Add a point before the vertex in the direction of the previous vertex
		new_points.append(points[_i] + (points[posmod((_i - 1), points.size())] - points[_i]).normalized() * offset)

		# Start with the vertex itself
		new_points.append(points[_i])

		# Add a point to the next vertex but offset by value
		new_points.append(points[_i] + (points[posmod((_i + 1), points.size())] - points[_i]).normalized() * offset)

	# We really prefer to have the first point be a vertex so move the first point to the end
	var store_point = new_points[0]
	new_points.remove(0)
	new_points.append(store_point)

	return new_points

# Function to hide all preview
func hide_all_previews():

	hide_preview("WallTool")
	hide_preview("PathTool")

# Function to hide/delete the preview
func hide_preview(tool_type: String):

	outputlog("hide_preview",4)

	# Remove any preview lines
	if preview_line[tool_type] != null:
		if preview_line[tool_type].get_parent() != null:
			preview_line[tool_type].get_parent().remove_child(preview_line[tool_type])
		preview_line[tool_type].queue_free()
	
	preview_path[tool_type] = null
	preview_line[tool_type] = null
	initial_mouse_position = null
	store_shape_type = ""
	store_path_preview_points = []

func polygon_area(points: Array) -> float:
	var area := 0.0
	var count := points.size()
	
	if count < 3:
		return 0.0
	
	for i in range(count):
		var p1: Vector2 = points[i]
		var p2: Vector2 = points[(i + 1) % count]
		area += (p1.x * p2.y) - (p2.x * p1.y)
	
	return abs(area) * 0.5


#########################################################################################################
##
## UPDATE FUNCTIONS
##
#########################################################################################################	

# this method is automatically called every frame. delta is a float in seconds. can be removed from script.
func update(delta: float):

	# A new node has been added since we last checked
	if Global.Editor.ActiveToolName in ["WallTool","PathTool"]:
		if Global.World.nextNodeID-1 != last_node_id:
			# If we have placed a new node, check that it is a wall
			update_shape_points_to_preview_points(Global.Editor.ActiveToolName, store_shape_type)
			last_node_id = Global.World.nextNodeID-1		
		else:
			# If we are drawing the update the preview
			if Global.Editor.Tools[Global.Editor.ActiveToolName].isDrawing:
				# Update the preview				
				show_update_preview(Global.WorldUI.SnappedPosition, Global.Editor.ActiveToolName)
			else:
				# If we have stopped drawing then unblock the preview but hide it
				block_preview = false
				hide_preview(Global.Editor.ActiveToolName)
	else:
		hide_all_previews()
		if Global.World.nextNodeID-1 != last_node_id:
			last_node_id = Global.World.nextNodeID-1

# Function to make the core UI
func create_tooltips():

	outputlog("create_tooltips")
	
	var a_key_label = Global.Editor.find_node("Tooltips").find_node("Object").find_node("Mirror").find_node("A").duplicate()
	var plus_label = Global.Editor.find_node("Tooltips").find_node("Object").find_node("Cycle").find_node("+").duplicate()

	# Section to add tooltip for Erase
	ui_config["tooltips"] = {}
	var arc_tooltip = Global.Editor.find_node("Tooltips").find_node("Erase").duplicate()
	var spacer = Global.Editor.find_node("Tooltips").find_node("Object").find_node("Space").duplicate()
	arc_tooltip.find_node("Erase").text = "Circle Arc"

	var arc_reversed_tooltip = arc_tooltip.duplicate()
	arc_reversed_tooltip.add_child(plus_label)
	arc_reversed_tooltip.move_child(plus_label,2)
	arc_reversed_tooltip.add_child(a_key_label)
	arc_reversed_tooltip.move_child(a_key_label,3)
	arc_reversed_tooltip.find_node("Erase").text = "Circle Arc (reversed)"

	for type in ["Line","Wall"]:
	
		# Add to the Path tool tooltips
		Global.Editor.find_node("Tooltips").find_node(type).add_child(spacer.duplicate())
		Global.Editor.find_node("Tooltips").find_node(type).add_child(arc_tooltip.duplicate())
		Global.Editor.find_node("Tooltips").find_node(type).add_child(spacer.duplicate())
		Global.Editor.find_node("Tooltips").find_node(type).add_child(arc_reversed_tooltip.duplicate())
		ui_config["tooltips"][type] = {}
		ui_config["tooltips"][type]["arc_tooltip"] = arc_tooltip
		ui_config["tooltips"][type]["arc_reversed_tooltip"] = arc_reversed_tooltip

# Note that updating the text of the label doesn't seem to actually affect the displayed tooltip so this function effectively fails
func update_tooltips_with_mod_config():

	outputlog("update_tooltips_with_mod_config")

	if Engine.has_signal("_lib_register_mod"):
		if InputMap.has_action("reverse_circle_arc"):
			var event_list = InputMap.get_action_list("reverse_circle_arc")
			if event_list.size() > 0:
				for type in ["Line","Wall"]:
					ui_config["tooltips"][type]["arc_reversed_tooltip"].get_child(3).text = OS.get_scancode_string(event_list[0].scancode)


func on_preferences_applied():

	outputlog("on_preferences_applied")

	var timer = Timer.new()
	timer.autostart = false
	timer.one_shot = true
	Global.Editor.get_node("Windows").add_child(timer)

	timer.start(0.5)
	yield(timer,"timeout")
	
	update_tooltips_with_mod_config()
	if Engine.has_signal("_lib_register_mod"):
		logging_level = int(_lib_mod_config.core_log_level)

	Global.Editor.get_node("Windows").remove_child(timer)
	timer.queue_free()
	
#########################################################################################################
##
## VERSION CHECKER FUNCTIONS
##
#########################################################################################################

# Check whether a semver strng 2 is greater than string one. Only works on simple comparisons - DO NOT USE THIS FUNCTION OUTSIDE THIS CONTEXT
func compare_semver(semver1: String, semver2: String) -> bool:

	outputlog("compare_semver: semver1: " + str(semver1) + " semver2" + str(semver2),2)
	var semver1data = get_semver_data(semver1)
	var semver2data = get_semver_data(semver2)

	if semver1data == null || semver2data == null : return false

	if semver1data["major"] != semver2data["major"]:
		return semver1data["major"] < semver2data["major"]
	if semver1data["minor"] != semver2data["minor"]:
		return semver1data["minor"] < semver2data["minor"]
	if semver1data["patch"] != semver2data["patch"]:
		return semver1data["major"] < semver2data["major"]
	
	return false

# Parse the semver string
func get_semver_data(semver: String):

	var data = {}

	if semver.split(".").size() < 3: return null

	return {
		"major": int(semver.split(".")[0]),
		"minor": int(semver.split(".")[1]),
		"patch": int(semver.split(".")[2].split("-")[0])
	}

#########################################################################################################
##
## MAIN FUNCTIONS
##
#########################################################################################################

# Function to update the config label
func update_config_label(value, label: Label):

	label.text =  "%0.1f" % value

# Main Script
func start() -> void:

	outputlog("Wall Shapes Mod Has been loaded.")

	ui_config = {}

	make_wall_shapes_ui("WallTool")
	make_wall_shapes_ui("PathTool")

	create_tooltips()

	# If _Lib is installed then register with it
	if Engine.has_signal("_lib_register_mod"):
		# Register this mod with _lib
		Engine.emit_signal("_lib_register_mod", self)
		var shortcut_definitions = { "Key to reverse Circle Arc direction": ["reverse_circle_arc","65"] }
		Global.API.InputMapApi.add_actions(shortcut_definitions)
		# Create a config builder to ensure we can update the offset if needed
		var _lib_config_builder = Global.API.ModConfigApi.create_config()
		_lib_mod_config = _lib_config_builder\
			.shortcuts("shortcuts",shortcut_definitions)\
			.h_box_container().enter()\
				.label("Rectangle Offset Value (in sq) ")\
				.label().ref("slider_label")\
				.label(" ")\
				.h_slider("rectangle_offset_slider",0.1)\
					.with("max_value",2)\
					.with("min_value",0.1)\
					.with("step",0.1)\
					.connect_current("loaded", self, "update_config_label", [_lib_config_builder.get_ref("slider_label")])\
					.connect_current("value_changed", self, "update_config_label", [_lib_config_builder.get_ref("slider_label")])\
					.size_flags_h(Control.SIZE_EXPAND_FILL)\
					.size_flags_v(Control.SIZE_FILL)\
			.exit()\
			.h_box_container().enter()\
				.label("Core Log Level ")\
				.option_button("core_log_level", 0, ["0","1","2","3","4"])\
			.exit()\
			.build()

		update_config_label(float(_lib_mod_config.rectangle_offset_slider),_lib_config_builder.get_ref("slider_label"))
		logging_level = int(_lib_mod_config.core_log_level)
		var _lib_mod_meta = Global.API.ModRegistry.get_mod_info("CreepyCre._Lib").mod_meta
		if _lib_mod_meta != null:
			if compare_semver("1.1.2", _lib_mod_meta["version"]):
				var update_checker = Global.API.UpdateChecker
				
				update_checker.register(Global.API.UpdateChecker.builder()\
														.fetcher(update_checker.github_fetcher("uchideshi34", "WallShapes"))\
														.downloader(update_checker.github_downloader("uchideshi34", "WallShapes"))\
														.build())
	
	Global.Editor.Windows["Preferences"].find_node("SaveButton").connect("pressed", self, "on_preferences_applied")
	update_tooltips_with_mod_config()
		

	

