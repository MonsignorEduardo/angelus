# Horizons Fixtures

`de442_positions.json` must be generated from JPL Horizons with `mix angelus.validate.horizons --write` once live Horizons query support is implemented. Tests in `test/e2e` load CSPICE and compare Angelus output against this fixture.

Do not add hand-written or placeholder position values here; v0.1 validation fixtures must contain real Horizons output for DE442.
