when defined(amd64):
  # Inspired by linux's rdtsc_ordered
  when not defined(vcc):
    proc cycles1*(): float64 {.inline.} =
      var low, hi: uint64
      {.emit: """asm volatile(
        "lfence\n"
        "rdtsc\n"
        : "=a"(`low`), "=d"(`hi`)
        :
        : "memory"
      );""".}
      result = ((hi shl 32) or low).float64
  else:
    proc rdtsc(): int64 {.importc: "__rdtsc", header: "<intrin.h>".}
    proc lfence() {.importc: "__mm_lfence", header: "<intrin.h>".}

    proc cycles1*(): float64 {.inline.} =
      lfence()
      return rdtsc().float64
else:
  {.error: "Cycle counting not implemented yet for this platform".}
