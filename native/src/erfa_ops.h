/*
 * erfa_ops.h — ERFA-based lunar node calculations for angelus_worker.
 *
 * Computes the ecliptic longitude of the Moon's ascending node using the
 * ERFA (Essential Routines for Fundamental Astronomy) library v2.0.1,
 * which implements the IAU SOFA algorithms.
 *
 * Both the mean node and true node are returned as ecliptic longitude in
 * degrees [0, 360).  Ecliptic latitude and distance are identically zero
 * because the nodes are geometric intersection points on the ecliptic, not
 * physical bodies.
 */

#ifndef ANGELUS_ERFA_OPS_H
#define ANGELUS_ERFA_OPS_H

/* Calculation type selector. */
typedef enum {
  ERFA_CALC_MEAN_LUNAR_NODE = 0,
  ERFA_CALC_TRUE_LUNAR_NODE = 1,
} ErfaCalcType;

/*
 * ops_lunar_node — compute the ecliptic longitude of the Moon's ascending
 * node.
 *
 * Parameters:
 *   calc_type   — ERFA_CALC_MEAN_LUNAR_NODE or ERFA_CALC_TRUE_LUNAR_NODE
 *   et          — Ephemeris Time (TDB seconds since J2000.0 TDB epoch),
 *                 as returned by CSPICE str2et_c / utc_to_et.
 *   longitude   — output: ecliptic longitude in degrees [0, 360)
 *   error_buf   — output buffer for error messages (on failure)
 *   buf_size    — size of error_buf
 *
 * Returns 0 on success, -1 on failure (error_buf populated).
 */
int ops_lunar_node(ErfaCalcType calc_type, double et,
                   double *longitude,
                   char *error_buf, int buf_size);

#endif /* ANGELUS_ERFA_OPS_H */
