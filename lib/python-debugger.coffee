{CompositeDisposable} = require "atom"
path = require "path"
Breakpoint = require "./breakpoint"
BreakpointStore = require "./breakpoint-store"

module.exports = PythonDebugger =
  pythonDebuggerView: null
  subscriptions: null

  config:
    pythonExecutable:
      title: "Path to Python executable to use during debugging"
      type: "string"
      default: "python"

  createDebuggerView: (backendDebugger) ->
    unless @pythonDebuggerView?
      PythonDebuggerView = require "./python-debugger-view"
      @pythonDebuggerView = new PythonDebuggerView(@breakpointStore)
    @pythonDebuggerView

  activate: ({attached}={}) ->

    @subscriptions = new CompositeDisposable
    @breakpointStore = new BreakpointStore()
    @createDebuggerView().toggle() if attached

    @subscriptions.add atom.commands.add "atom-workspace",
      "python-debugger:toggle": => @createDebuggerView().toggle()
      "python-debugger:breakpoint": => @toggleBreakpoint()

  toggleBreakpoint: ->
    editor = atom.workspace.getActiveTextEditor()
    filename = editor.getTitle()
    lineNumber = editor.getCursorBufferPosition().row + 1
    breakpoint = new Breakpoint(filename, lineNumber)
    @breakpointStore.toggle(breakpoint)

  deactivate: ->
    @backendDebuggerInputView.destroy()
    @subscriptions.dispose()
    @pythonDebuggerView.destroy()

  serialize: ->
    pythonDebuggerViewState: @pythonDebuggerView?.serialize()

    activePath = editor?.getPath()
    relative = atom.project.relativizePath(activePath)
    themPaths = relative[0] || (path.dirname(activePath) if activePath?)
