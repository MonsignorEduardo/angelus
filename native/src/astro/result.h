/*
 * result.h — shared native result types returned through the JSON protocol.
 */

#ifndef ANGELUS_ASTRO_RESULT_H
#define ANGELUS_ASTRO_RESULT_H

typedef struct {
  double state_km[6];        /* {x, y, z, vx, vy, vz} km / km.s^-1 */
  double distance_au;        /* |r| in AU */
  double ecliptic_longitude; /* degrees [0, 360) unless caller requested rad */
  double ecliptic_latitude; /* degrees (-90, +90] unless caller requested rad */
  double light_time_seconds; /* one-way light time */
  double et;                 /* ephemeris time used */
} AstroState;

typedef struct {
  int ok;
  char error[1024];
} OpResult;

typedef struct {
  int ok;
  double et;
  char error[1024];
} TimeResult;

typedef struct {
  int ok;
  AstroState state;
  char error[1024];
} AstroResult;

typedef struct {
  int ok;
  double longitude;
  double et;
  char error[1024];
} LunarNodeResult;

#endif /* ANGELUS_ASTRO_RESULT_H */
