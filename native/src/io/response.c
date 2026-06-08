/*
 * response.c — JSON response serialization for the angelus_worker protocol.
 */

#include "response.h"

#include "io/packet.h"

#include <cjson/cJSON.h>

#include <stdint.h>
#include <stdlib.h>
#include <string.h>

static int send_json(cJSON *root) {
  char *text = cJSON_PrintUnformatted(root);
  cJSON_Delete(root);
  if (!text)
    return -1;

  int rc = write_packet(text, (uint32_t)strlen(text));
  free(text);
  return rc;
}

int send_ok_str(int id, const char *value) {
  cJSON *root = cJSON_CreateObject();
  cJSON_AddNumberToObject(root, "id", id);
  cJSON_AddTrueToObject(root, "ok");
  cJSON_AddStringToObject(root, "result", value);
  return send_json(root);
}

int send_ok_body(int id, const AngelusBodyState *state) {
  cJSON *root = cJSON_CreateObject();
  cJSON *result = cJSON_AddObjectToObject(root, "result");
  cJSON *state_km = cJSON_AddArrayToObject(result, "state_km");

  cJSON_AddNumberToObject(root, "id", id);
  cJSON_AddTrueToObject(root, "ok");

  for (int i = 0; i < 6; i++)
    cJSON_AddItemToArray(state_km, cJSON_CreateNumber(state->state_km[i]));

  cJSON_AddNumberToObject(result, "light_time_seconds", state->light_time_seconds);
  cJSON_AddNumberToObject(result, "et_seconds", state->et_seconds);

  return send_json(root);
}

int send_ok_point(int id, const AngelusPointState *state) {
  cJSON *root = cJSON_CreateObject();
  cJSON *result = cJSON_AddObjectToObject(root, "result");

  cJSON_AddNumberToObject(root, "id", id);
  cJSON_AddTrueToObject(root, "ok");

  cJSON_AddNumberToObject(result, "longitude_rad", state->longitude_rad);
  cJSON_AddNumberToObject(result, "speed_rad_day", state->speed_rad_day);
  cJSON_AddNumberToObject(result, "et_seconds", state->et_seconds);

  return send_json(root);
}

int send_error(int id, const char *reason) {
  cJSON *root = cJSON_CreateObject();
  cJSON_AddNumberToObject(root, "id", id);
  cJSON_AddFalseToObject(root, "ok");
  cJSON_AddStringToObject(root, "error", reason);
  return send_json(root);
}
