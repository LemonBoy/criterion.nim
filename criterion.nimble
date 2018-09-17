# Package

version       = "0.1.0"
author        = "LemonBoy"
description   = "A new awesome nimble package"
license       = "MIT"
srcDir        = "src"

# Dependencies

requires "nim >= 0.18.0"

task test, "Runs the test suite":
  exec "nim c -d:release -r tests/tfib.nim"
  # Let's make sure the code at least compiles
  exec "nim check --os:macosx tests/tfib.nim"
  exec "nim check --os:windows --cc:vcc tests/tfib.nim"
