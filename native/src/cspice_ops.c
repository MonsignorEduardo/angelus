/*
 * cspice_ops.c — CSPICE operation implementations for angelus_worker.
 */

#include "cspice_ops.h"

#include <stdio.h>
#include <string.h>

#define RAD_TO_DEG (180.0 / 3.14159265358979323846)

/* ── Helpers ────────────────────────────────────────────────────────────── */

static void fill_error(char *buf, int size, const char *msg) {
  if (buf && size > 0) {
    strncpy(buf, msg, size - 1);
    buf[size - 1] = '\0';
  }
}

/* Retrieve CSPICE long error message and reset the error state. */
static void get_cspice_error(char *buf, int size) {
  SpiceChar msg[1024] = {0};
  getmsg_c("LONG", 1024, msg);
  reset_c();
  fill_error(buf, size, msg);
}

/* ── Implementations ─────────────────────────────────────────────────────── */

void ops_init(void) {
  /* Configure CSPICE to RETURN on error instead of aborting the process. */
  erract_c("SET", 4096, "RETURN");
}

int ops_clear_kernels(char *error_buf, int buf_size) {
  kclear_c();
  if (failed_c()) {
    get_cspice_error(error_buf, buf_size);
    return -1;
  }
  return 0;
}

int ops_load_kernels(const char **paths, int count, char *error_buf,
                     int buf_size) {
  for (int i = 0; i < count; i++) {
    furnsh_c(paths[i]);
    if (failed_c()) {
      get_cspice_error(error_buf, buf_size);
      return -1;
    }
  }
  return 0;
}

int ops_utc_to_et(const char *iso8601, double *et_out, char *error_buf,
                  int buf_size) {
  str2et_c(iso8601, et_out);
  if (failed_c()) {
    get_cspice_error(error_buf, buf_size);
    return -1;
  }
  return 0;
}

int ops_state(const char *target, double et, const char *observer,
              const char *frame, const char *abcorr, SpiceState *out,
              char *error_buf, int buf_size) {
  SpiceDouble state[6];
  SpiceDouble lt;

  spkezr_c(target, et, frame, abcorr, observer, state, &lt);
  if (failed_c()) {
    get_cspice_error(error_buf, buf_size);
    return -1;
  }

  /* reclat_c: rectangular -> radius (km), longitude (rad), latitude (rad) */
  SpiceDouble radius, lon_rad, lat_rad;
  reclat_c(state, &radius, &lon_rad, &lat_rad);
  if (failed_c()) {
    get_cspice_error(error_buf, buf_size);
    return -1;
  }

  /* Convert radius km -> AU using CSPICE convrt_c */
  SpiceDouble radius_au;
  convrt_c(radius, "KM", "AU", &radius_au);
  if (failed_c()) {
    get_cspice_error(error_buf, buf_size);
    return -1;
  }

  /* lon_rad in (-pi, pi]; convert to degrees and normalize to [0, 360) */
  double lon_deg = lon_rad * RAD_TO_DEG;
  if (lon_deg < 0.0)
    lon_deg += 360.0;

  double lat_deg = lat_rad * RAD_TO_DEG;

  out->state_km[0] = state[0];
  out->state_km[1] = state[1];
  out->state_km[2] = state[2];
  out->state_km[3] = state[3];
  out->state_km[4] = state[4];
  out->state_km[5] = state[5];
  out->distance_au = radius_au;
  out->ecliptic_longitude = lon_deg;
  out->ecliptic_latitude = lat_deg;
  out->light_time_seconds = lt;
  out->et = et;

  return 0;
}
