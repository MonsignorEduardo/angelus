/*
 * state.h - scientific astronomical state structs.
 */

#ifndef ANGELUS_ASTRO_STATE_H
#define ANGELUS_ASTRO_STATE_H

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Scientific astronomical structs only.
 *
 * Conventions:
 * - Distances in kilometers unless stated otherwise.
 * - Velocities in kilometers per second unless stated otherwise.
 * - Angles in radians unless stated otherwise.
 * - Longitude is east-positive.
 * - state_km = {x, y, z, vx, vy, vz}
 * - Ecliptic longitude is normalized to [0, 2*pi).
 * - Ecliptic latitude is in [-pi/2, +pi/2].
 */

typedef enum {
  ANGELUS_FRAME_ICRF = 1,
  ANGELUS_FRAME_J2000 = 2,
  ANGELUS_FRAME_GCRS = 3,
  ANGELUS_FRAME_ITRF = 4,
  ANGELUS_FRAME_TRUE_ECLIPTIC_OF_DATE = 5,
  ANGELUS_FRAME_ECLIPJ2000 = 6
} AngelusReferenceFrame;

typedef enum {
  ANGELUS_ABCORR_NONE = 0,
  ANGELUS_ABCORR_LT = 1,
  ANGELUS_ABCORR_LTS = 2,
  ANGELUS_ABCORR_CN = 3,
  ANGELUS_ABCORR_CNS = 4
} AngelusAberrationCorrection;

typedef struct {
  double state_km[6];

  double distance_km;
  double distance_au;

  double right_ascension_rad;
  double declination_rad;

  double ecliptic_longitude_rad;
  double ecliptic_latitude_rad;

  double radial_velocity_km_s;
  double ecliptic_longitude_speed_rad_day;
  double ecliptic_latitude_speed_rad_day;
  double distance_speed_km_s;

  double light_time_seconds;
  double et_seconds;

  AngelusReferenceFrame frame;
  AngelusAberrationCorrection abcorr;
} AngelusGeocentricState;

#ifdef __cplusplus
}
#endif

#endif /* ANGELUS_ASTRO_STATE_H */
