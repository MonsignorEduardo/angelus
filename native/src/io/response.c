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

static const char *frame_name(AngelusReferenceFrame frame) {
  switch (frame) {
  case ANGELUS_FRAME_ICRF:
    return "ICRF";
  case ANGELUS_FRAME_J2000:
    return "J2000";
  case ANGELUS_FRAME_GCRS:
    return "GCRS";
  case ANGELUS_FRAME_ITRF:
    return "ITRF";
  case ANGELUS_FRAME_TRUE_ECLIPTIC_OF_DATE:
    return "TRUE_ECLIPTIC_OF_DATE";
  case ANGELUS_FRAME_ECLIPJ2000:
    return "ECLIPJ2000";
  default:
    return "J2000";
  }
}

static const char *abcorr_name(AngelusAberrationCorrection abcorr) {
  switch (abcorr) {
  case ANGELUS_ABCORR_NONE:
    return "NONE";
  case ANGELUS_ABCORR_LT:
    return "LT";
  case ANGELUS_ABCORR_LTS:
    return "LT+S";
  case ANGELUS_ABCORR_CN:
    return "CN";
  case ANGELUS_ABCORR_CNS:
    return "CN+S";
  default:
    return "LT+S";
  }
}

int send_ok_state(int id, const AngelusGeocentricState *state) {
  cJSON *root = cJSON_CreateObject();
  cJSON *result = cJSON_AddObjectToObject(root, "result");
  cJSON *state_km = cJSON_AddArrayToObject(result, "state_km");

  cJSON_AddNumberToObject(root, "id", id);
  cJSON_AddTrueToObject(root, "ok");

  for (int i = 0; i < 6; i++)
    cJSON_AddItemToArray(state_km, cJSON_CreateNumber(state->state_km[i]));

  cJSON_AddNumberToObject(result, "distance_km", state->distance_km);
  cJSON_AddNumberToObject(result, "distance_au", state->distance_au);
  cJSON_AddNumberToObject(result, "right_ascension_rad",
                          state->right_ascension_rad);
  cJSON_AddNumberToObject(result, "declination_rad", state->declination_rad);
  cJSON_AddNumberToObject(result, "ecliptic_longitude_rad",
                          state->ecliptic_longitude_rad);
  cJSON_AddNumberToObject(result, "ecliptic_latitude_rad",
                          state->ecliptic_latitude_rad);
  cJSON_AddNumberToObject(result, "radial_velocity_km_s",
                          state->radial_velocity_km_s);
  cJSON_AddNumberToObject(result, "ecliptic_longitude_speed_rad_day",
                          state->ecliptic_longitude_speed_rad_day);
  cJSON_AddNumberToObject(result, "ecliptic_latitude_speed_rad_day",
                          state->ecliptic_latitude_speed_rad_day);
  cJSON_AddNumberToObject(result, "distance_speed_km_s",
                          state->distance_speed_km_s);
  cJSON_AddNumberToObject(result, "light_time_seconds",
                          state->light_time_seconds);
  cJSON_AddNumberToObject(result, "et_seconds", state->et_seconds);
  cJSON_AddStringToObject(result, "frame", frame_name(state->frame));
  cJSON_AddStringToObject(result, "abcorr", abcorr_name(state->abcorr));

  return send_json(root);
}

int send_error(int id, const char *reason) {
  cJSON *root = cJSON_CreateObject();
  cJSON_AddNumberToObject(root, "id", id);
  cJSON_AddFalseToObject(root, "ok");
  cJSON_AddStringToObject(root, "error", reason);
  return send_json(root);
}
