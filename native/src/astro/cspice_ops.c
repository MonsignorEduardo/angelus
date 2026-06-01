/*
 * cspice_ops.c — CSPICE operation implementations for angelus_worker.
 */

#include "cspice_ops.h"
#include "time.h"

#include <cspice/SpiceUsr.h>

#include <stdio.h>
#include <string.h>

static const double PI = 3.14159265358979323846;
static const double RAD_TO_DEG = 180.0 / PI;
static const double DEG_TO_RAD = PI / 180.0;

static void fill_error(char *buf, int size, const char *msg) {
  if (buf && size > 0) {
    strncpy(buf, msg, size - 1);
    buf[size - 1] = '\0';
  }
}

static void get_cspice_error(char *buf, int size) {
  SpiceChar msg[1024] = {0};
  getmsg_c("LONG", 1024, msg);
  reset_c();
  fill_error(buf, size, msg);
}

void set_cspice_errors(void) { erract_c("SET", 4096, "RETURN"); }

OpResult ops_clear_kernels(void) {
  OpResult result = {0};

  kclear_c();
  if (failed_c()) {
    get_cspice_error(result.error, sizeof(result.error));
    return result;
  }

  result.ok = 1;
  return result;
}

OpResult ops_load_kernels(const char *const *paths, int count) {
  OpResult result = {0};

  for (int i = 0; i < count; i++) {
    furnsh_c(paths[i]);
    if (failed_c()) {
      get_cspice_error(result.error, sizeof(result.error));
      return result;
    }
  }

  result.ok = 1;
  return result;
}

AstroResult ops_ephemeride(const char *target, const char *iso8601,
                           const char *observer, const char *frame,
                           const char *abcorr, const char *units) {
  AstroResult result = {0};

  TimeResult time = astro_utc_to_et(iso8601);
  if (!time.ok) {
    snprintf(result.error, sizeof(result.error), "%s", time.error);
    return result;
  }

  SpiceDouble state[6];
  SpiceDouble lt;

  spkezr_c(target, time.et, frame, abcorr, observer, state, &lt);
  if (failed_c()) {
    get_cspice_error(result.error, sizeof(result.error));
    return result;
  }

  SpiceDouble radius, lon_rad, lat_rad;
  reclat_c(state, &radius, &lon_rad, &lat_rad);
  if (failed_c()) {
    get_cspice_error(result.error, sizeof(result.error));
    return result;
  }

  SpiceDouble radius_au;
  convrt_c(radius, "KM", "AU", &radius_au);
  if (failed_c()) {
    get_cspice_error(result.error, sizeof(result.error));
    return result;
  }

  double lon_deg = lon_rad * RAD_TO_DEG;
  if (lon_deg < 0.0)
    lon_deg += 360.0;

  double lat_deg = lat_rad * RAD_TO_DEG;

  result.state.state_km[0] = state[0];
  result.state.state_km[1] = state[1];
  result.state.state_km[2] = state[2];
  result.state.state_km[3] = state[3];
  result.state.state_km[4] = state[4];
  result.state.state_km[5] = state[5];
  result.state.distance_au = radius_au;
  result.state.ecliptic_longitude = lon_deg;
  result.state.ecliptic_latitude = lat_deg;
  result.state.light_time_seconds = lt;
  result.state.et = time.et;

  if (units && strcmp(units, "rad") == 0) {
    result.state.ecliptic_longitude =
        result.state.ecliptic_longitude * DEG_TO_RAD;
    result.state.ecliptic_latitude =
        result.state.ecliptic_latitude * DEG_TO_RAD;
  }

  result.ok = 1;
  return result;
}
