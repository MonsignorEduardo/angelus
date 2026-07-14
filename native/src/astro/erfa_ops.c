/*
 * erfa_ops.c - osculating lunar point calculations for angelus_worker.
 */

#include "erfa_ops.h"

#include "frames.h"
#include "time.h"

#include <cspice/SpiceUsr.h>

#include <math.h>
#include <stdio.h>
#include <string.h>

#define ANGELUS_PI 3.14159265358979323846
#define RAD_2PI (2.0 * ANGELUS_PI)
#define SPEED_STEP_DAYS 0.5
#define VECTOR_EPSILON 1.0e-15

static void fill_error(char *buffer, int size, const char *message) {
  if (buffer && size > 0) {
    snprintf(buffer, (size_t)size, "%s", message);
  }
}

static void get_cspice_error(char *buffer, int size) {
  SpiceChar message[1024] = {0};
  getmsg_c("LONG", sizeof(message), message);
  reset_c();
  fill_error(buffer, size, message);
}

static double normalize_rad(double radians) {
  radians = fmod(radians, RAD_2PI);
  if (radians < 0.0)
    radians += RAD_2PI;
  return radians;
}

static double angular_delta(double after, double before) {
  double delta = after - before;
  if (delta > ANGELUS_PI)
    delta -= RAD_2PI;
  if (delta < -ANGELUS_PI)
    delta += RAD_2PI;
  return delta;
}

static void cross_product(const double left[3], const double right[3],
                          double result[3]) {
  result[0] = left[1] * right[2] - left[2] * right[1];
  result[1] = left[2] * right[0] - left[0] * right[2];
  result[2] = left[0] * right[1] - left[1] * right[0];
}

static double vector_norm(const double vector[3]) {
  return sqrt(vector[0] * vector[0] + vector[1] * vector[1] +
              vector[2] * vector[2]);
}

static int parse_point(const char *point, ErfaCalcType *calc_type) {
  if (strcmp(point, "TRUE_NODE") == 0) {
    *calc_type = ERFA_CALC_TRUE_LUNAR_NODE;
    return 1;
  }

  if (strcmp(point, "LILITH") == 0) {
    *calc_type = ERFA_CALC_TRUE_LUNAR_APOGEE;
    return 1;
  }

  return 0;
}

static int lunar_state(double et, double state[6], char *error,
                       int error_size) {
  SpiceDouble light_time;
  spkezr_c("MOON", et, "ECLIPJ2000", "NONE", "EARTH", state, &light_time);

  if (failed_c()) {
    get_cspice_error(error, error_size);
    return 0;
  }

  return 1;
}

static int gravitational_parameter(double *mu, char *error, int error_size) {
  SpiceInt count;
  SpiceDouble earth_gm[1];
  SpiceDouble moon_gm[1];

  bodvrd_c("EARTH", "GM", 1, &count, earth_gm);
  if (failed_c() || count != 1) {
    get_cspice_error(error, error_size);
    return 0;
  }

  bodvrd_c("MOON", "GM", 1, &count, moon_gm);
  if (failed_c() || count != 1) {
    get_cspice_error(error, error_size);
    return 0;
  }

  *mu = earth_gm[0] + moon_gm[0];
  return 1;
}

static int true_node_longitude(const double state[6], double *longitude,
                               char *error, int error_size) {
  double angular_momentum[3];
  cross_product(state, state + 3, angular_momentum);

  /* k x h points along the ascending intersection with the ecliptic. */
  double node[3] = {-angular_momentum[1], angular_momentum[0], 0.0};
  if (vector_norm(node) <= VECTOR_EPSILON) {
    fill_error(error, error_size, "lunar node is undefined");
    return 0;
  }

  *longitude = normalize_rad(atan2(node[1], node[0]));
  return 1;
}

static int true_apogee_longitude(const double state[6], double *longitude,
                                 char *error, int error_size) {
  double mu;
  if (!gravitational_parameter(&mu, error, error_size))
    return 0;

  double angular_momentum[3];
  double velocity_cross_h[3];
  cross_product(state, state + 3, angular_momentum);
  cross_product(state + 3, angular_momentum, velocity_cross_h);

  double radius = vector_norm(state);
  if (radius <= VECTOR_EPSILON || mu <= 0.0) {
    fill_error(error, error_size, "lunar apogee is undefined");
    return 0;
  }

  double eccentricity[3];
  for (int index = 0; index < 3; index++)
    eccentricity[index] = velocity_cross_h[index] / mu - state[index] / radius;

  if (vector_norm(eccentricity) <= VECTOR_EPSILON) {
    fill_error(error, error_size, "lunar apogee is undefined");
    return 0;
  }

  /* The eccentricity vector points to perigee; apogee is opposite. */
  *longitude = normalize_rad(atan2(-eccentricity[1], -eccentricity[0]));
  return 1;
}

static int longitude_at_et(ErfaCalcType calc_type, double et,
                           double *longitude, char *error, int error_size) {
  double state[6];
  if (!lunar_state(et, state, error, error_size))
    return 0;

  double eclipj2000_longitude;
  int calculated;
  switch (calc_type) {
  case ERFA_CALC_TRUE_LUNAR_NODE:
    calculated = true_node_longitude(state, &eclipj2000_longitude, error,
                                     error_size);
    break;
  case ERFA_CALC_TRUE_LUNAR_APOGEE:
    calculated = true_apogee_longitude(state, &eclipj2000_longitude, error,
                                       error_size);
    break;
  default:
    fill_error(error, error_size, "unknown lunar point calculation");
    return 0;
  }

  if (!calculated)
    return 0;

  double direction[3] = {cos(eclipj2000_longitude),
                         sin(eclipj2000_longitude), 0.0};
  double latitude;
  double declination;
  return astro_true_ecliptic_coordinates(et, direction, longitude, &latitude,
                                          &declination, error, error_size);
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

  double step_seconds = SPEED_STEP_DAYS * 86400.0;
  double before;
  double current;
  double after;
  if (!longitude_at_et(calc_type, time.et - step_seconds, &before,
                       result.error, sizeof(result.error)) ||
      !longitude_at_et(calc_type, time.et, &current, result.error,
                       sizeof(result.error)) ||
      !longitude_at_et(calc_type, time.et + step_seconds, &after,
                       result.error, sizeof(result.error)))
    return result;

  result.state.longitude_rad = current;
  result.state.speed_rad_day =
      angular_delta(after, before) / (2.0 * SPEED_STEP_DAYS);
  if (!astro_true_ecliptic_declination(time.et, current, 0.0,
                                       &result.state.declination_rad,
                                       result.error, sizeof(result.error)))
    return result;
  result.state.et_seconds = time.et;
  result.ok = 1;
  return result;
}
