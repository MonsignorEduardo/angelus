/*
 * erfa_ops.h — ERFA-based lunar node calculations for angelus_worker.
 */

#ifndef ANGELUS_ASTRO_ERFA_OPS_H
#define ANGELUS_ASTRO_ERFA_OPS_H

#include "result.h"

typedef enum {
  ERFA_CALC_TRUE_LUNAR_NODE = 0,
  ERFA_CALC_TRUE_LUNAR_APOGEE = 1,
} ErfaCalcType;

PointResult ops_math_point(const char *point, const char *iso8601);

#endif /* ANGELUS_ASTRO_ERFA_OPS_H */
