/*
 * request.h — JSON request parsing for angelus_worker operations.
 */

#ifndef ANGELUS_IO_REQUEST_H
#define ANGELUS_IO_REQUEST_H

#include <cjson/cJSON.h>

#define REQUEST_MAX_PATHS 32

typedef enum {
  ACTION_INVALID,
  ACTION_UNKNOWN,
  ACTION_PING,
  ACTION_CLEAR_KERNELS,
  ACTION_LOAD_KERNELS,
  ACTION_BODY,
  ACTION_TOPOCENTRIC_BODY,
  ACTION_MATH_POINT,
} ActionName;

typedef struct {
  const char *paths[REQUEST_MAX_PATHS];
  int path_count;
} LoadKernelsArgs;

typedef struct {
  const char *target;
  const char *utc;
} BodyArgs;

typedef struct {
  const char *target;
  const char *utc;
  double latitude_degrees;
  double longitude_degrees;
  double ellipsoidal_height_m;
} TopocentricBodyArgs;

typedef struct {
  const char *point;
  const char *utc;
} MathPointArgs;

typedef struct {
  ActionName name;
  int id;
  const char *op;
  const char *error;
  cJSON *root;

  union {
    LoadKernelsArgs load_kernels;
    BodyArgs body;
    TopocentricBodyArgs topocentric_body;
    MathPointArgs math_point;
  } args;
} ParsedAction;

ParsedAction parse_packet(const char *json);
void parsed_action_free(ParsedAction *action);

#endif /* ANGELUS_IO_REQUEST_H */
