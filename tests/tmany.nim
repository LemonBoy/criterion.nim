import criterion

type
  Z = int

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
  func foo(x:Z): cint {.measureArgs: [1.Z].} =
    discard

benchmark cfg:
  type O = object
    x: int
  func dodo(x: O) {.measureArgs: [O(x:42)].} =
    discard
  func dodo(x: array[3,int]) {.measureArgs: [[1,2,3]].} =
    discard
