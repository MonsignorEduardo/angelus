/*
 * request.c — JSON request parsing for angelus_worker operations.
 */

#include "request.h"

#include <string.h>

static int request_id(cJSON *root) {
  cJSON *item = cJSON_GetObjectItem(root, "id");
  return cJSON_IsNumber(item) ? (int)item->valueint : 0;
}

static const char *request_string(cJSON *root, const char *key,
                                  const char *fallback) {
  cJSON *item = cJSON_GetObjectItem(root, key);
  return cJSON_IsString(item) ? item->valuestring : fallback;
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

static LoadKernelsArgs parse_load_kernels(cJSON *root) {
  LoadKernelsArgs args = {0};
  cJSON *arr = cJSON_GetObjectItem(root, "paths");

  if (cJSON_IsArray(arr)) {
    cJSON *item;
    cJSON_ArrayForEach(item, arr) {
      if (cJSON_IsString(item) && args.path_count < REQUEST_MAX_PATHS)
        args.paths[args.path_count++] = item->valuestring;
    }
  }

  return args;
}

ParsedAction parse_packet(const char *json) {
  ParsedAction action = {0};
  action.name = ACTION_INVALID;
  action.error = "invalid JSON";

  cJSON *root = cJSON_Parse(json);
  if (!root)
    return action;

  action.root = root;
  action.id = request_id(root);

  cJSON *op_item = cJSON_GetObjectItem(root, "op");
  if (!op_item || !cJSON_IsString(op_item)) {
    action.error = "missing op";
    return action;
  }

  action.op = op_item->valuestring;
  action.name = action_name(action.op);

  switch (action.name) {
  case ACTION_LOAD_KERNELS:
    action.args.load_kernels = parse_load_kernels(root);
    break;
  case ACTION_BODY:
    action.args.body.target = request_string(root, "target", "");
    action.args.body.utc = request_string(root, "utc", "");
    action.args.body.observer = request_string(root, "observer", "EARTH");
    action.args.body.frame = request_string(root, "frame", "ECLIPJ2000");
    action.args.body.abcorr = request_string(root, "abcorr", "LT+S");
    break;
  case ACTION_MATH_POINT:
    action.args.math_point.point = request_string(root, "point", "");
    action.args.math_point.utc = request_string(root, "utc", "");
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
