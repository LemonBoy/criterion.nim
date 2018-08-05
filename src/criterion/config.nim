type
  Config* = object
    budget*: int
    resamples*: int
    minSamples*: int
    kdePoints*: int
    # output options

proc newDefaultConfig*(): Config =
  result.budget = 5
  result.resamples = 1_000
  result.minSamples = 30
  result.kdePoints = 200
