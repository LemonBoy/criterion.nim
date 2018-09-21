import statistics

type
  ParamTuple* = tuple
    name: string
    value: string

  BenchmarkResult* = tuple
    stats: Statistics
    label: string
    params: seq[ParamTuple]
