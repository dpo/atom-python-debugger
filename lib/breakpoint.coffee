module.exports =
class Breakpoint
  decoration: null
  constructor: (@filename, @lineNumber) ->
  addCommand: ->
    "b " + @filename + ":" + @lineNumber
  clearCommand: ->
    "cl " + @filename + ":" + @lineNumber
