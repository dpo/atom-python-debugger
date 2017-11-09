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
    return "" unless editor = atom.workspace.getActivePaneItem()
    return "" unless buffer = editor.buffer
    return buffer.file?.path

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
      @button outlet: "breakpointBtn", click: "toggleBreakpoint", class: "btn", =>
        @span "breakpoint"
      @button class: "btn", =>
        @span "        "
      @button outlet: "runBtn", click: "runApp", class: "btn", =>
        @span "run"
      @button outlet: "stopBtn", click: "stopApp", class: "btn", =>
        @span "stop"
      @button class: "btn", =>
        @span "        "
      @button outlet: "stepOverBtn", click: "stepOverBtnPressed", class: "btn", =>
        @span "next"
      @button outlet: "stepInBtn", click: "stepInBtnPressed", class: "btn", =>
        @span "step"
      @button outlet: "varBtn", click: "varBtnPressed", class: "btn", =>
        @span "variables"
      @button class: "btn", =>
        @span "        "
      @button outlet: "returnBtn", click: "returnBtnPressed", class: "btn", =>
        @span "return"
      @button outlet: "continueBtn", click: "continueBtnPressed", class: "btn", =>
        @span "continue"
      @button class: "btn", =>
        @span "        "
      @button outlet: "clearBtn", click: "clearOutput", class: "btn", =>
        @span "clear"
      @div class: "panel-body", outlet: "outputContainer", =>
        @pre class: "command-output", outlet: "output"

  toggleBreakpoint: ->
    editor = atom.workspace.getActiveTextEditor()
    filename = @getCurrentFilePath()
    lineNumber = editor.getCursorBufferPosition().row + 1
    # add to or remove breakpoint from internal list
    cmd = @breakpointStore.toggle(new Breakpoint(filename, lineNumber))
    debuggerCmd = cmd + "\n"
    @backendDebugger.stdin.write(debuggerCmd) if @backendDebugger
    @output.append(debuggerCmd)

  stepOverBtnPressed: ->
    @backendDebugger?.stdin.write("n\n")

  stepInBtnPressed: ->
    @backendDebugger?.stdin.write("s\n")

  continueBtnPressed: ->
    @backendDebugger?.stdin.write("c\n")

  returnBtnPressed: ->
    @backendDebugger?.stdin.write("r\n")

  loopOverBreakpoints: () ->
    n = @breakpointStore.breakpoints.length
    for i in [0..n-1]
      # always yield first element; it will be spliced out
      yield @breakpointStore.breakpoints[0]

  clearBreakpoints: () ->
    return unless @breakpointStore.breakpoints.length > 0
    # The naive `@toggle breakpoint for breakpoint in @breakpoints`
    # gives indexing errors because of the async loop.
    # Clear breakpoints sequentially.

    # for ... from will be supported in a future version of Atom
    # for breakpoint from @loopOverBreakpoints()
    #   cmd = @toggle breakpoint
    #   debuggerCmd = cmd + "\n"
    #   @backendDebugger.stdin.write(debuggerCmd) if @backendDebugger
    #   @output.append(debuggerCmd)
    `
    for (let breakpoint of this.loopOverBreakpoints()) {
      cmd = this.breakpointStore.toggle(breakpoint)
      debuggerCmd = cmd + "\n"
     if (this.backendDebugger) {
        this.backendDebugger.stdin.write(debuggerCmd)
        this.output.append(debuggerCmd)
      }
    }
    `
    return

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

  varBtnPressed: ->
    @backendDebugger?.stdin.write("for (__k, __v) in [(__k, __v) for __k, __v in globals().items() if not __k.startswith('__')]: print __k, '=', __v\n")
    @backendDebugger?.stdin.write("print '-------------'\n")
    @backendDebugger?.stdin.write("for (__k, __v) in [(__k, __v) for __k, __v in locals().items() if __k != 'self' and not __k.startswith('__')]: print __k, '=', __v\n")
    @backendDebugger?.stdin.write("for (__k, __v) in [(__k, __v) for __k, __v in (self.__dict__ if 'self' in locals().keys() else {}).items()]: print 'self.{0}'.format(__k), '=', __v\n")

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

    @highlightLineInEditor fileName, lineNumber
    @addOutput(data_str.trim())

  highlightLineInEditor: (fileName, lineNumber) ->
    return unless fileName && lineNumber
    lineNumber = parseInt(lineNumber)
    focusOnCmd = atom.config.get "python-debugger.focusOnCmd"
    options = {
      searchAllPanes: true,
      activateItem: true,
      activatePane: focusOnCmd,
    }
    atom.workspace.open(fileName, options).then (editor) ->
      position = Point(lineNumber - 1, 0)
      editor.setCursorBufferPosition(position)
      editor.unfoldBufferRow(lineNumber)
      editor.scrollToBufferPosition(position)
      # TODO: add decoration to current line?

  runBackendDebugger: ->
    args = [path.join(@backendDebuggerPath, @backendDebuggerName)]
    args.push(@debuggedFileName)
    args.push(arg) for arg in @debuggedFileArgs
    python = atom.config.get "python-debugger.pythonExecutable"
    console.log("python-debugger: using", python)
    @backendDebugger = spawn python, args

    for breakpoint in @breakpointStore.breakpoints
      @backendDebugger.stdin.write(breakpoint.addCommand() + "\n")

    # Move to first breakpoint or run program if there are none.
    @backendDebugger.stdin.write("c\n")

    @backendDebugger.stdout.on "data", (data) =>
      @processDebuggerOutput(data)
    @backendDebugger.stderr.on "data", (data) =>
      @processDebuggerOutput(data)
    @backendDebugger.on "exit", (code) =>
      @addOutput("debugger exits with code: " + code.toString().trim()) if code?

  stopApp: ->
    console.log "backendDebugger is ", @backendDebugger
    @backendDebugger?.stdin.write("\nexit()\n")
    @backendDebugger = null
    @debuggedFileName = null
    @debuggedFileArgs = []
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
    @addOutput("To set or change the entry point, set file to debug using e=fileName")

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
      # TODO: check that file exists
      if fs.existsSync match[1]
        @debuggedFileName = match[1]
        @addOutput("The file being debugged is: " + @debuggedFileName)
        return true
      else
        @addOutput("File #{match[1]} does not appear to exist")
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
