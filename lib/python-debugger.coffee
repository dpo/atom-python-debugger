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
    focusOnCmd:
      title: "Focus editor on current line change"
      type: "boolean"
      default: false

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
      "python-debugger:breakpoint": => @pythonDebuggerView?.toggleBreakpoint()
      "python-debugger:clear-all-breakpoints": => @pythonDebuggerView?.clearBreakpoints()

  deactivate: ->
    @backendDebuggerInputView.destroy()
    @subscriptions.dispose()
    @pythonDebuggerView.destroy()

  serialize: ->
    pythonDebuggerViewState: @pythonDebuggerView?.serialize()

    activePath = editor?.getPath()
    relative = atom.project.relativizePath(activePath)
    themPaths = relative[0] || (path.dirname(activePath) if activePath?)
