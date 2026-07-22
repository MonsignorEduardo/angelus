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

static cJSON *body_state_json(const AngelusBodyState *state, const char *observer,
                              const char *observer_frame) {
  cJSON *result = cJSON_CreateObject();
  if (!result)
    return NULL;

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

  cJSON *direction_j2000 = cJSON_AddArrayToObject(result, "direction_j2000");
  if (!direction_j2000)
    goto fail;

  for (int i = 0; i < 3; i++) {
    if (!isfinite(state->direction_j2000[i]))
      goto fail;
    cJSON *number = cJSON_CreateNumber(state->direction_j2000[i]);
    if (!number || !cJSON_AddItemToArray(direction_j2000, number)) {
      cJSON_Delete(number);
      goto fail;
    }
  }

  if (!isfinite(state->light_time_seconds) || !isfinite(state->longitude_rad) ||
      !isfinite(state->latitude_rad) || !isfinite(state->declination_rad) ||
      !isfinite(state->right_ascension_rad) || !isfinite(state->longitude_rate_rad_day) ||
      !isfinite(state->latitude_rate_rad_day) ||
      !isfinite(state->right_ascension_rate_rad_day) ||
      !isfinite(state->declination_rate_rad_day) || !isfinite(state->distance_au) ||
      !isfinite(state->radial_velocity_km_s) ||
      !cJSON_AddNumberToObject(result, "light_time_seconds", state->light_time_seconds) ||
      !cJSON_AddNumberToObject(result, "longitude_rad", state->longitude_rad) ||
      !cJSON_AddNumberToObject(result, "latitude_rad", state->latitude_rad) ||
      !cJSON_AddNumberToObject(result, "declination_rad", state->declination_rad) ||
      !cJSON_AddNumberToObject(result, "right_ascension_rad", state->right_ascension_rad) ||
      !cJSON_AddNumberToObject(result, "longitude_rate_rad_day",
                               state->longitude_rate_rad_day) ||
      !cJSON_AddNumberToObject(result, "latitude_rate_rad_day",
                               state->latitude_rate_rad_day) ||
      !cJSON_AddNumberToObject(result, "right_ascension_rate_rad_day",
                               state->right_ascension_rate_rad_day) ||
      !cJSON_AddNumberToObject(result, "declination_rate_rad_day",
                               state->declination_rate_rad_day) ||
      !cJSON_AddNumberToObject(result, "distance_au", state->distance_au) ||
      !cJSON_AddNumberToObject(result, "radial_velocity_km_s",
                               state->radial_velocity_km_s) ||
      !cJSON_AddStringToObject(result, "frame", "ECLIPJ2000") ||
      !cJSON_AddStringToObject(result, "observer", observer) ||
      !cJSON_AddStringToObject(result, "abcorr", "CN+S"))
    goto fail;

  if (observer_frame && !cJSON_AddStringToObject(result, "observer_frame", observer_frame))
    goto fail;

  return result;

fail:
  cJSON_Delete(result);
  return NULL;
}

static cJSON *topocentric_enu_state_json(const AngelusBodyState *state) {
  cJSON *result = cJSON_CreateObject();
  if (!result)
    return NULL;

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

  if (!isfinite(state->light_time_seconds) ||
      !cJSON_AddNumberToObject(result, "light_time_seconds", state->light_time_seconds) ||
      !cJSON_AddStringToObject(result, "frame", "TOPOCENTRIC_ENU") ||
      !cJSON_AddStringToObject(result, "observer", "SURFACE_LOCATION") ||
      !cJSON_AddStringToObject(result, "observer_frame", "ITRF93") ||
      !cJSON_AddStringToObject(result, "abcorr", "CN+S"))
    goto fail;

  return result;

fail:
  cJSON_Delete(result);
  return NULL;
}

int send_ok_body(int id, const BodyResult *body) {
  cJSON *root = cJSON_CreateObject();
  if (!root || !body)
    goto fail;

  cJSON *result = cJSON_AddObjectToObject(root, "result");
  if (!result || !cJSON_AddNumberToObject(root, "id", id) ||
      !cJSON_AddTrueToObject(root, "ok") ||
      !cJSON_AddNumberToObject(result, "protocol_version", 2) ||
      !cJSON_AddNumberToObject(result, "et_seconds", body->geocentric.et_seconds))
    goto fail;

  cJSON *geocentric = body_state_json(&body->geocentric, "EARTH_CENTER", NULL);
  if (!geocentric || !cJSON_AddItemToObject(result, "geocentric", geocentric)) {
    cJSON_Delete(geocentric);
    goto fail;
  }

  if (body->has_topocentric) {
    cJSON *topocentric = topocentric_enu_state_json(&body->topocentric);
    if (!topocentric || !cJSON_AddItemToObject(result, "topocentric", topocentric)) {
      cJSON_Delete(topocentric);
      goto fail;
    }
  }

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
