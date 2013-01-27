# REPLer #

REPLer is a small, and basic library for [LÖVE][love] that spawns an extra
thread, and runs a REPL (read-eval-print-loop) in it. This means that you
can interactively use lua in your console, while running LÖVE, but wait,
there's more! Even though this runs in a thread, the actual commands are
executed on the main thread, this means you can modify the game's environment
easily.

### Notes ###
This works really well with [rlwrap][].

[love]: http://love2d.org
[rlwrap]: http://utopia.knoware.nl/~hlub/rlwrap/#rlwrap
