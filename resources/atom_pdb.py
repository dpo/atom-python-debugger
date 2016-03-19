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

    ver = sys.version_info
    if isinstance(ver, tuple):
        # We're using python <= 2.6
        py2 = True
    else:
        py2 = ver.major == 2
    if py2:
        def do_locate(self, arg):
            # An interface can grep the file and line number to follow along.
            frame, lineno = self.stack[self.curindex]
            filename = self.canonic(frame.f_code.co_filename)
            self.stdout.write("file:: %s\nline:: %s\n" % (filename, lineno))

    else:
        def do_locate(self, arg):
            # An interface can grep the file and line number to follow along.
            frame, lineno = self.stack[self.curindex]
            filename = self.canonic(frame.f_code.co_filename)
            self.message("file:: %s\nline:: %s\n" % (filename, lineno))

    def preloop(self):
        self.do_locate(1)

    def precmd(self, line):
        return line

    def postcmd(self, stop, line):
        return stop


def main():
    if not sys.argv[1:] or sys.argv[1] in ("--help", "-h"):
        sys.stdout.write("atom_pdb.py script [args...]\n")
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
            sys.stdout.write("The program finished and will be restarted\n")
        except Restart:
            sys.stdout.write("Restarting %s with arguments: " % script)
            sys.stdout.write(" ".join(sys.argv[1:]) + "\n")
        except SystemExit:
            sys.stdout.write("The program exited via sys.exit(). ")
            sys.stdout.write("Exit status: %s\n" % sys.exc_info()[1])
        except Exception:
            inst = sys.exc_info()[1]
            traceback.print_exc()
            sys.stdout.write("Uncaught exception %s " % str(type(inst)))
            sys.stdout.write("... entering post-mortem debugging\n")
            sys.stdout.write("Continue or Step will restart the program\n")
            apdb.interaction(None, sys.exc_info()[2])
            sys.stdout.write("Post-mortem debugging finished.")
            sys.stdout.write(" %s will be restarted.\n" % script)


if __name__ == "__main__":

    import atom_pdb
    atom_pdb.main()
