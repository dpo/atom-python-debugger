"""Sample program.

Bring up the debugger with option-r.
"""

from some_module import some_function


def do_something(x):
    """A silly function."""
    y = x
    z = some_function(y)  # Stepping in opens the relevant file
    return z + " rules!"

if __name__ == "__main__":
    import sys
    x = sys.argv[1]  # Set a breakpoint with option-shift-R or palette
    y = do_something(x)
    print(y)
