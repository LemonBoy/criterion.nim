import criterion

let cfg = newDefaultConfig()

benchmark cfg:
  proc foo(x, y: int) {.measureArgs: [(1,2)].} =
    discard x + y

benchmark cfg:
  iterator bar(): (int, int) =
    yield (42, 42)

  proc foo(x, y: int) {.measureArgs: bar.} =
    discard x + y

benchmark cfg:
  func foo(x:int,w:float): cint {.measureArgs: [(1,1.0),(2,2.0)].} =
    discard
