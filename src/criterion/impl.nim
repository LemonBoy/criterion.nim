import math
import random
import algorithm
import sequtils

import config
import timer
import statistics
import cycles

iterator geometricProgression(base: int, N: int): int =
  var v = base.float
  var t: int
  while true:
    t = v.int
    yield t
    while v.int == t: v *= 1.05

proc bench*(cfg: Config, label: string, body: proc (): void): Statistics =
  let budget = NS_IN_S * cfg.budget.float64
  var elapsed = 0.0'f64

  var iters: seq[int]
  var times: seq[float64]
  var cycless: seq[float64]

  for _ in 0..100:
    body()

  for iterCount in geometricProgression(1, 2):
    GC_fullCollect()

    let rtBegin = getMonotonicTime()
    let cyBegin = cycles1()

    for _ in 0..<iterCount:
      body()

    let cyFinish = cycles1()
    let rtFinish = getMonotonicTime()
    let duration = rtFinish - rtBegin

    iters.add(iterCount)
    times.add(duration)
    cycless.add(cyFinish - cyBegin)

    elapsed += duration

    # Make sure we collected enough samples to have meaningful results
    if elapsed >= budget and iters.len >= cfg.minSamples:
      echo "Collected ", iters.len, " samples"
      break

  result = newStatistics(cfg, label, iters, times, cycless)
