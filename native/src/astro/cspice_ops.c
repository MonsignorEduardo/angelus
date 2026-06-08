/*
 * cspice_ops.c — CSPICE operation implementations for angelus_worker.
 */

#include "cspice_ops.h"
#include "time.h"

#include <cspice/SpiceUsr.h>

#include <stdio.h>
#include <string.h>

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

static AngelusReferenceFrame parse_frame(const char *frame) {
  if (strcmp(frame, "ICRF") == 0)
    return ANGELUS_FRAME_ICRF;
  if (strcmp(frame, "J2000") == 0)
    return ANGELUS_FRAME_J2000;
  if (strcmp(frame, "ECLIPJ2000") == 0)
    return ANGELUS_FRAME_ECLIPJ2000;
  if (strcmp(frame, "GCRS") == 0)
    return ANGELUS_FRAME_GCRS;
  if (strcmp(frame, "ITRF") == 0)
    return ANGELUS_FRAME_ITRF;
  if (strcmp(frame, "TRUE_ECLIPTIC_OF_DATE") == 0)
    return ANGELUS_FRAME_TRUE_ECLIPTIC_OF_DATE;
  return ANGELUS_FRAME_J2000;
}

static AngelusAberrationCorrection parse_abcorr(const char *abcorr) {
  if (strcmp(abcorr, "NONE") == 0)
    return ANGELUS_ABCORR_NONE;
  if (strcmp(abcorr, "LT") == 0)
    return ANGELUS_ABCORR_LT;
  if (strcmp(abcorr, "LT+S") == 0)
    return ANGELUS_ABCORR_LTS;
  if (strcmp(abcorr, "CN") == 0)
    return ANGELUS_ABCORR_CN;
  if (strcmp(abcorr, "CN+S") == 0)
    return ANGELUS_ABCORR_CNS;
  return ANGELUS_ABCORR_LTS;
}

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

BodyResult ops_body(const char *target, const char *iso8601,
                    const char *observer, const char *frame,
                    const char *abcorr) {
  BodyResult result = {0};

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

  result.state.state_km[0] = state[0];
  result.state.state_km[1] = state[1];
  result.state.state_km[2] = state[2];
  result.state.state_km[3] = state[3];
  result.state.state_km[4] = state[4];
  result.state.state_km[5] = state[5];
  result.state.light_time_seconds = lt;
  result.state.et_seconds = time.et;
  result.state.frame = parse_frame(frame);
  result.state.abcorr = parse_abcorr(abcorr);

  result.ok = 1;
  return result;
}
