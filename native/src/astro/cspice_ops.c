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
static const char *SURFACE_OBSERVER_FRAME = "ITRF93";

static void fill_error(char *buf, int size, const char *msg);
static void get_cspice_error(char *buf, int size);

static int itrf93_coverage(SpiceDouble et, char *error, int error_size) {
  SpiceInt frame_id;
  SpiceInt center;
  SpiceInt frame_class;
  SpiceInt class_id;
  SpiceBoolean found;
  SpiceInt kernel_count;
  SPICEDOUBLE_CELL(coverage, 200);

  namfrm_c(SURFACE_OBSERVER_FRAME, &frame_id);
  frinfo_c(frame_id, &center, &frame_class, &class_id, &found);
  if (failed_c()) {
    get_cspice_error(error, error_size);
    return 0;
  }
  if (frame_id == 0 || !found) {
    fill_error(error, error_size, "ITRF93 frame data are unavailable");
    return 0;
  }

  ktotal_c("PCK", &kernel_count);
  if (failed_c()) {
    get_cspice_error(error, error_size);
    return 0;
  }

  for (SpiceInt index = 0; index < kernel_count; index++) {
    SpiceChar file[1024] = {0};
    SpiceChar type[64] = {0};
    SpiceChar source[1024] = {0};
    SpiceInt handle;

    kdata_c(index, "PCK", sizeof(file), sizeof(type), sizeof(source), file,
            type, source, &handle, &found);
    if (failed_c()) {
      get_cspice_error(error, error_size);
      return 0;
    }
    if (found) {
      SpiceChar architecture[32] = {0};
      SpiceChar file_type[32] = {0};
      getfat_c(file, sizeof(architecture), sizeof(file_type), architecture, file_type);
      if (failed_c()) {
        get_cspice_error(error, error_size);
        return 0;
      }

      if (strcmp(architecture, "DAF") == 0 && strcmp(file_type, "PCK") == 0) {
        pckcov_c(file, class_id, &coverage);
        if (failed_c()) {
          get_cspice_error(error, error_size);
          return 0;
        }
      }
    }
  }

  if (wncard_c(&coverage) == 0 || !wnincd_c(et, et, &coverage)) {
    fill_error(error, error_size, "observer outside ITRF93 coverage");
    return 0;
  }

  return 1;
}

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

static int populate_body_state(AngelusBodyState *result, const SpiceDouble state[6],
                               SpiceDouble light_time, SpiceDouble et,
                               char *error, int error_size) {
  for (int i = 0; i < 6; i++)
    result->state_km[i] = state[i];

  result->light_time_seconds = light_time;
  result->et_seconds = et;
  if (!astro_body_coordinates(
          et, result->state_km, result->direction_j2000, &result->longitude_rad,
          &result->latitude_rad, &result->declination_rad, &result->right_ascension_rad,
          &result->longitude_rate_rad_day, &result->latitude_rate_rad_day,
          &result->right_ascension_rate_rad_day, &result->declination_rate_rad_day,
          error, error_size))
    return 0;

  double distance_km = sqrt(result->state_km[0] * result->state_km[0] +
                            result->state_km[1] * result->state_km[1] +
                            result->state_km[2] * result->state_km[2]);
  if (distance_km <= 1.0e-15) {
    fill_error(error, error_size, "degenerate position vector");
    return 0;
  }
  result->distance_au = distance_km / 149597870.7;
  result->radial_velocity_km_s =
      (result->state_km[0] * result->state_km[3] +
       result->state_km[1] * result->state_km[4] +
       result->state_km[2] * result->state_km[5]) / distance_km;

  result->frame = ANGELUS_FRAME_ECLIPJ2000;
  result->coordinate_frame = ANGELUS_FRAME_TRUE_ECLIPTIC_OF_DATE;
  result->abcorr = ANGELUS_ABCORR_CNS;
  return 1;
}

static int populate_topocentric_enu_state(AngelusBodyState *result,
                                          const SpiceDouble state_eclipj2000[6],
                                          SpiceDouble light_time, SpiceDouble et,
                                          const AngelusSurfaceObserver *observer,
                                          char *error, int error_size) {
  SpiceDouble eclipj2000_to_itrf93[6][6];
  SpiceDouble state_itrf93[6];
  SpiceDouble east[3] = {-sin(observer->longitude_rad), cos(observer->longitude_rad), 0.0};
  SpiceDouble north[3] = {
      -sin(observer->latitude_rad) * cos(observer->longitude_rad),
      -sin(observer->latitude_rad) * sin(observer->longitude_rad),
      cos(observer->latitude_rad)};
  SpiceDouble up[3] = {
      cos(observer->latitude_rad) * cos(observer->longitude_rad),
      cos(observer->latitude_rad) * sin(observer->longitude_rad),
      sin(observer->latitude_rad)};

  sxform_c(POSITION_FRAME, SURFACE_OBSERVER_FRAME, et, eclipj2000_to_itrf93);
  if (failed_c()) {
    get_cspice_error(error, error_size);
    return 0;
  }

  mxvg_c(eclipj2000_to_itrf93, state_eclipj2000, 6, 6, state_itrf93);

  for (int offset = 0; offset <= 3; offset += 3) {
    result->state_km[offset] = east[0] * state_itrf93[offset] +
                                east[1] * state_itrf93[offset + 1] +
                                east[2] * state_itrf93[offset + 2];
    result->state_km[offset + 1] = north[0] * state_itrf93[offset] +
                                    north[1] * state_itrf93[offset + 1] +
                                    north[2] * state_itrf93[offset + 2];
    result->state_km[offset + 2] = up[0] * state_itrf93[offset] +
                                    up[1] * state_itrf93[offset + 1] +
                                    up[2] * state_itrf93[offset + 2];
  }

  result->light_time_seconds = light_time;
  result->et_seconds = et;
  result->frame = ANGELUS_FRAME_TOPOCENTRIC_ENU;
  result->abcorr = ANGELUS_ABCORR_CNS;
  return 1;
}

BodyResult get_position(const char *target, const char *iso8601,
                        const AngelusSurfaceObserver *observer) {
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

  if (!populate_body_state(&result.geocentric, state, lt, time.et, result.error,
                           sizeof(result.error)))
    return result;

  if (observer && observer->present) {
    SpiceDouble radii[3];
    SpiceInt radius_count;
    SpiceDouble observer_position[3];
    SpiceDouble flattening;

    if (!itrf93_coverage(time.et, result.error, sizeof(result.error)))
      return result;

    bodvrd_c("EARTH", "RADII", 3, &radius_count, radii);
    if (failed_c()) {
      get_cspice_error(result.error, sizeof(result.error));
      return result;
    }

    if (radius_count != 3 || radii[0] <= 0.0 || radii[2] <= 0.0) {
      fill_error(result.error, sizeof(result.error), "invalid Earth radii");
      return result;
    }

    flattening = (radii[0] - radii[2]) / radii[0];
    georec_c(observer->longitude_rad, observer->latitude_rad, observer->height_km,
             radii[0], flattening, observer_position);
    if (failed_c()) {
      get_cspice_error(result.error, sizeof(result.error));
      return result;
    }

    spkcpo_c(target, time.et, POSITION_FRAME, "OBSERVER", POSITION_ABCORR,
             observer_position, POSITION_OBSERVER, SURFACE_OBSERVER_FRAME, state, &lt);
    if (failed_c()) {
      get_cspice_error(result.error, sizeof(result.error));
      return result;
    }

    if (!populate_topocentric_enu_state(&result.topocentric, state, lt, time.et,
                                        observer, result.error, sizeof(result.error)))
      return result;

    result.has_topocentric = 1;
  }

  result.ok = 1;
  return result;
}
