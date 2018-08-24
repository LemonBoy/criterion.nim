import strformat
import terminal

import statistics
import config

proc formatNum(v: float64): string =
  &"{v:.4f}"

proc formatCycles(v: float64): string =
  &"{v.int64:d}cycles"

proc formatTime(v: float64): string =
  let (unit, fact) =
    if v <= 1e3: ("ns", 1.0)
    elif v <= 1e6: ("us", 1e3)
    elif v <= 1e9: ("ms", 1e6)
    elif v <= 1e12: ("s", 1e9)
    else: ("ns", 1.0)

  &"{v / fact:.4f}{unit}"

proc formatConf[T](v: CI[T], fmt: proc(x: T): string): string =
  &"{v.value.fmt} ({v.lower.fmt} .. {v.upper.fmt})"

proc toShow*(cfg: Config, title: string, st: Statistics) =
  let N = st.samples.len

  styledWriteLine(stdout, styleBright, fgGreen, "Benchmark: ", resetStyle, title)
  echo "Collected ", N, " samples"

  if not st.outliers.isZero:
    styledWriteLine(stdout, styleBright, fgYellow, "Warning: ", resetStyle,
      &"Found {st.outliers.mild} mild and {st.outliers.extreme} extreme outliers in the time measurements")
  if not st.cycleOutliers.isZero:
    styledWriteLine(stdout, styleBright, fgYellow, "Warning: ", resetStyle,
      &"Found {st.cycleOutliers.mild} mild and {st.cycleOutliers.extreme} extreme outliers in the cycles measurements")

  if cfg.brief:
    echo "  Time: ", formatTime(st.samplesEst.mean.value) & " ± " &
      formatTime(st.samplesEst.stddev)
    echo "  Cycles: ", formatCycles(st.cycleSamplesEst.mean.value) & " ± " &
      formatCycles(st.cycleSamplesEst.stddev.value)
  else:
    styledWriteLine(stdout, styleBright, fgBlue, "Time", resetStyle)
    block:
      let est = st.samplesEst
      echo "  Mean:  ", formatConf(est.mean, formatTime)
      echo "  Std:   ", formatConf(est.stddev, formatTime)
      echo "  Slope: ", formatConf(est.slope, formatTime)
      echo "  r^2:   ", formatConf(est.rsquare, formatNum)
    block:
      let est = st.cycleSamplesEst
      styledWriteLine(stdout, styleBright, fgBlue, "Cycles", resetStyle)
      echo "  Mean:  ", formatConf(est.mean, formatCycles)
      echo "  Std:   ", formatConf(est.stddev, formatCycles)
      echo "  Slope: ", formatConf(est.slope, formatCycles)
      echo "  r^2:   ", formatConf(est.rsquare, formatNum)
