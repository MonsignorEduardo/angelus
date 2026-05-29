/*
 * cspice_ops.h — CSPICE operation declarations for spice_worker.
 *
 * All functions operate on CSPICE global state.
 * The worker process is single-threaded; concurrency is handled by the
 * Elixir pool (one process per worker).
 */

#ifndef ANGELUS_CSPICE_OPS_H
#define ANGELUS_CSPICE_OPS_H

#include <cspice/SpiceUsr.h>

/*
 * ops_init — configure CSPICE error handling to RETURN mode.
 * Must be called once at process startup before any CSPICE call.
 */
void ops_init(void);

/*
 * ops_clear_kernels — unload all kernels (kclear_c).
 * Returns 0 on success, -1 on CSPICE error.
 * error_buf (size >= 1024) receives a description on failure.
 */
int ops_clear_kernels(char *error_buf, int buf_size);

/*
 * ops_load_kernels — furnsh_c each path in the list.
 * paths: array of C strings; count: length of array.
 * Returns 0 on success, -1 on first CSPICE error.
 */
int ops_load_kernels(const char **paths, int count,
                     char *error_buf, int buf_size);

/*
 * ops_utc_to_et — str2et_c wrapper.
 * iso8601: NUL-terminated UTC string (e.g. "1990-05-24T06:30:00").
 * et_out: receives ephemeris time in seconds TDB from J2000.
 * Returns 0 on success, -1 on CSPICE error.
 */
int ops_utc_to_et(const char *iso8601, double *et_out,
                  char *error_buf, int buf_size);

/*
 * Result struct for ops_state.
 */
typedef struct {
  double state_km[6];        /* {x, y, z, vx, vy, vz} km / km·s⁻¹ */
  double distance_au;        /* |r| in AU */
  double ecliptic_longitude; /* degrees [0, 360) */
  double ecliptic_latitude;  /* degrees (-90, +90] */
  double light_time_seconds; /* one-way light time */
  double et;                 /* ephemeris time used */
} SpiceState;

/*
 * ops_state — spkezr_c + reclat_c + convrt_c.
 * target:   SPICE target name (e.g. "JUPITER").
 * et:       ephemeris time (seconds TDB from J2000).
 * observer: observer name (e.g. "EARTH").
 * frame:    reference frame (e.g. "ECLIPJ2000").
 * abcorr:   aberration correction (e.g. "LT+S").
 * out:      filled on success.
 * Returns 0 on success, -1 on CSPICE error.
 */
int ops_state(const char *target, double et, const char *observer,
              const char *frame, const char *abcorr,
              SpiceState *out, char *error_buf, int buf_size);

#endif /* ANGELUS_CSPICE_OPS_H */
