import criterion

let cfg = newDefaultConfig()

benchmark(cfg):
  # in block
  block foo:
    block bar:
      proc f(x: int) {.measure: 1.} =
        discard
