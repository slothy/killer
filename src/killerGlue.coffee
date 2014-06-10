$(document).ready ->

  canvas = new window.KillerCanvas document.getElementById('killer')

  newGame = ->
    tricksiness = parseFloat $('#tricksiness').val()
    sudoku = Generator.generateSudoku 3
    killer = Generator.generateKiller sudoku, tricksiness
    canvas.model killer
  $('#newGame').on 'click', newGame
  $('#tricksiness').on 'change', newGame
  newGame()


  calculator = new window.SumCalculator 9
  sumCalcBody = $('#sumCalcBody')
  sumCalcFooter = $('#sumCalcFooter')

  updateCalculatorSolutions = ->
    sum = parseInt $('#sumCalcSum').val()
    length = parseInt $('#sumCalcLength').val()
    if isNaN(sum) or isNaN(length)
      sumCalcBody.hide()
      sumCalcFooter.hide()
    else
      showSolutions = (solutions) ->
        if solutions.length > 0
          sumCalcBody.html solutions.map (solution) -> "<div class='solution'>#{solution.join ' '}</div>"
        else
          sumCalcBody.html "Sorry, no can do #{sum} from #{length} cells"
        sumCalcBody.show()
      showIncludesExcludes = (solutions) ->
        if solutions.length > 1
          numbers = _.uniq(_.flatten(solutions)).sort()
          for div in ['Includes', 'Excludes']
            checkboxes = numbers.map (i) -> "<input type='checkbox' class='sumCalc#{div}' value='#{i}'> #{i}"
            $("#sumCalc#{div}").html checkboxes.join ' &#9679; '
          sumCalcFooter.show()
        else
          sumCalcFooter.hide()
      solutions = calculator.calculate sum, length
      showSolutions solutions
      showIncludesExcludes solutions

  $('#sumCalcSum, #sumCalcLength').on 'input', updateCalculatorSolutions
  updateCalculatorSolutions()

  updateSolutionHighlighting = ->
    includes = $.map $('.sumCalcIncludes:checked'), (cb) -> cb.value
    excludes = $.map $('.sumCalcExcludes:checked'), (cb) -> cb.value
    $.each $('.solution'), (index, div) ->
      values = div.innerHTML.split ' '
      $(div).removeClass 'filtered'
      $(div).addClass 'filtered' unless _.intersection(values, includes).length is includes.length and _.intersection(values, excludes).length is 0

  $('#sumCalcFooter').on 'click', '.sumCalcIncludes, .sumCalcExcludes', updateSolutionHighlighting


