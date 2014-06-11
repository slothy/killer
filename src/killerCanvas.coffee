class Rectangle

  constructor: (@x, @y, @w, @h) ->

  toString: -> "{ x: #{@x}, y: #{@y}, w: #{@w}, h:#{@h} }"

  innerRect: (inset) -> new Rectangle @x + inset, @y + inset, @w - (2 * inset), @h - (2 * inset)

  middle: ->
      x: @x + (@w / 2)
      y: @y + (@h / 2)


class KillerCanvas

  MAJOR_GRID_LINE:       3
  MINOR_GRID_LINE:       1
  REGION_INSET:          5
  REGION_SUM_INSET:      3
  COLOR_FOR_GRID_LINES:  'black'
  COLOR_FOR_REGIONS:     'darkgreen'
  COLOR_FOR_FOCUS:       'yellow'
  COLOR_FOR_ENTRIES:     'darkblue'
  COLOR_FOR_BAD_ENTRIES: 'darkred'
  FONT:                  'Helvetica Neue'

  constructor: (@canvasElement) ->
    @canvas = @canvasElement[0]
    @size = @canvas.width
    console.log "The canvas ain't square you bozo - this won't render very well" unless @canvas.width is @canvas.height

    @ctx = @canvas.getContext "2d"
    @hasFocus = false

    @model undefined

    @canvasElement.mousemove @_mouseMove
    @canvasElement.keydown @_keyPress
    @canvasElement.focusin =>
      @hasFocus = true
      @redraw()
    @canvasElement.focusout =>
      @hasFocus = false
      @redraw()
    @canvasElement.mouseenter =>
      @canvasElement.focus()

  model: (@killer) ->
    @focusCell = @killer?.cellAt 0, 0
    @killer?.changeListeners.push this
    @redraw()

  redraw: (checkForCompletion = false) =>
    if checkForCompletion and @killer?.isComplete()
      @ctx.fillStyle = "darkgreen"
      @ctx.fillRect 0, 0, @size, @size
      @ctx.fillStyle = "#EEEEEE"
      @ctx.font = "40px #{@FONT}"
      @ctx.textAlign = 'center'
      @ctx.textBaseline = 'middle'
      rect = new Rectangle 0, 0, @size, @size
      @ctx.fillText "You did it!!!", rect.middle().x, rect.middle().y
      console.log "Although that is not the exact solution I had in mind..." unless @killer.isCompleteWithPreordainedEntries()
    else
      @ctx.setLineDash [1000]
      @ctx.fillStyle = "white"
      @ctx.fillRect 0, 0, @size, @size
      if not @killer?
        @_drawGridLines 9, @COLOR_FOR_GRID_LINES, @MINOR_GRID_LINE
        @_drawGridLines 3, @COLOR_FOR_GRID_LINES, @MAJOR_GRID_LINE
      else
        @_drawGridLines @killer.size, @COLOR_FOR_GRID_LINES, @MINOR_GRID_LINE
        @_drawGridLines Math.sqrt(@killer.size), @COLOR_FOR_GRID_LINES, @MAJOR_GRID_LINE
        @_assignCellBounds()
        @_drawRegions()
        @_drawFocus() if @hasFocus
        @_drawRegionSums()
        @_drawEntries()

  _assignCellBounds: ->
    w = h = @size / @killer.size
    for row in [0...@killer.size]
      for col in [0...@killer.size]
        cell = @killer.cellAt row, col
        cell.bounds = new Rectangle col * w, row * h, w, h

  _drawGridLines: (numberOfGridLines, strokeStyle, lineWidth) =>
    @ctx.strokeStyle = strokeStyle
    @ctx.lineWidth = lineWidth
    @ctx.beginPath()
    for index in [0..numberOfGridLines]
      x = y = Math.floor index * (@size / numberOfGridLines)
      @ctx.moveTo x, 0
      @ctx.lineTo x, @size
      @ctx.moveTo 0, y
      @ctx.lineTo @size, y
    @ctx.stroke()
    @ctx.closePath()

  _drawRegions: ->
    line = (x1, y1, x2, y2) =>
      @ctx.moveTo x1, y1
      @ctx.lineTo x2, y2
    more = (cell, movement) =>
      if cell.region.contains cell[movement]()
        (2 * @REGION_INSET)
      else
        0
    @ctx.strokeStyle = @COLOR_FOR_REGIONS
    @ctx.setLineDash [1]
    @ctx.lineWidth = 1
    @ctx.beginPath()
    for row in [0...@killer.size]
      for col in [0...@killer.size]
        cell = @killer.cellAt row, col
        rect = cell.bounds.innerRect @REGION_INSET
        x1 = rect.x
        y1 = rect.y
        x2 = rect.x + rect.w
        y2 = rect.y + rect.h
        unless cell.region.contains cell.up()
          line x1 - more(cell, 'left'), y1, x2 + more(cell, 'right'), y1
        unless cell.region.contains cell.right()
          line x2, y1 - more(cell, 'up'), x2, y2 + more(cell, 'down')
        unless cell.region.contains cell.down()
          line x1 - more(cell, 'left'), y2, x2 + more(cell, 'right'), y2
        unless cell.region.contains cell.left()
          line x1, y1 - more(cell, 'up'), x1, y2 + more(cell, 'down')
    @ctx.stroke()
    @ctx.closePath()

  _drawRegionSums: () ->
    @ctx.fillStyle = @COLOR_FOR_REGIONS
    @ctx.font = "bold 12px #{@FONT}"
    @ctx.textAlign = 'left'
    @ctx.textBaseline = 'top'
    for region in @killer.regions
      cell = region.cells[0]
      rect = cell.bounds.innerRect @REGION_INSET + @REGION_SUM_INSET
      @ctx.fillText cell.region.sum(), rect.x, rect.y

  _drawFocus: () ->
    if @focusCell?
      rect = @focusCell.bounds.innerRect 1.5 * @REGION_INSET
      @ctx.fillStyle = @COLOR_FOR_FOCUS
      @ctx.fillRect rect.x, rect.y, rect.w, rect.h

  _drawEntries: () ->
    fontSize = (numEntries) =>
      if numEntries is 1
        24
      else if numEntries < 5
        13
      else
        10
    @ctx.textBaseline = 'middle'
    for row in [0...@killer.size]
      for col in [0...@killer.size]
        cell = @killer.cellAt row, col
        if cell.entries.length > 0
          if cell.flaggedAsDodgy is true
            @ctx.fillStyle = @COLOR_FOR_BAD_ENTRIES
          else
            @ctx.fillStyle = @COLOR_FOR_ENTRIES
          @ctx.font = "#{fontSize(cell.entries.length)}px #{@FONT}"
          x = cell.bounds.middle().x - (@ctx.measureText(cell.entriesAsString()).width / 2)
          y = cell.bounds.middle().y
          @ctx.fillText cell.entriesAsString(), x, y


  _mouseMove: (evt) =>
    return false unless @killer?
    rect = @canvas.getBoundingClientRect()
    x = evt.clientX - rect.left
    y = evt.clientY - rect.top
    row = Math.floor (y * (@killer.size / @size))
    col = Math.floor (x * (@killer.size / @size))
    cell = @killer.cellAt row, col
    if cell isnt @focusCell
      @focusCell = cell
      @redraw()

  _verify: ->
    for cell in @killer.cells
      cell.flaggedAsDodgy = cell.entries.length > 0 and cell.value not in cell.entries

  # callback via Sudoku.ChangeListener
  changed: (sudoku, cell) ->
    cell.flaggedAsDodgy = false

  _keyPress: (evt) =>
    if @focusCell?
      value = String.fromCharCode(evt.keyCode)
      if evt.keyCode in [49..57]
        @focusCell.enter parseInt(value), evt.shiftKey
        @redraw(true)
      else if evt.keyCode in [37..40]
        movement = {37: 'left', 38: 'up', 39: 'right', 40: 'down'}[evt.keyCode]
        if @focusCell[movement]()?
          @focusCell = @focusCell[movement]()
          @redraw()
      else if value is 'C'
        @focusCell.entries.length = 0
        @redraw()
      else if value is 'Z'
        @killer.undo()
        @redraw()
      else if value is 'Y'
        @killer.redo()
        @redraw()
      else if value is 'V'
        @_verify()
        @redraw()
      else if @keyPressHandler? and @focusCell?
        @keyPressHandler value, @focusCell
      else
        false


root = exports ? window
root.KillerCanvas = KillerCanvas
