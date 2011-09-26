field_click_1 = false

class NodeBase 
  constructor: (@x, @y) ->
    @nid = get_uid()
    @container = $("#container")
    @out_connections = []
    @node_fields = {}
    @node_fields.inputs = {}
    @node_fields.outputs = {}
    @node_fields_by_name = {}
    @node_fields_by_name.inputs = {}
    @node_fields_by_name.outputs = {}
    @value = false
    @name = false
    @main_view = false
    @updated = false
    @init()
    
  typename: => "Node"
  
  
  has_out_connection: () =>
    @out_connections.length != 0
  
  update_inputs: =>
    for f of @node_fields.inputs
      @node_fields.inputs[f].update_input_node()
  
  compute: () =>
    @value = @value
  
  update: () =>
    if @updated == true
      return true
    @updated = true
    # update all input fields ( if they have connections they take care themselft to update their source node)
    @update_inputs()
    # update node output values based on inputs
    @compute()
  
  get_in: (n) =>
    @node_fields_by_name.inputs[n]
  
  get_out: (n) =>
    @node_fields_by_name.outputs[n]
  
  apply_fields_to_val: (afields, target) =>
    for f of afields
      nf = afields[f]
      if nf.name != "children"
        target[nf.name] = @get_in(nf.name).val
  
  create_field_from_default_type: (fname, default_value) ->
    ftype = switch $.type(default_value)
      when "number" then "Float"
      when "boolean" then "Bool"
      else "String"
    new fields.types[ftype](fname, default_value)
  
  addFields: (fields_array) =>
    for dir of fields_array
      # dir = inputs / outputs
      for fname of fields_array[dir]
        k = fields_array[dir][fname]
        f = false
        if $.type(k) == "object"
          f = new fields.types[k.type](fname, k.val)
        else
          f = @create_field_from_default_type(fname, k)
        if dir == "inputs"
          @addInput(f)
        else
          @addOutput(f)
    false
    
  addInput: (field) =>
    field.node = this
    @node_fields.inputs["fid-" + field.fid] = field
    @node_fields_by_name.inputs[field.name] = field
    $(".inputs", @main_view).append(field.render_button())
    @add_field_listener($("#fid-#{field.fid}"))
    field
  
  addOutput: (field) =>
    field.node = this
    field.is_output = true
    @node_fields.outputs["fid-" + field.fid] = field
    @node_fields_by_name.outputs[field.name] = field
    $(".outputs", @main_view).append(field.render_button())
    @add_field_listener($("#fid-#{field.fid}"))
    field
  
  add_center_textfield: (field) =>
    $(".options .center", @main_view).append("<div><input type='text' id='f-txt-input-#{field.fid}' /></div>")
    f_in = $("#f-txt-input-#{field.fid}")
    field.signal.add (v) ->
      f_in.val(v.toString().substring(0, 10))
    f_in.val(field.val)
    if field.is_output == true
      f_in.attr("disabled", "disabled")
    else
      f_in.keypress (e) ->
        if e.which == 13
          field.signal.dispatch($(this).val())
          $(this).blur()

  create_field_connection: (field) =>
    f = this
    if field_click_1 == false
      field_click_1 = field
      $(".inputs .field").filter () ->
        $(this).parent().parent().parent().attr("id") != "nid-#{f.nid}"
      .addClass "field-target"
    else
      field_click_2 = field
      new NodeConnection(field_click_1, field_click_2)
      $(".field").removeClass "field-target"
      field_click_1 = false
      
  add_field_listener: ($field) =>
    self = this
    f_name = $field.attr("id")
    f_type = $field.parent().attr("class")
    field = @node_fields[f_type][f_name]
    $field.click (e) ->
      e.preventDefault()
      if e.shiftKey == true
        field.remove_connections()
      else
        self.create_field_connection(field)
  
  add_out_connection: (c, field) =>
    if @out_connections.indexOf(c) == -1
      @out_connections.push(c)
      
  remove_connection: (c) =>
    c_index = @out_connections.indexOf(c)
    if c_index != -1
      @out_connections.splice(c_index, 1)
      
  init: () =>
    n = this
    @container.append "<div id='nid-#{@nid}' class='node node-#{@typename()}'><div class='head'>#{@typename()}</div><div class='options'><div class='inputs'></div><div class='center'></div><div class='outputs'></div></div></div>"
    @main_view = $("#nid-#{@nid}")
    @main_view.css
      left: @x
      top: @y
    @main_view.draggable
      drag: () ->
        render_connections()
      stop: () ->
        render_connections()
    $(".head", @main_view).dblclick (e) ->
      $(".options", n.main_view).animate {height: 'toggle'}, 120, () ->
        render_connections()

class NodeNumberSimple extends NodeBase
  constructor: (x, y) ->
    super x, y
    @value = 0
    @v_in = @addInput(new fields.types.Float("in", 0))
    @v_out = @addOutput(new fields.types.Float("out", 0))
  
  process_val: (num, i) =>
    num
  
  compute: =>
    res = false
    switch $.type(@v_in.val)
      when "array" then res = _.map(@v_in.val, (n, i) -> @process_val(n, i))
      else res = @process_val(@v_in.val, 0)
    if @v_out.val != res
      @v_out.set res
    true

class nodes.types.Base.Number extends NodeNumberSimple
  constructor: (x, y) ->
    super x, y
    @add_center_textfield(@v_in)
  
  typename : => "Number"

class nodes.types.Base.String extends NodeBase
  constructor: (x, y) ->
    super x, y
    @value = ""
    @addFields
      inputs:
        "string": ""
      outputs:
        "out": {type: "Any", val: @ob}
  compute: =>
    @get_out("out").set @get_in("string")
  typename : => "String"

class nodes.types.Math.Sin extends NodeNumberSimple
  constructor: (x, y) ->
    super x, y
  process_val: (num, i) =>
    Math.sin(num)
  typename : => "Sin"

class nodes.types.Math.Cos extends NodeNumberSimple
  constructor: (x, y) ->
    super x, y
  process_val: (num, i) =>
    Math.cos(num)
  typename : => "Cos"

class nodes.types.Math.Tan extends NodeNumberSimple
  constructor: (x, y) ->
    super x, y
  process_val: (num, i) =>
    Math.tan(num)
  typename : => "Tan"

class nodes.types.Math.Round extends NodeNumberSimple
  constructor: (x, y) ->
    super x, y
  process_val: (num, i) =>
    Math.round(num)
  typename : => "Round"

class nodes.types.Math.Mult extends NodeNumberSimple
  constructor: (x, y) ->
    super x, y
    @v_factor = @addInput(new fields.types.Float("factor", 2))
  process_val: (num, i) =>
    num * @v_factor.val
  typename : => "Mult"

class nodes.types.Math.Max extends NodeNumberSimple
  constructor: (x, y) ->
    super x, y
    @v_inb = @addInput(new fields.types.Float("in2", 0))
  process_val: (num, i) =>
    Math.max(num, @v_inb.val)
  typename : => "Max"

class nodes.types.Math.Min extends NodeNumberSimple
  constructor: (x, y) ->
    super x, y
    @v_inb = @addInput(new fields.types.Float("in2", 0))
  process_val: (num, i) =>
    Math.min(num, @v_inb.val)
  typename : => "Min"

class nodes.types.Utils.Random extends NodeBase
  constructor: (x, y) ->
    super x, y
    @addFields
      inputs:
        "min" : 0
        "max" : 1
      outputs:
        "out" : 0
    @add_center_textfield(@get_out("out"))

  compute: =>
    old = @get_out("out").val
    @value = @get_in("min").val + Math.random() * (@get_in("max").val - @get_in("min").val)
    if @value != old
      @get_out("out").set @value
  typename : => "Random"

class nodes.types.Utils.Merge extends NodeBase
  constructor: (x, y) ->
    super x, y
    @addFields
      inputs:
        "in0" : {type: "Any", val: null}
        "in1" : {type: "Any", val: null}
        "in2" : {type: "Any", val: null}
        "in3" : {type: "Any", val: null}
        "in4" : {type: "Any", val: null}
        "in5" : {type: "Any", val: null}
      outputs:
        "out" : {type: "Array", val: []}

  compute: =>
    old = @get_out("out").val
    @value = []
    for f of @node_fields.inputs
      k = @node_fields.inputs[f]
      if k.val != null
        @value[@value.length] = k.val
    if @value != old
      @get_out("out").set @value
  typename : => "Merge"

class nodes.types.Utils.Get extends NodeBase
  constructor: (x, y) ->
    super x, y
    @addFields
      inputs:
        "array" : {type: "Array", val: null}
        "index" : 0
      outputs:
        "out" : {type: "Any", val: null}

  compute: =>
    old = @get_out("out").val
    @value = false
    arr = @get_in("array").val
    ind = parseInt(@get_in("index").val)
    if $.type(arr) == "array"
      @value = arr[ind % arr.length]
    if @value != old
      @get_out("out").set @value
  typename : => "Get"

class nodes.types.Utils.Timer extends NodeBase
  constructor: (x, y) ->
    super x, y
    @old = @get_time()
    @counter = 0
    @addFields
      inputs:
        "reset" : false
        "pause" : false
        "max" : 99999999999
      outputs:
        "out" : 0
    
    @add_center_textfield(@get_out("out"))
  
  get_time: => new Date().getTime()
    
  compute: =>
    oldval = @get_out("out").val
    now = @get_time()
    if @get_in("pause").val == false
      @counter += now - @old
    if @get_in("reset").val == true
      @counter = 0
    
    diff = @get_in("max").val - @counter
    if diff <= 0
      #@counter = diff * -1
      @counter = 0
    @old = now

    #if @counter != oldval
    @get_out("out").set @counter
  typename : => "Timer"

class nodes.types.Base.Vector2 extends NodeBase
  constructor: (x, y) ->
    super x, y
    @vec = new THREE.Vector2(0, 0)
    @addFields
      inputs:
        "xy" : {type: "Vector2", val: false}
        "x" : 0
        "y" : 0
      outputs:
        "xy" : {type: "Vector2", val: false}
        "x" : 0
        "y" : 0
  
  compute: =>
    old = @get_out("xy").val
    @value = @get_in("xy").val
    if @get_in("xy").connections.length == 0
      @value = new THREE.Vector2(@get_in("x").val, @get_in("y").val)
    if @value != old
      #@v_out.signal.dispatch @value
      @get_out("xy").set @value
      @get_out("x").set @value.x
      @get_out("y").set @value.y
  typename : -> "Vector2"

class nodes.types.Base.Vector3 extends NodeBase
  constructor: (x, y) ->
    super x, y
    @vec = new THREE.Vector3(0, 0, 0)
    @addFields
      inputs:
        "xyz" : {type: "Vector3", val: false}
        "x" : 0
        "y" : 0
        "z" : 0
      outputs:
        "xyz" : {type: "Vector3", val: false}
        "x" : 0
        "y" : 0
        "z" : 0
  
  compute: =>
    old = @get_out("xyz").val
    @value = @get_in("xyz").val
    if @get_in("xyz").connections.length == 0
      #@vec.set @v_in_x.val, @v_in_y.val, @v_in_z.val
      #@value = @vec
      @value = new THREE.Vector3(@get_in("x").val, @get_in("y").val, @get_in("z").val)
    if @value != old
      #@v_out.signal.dispatch @value
      @get_out("xyz").set @value
      @get_out("x").set @value.x
      @get_out("y").set @value.y
      @get_out("z").set @value.z
  typename : -> "Vector3"

class nodes.types.Base.Color extends NodeBase
  constructor: (x, y) ->
    super x, y
    @vec = new THREE.Color(1, 0, 0)
    @addFields
      inputs:
        "rgb": {type: "Color", val: false}
        "r": 0
        "g": 0
        "b": 0
      outputs:
        "rgb": {type: "Color", val: false}
        "r": 0
        "g": 0
        "b": 0
  
  compute: =>
    old = @get_out("rgb").val
    @value = @get_in("rgb").val
    if @get_in("rgb").connections.length == 0
      @value = new THREE.Color(@get_in("r").val, @get_in("g").val, @get_in("b").val)
    if @value != old
      @get_out("rgb").set @value
      @get_out("r").set @value.x
      @get_out("g").set @value.y
      @get_out("b").set @value.z
  typename : -> "Color"

class nodes.types.Geometry.CubeGeometry extends NodeBase
  constructor: (x, y) ->
    super x, y
    @ob = new THREE.CubeGeometry(100, 100, 100, 1, 1, 1)
    #@value = 0
    @addFields
      inputs:
        "materials": {type: "Array", val: []}
        "flip": -1
        "position": {type: "Vector3", val: new THREE.Vector3()}
        "rotation": {type: "Vector3", val: new THREE.Vector3()}
        "scale": {type: "Vector3", val: new THREE.Vector3(1, 1, 1)}
        "doubleSided": false
        "visible": true
      outputs:
        "out": {type: "Any", val: @ob}

  compute: =>
    @apply_fields_to_val(@node_fields.inputs, @ob)
    @get_out("out").set @ob
  typename : => "CubeGeometry"

class nodes.types.Three.Object3D extends NodeBase
  constructor: (x, y) ->
    super x, y
    @ob = new THREE.Object3D()
    @addFields
      inputs:
        "children": {type: "Array", val: []}
        "position": {type: "Vector3", val: new THREE.Vector3()}
        "rotation": {type: "Vector3", val: new THREE.Vector3()}
        "scale": {type: "Vector3", val: new THREE.Vector3(1, 1, 1)}
        "doubleSided": false
        "visible": true
      outputs:
        "out": {type: "Any", val: @ob}

  compute: =>
    @apply_fields_to_val(@node_fields.inputs, @ob)
    for child in @get_in("children").val
      ind = @ob.children.indexOf(child)
      if ind == -1
        @ob.addChild(child)
    for child in @ob.children
      ind = @get_in("children").val.indexOf(child)
      if ind != -1
        @ob.removeChild(child)
    @get_out("out").set @ob
  typename : => "Object3D"
  
class nodes.types.Three.Scene extends nodes.types.Three.Object3D
  constructor: (x, y) ->
    super x, y
    @ob = new THREE.Scene()

  compute: =>
    @apply_fields_to_val(@node_fields.inputs, @ob)
    childs_in = @get_in("children").val
    # remove old childs
    for child in @ob.children
      ind = childs_in.indexOf(child)
      if ind == -1
        @ob.removeChild(child)
    
    #add new childs
    for child in childs_in
      ind = @ob.children.indexOf(child)
      if ind == -1
        console.log child
        @ob.addChild(child)
    @get_out("out").set @ob
  typename : => "Scene"

class nodes.types.Three.Mesh extends nodes.types.Three.Object3D
  constructor: (x, y) ->
    super x, y
    @ob = new THREE.Mesh(new THREE.CubeGeometry( 200, 200, 200 ), new THREE.MeshBasicMaterial( { color: 0xff0000, wireframe: true }))
    @addFields
      inputs:
        #"geometry": {type: "Any", val: new THREE.CubeGeometry( 200, 200, 200 )}
        "materials": {type: "Any", val: [new THREE.MeshBasicMaterial( { color: 0xff0000, wireframe: true })]}
        "overdraw": false
    @get_out("out").set @ob

  compute: =>
    @apply_fields_to_val(@node_fields.inputs, @ob)
    @get_out("out").set @ob
  typename : => "Mesh"

class nodes.types.Three.Camera extends NodeBase
  constructor: (x, y) ->
    super x, y
    @ob = new THREE.Camera()
    @addFields
      inputs:
        "fov": 50
        "aspect": 1
        "near": 0.1
        "far": 2000
        "position": {type: "Vector3", val: new THREE.Vector3()}
        "target": {type: "Object3D", val: new THREE.Object3D()}
        "useTarget": false
      outputs:
        "out": {type: "Any", val: @ob}

  compute: =>
    @apply_fields_to_val(@node_fields.inputs, @ob)
    @get_out("out").set @ob
  typename : => "Camera"

class nodes.types.Three.WebGLRenderer extends NodeBase
  constructor: (x, y) ->
    super x, y
    @ob = new THREE.WebGLRenderer()
    @addFields
      inputs:
        "width": 800
        "height": 600
        "scene": {type: "Scene", val: new THREE.Scene()}
        "camera": {type: "Camera", val: new THREE.Camera(75, 800 / 600, 1, 10000)}
      outputs:
        "out": {type: "Any", val: @ob}
    @apply_size()
    @get_in("camera").val.position.z = 1000
    
    @win = window.open('', 'win' + @nid, "width=800,height=600,scrollbars=false")
    @win.document.body.appendChild( @ob.domElement );
  
  apply_size: =>
    @ob.setSize(@get_in("width").val, @get_in("height").val)
    
  compute: =>
    @apply_size()
    
    sce = @get_in("scene").val
    cam = @get_in("camera").val
    #if sce != false && cam != false
    @ob.render(sce, cam)
    #@get_out("out").set @ob
  typename : => "WebGLRenderer"

class nodes.types.Three.PointLight extends NodeBase
  constructor: (x, y) ->
    super x, y
    @ob = new THREE.PointLight(0xffffff)
    @addFields
      inputs:
        "color": {type: "Color", val: new THREE.Color(1, 1, 1)}
        "position": {type: "Vector3", val: new THREE.Vector3()}
        "intensity": 1
        "distance": 0
      outputs:
        "out": {type: "Any", val: @ob}

  compute: =>
    @apply_fields_to_val(@node_fields.inputs, @ob)
    @get_out("out").set @ob
  typename : => "PointLight"

class nodes.types.Materials.MeshBasicMaterial extends NodeBase
  constructor: (x, y) ->
    super x, y
    @ob = new THREE.MeshBasicMaterial({color: 0xff0000})
    @addFields
      inputs:
        "color": {type: "Color", val: new THREE.Color(1, 0, 0)}
        "reflectivity": 1
        "refractionRatio": 0.98
        "wireframe": false
        "wireframeLinecap": 1
        "vertexColors": false
        "skinning": false
      outputs:
        "out": {type: "Any", val: @ob}
  
  compute: =>
    @apply_fields_to_val(@node_fields.inputs, @ob)
    @get_out("out").set @ob
  typename : => "MeshBasicMaterial"



