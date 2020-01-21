# Package

version       = "0.2.2"
author        = "Mark Baggett"
description   = "High Level OAI-PMH library for Nim"
license       = "GPL-3.0"
srcDir        = "src"



# Dependencies

requires "nim >= 1.0.2"
requires "xmltools >= 0.1.5"

# Tests

task test, "Test":
  exec "nim c -r tests/tests.nim"

# Documentation

task docs, "Docs":
  exec "nim doc --git.url:https://github.com/markpbaggett/oaitools.nim -o:./docs/index.html src/oaitools.nim"
