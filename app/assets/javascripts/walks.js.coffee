# This creates and initializes a walk map, as well as provides
# functions to add and edit waypoints

class window.SanpoMap
  # Default options
  # TODO: get sensible defaults for centerLat/Lng
  options:
    waypoints: []
    centerLat: null
    centerLng: null
    isNewWalk: false

  constructor: (options) ->
    # If we get passed an options object, set options accordingly
    # Options that haven't been explicitly set use the default values
    if options
      if options.waypoints
        @options.waypoints = options.waypoints
      if options.centerLat
        @options.centerLat = options.centerLat
      if options.centerLng
        @options.centerLng = options.centerLng
      if options.isNewWalk
        @options.isNewWalk = options.isNewWalk

    # Initialize the map itself
    @centerPoint = new google.maps.LatLng(@options.centerLat, @options.centerLng)
    mapOptions =
      zoom: 17
      center: @centerPoint
      mapTypeId: google.maps.MapTypeId.ROADMAP
      panControl: false
      scrollwheel: false
      streetViewControl: false
      zoomControlOptions:
        position: google.maps.ControlPosition.LEFT_CENTER
    @map = new google.maps.Map(document.getElementById('map_canvas'), mapOptions)

    # Initialize the polyline to draw our route
    polyOptions =
      strokeColor: '#00f'
      strokeOpacity: 0.5
      strokeWeight: 5
    @poly = new google.maps.Polyline(polyOptions)
    @poly.setMap(@map)

    # if a path already exists, build it here
    if @options.waypoints.length > 0
      @addLatLngToPath(new google.maps.LatLng(waypoint.lat, waypoint.lon)) for waypoint in @options.waypoints

    # Keep track of changes to walk so that we only update the db if needed
    @walkChanged = false

    # If this is a new walk form, we should switch to edit mode right away
    if @options.isNewWalk
      @setEditMode(true)

    # Handle clicks on the edit button
    $('#map_controls .editButton').click (event) =>
      @toggleEditMode()
      event.stopPropagation()
      event.preventDefault()

  mapClickHandler: (event) =>
    @addLatLngToPath(event.latLng)

  # Add a vertex to the polyline. If we're in edit mode, also add the draggable handler
  addLatLngToPath: (latLng) ->
    path = @poly.getPath()
    path.push(latLng)
    if @editMode
      @createMarkerVertex(latLng).editIndex = path.getLength() - 1
      @walkChanged = true
    console.log "path: #{path.b.toString()}"

  toggleEditMode: ->
    @setEditMode(!@editMode)

  # Check if we're not going into edit mode twice by mistake
  setEditMode: (editMode = true) ->
    if editMode != @editMode
      @editMode = editMode
      if @editMode
        @startEditMode()
      else
        @stopEditMode()
    else
      console.log "Requested mode already active, not setting again"

  startEditMode: =>
    @createMarkers()
    console.log "Starting edit mode"

    google.maps.event.addListener(@map, 'click', @mapClickHandler)
    @map.draggableCursor = 'crosshair'
    @map.draggingCursor = 'move'
    $('#map_container').addClass 'editMode'
    $('.editButton').removeClass('primary').addClass('danger').text("Save the changes")

  stopEditMode: =>
    @clearMarkers()
    console.log "Stopping edit mode"

    google.maps.event.clearListeners(@map, 'click')
    @map.draggableCursor = 'auto'
    @map.draggingCursor = 'auto'
    $('#map_container').removeClass 'editMode'
    $('.editButton').removeClass('danger').addClass('primary').text("Edit the route")

    @saveUpdatedPath()

  # Save waypoints to the form (if new walk) or to the db (if updating a walk)
  saveUpdatedPath: ->
    console.log "Saving the path: #{@poly.getPath().b.toString()}"
    if @options.isNewWalk
      console.log "This is a new walk: saving waypoints into the form"
      $('#waypoints_container').html('')
      @poly.getPath().forEach (vertex, index) ->
        $('#waypoints_container').append(
          "<input type='hidden' id='walk_waypoints_#{index}_lat' name='walk[waypoints][#{index}][lat]' value='#{vertex.lat()}' />" \
          + "<input type='hidden' id='walk_waypoints_#{index}_lng' name='walk[waypoints][#{index}][lng]' value='#{vertex.lng()}' />"
        )
    else if @walkChanged
      console.log "Updating a walk: sending an ajax update request"
    else
      console.log "No changes!"

  #
  # ------------- Vertex management --------------------------------------------------
  #
  createMarkers: ->
    @poly.getPath().forEach (vertex, index) =>
      @createMarkerVertex(vertex).editIndex = index

  clearMarkers: ->
    @poly.getPath().forEach (vertex, index) ->
      if vertex.marker
        vertex.marker.setMap(null)
        vertex.marker = undefined

  createMarkerVertex: (point) ->
    vertex = point.marker
    if !vertex
      vertex = new google.maps.Marker(
        position: point
        map: @map
        icon: @vertexImage
        draggable: true
        raiseOnDrag: false
        self: this # OMG, this is the ugliest thing ever
      )
      google.maps.event.addListener(vertex, "mouseover", @vertexMouseOver)
      google.maps.event.addListener(vertex, "mouseout", @vertexMouseOut)
      google.maps.event.addListener(vertex, "drag", @vertexDrag)
      google.maps.event.addListener(vertex, "dragend", @vertexDragEnd)
      google.maps.event.addListener(vertex, "rightclick", @vertexRightClick)
      point.marker = vertex
      return vertex
    vertex.setPosition(point)

  vertexImage: new google.maps.MarkerImage(
    '/assets/vertex.png',
    new google.maps.Size(16, 16),
    new google.maps.Point(0, 0),
    new google.maps.Point(8, 8)
  )

  vertexOverImage: new google.maps.MarkerImage(
    '/assets/vertex_over.png',
    new google.maps.Size(16, 16),
    new google.maps.Point(0, 0),
    new google.maps.Point(8, 8)
  )

  vertexMouseOver: ->
    this.setIcon(this.self.vertexOverImage)

  vertexMouseOut: ->
    this.setIcon(this.self.vertexImage)

  vertexDrag: ->
    vertex = this.getPosition()
    vertex.marker = this
    this.self.poly.getPath().setAt(this.editIndex, vertex)
    this.self.walkChanged = true

  vertexDragEnd:  ->
    console.log "ending drag - path: #{this.self.poly.getPath().b.toString()}"

  vertexRightClick: ->
    console.log "vertexRightClick"
