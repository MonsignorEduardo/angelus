/*
 * erfa_ops.c — ERFA-based lunar node calculations for angelus_worker.
 */

#include "erfa_ops.h"

#include "erfa.h"
#include "erfam.h"
#include "time.h"

#include <math.h>
#include <stdio.h>
#include <string.h>
#define RAD_2PI (2.0 * ERFA_DPI)
#define SPEED_STEP_DAYS 0.5

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

static double angular_delta(double after, double before) {
  double delta = after - before;
  if (delta > ERFA_DPI)
    delta -= RAD_2PI;
  if (delta < -ERFA_DPI)
    delta += RAD_2PI;
  return delta;
}

static int parse_point(const char *point, ErfaCalcType *calc_type) {
  if (strcmp(point, "TRUE_NODE") == 0) {
    *calc_type = ERFA_CALC_TRUE_LUNAR_NODE;
    return 1;
  }

  if (strcmp(point, "LILITH") == 0) {
    *calc_type = ERFA_CALC_MEAN_LUNAR_APOGEE;
    return 1;
  }

  if (strcmp(point, "MEAN_NODE") == 0) {
    *calc_type = ERFA_CALC_MEAN_LUNAR_NODE;
    return 1;
  }

  return 0;
}

static double longitude_at_et(ErfaCalcType calc_type, double et) {
  JulianDate jd = et_to_jd_tt(et);
  double t = jd.jd2 / ERFA_DJC;
  double mean_node_rad = eraFaom03(t);
  double point_rad;

  switch (calc_type) {
  case ERFA_CALC_MEAN_LUNAR_NODE:
    point_rad = mean_node_rad;
    break;

  case ERFA_CALC_TRUE_LUNAR_NODE: {
    double dpsi, deps;
    eraNut06a(jd.jd1, jd.jd2, &dpsi, &deps);

    double eps0 = eraObl06(jd.jd1, jd.jd2);
    point_rad = mean_node_rad + dpsi * cos(eps0);
    break;
  }

  case ERFA_CALC_MEAN_LUNAR_APOGEE:
    point_rad = mean_node_rad + ERFA_DPI;
    break;

  default:
    point_rad = 0.0;
    break;
  }

  return normalize_rad(point_rad);
}

PointResult ops_math_point(const char *point, const char *iso8601) {
  PointResult result = {0};
  ErfaCalcType calc_type;

  if (!parse_point(point, &calc_type)) {
    snprintf(result.error, sizeof(result.error), "unknown math point: %s", point);
    return result;
  }

  TimeResult time = astro_utc_to_et(iso8601);
  if (!time.ok) {
    snprintf(result.error, sizeof(result.error), "%s", time.error);
    return result;
  }

  double step_seconds = SPEED_STEP_DAYS * ERFA_DAYSEC;
  double before = longitude_at_et(calc_type, time.et - step_seconds);
  double after = longitude_at_et(calc_type, time.et + step_seconds);

  result.state.longitude_rad = longitude_at_et(calc_type, time.et);
  result.state.speed_rad_day = angular_delta(after, before) / (2.0 * SPEED_STEP_DAYS);
  result.state.et_seconds = time.et;

  result.ok = 1;
  return result;
}
