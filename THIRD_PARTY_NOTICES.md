# Third-Party Notices

Angelus source code is MIT licensed. Some native artefacts and optional data files use third-party components distributed under their own terms.

## NAIF CSPICE

Angelus native artefacts may include components from the NAIF SPICE Toolkit for C (CSPICE). CSPICE is provided by NASA/JPL/NAIF under custom terms, including warranty and liability disclaimers. Angelus is not affiliated with or endorsed by NASA, JPL, or NAIF.

## JPL/NAIF Kernels

Angelus does not bundle kernel data. Users install the full kernel set with `mix angelus.kernels`; the task downloads generic JPL/NAIF kernels and pinned minor-planet SPKs generated through the JPL Horizons API. Pinned SPKs are verified against catalogued SHA-256 checksums. All kernel files remain subject to their respective terms.

## Build Tooling

Angelus uses `elixir_make` and `cc_precompiler` to restore precompiled native artefacts during dependency compilation. Those packages are distributed under their respective licenses.
