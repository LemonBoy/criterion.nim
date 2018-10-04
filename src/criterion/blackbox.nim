proc inner(x: ptr char) {.codegenDecl: "$# $#(char const volatile *x)".} =
  discard

template blackBox*[T](x: var T) =
  # Very simple (and far from zero-cost) harness that prevents the compiler from
  # optimizing ``x`` away.
  # At least it doesn't require any inline asm and is relatively portable.
  inner(cast[ptr char](unsafeAddr x))
