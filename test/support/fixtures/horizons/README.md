# Horizons Fixtures

`de442_positions.json` contains responses retrieved from the NASA/JPL Horizons
API. Each case records the original corrected vector and the query parameters
needed to reproduce it. The E2E tests load the Angelus DE442 kernel set and
compare its geocentric distance against these independent Horizons results.

Horizons currently identifies its planetary source as DE441. DE441 and DE442
share the same underlying planetary solution over the public Angelus range;
DE442 extends its time coverage. The fixture tolerance accounts for differences
between Horizons `LT+S` and Angelus `CN+S` light-time convergence.

Do not add hand-written or placeholder position values here. New cases must be
retrieved from `https://ssd.jpl.nasa.gov/api/horizons.api` and retain their
source vectors and query parameters in the JSON fixture.
