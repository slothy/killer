do -> Array::shuffle ?= ->
  for i in [@length-1..1]
    j = Math.floor Math.random() * (i + 1)
    [@[i], @[j]] = [@[j], @[i]]
  @

class Sudoku

  constructor: (values) ->

    @size = Math.sqrt(values.length)
    throw new Error "That's not a valid square you bozo" unless Math.round(@size) is @size
    @root = Math.sqrt @size
    throw new Error "That's not a valid square square you bozo" unless Math.round(@root) is @root

    @validValues = [0...@size].map (value) => value + 1

    @cells = []
    @rows = []
    @cols = []
    @boxes = []

    for blockType in ['rows', 'cols', 'boxes']
      for index in [0...@size]
        @[blockType].push new CellBlock

    for row in [0...@size]
      for col in [0...@size]
        index = (row * @size) + col
        throw new Error "Invalid value '#{values[index]}' at row #{row} column #{col}" unless values[index] in @validValues or values[index] is null
        cell = new Cell this, row, col, values[index]
        @cells.push cell
        @rows[row].push cell
        @cols[col].push cell
        boxIndex = (Math.floor(row / @root) * @root) + Math.floor(col / @root)
        @boxes[boxIndex].push cell

  cellAt: (row, col) -> @cells[(row * @size) + col]

  values: -> @cells.map (cell) => cell.value

  isComplete: ->
    for cell in @cells
      return false unless cell.hasCorrectEntry()
    true

class CellBlock

  constructor: -> @cells = []

  push: (cell) ->
    throw new Error "Duplicate value '#{cell.value}' at row #{cell.row} column #{cell.col}" if cell.value in @values() and cell.value isnt null
    @cells.push cell
    cell.blocks.push this

  values: -> @cells.map (cell) => cell.value

  sum: -> @values().reduce (x,y) -> x + y

  entries: ->
    entries = []
    for cell in @cells
      entries.push cell.entry() if cell.entry()?
    entries

class Cell

  constructor: (@sudoku, @row, @col, @value) ->
    @entries = []
    @blocks = []

  index: -> (@row * @sudoku.size) + @col

  isNextTo: (cell) ->
    rowDiff = Math.abs(@row - cell.row)
    colDiff = Math.abs(@col - cell.col)
    (rowDiff is 1 and colDiff is 0) or (rowDiff is 0 and colDiff is 1)

  up:    -> @sudoku.cellAt @row - 1, @col
  down:  -> @sudoku.cellAt @row + 1, @col
  left:  -> @sudoku.cellAt @row,     @col - 1 unless @col == 0
  right: -> @sudoku.cellAt @row,     @col + 1 unless @col >= (@sudoku.size - 1)

  enter: (value) ->
    if value in @sudoku.validValues
      if value in @entries
        @entries = @entries.filter (e) -> e isnt value
      else
        @entries.push value

  entriesAsString: () -> @entries.join ''

  entry: -> @entries[0] if @entries.length is 1

  hasCorrectEntry: -> @entry() is @value

  availableValues: ->
    allValues = @sudoku.validValues[0..@sudoku.validValues.length]
    for block in @blocks
      for cell in block.cells
        unless cell is this
          allValues = allValues.filter (e) -> e isnt cell.value
    allValues

  availableEntries: ->
    allValues = @sudoku.validValues[0..@sudoku.validValues.length]
    for block in @blocks
      for cell in block.cells
        unless cell is this
          allValues = allValues.filter (e) -> e isnt cell.entry()
    allValues

  toString: -> "#{@row},#{@col}:#{@value}"

class Killer extends Sudoku

  constructor: (values, regionIds) ->
    super values
    throw new Error "Incorrect number of regions you bozo" unless regionIds.length is @cells.length
    @regions= []
    for regionId,index in regionIds
      row = Math.floor(index / @size)
      col = index % @size
      cell = @cellAt row, col
      region = (@regions.filter (r) -> r.id is regionId)[0]
      unless region
        region = new Region regionId
        @regions.push region
      region.push cell
      cell.region = region

    for region in @regions
      region.validate()

  regionIds: -> @cells.map (cell) => cell.region.id

  entries: -> @cells.map (cell) => cell.entry()

  isCompleteDisregardingValues: ->
    for cell in @cells
      return false unless cell.entry()?
    for cell in @cells
      for block in cell.blocks
        for neighbour in block.cells
          return false if cell.entry() is neighbour.entry unless cell is neighbour
    for region in @regions
      return false unless region.sumOfEntries() is region.sum()

    true


class Region extends CellBlock

  constructor: (@id) -> super()

  validate: ->
    throw new Error "Huh, empty region - how did that happen???" if @cells.length is 0
    if @cells.length > 1
      hasAtLeastOneNeighbour = (cell) =>
        for other in @cells
          return true if other isnt cell and other.isNextTo cell
        false
      for cell in @cells
        throw new Error "Non-contiguous cell #{cell.toString()} pushed to region '#{@id}' you bozo" unless hasAtLeastOneNeighbour cell

  contains: (cell) -> cell in @cells

  sumOfEntries: ->
    sum = 0
    for cell in @cells
      sum += cell.entry() if cell.entry()?
    sum

class Generator

  @generateSudoku = (root) ->

    returnValidNewSudokuOrNull = (values) ->
      try
        return new Sudoku values
      catch
        return null

    worker = (working, index) ->
      values = working.values()
      cell = working.cellAt Math.floor(index / working.size), index % working.size
      candidates = cell.availableValues()
      while candidates.length > 0
        candidate = candidates[Math.floor(Math.random() * candidates.length)]
        candidates = candidates.filter (e) -> e isnt candidate
        values[index] = candidate
        next = returnValidNewSudokuOrNull values
        if next?
          if (index + 1) is Math.pow(working.size, 2)
            return next
          else
            result = worker next, index+1
            return result if result?

    numCells = Math.pow root, 4
    sudokuWhereAllCellsHaveValueNull = new Sudoku [0...numCells].map (i) -> null
    worker sudokuWhereAllCellsHaveValueNull, 0


  @generateKiller = (sudoku) ->

    mergeAwaySingleCellRegions = (killer) ->
      regionsWithOnlyOneCell = killer.regions.filter (r) => r.cells.length is 1
      if regionsWithOnlyOneCell.length > 0
        regionToKill = regionsWithOnlyOneCell[Math.floor(Math.random() * regionsWithOnlyOneCell.length)]
        cellToRelocate = regionToKill.cells[0]
        cellToBecomeNeighbour = findValidMergeTarget cellToRelocate
        if cellToBecomeNeighbour?
          values = killer.values()
          regions = killer.regionIds()
          regions[cellToRelocate.index()] = cellToBecomeNeighbour.region.id
          killer = mergeAwaySingleCellRegions new Killer values, regions
      killer

    findValidMergeTarget = (cellToRelocate) ->
      directions = ['up', 'right', 'left', 'down'].shuffle()
      for direction in directions
        cellToBecomeNeighbour = cellToRelocate[direction]()
        if cellToBecomeNeighbour?
          valuesAlreadyInRegion = cellToBecomeNeighbour.region.cells.map (cell) => cell.value
          if valuesAlreadyInRegion.indexOf(cellToRelocate.value) is -1
            return cellToBecomeNeighbour
      return null

    killerWhereAllRegionsHaveOnlyCell = new Killer sudoku.values(), sudoku.values().map (value, index) => index
    mergeAwaySingleCellRegions killerWhereAllRegionsHaveOnlyCell


class SudokuStringifier

  @stringify: (sudoku) ->
    out = ""
    for row in [0...sudoku.size]
      for col in [0...sudoku.size]
        out += sudoku.cellAt(row, col).value
        out += '  ' if (col + 1) % sudoku.root is 0
        out += ' ' if col < sudoku.size - 1
      out += '\n' if (row + 1) % sudoku.root is 0
      out += '\n' if row < sudoku.size - 1
    out


root = exports ? window
root.Sudoku = Sudoku
root.Cell = Cell
root.Killer = Killer
root.Region = Region
root.SudokuStringifier = SudokuStringifier
root.Generator = Generator