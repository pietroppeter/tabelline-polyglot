# Package

version       = "0.1.0"
author        = "Pietro Peterlongo"
description   = "tabelline as a C library, and proofs of concept in eight languages that call it"
license       = "MIT"
srcDir        = "."  # capi/ is imported as `capi/spec` (tabelline's docs show it)

# Dependencies

requires "nim >= 2.2.0"
# tabelline is in a feature so that tabelline's own docs, which import capi/ from here, do not
# get a second copy of tabelline: `atlas install --feature=build` (tools/setup.sh) in this repository.

feature "build":
  requires "https://github.com/pietroppeter/tabelline#head"  # 0.2 is not tagged yet
