/*
 * request.c — JSON request parsing for angelus_worker operations.
 */

#include "request.h"

#include <limits.h>
#include <math.h>
#include <string.h>

static int parse_request_id(cJSON *root, int *id) {
  cJSON *item = cJSON_GetObjectItemCaseSensitive(root, "id");
  if (!cJSON_IsNumber(item) || !isfinite(item->valuedouble) ||
      item->valuedouble < 1 || item->valuedouble > INT_MAX ||
      floor(item->valuedouble) != item->valuedouble)
    return -1;

  *id = (int)item->valuedouble;
  return 0;
}

static int parse_request_string(cJSON *root, const char *key,
                                const char **value) {
  cJSON *item = cJSON_GetObjectItemCaseSensitive(root, key);
  if (!cJSON_IsString(item) || !item->valuestring || item->valuestring[0] == '\0')
    return -1;

  *value = item->valuestring;
  return 0;
}

static ActionName action_name(const char *op) {
  if (strcmp(op, "ping") == 0)
    return ACTION_PING;
  if (strcmp(op, "clear_kernels") == 0)
    return ACTION_CLEAR_KERNELS;
  if (strcmp(op, "load_kernels") == 0)
    return ACTION_LOAD_KERNELS;
  if (strcmp(op, "body") == 0)
    return ACTION_BODY;
  if (strcmp(op, "math_point") == 0)
    return ACTION_MATH_POINT;
  return ACTION_UNKNOWN;
}

static int parse_load_kernels(cJSON *root, LoadKernelsArgs *args) {
  cJSON *arr = cJSON_GetObjectItemCaseSensitive(root, "paths");
  if (!cJSON_IsArray(arr))
    return -1;

  int count = cJSON_GetArraySize(arr);
  if (count < 0 || count > REQUEST_MAX_PATHS)
    return -1;

  cJSON *item;
  cJSON_ArrayForEach(item, arr) {
    if (!cJSON_IsString(item) || !item->valuestring || item->valuestring[0] == '\0')
      return -1;
    args->paths[args->path_count++] = item->valuestring;
  }

  return 0;
}

static int parse_surface_observer(cJSON *root, AngelusSurfaceObserver *observer) {
  cJSON *item = cJSON_GetObjectItemCaseSensitive(root, "observer");
  if (!item)
    return 0;

  if (!cJSON_IsObject(item))
    return -1;

  cJSON *kind = cJSON_GetObjectItemCaseSensitive(item, "kind");
  cJSON *latitude = cJSON_GetObjectItemCaseSensitive(item, "latitude_rad");
  cJSON *longitude = cJSON_GetObjectItemCaseSensitive(item, "longitude_rad");
  cJSON *height = cJSON_GetObjectItemCaseSensitive(item, "height_km");
  cJSON *frame = cJSON_GetObjectItemCaseSensitive(item, "body_fixed_frame");

  if (!cJSON_IsString(kind) || strcmp(kind->valuestring, "surface") != 0 ||
      !cJSON_IsString(frame) || strcmp(frame->valuestring, "ITRF93") != 0 ||
      !cJSON_IsNumber(latitude) || !isfinite(latitude->valuedouble) ||
      !cJSON_IsNumber(longitude) || !isfinite(longitude->valuedouble) ||
      !cJSON_IsNumber(height) || !isfinite(height->valuedouble) ||
      latitude->valuedouble < -1.5707963267948966 ||
      latitude->valuedouble > 1.5707963267948966 ||
      longitude->valuedouble < -3.1415926535897932 ||
      longitude->valuedouble > 3.1415926535897932 ||
      height->valuedouble < -0.5 || height->valuedouble > 100.0)
    return -1;

  observer->present = 1;
  observer->latitude_rad = latitude->valuedouble;
  observer->longitude_rad = longitude->valuedouble;
  observer->height_km = height->valuedouble;
  return 0;
}

ParsedAction parse_packet(const char *json) {
  ParsedAction action = {0};
  action.name = ACTION_INVALID;
  action.id = -1;
  action.error = "invalid JSON";

  cJSON *root = cJSON_Parse(json);
  if (!root)
    return action;

  action.root = root;
  if (!cJSON_IsObject(root))
    return action;

  if (parse_request_id(root, &action.id) != 0) {
    action.error = "invalid id";
    return action;
  }

  cJSON *op_item = cJSON_GetObjectItemCaseSensitive(root, "op");
  if (!cJSON_IsString(op_item) || !op_item->valuestring ||
      op_item->valuestring[0] == '\0') {
    action.error = "invalid op";
    return action;
  }

  action.op = op_item->valuestring;
  action.name = action_name(action.op);

  switch (action.name) {
  case ACTION_LOAD_KERNELS:
    if (parse_load_kernels(root, &action.args.load_kernels) != 0) {
      action.name = ACTION_INVALID;
      action.error = "invalid paths";
    }
    break;
  case ACTION_BODY:
    if (parse_request_string(root, "target", &action.args.body.target) != 0 ||
        parse_request_string(root, "utc", &action.args.body.utc) != 0 ||
        parse_surface_observer(root, &action.args.body.observer) != 0) {
      action.name = ACTION_INVALID;
      action.error = "invalid body arguments";
    }
    break;
  case ACTION_MATH_POINT:
    if (parse_request_string(root, "point", &action.args.math_point.point) != 0 ||
        parse_request_string(root, "utc", &action.args.math_point.utc) != 0) {
      action.name = ACTION_INVALID;
      action.error = "invalid math_point arguments";
    }
    break;
  case ACTION_UNKNOWN:
    action.error = "unknown op";
    break;
  case ACTION_INVALID:
  case ACTION_PING:
  case ACTION_CLEAR_KERNELS:
    break;
  }

  return action;
}

void parsed_action_free(ParsedAction *action) {
  if (action->root)
    cJSON_Delete(action->root);
  action->root = NULL;
}
