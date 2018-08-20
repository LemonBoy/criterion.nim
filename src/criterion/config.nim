type
  Config* = object
    budget*: int
    resamples*: int
    minSamples*: int

proc newDefaultConfig*(): Config =
  result.budget = 5
  result.resamples = 1_000
  result.minSamples = 30
