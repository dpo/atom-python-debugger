# Python-Debugger package

[![Build Status](https://travis-ci.org/dpo/atom-python-debugger.svg?branch=master)](https://travis-ci.org/dpo/atom-python-debugger)
[![Build status](https://ci.appveyor.com/api/projects/status/x3bskgp134oaxsxm/branch/master?svg=true)](https://ci.appveyor.com/project/dpo/atom-python-debugger/branch/master)

An Atom package for an IDE-like Python debugging experience.

This package is a modification of [swift-debugger](https://atom.io/packages/swift-debugger). Thanks to [aciidb0md3r](https://atom.io/users/aciidb0mb3r)!

## Keyboard Shortcuts

- `alt-r`/`option-r`: hide/show the debugger view
- `alt-shift-r`/`option-shift-r`: toggle breakpoint at the current line

## How to use

1. Install using APM
    ```
    $ apm install python-debugger language-python
    ```
    The `language-python` package provides syntax highlighting
2. Open the Python file to debug and insert breakpoints
3. Press `alt-r` to show the debugger view
4. Insert input arguments in the input arguments field if applicable
5. Hit the `Run` button. Focus moves to the first breakpoint.
6. Use the buttons provided to navigate through your source. You can enter debugger commands directly in the command field.

The current version should support Python 2.5 and higher, including Python 3.
The Python executable to be used while debugging can be changed in the settings.

![Atom Python Debugger](https://github.com/dpo/atom-python-debugger/raw/master/screenshots/atom-python-debugger-demo.gif)

## Current limitations

- Breakpoints inserted with `alt-shift-r` or the command palette after starting the debugger are not taken into account. If you need to add breakpoints mid-course, use an explicit debugger command (e.g., `b 25`). The downside is that they won't be highlighted in the editor.
- No remote debugging.
- No watched variables or expressions.

Pull requests welcome!

Happy debugging!
