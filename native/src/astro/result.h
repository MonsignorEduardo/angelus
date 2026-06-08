/*
 * result.h — shared native result types returned through the JSON protocol.
 */

#ifndef ANGELUS_ASTRO_RESULT_H
#define ANGELUS_ASTRO_RESULT_H

#include "state.h"

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
  AngelusBodyState state;
  char error[1024];
} BodyResult;

typedef struct {
  int ok;
  AngelusPointState state;
  char error[1024];
} PointResult;

#endif /* ANGELUS_ASTRO_RESULT_H */
