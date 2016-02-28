#!/usr/bin/env python

# This is a simple customized pdb that has no prompt and outputs the
# name and line number of the file being debugged after each command.
# It is appropriate for a IDE-like debugger package in a text editor,
# such as Atom.
# dominique.orban@gmail.com, 2016.

import os
import pdb
import sys
import traceback

class Restart(Exception):
    """Causes a debugger to be restarted for the debugged python program."""
    pass


class AtomPDB(pdb.Pdb):

    def __init__(self, **kwargs):
        kwargs.pop("stdout", None)
        pdb.Pdb.__init__(self, stdout=sys.__stdout__, **kwargs)
        self.prompt = ""

    def do_locate(self, arg):
        # An interface can grep the file and line number to follow along.
        frame, lineno = self.stack[self.curindex]
        filename = self.canonic(frame.f_code.co_filename)
        print >> self.stdout, "file::", filename, "\nline::", lineno

    def preloop(self):
        self.do_locate(1)

    def precmd(self, line):
        return line

    def postcmd(self, stop, line):
        return stop


def main():
    if not sys.argv[1:] or sys.argv[1] in ("--help", "-h"):
        print >> sys.__stdout__, "atom_pdb.py script [args...]"
        sys.exit(2)

    script = sys.argv[1]
    if not os.path.exists(script):
        sys.exit(1)
    del sys.argv[0]
    sys.path[0] = os.path.dirname(script)
    apdb = AtomPDB()
    while True:
        try:
            apdb._runscript(script)
            if apdb._user_requested_quit:
                break
            print >> sys.__stdout__, "The program finished and will be restarted"
        except Restart:
            print >> sys.__stdout__, "Restarting", script, "with arguments:"
            print >> sys.__stdout__, " ".join(sys.argv[1:])
        except SystemExit:
            print >> sys.__stdout__, "The program exited via sys.exit(). Exit status: ", sys.exc_info()[1]
        except Exception as inst:
            traceback.print_exc()
            print >> sys.__stdout__, "Uncaught exception ", type(inst), " ... entering post-mortem debugging"
            print >> sys.__stdout__, "Continue or Step will restart the program"
            apdb.interaction(None, sys.exc_info()[2])
            print >> sys.__stdout__, "Post-mortem debugging finished. ", script, " will be restarted."


if __name__ == "__main__":

    import atom_pdb
    atom_pdb.main()
