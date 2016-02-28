# Python-Debugger package

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

![Atom Python Debugger](https://github.com/dpo/atom-python-debugger/raw/master/screenshots/atom-python-debugger-demo.gif)

## Current limitations

- Breakpoints inserted with `alt-shift-r` or the command palette after starting the debugger are not taken into account. If you need to add breakpoints mid-course, use an explicit debugger command (e.g., `b 25`). The downside is that they won't be highlighted in the editor.
- No remote debugging.
- No watched variables or expressions.

Pull requests welcome!

Happy debugging!
