/*
 * cspice_ops.h — CSPICE operation declarations for angelus_worker.
 *
 * All functions operate on CSPICE global state. The worker process is
 * single-threaded; concurrency is handled by the Elixir pool.
 */

#ifndef ANGELUS_ASTRO_CSPICE_OPS_H
#define ANGELUS_ASTRO_CSPICE_OPS_H

#include "result.h"

/* Configure CSPICE error handling to RETURN mode. */
void set_cspice_errors(void);

/* Unload all kernels. Returns 0 on success, -1 on CSPICE error. */
OpResult ops_clear_kernels(void);

/* furnsh_c each path in the list. Returns 0 on success. */
OpResult ops_load_kernels(const char *const *paths, int count);

/* Single call that accepts UTC ISO8601 and returns a body position result. */
BodyResult get_position(const char *target, const char *iso8601);

BodyResult get_topocentric_position(const char *target, const char *iso8601,
                                    double latitude_degrees,
                                    double longitude_degrees,
                                    double ellipsoidal_height_m);

#endif /* ANGELUS_ASTRO_CSPICE_OPS_H */
