# Third-Party Notices

Angelus source code is MIT licensed. Some native artefacts and optional data files use third-party components distributed under their own terms.

## NAIF CSPICE

Angelus native artefacts may include components from the NAIF SPICE Toolkit for C (CSPICE). CSPICE is provided by NASA/JPL/NAIF under custom terms, including warranty and liability disclaimers. Angelus is not affiliated with or endorsed by NASA, JPL, or NAIF.

## JPL/NAIF Kernels

Angelus does not bundle JPL/NAIF data kernels. Users download kernels separately with `mix angelus.kernels`, and those files remain subject to their respective terms.

## Build Tooling

Angelus uses `elixir_make` and `cc_precompiler` to restore precompiled native artefacts during dependency compilation. Those packages are distributed under their respective licenses.
