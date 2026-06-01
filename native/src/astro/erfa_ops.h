/*
 * erfa_ops.h — ERFA-based lunar node calculations for angelus_worker.
 */

#ifndef ANGELUS_ASTRO_ERFA_OPS_H
#define ANGELUS_ASTRO_ERFA_OPS_H

#include "result.h"

typedef enum {
  ERFA_CALC_MEAN_LUNAR_NODE = 0,
  ERFA_CALC_TRUE_LUNAR_NODE = 1,
} ErfaCalcType;

LunarNodeResult ops_lunar_node(ErfaCalcType calc_type, const char *iso8601,
                               const char *units);

#endif /* ANGELUS_ASTRO_ERFA_OPS_H */
