# Third-Party Notices

Angelus source code is MIT licensed. Some native artefacts and optional data files use third-party components distributed under their own terms.

## NAIF CSPICE

Angelus native artefacts may include components from the NAIF SPICE Toolkit for C (CSPICE). CSPICE is provided by NASA/JPL/NAIF under custom terms, including warranty and liability disclaimers. Angelus is not affiliated with or endorsed by NASA, JPL, or NAIF.

## JPL/NAIF Kernels

Angelus bundles JPL Horizons SPK data for supported minor planets. Users install the full kernel set with `mix angelus.kernels`; the task copies those bundled SPKs and downloads the remaining JPL/NAIF kernels separately. All kernel files remain subject to their respective terms.

## Build Tooling

Angelus uses `elixir_make` and `cc_precompiler` to restore precompiled native artefacts during dependency compilation. Those packages are distributed under their respective licenses.
