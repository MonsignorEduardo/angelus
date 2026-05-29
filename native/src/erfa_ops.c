/*
 * erfa_ops.c — ERFA-based lunar node calculations for spice_worker.
 *
 * Mean node:
 *   Uses eraFaom03(t), the IAU IERS Conventions (2003) polynomial for
 *   the mean longitude of the Moon's ascending node.
 *   Input t is Julian centuries TDB since J2000.0.
 *
 * True node:
 *   The true node is the mean node corrected by the periodic nutation
 *   terms in longitude (dpsi).  We use eraNut06a() (IAU 2006/2000A),
 *   which gives the full luni-solar + planetary nutation in longitude.
 *   The true node longitude is:
 *
 *     true_node = mean_node + dpsi * cos(eps0)
 *
 *   where eps0 is the mean obliquity of the ecliptic (eraObl06).
 *   This is the standard approximation used by Swiss Ephemeris and
 *   consistent with JPL Horizons "True Ascending Node" output.
 *
 * Coordinate system:
 *   Output is ecliptic longitude referred to the mean ecliptic of date
 *   (same frame as the SPICE adapter outputs for planetary bodies).
 */

#include "erfa_ops.h"
#include "erfa.h"
#include "erfam.h"

#include <math.h>
#include <string.h>
#include <stdio.h>

#define DEG_360 360.0
#define RAD_TO_DEG (180.0 / ERFA_DPI)

/* ── Helpers ─────────────────────────────────────────────────────────── */

/*
 * et_to_jd_tt — convert CSPICE Ephemeris Time (TDB seconds since J2000.0)
 * to a two-part Julian Date in TT suitable for ERFA.
 *
 * ET (CSPICE) is referenced to the J2000.0 TDB epoch = JD 2451545.0 TDB.
 * The difference between TDB and TT is at most ~1.7 ms, which is negligible
 * for lunar node purposes (error << 1 arcsecond).  We treat ET ≈ TT here.
 *
 * ERFA uses two-part JD for precision; we split as (J2000.0, delta_days).
 */
static void et_to_jd_tt(double et, double *jd1, double *jd2) {
  *jd1 = ERFA_DJ00;                   /* 2451545.0 — J2000.0 epoch */
  *jd2 = et / ERFA_DAYSEC;            /* ERFA_DAYSEC = 86400.0     */
}

/*
 * normalize_deg — bring an angle in degrees to [0, 360).
 */
static double normalize_deg(double deg) {
  deg = fmod(deg, DEG_360);
  if (deg < 0.0)
    deg += DEG_360;
  return deg;
}

/* ── Implementation ──────────────────────────────────────────────────── */

int ops_lunar_node(ErfaCalcType calc_type, double et,
                   double *longitude,
                   char *error_buf, int buf_size) {
  double jd1, jd2;
  et_to_jd_tt(et, &jd1, &jd2);

  /* Julian centuries TDB/TT since J2000.0 — argument for eraFaom03. */
  double t = jd2 / ERFA_DJC;   /* ERFA_DJC = 36525.0 days/century */

  /* Mean longitude of the Moon's ascending node (radians). */
  double mean_node_rad = eraFaom03(t);

  double node_deg;

  switch (calc_type) {
    case ERFA_CALC_MEAN_LUNAR_NODE:
      node_deg = mean_node_rad * RAD_TO_DEG;
      break;

    case ERFA_CALC_TRUE_LUNAR_NODE: {
      /*
       * True node = mean node + nutation correction in longitude projected
       * onto the ecliptic.
       *
       * dpsi: nutation in longitude (rad), referred to mean ecliptic of date.
       * eps0: mean obliquity of the ecliptic (rad), eraObl06.
       *
       * The correction Δnode ≈ dpsi * cos(eps0) accounts for how the
       * nutation in longitude shifts the node longitude along the ecliptic.
       * This matches the Swiss Ephemeris / Astro-Seek "True Node" definition.
       */
      double dpsi, deps;
      eraNut06a(jd1, jd2, &dpsi, &deps);

      double eps0 = eraObl06(jd1, jd2);

      double true_node_rad = mean_node_rad + dpsi * cos(eps0);
      node_deg = true_node_rad * RAD_TO_DEG;
      break;
    }

    default:
      if (error_buf && buf_size > 0) {
        snprintf(error_buf, buf_size, "unknown calc_type: %d", (int)calc_type);
      }
      return -1;
  }

  *longitude = normalize_deg(node_deg);
  return 0;
}
