{Point, Disposable, CompositeDisposable} = require "atom"
{$, $$, View, TextEditorView} = require "atom-space-pen-views"
Breakpoint = require "./breakpoint"
BreakpointStore = require "./breakpoint-store"

spawn = require("child_process").spawn
path = require "path"
fs = require "fs"

module.exports =
class PythonDebuggerView extends View
  debuggedFileName: null
  debuggedFileArgs: []
  backendDebuggerPath: null
  backendDebuggerName: "atom_pdb.py"

  getCurrentFilePath: ->
    editor = atom.workspace.getActivePaneItem()
    file = editor?.buffer.file
    return file?.path

  getDebuggerPath: ->
    pkgs = atom.packages.getPackageDirPaths()[0]
    debuggerPath = path.join(pkgs, "python-debugger", "resources")
    return debuggerPath

  @content: ->
    @div class: "pythonDebuggerView", =>
      @subview "argsEntryView", new TextEditorView
        mini: true,
        placeholderText: "> Enter input arguments here"
      @subview "commandEntryView", new TextEditorView
        mini: true,
        placeholderText: "> Enter debugger commands here"
      @button outlet: "runBtn", click: "runApp", class: "btn", =>
        @span "run"
      @button outlet: "stopBtn", click: "stopApp", class: "btn", =>
        @span "stop"
      @button outlet: "clearBtn", click: "clearOutput", class: "btn", =>
        @span "clear"
      @button outlet: "stepOverBtn", click: "stepOverBtnPressed", class: "btn", =>
        @span "next"
      @button outlet: "stepInBtn", click: "stepInBtnPressed", class: "btn", =>
        @span "step"
      @button outlet: "continueBtn", click: "continueBtnPressed", class: "btn", =>
        @span "continue"
      @button outlet: "returnBtn", click: "returnBtnPressed", class: "btn", =>
        @span "return"
      @div class: "panel-body", outlet: "outputContainer", =>
        @pre class: "command-output", outlet: "output"

  stepOverBtnPressed: ->
    @backendDebugger?.stdin.write("n\n")

  stepInBtnPressed: ->
    @backendDebugger?.stdin.write("s\n")

  continueBtnPressed: ->
    @backendDebugger?.stdin.write("c\n")

  returnBtnPressed: ->
    @backendDebugger?.stdin.write("r\n")

  workspacePath: ->
    editor = atom.workspace.getActiveTextEditor()
    activePath = editor.getPath()
    relative = atom.project.relativizePath(activePath)
    pathToWorkspace = relative[0] || (path.dirname(activePath) if activePath?)
    pathToWorkspace

  runApp: ->
    @stopApp() if @backendDebugger
    @debuggedFileArgs = @getInputArguments()
    console.log @debuggedFileArgs
    if @pathsNotSet()
      @askForPaths()
      return
    @runBackendDebugger()

  # Extract the file name and line number output by the debugger.
  processDebuggerOutput: (data) ->
    data_str = data.toString().trim()
    lineNumber = null
    fileName = null

    [data_str, tail] = data_str.split("line:: ")
    if tail
      [lineNumber, tail] = tail.split("\n")
      data_str = data_str + tail if tail

    [data_str, tail] = data_str.split("file:: ")
    if tail
      [fileName, tail] = tail.split("\n")
      data_str = data_str + tail if tail
      fileName = fileName.trim() if fileName
      fileName = null if fileName == "<string>"

    if lineNumber && fileName
      lineNumber = parseInt(lineNumber)
      options = {initialLine: lineNumber-1, initialColumn:0}
      atom.workspace.open(fileName, options) if fs.existsSync(fileName)
      # TODO: add decoration to current line?

    @addOutput(data_str.trim())

  runBackendDebugger: ->
    args = [path.join(@backendDebuggerPath, @backendDebuggerName)]
    args.push(@debuggedFileName)
    args.push(arg) for arg in @debuggedFileArgs
    python = atom.config.get "python-debugger.pythonExecutable"
    console.log("python-debugger: using", python)
    @backendDebugger = spawn python, args

    for breakpoint in @breakpointStore.breakpoints
      @backendDebugger.stdin.write(breakpoint.toCommand() + "\n")

    # Move to first breakpoint if there are any.
    if @breakpointStore.breakpoints.length > 0
      @backendDebugger.stdin.write("c\n")

    @backendDebugger.stdout.on "data", (data) =>
      @processDebuggerOutput(data)
    @backendDebugger.stderr.on "data", (data) =>
      @processDebuggerOutput(data)
    @backendDebugger.on "exit", (code) =>
      @addOutput("debugger exits with code: " + code.toString().trim()) if code?

  stopApp: ->
    @backendDebugger?.stdin.write("\nexit()\n")
    @backendDebugger = null
    console.log "debugger stopped"

  clearOutput: ->
    @output.empty()

  createOutputNode: (text) ->
    node = $("<span />").text(text)
    parent = $("<span />").append(node)

  addOutput: (data) ->
    atBottom = @atBottomOfOutput()
    node = @createOutputNode(data)
    @output.append(node)
    @output.append("\n")
    if atBottom
      @scrollToBottomOfOutput()

  pathsNotSet: ->
    !@debuggedFileName

  askForPaths: ->
    @addOutput("To use a different entry point, set file to debug using e=fileName")

  initialize: (breakpointStore) ->
    @breakpointStore = breakpointStore
    @debuggedFileName = @getCurrentFilePath()
    @backendDebuggerPath = @getDebuggerPath()
    @addOutput("Welcome to Python Debugger for Atom!")
    @addOutput("The file being debugged is: " + @debuggedFileName)
    @askForPaths()
    @subscriptions = atom.commands.add @element,
      "core:confirm": (event) =>
        if @parseAndSetPaths()
          @clearInputText()
        else
          @confirmBackendDebuggerCommand()
        event.stopPropagation()
      "core:cancel": (event) =>
        @cancelBackendDebuggerCommand()
        event.stopPropagation()

  parseAndSetPaths:() ->
    command = @getCommand()
    return false if !command
    if /e=(.*)/.test command
      match = /e=(.*)/.exec command
      @debuggedFileName = match[1]
      @addOutput("The file being debugged is: " + @debuggedFileName)
      return true
    return false

  stringIsBlank: (str) ->
    !str or /^\s*$/.test str

  escapeString: (str) ->
    !str or str.replace(/[\\"']/g, '\\$&').replace(/\u0000/g, '\\0')

  getInputArguments: ->
    args = @argsEntryView.getModel().getText()
    return if !@stringIsBlank(args) then args.split(" ") else []

  getCommand: ->
    command = @commandEntryView.getModel().getText()
    command if !@stringIsBlank(command)

  cancelBackendDebuggerCommand: ->
    @commandEntryView.getModel().setText("")

  confirmBackendDebuggerCommand: ->
    if !@backendDebugger
      @addOutput("Program not running")
      return
    command = @getCommand()
    if command
      @backendDebugger.stdin.write(command + "\n")
      @clearInputText()

  clearInputText: ->
    @commandEntryView.getModel().setText("")

  serialize: ->
    attached: @panel?.isVisible()

  destroy: ->
    @detach()

  toggle: ->
    if @panel?.isVisible()
      @detach()
    else
      @attach()

  atBottomOfOutput: ->
    @output[0].scrollHeight <= @output.scrollTop() + @output.outerHeight()

  scrollToBottomOfOutput: ->
    @output.scrollToBottom()

  attach: ->
    console.log "attached"
    @panel = atom.workspace.addBottomPanel(item: this)
    @panel.show()
    @scrollToBottomOfOutput()

  detach: ->
    console.log "detached"
    @panel.destroy()
    @panel = null
