import strformat

import statistics

proc formatNum(v: float64): string =
  &"{v:.4f}"

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

proc toShow*(st: Statistics) =
  echo "Results for: " & st.label
  echo "Mean: " & formatConf(st.mean, formatTime)
  echo "Std: " & formatConf(st.stddev, formatTime)
  echo "Slope: " & formatConf(st.slope, formatTime)
  echo "r^2: " & formatConf(st.rsquare, formatNum)
