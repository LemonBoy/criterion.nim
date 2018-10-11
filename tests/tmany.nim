import criterion

type
  Z = int

let cfg = newDefaultConfig()

benchmark cfg:
  proc foo(x, y: int) {.measure: [(1,2)].} =
    doAssert x + y == 1 + 2

benchmark cfg:
  proc foo(x, y: int) {.measure: @[(1,2)].} =
    doAssert x + y == 1 + 2

benchmark cfg:
  proc foo(x: int) {.measure: 0..10.} =
    doAssert x >= 0 and x <= 10

benchmark cfg:
  iterator bar(): (int, int) =
    yield (42, 42)

  proc foo(x, y: int) {.measure: bar.} =
    doAssert x + y == 42 + 42

benchmark cfg:
  func foo(x:int,w:float): void {.measure: [(1,1.0),(2,2.0)].} =
    discard
  func foo(x:Z): void {.measure: [1.Z].} =
    discard

benchmark cfg:
  type O = object
    x: int
  func dodo(x: O) {.measure: [O(x:42)].} =
    doAssert x.x == 42
  func dodo(x: array[3,int]) {.measure: [[1,2,3]].} =
    doAssert x.len == 3 and (x[0] + x[1] + x[2]) == 6
