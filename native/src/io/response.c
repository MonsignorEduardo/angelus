/*
 * response.c — JSON response serialization for the angelus_worker protocol.
 */

#include "response.h"

#include "io/packet.h"

#include <cjson/cJSON.h>

#include <math.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

static int send_json(cJSON *root) {
  if (!root)
    return -1;

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
  if (!root || !value || !cJSON_AddNumberToObject(root, "id", id) ||
      !cJSON_AddTrueToObject(root, "ok") ||
      !cJSON_AddStringToObject(root, "result", value)) {
    cJSON_Delete(root);
    return -1;
  }
  return send_json(root);
}

int send_ok_body(int id, const AngelusBodyState *state) {
  cJSON *root = cJSON_CreateObject();
  if (!root || !state)
    goto fail;

  cJSON *result = cJSON_AddObjectToObject(root, "result");
  if (!result || !cJSON_AddNumberToObject(root, "id", id) ||
      !cJSON_AddTrueToObject(root, "ok"))
    goto fail;

  cJSON *state_km = cJSON_AddArrayToObject(result, "state_km");
  if (!state_km)
    goto fail;

  for (int i = 0; i < 6; i++) {
    if (!isfinite(state->state_km[i]))
      goto fail;
    cJSON *number = cJSON_CreateNumber(state->state_km[i]);
    if (!number || !cJSON_AddItemToArray(state_km, number)) {
      cJSON_Delete(number);
      goto fail;
    }
  }

  if (!isfinite(state->light_time_seconds) || !isfinite(state->et_seconds) ||
       !isfinite(state->longitude_rad) || !isfinite(state->latitude_rad) ||
       !isfinite(state->declination_rad) ||
      !cJSON_AddNumberToObject(result, "light_time_seconds",
                                state->light_time_seconds) ||
       !cJSON_AddNumberToObject(result, "et_seconds", state->et_seconds) ||
       !cJSON_AddNumberToObject(result, "longitude_rad", state->longitude_rad) ||
       !cJSON_AddNumberToObject(result, "latitude_rad", state->latitude_rad) ||
       !cJSON_AddNumberToObject(result, "declination_rad", state->declination_rad))
    goto fail;

  return send_json(root);

fail:
  cJSON_Delete(root);
  return -1;
}

int send_ok_point(int id, const AngelusPointState *state) {
  cJSON *root = cJSON_CreateObject();
  if (!root || !state || !isfinite(state->longitude_rad) ||
       !isfinite(state->declination_rad) || !isfinite(state->speed_rad_day) ||
       !isfinite(state->et_seconds))
    goto fail;

  cJSON *result = cJSON_AddObjectToObject(root, "result");
  if (!result || !cJSON_AddNumberToObject(root, "id", id) ||
       !cJSON_AddTrueToObject(root, "ok") ||
       !cJSON_AddNumberToObject(result, "longitude_rad", state->longitude_rad) ||
       !cJSON_AddNumberToObject(result, "declination_rad", state->declination_rad) ||
      !cJSON_AddNumberToObject(result, "speed_rad_day", state->speed_rad_day) ||
      !cJSON_AddNumberToObject(result, "et_seconds", state->et_seconds))
    goto fail;

  return send_json(root);

fail:
  cJSON_Delete(root);
  return -1;
}

int send_error(int id, const char *reason) {
  cJSON *root = cJSON_CreateObject();
  if (!root || !reason || !cJSON_AddNumberToObject(root, "id", id) ||
      !cJSON_AddFalseToObject(root, "ok") ||
      !cJSON_AddStringToObject(root, "error", reason)) {
    cJSON_Delete(root);
    return -1;
  }
  return send_json(root);
}
