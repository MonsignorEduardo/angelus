/*
 * cspice_ops.c — CSPICE operation implementations for angelus_worker.
 */

#include "cspice_ops.h"
#include "frames.h"
#include "time.h"

#include <cspice/SpiceUsr.h>

#include <math.h>
#include <stdio.h>
#include <string.h>

static const char *POSITION_OBSERVER = "EARTH";
static const char *POSITION_FRAME = "ECLIPJ2000";
static const char *POSITION_ABCORR = "CN+S";

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
      kclear_c();
      if (failed_c())
        reset_c();
      return result;
    }
  }

  result.ok = 1;
  return result;
}

BodyResult get_position(const char *target, const char *iso8601) {
  BodyResult result = {0};

  TimeResult time = astro_utc_to_et(iso8601);
  if (!time.ok) {
    snprintf(result.error, sizeof(result.error), "%s", time.error);
    return result;
  }

  SpiceDouble state[6];
  SpiceDouble lt;

  spkezr_c(target, time.et, POSITION_FRAME, POSITION_ABCORR,
           POSITION_OBSERVER, state, &lt);
  if (failed_c()) {
    get_cspice_error(result.error, sizeof(result.error));
    return result;
  }

  result.state.state_km[0] = state[0];
  result.state.state_km[1] = state[1];
  result.state.state_km[2] = state[2];
  result.state.state_km[3] = state[3];
  result.state.state_km[4] = state[4];
  result.state.state_km[5] = state[5];
  result.state.light_time_seconds = lt;
  result.state.et_seconds = time.et;
  if (!astro_true_ecliptic_coordinates(
          time.et, result.state.state_km, &result.state.longitude_rad,
          &result.state.latitude_rad, &result.state.declination_rad,
          result.error, sizeof(result.error)))
    return result;

  result.state.frame = ANGELUS_FRAME_ECLIPJ2000;
  result.state.coordinate_frame = ANGELUS_FRAME_TRUE_ECLIPTIC_OF_DATE;
  result.state.abcorr = ANGELUS_ABCORR_CNS;

  result.ok = 1;
  return result;
}
