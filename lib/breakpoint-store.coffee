{CompositeDisposable} = require "atom"
module.exports =
class BreakpointStore
  constructor: (gutter) ->
    @breakpoints = []

  toggle: (breakpoint) ->
    breakpointSearched = @containsBreakpoint(breakpoint)

    addDecoration = true
    if breakpointSearched
      @breakpoints.splice(breakpointSearched, 1)
      addDecoration = false
    else
      @breakpoints.push(breakpoint)

    editor = atom.workspace.getActiveTextEditor()

    if addDecoration
      marker = editor.markBufferPosition([breakpoint.lineNumber-1, 0])
      d = editor.decorateMarker(marker, type: "line-number", class: "line-number-red")
      d.setProperties(type: "line-number", class: "line-number-red")
      breakpoint.decoration = d
    else
      editor = atom.workspace.getActiveTextEditor()
      ds = editor.getLineNumberDecorations(type: "line-number", class: "line-number-red")
      for d in ds
        marker = d.getMarker()
        marker.destroy() if marker.getBufferRange().start.row == breakpoint.lineNumber-1

  containsBreakpoint: (bp) ->
    for breakpoint in @breakpoints
      if breakpoint.filename == bp.filename && breakpoint.lineNumber == bp.lineNumber
        return breakpoint
    return null

  currentBreakpoints: ->
    console.log breakpoint for breakpoint in @breakpoints

  clear: () ->
    @toggle breakpoint for breakpoint in @breakpoints
