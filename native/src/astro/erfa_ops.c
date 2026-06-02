/*
 * erfa_ops.c — ERFA-based lunar node calculations for angelus_worker.
 */

#include "erfa_ops.h"

#include "erfa.h"
#include "erfam.h"
#include "time.h"

#include <math.h>
#include <stdio.h>
#define RAD_2PI (2.0 * ERFA_DPI)

typedef struct {
  double jd1;
  double jd2;
} JulianDate;

static JulianDate et_to_jd_tt(double et) {
  JulianDate result = {0};
  result.jd1 = ERFA_DJ00;
  result.jd2 = et / ERFA_DAYSEC;
  return result;
}

static double normalize_rad(double rad) {
  rad = fmod(rad, RAD_2PI);
  if (rad < 0.0)
    rad += RAD_2PI;
  return rad;
}

LunarNodeResult ops_lunar_node(ErfaCalcType calc_type, const char *iso8601) {
  LunarNodeResult result = {0};

  TimeResult time = astro_utc_to_et(iso8601);
  if (!time.ok) {
    snprintf(result.error, sizeof(result.error), "%s", time.error);
    return result;
  }

  result.et = time.et;

  JulianDate jd = et_to_jd_tt(result.et);

  double t = jd.jd2 / ERFA_DJC;
  double mean_node_rad = eraFaom03(t);
  double node_rad;

  switch (calc_type) {
  case ERFA_CALC_MEAN_LUNAR_NODE:
    node_rad = mean_node_rad;
    break;

  case ERFA_CALC_TRUE_LUNAR_NODE: {
    double dpsi, deps;
    eraNut06a(jd.jd1, jd.jd2, &dpsi, &deps);

    double eps0 = eraObl06(jd.jd1, jd.jd2);
    node_rad = mean_node_rad + dpsi * cos(eps0);
    break;
  }

  case ERFA_CALC_MEAN_LUNAR_APOGEE:
    node_rad = mean_node_rad + ERFA_DPI;
    break;

  default:
    snprintf(result.error, sizeof(result.error), "unknown calc_type: %d",
             (int)calc_type);
    return result;
  }

  result.longitude = normalize_rad(node_rad);

  result.ok = 1;
  return result;
}
