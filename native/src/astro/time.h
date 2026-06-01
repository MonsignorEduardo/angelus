/*
 * time.h — shared astronomical time conversion helpers.
 */

#ifndef ANGELUS_ASTRO_TIME_H
#define ANGELUS_ASTRO_TIME_H

#include "result.h"

/* str2et_c wrapper. Returns ephemeris time in seconds TDB from J2000. */
TimeResult astro_utc_to_et(const char *iso8601);

#endif /* ANGELUS_ASTRO_TIME_H */
