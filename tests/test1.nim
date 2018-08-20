import criterion
import std/sha1
import strutils

let cfg = newDefaultConfig()

benchmark cfg:
  iterator strsrc(): string =
    yield repeat('a', 20)
    yield repeat('a', 200)
    yield repeat('a', 2000)

  proc fastSHA(input: string) {.measureArgs: strsrc.} =
    discard secureHash(input)
