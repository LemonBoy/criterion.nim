import math
import random
import algorithm
import sequtils

import exporter
import config
import timer
import statistics
import cycles

iterator geometricProgression(base: int, N: float): int =
  var v = base.float
  var t: int
  while true:
    t = v.int
    yield t
    while v.int == t: v *= N

proc bench*(cfg: Config, label: string, body: proc (): void): Statistics =
  let budget = NS_IN_S * cfg.budget.float64
  let warmupBudget = NS_IN_S * cfg.warmupBudget.float64
  var elapsed: float64

  var iters: seq[int] = @[]
  var times: seq[float64] = @[]
  var cycless: seq[float64] = @[]

  var warmupIters = 0
  elapsed = 0.0
  # Warm up the caches
  while elapsed < warmupBudget:
    let rtBegin = getMonotonicTime()
    body()
    let rtFinish = getMonotonicTime()
    elapsed += rtFinish - rtBegin
    inc warmupIters

  if cfg.verbose:
    echo "Performed ", warmupIters, " warmup iterations"

  elapsed = 0.0
  for iterCount in geometricProgression(1, 1.05):
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
      if cfg.verbose:
        echo "Collected ", iters.len, " samples"
      break

  result = newStatistics(cfg, label, iters, times, cycless)
