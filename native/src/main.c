/*
 * main.c — angelus_worker entry point.
 *
 * Reads length-prefixed JSON requests from stdin (packet:4 protocol),
 * dispatches to CSPICE operations and writes JSON responses to stdout.
 *
 * The process is single-threaded. Concurrency is achieved by running
 * multiple worker instances managed by the Elixir NimblePool / Supervisor.
 *
 * Supported operations:
 *   ping               -> {"id":N,"ok":true,"result":"pong"}
 *   clear_kernels      -> {"id":N,"ok":true,"result":"ok"}
 *   load_kernels       -> paths:[...]
 *   load_default_kernels -> base_path:"..."
 *   utc_to_et          -> utc:"ISO8601"
 *   state              -> target:"...", et:<float>, observer:"...",
 *                         frame:"...", abcorr:"..."
 *   lunar_node         -> calculation:"mean_lunar_node"|"true_lunar_node",
 *                         et:<float>
 */

#include "cspice_ops.h"
#include "erfa_ops.h"
#include "protocol.h"

#include <cjson/cJSON.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* ── Response helpers ────────────────────────────────────────────────────── */

static int send_json(cJSON *root) {
  char *text = cJSON_PrintUnformatted(root);
  cJSON_Delete(root);
  if (!text)
    return -1;
  int rc = write_packet(text, (uint32_t)strlen(text));
  free(text);
  return rc;
}

static int send_ok_str(int id, const char *value) {
  cJSON *root = cJSON_CreateObject();
  cJSON_AddNumberToObject(root, "id", id);
  cJSON_AddTrueToObject(root, "ok");
  cJSON_AddStringToObject(root, "result", value);
  return send_json(root);
}

static int send_ok_double(int id, double value) {
  cJSON *root = cJSON_CreateObject();
  cJSON_AddNumberToObject(root, "id", id);
  cJSON_AddTrueToObject(root, "ok");
  cJSON_AddNumberToObject(root, "result", value);
  return send_json(root);
}

static int send_ok_state(int id, const SpiceState *s) {
  cJSON *root = cJSON_CreateObject();
  cJSON *result = cJSON_AddObjectToObject(root, "result");
  cJSON *state = cJSON_AddArrayToObject(result, "state_km");

  cJSON_AddNumberToObject(root, "id", id);
  cJSON_AddTrueToObject(root, "ok");

  for (int i = 0; i < 6; i++)
    cJSON_AddItemToArray(state, cJSON_CreateNumber(s->state_km[i]));

  cJSON_AddNumberToObject(result, "distance_au", s->distance_au);
  cJSON_AddNumberToObject(result, "ecliptic_longitude", s->ecliptic_longitude);
  cJSON_AddNumberToObject(result, "ecliptic_latitude", s->ecliptic_latitude);
  cJSON_AddNumberToObject(result, "light_time_seconds", s->light_time_seconds);
  cJSON_AddNumberToObject(result, "et", s->et);

  return send_json(root);
}

static int send_error(int id, const char *reason) {
  cJSON *root = cJSON_CreateObject();
  cJSON_AddNumberToObject(root, "id", id);
  cJSON_AddFalseToObject(root, "ok");
  cJSON_AddStringToObject(root, "error", reason);
  return send_json(root);
}

/*
 * send_ok_lunar_node — respond with the ecliptic longitude of a lunar node.
 *
 * The result uses the same schema as send_ok_state so the Elixir layer can
 * decode both with the same code path.  Latitude, distance, light-time and
 * the state vector are all zero because nodes are geometric points, not
 * physical bodies.
 */
static int send_ok_lunar_node(int id, double ecliptic_longitude, double et) {
  cJSON *root = cJSON_CreateObject();
  cJSON *result = cJSON_AddObjectToObject(root, "result");
  cJSON *state = cJSON_AddArrayToObject(result, "state_km");

  cJSON_AddNumberToObject(root, "id", id);
  cJSON_AddTrueToObject(root, "ok");

  for (int i = 0; i < 6; i++)
    cJSON_AddItemToArray(state, cJSON_CreateNumber(0.0));

  cJSON_AddNumberToObject(result, "distance_au", 0.0);
  cJSON_AddNumberToObject(result, "ecliptic_longitude", ecliptic_longitude);
  cJSON_AddNumberToObject(result, "ecliptic_latitude", 0.0);
  cJSON_AddNumberToObject(result, "light_time_seconds", 0.0);
  cJSON_AddNumberToObject(result, "et", et);

  return send_json(root);
}

/* ── Dispatch ────────────────────────────────────────────────────────────── */

#define MAX_PATHS 32

static void dispatch(const char *json) {
  cJSON *root = cJSON_Parse(json);
  if (!root) {
    send_error(0, "invalid JSON");
    return;
  }

  int id = (int)cJSON_GetObjectItem(root, "id")->valueint;
  cJSON *op_item = cJSON_GetObjectItem(root, "op");
  if (!op_item || !cJSON_IsString(op_item)) {
    send_error(id, "missing op");
    cJSON_Delete(root);
    return;
  }
  const char *op = op_item->valuestring;

  /* ── ping ── */
  if (strcmp(op, "ping") == 0) {
    send_ok_str(id, "pong");

    /* ── clear_kernels ── */
  } else if (strcmp(op, "clear_kernels") == 0) {
    char err[1024] = "";
    if (ops_clear_kernels(err, sizeof(err)) == 0)
      send_ok_str(id, "ok");
    else
      send_error(id, err);

    /* ── load_kernels ── */
  } else if (strcmp(op, "load_kernels") == 0) {
    cJSON *arr = cJSON_GetObjectItem(root, "paths");
    const char *paths[MAX_PATHS];
    int path_count = 0;

    if (cJSON_IsArray(arr)) {
      cJSON *item;
      cJSON_ArrayForEach(item, arr) {
        if (cJSON_IsString(item) && path_count < MAX_PATHS)
          paths[path_count++] = item->valuestring;
      }
    }

    char err[1024] = "";
    if (ops_load_kernels(paths, path_count, err, sizeof(err)) == 0)
      send_ok_str(id, "ok");
    else
      send_error(id, err);

    /* ── load_default_kernels ── */
  } else if (strcmp(op, "load_default_kernels") == 0) {
    cJSON *bp = cJSON_GetObjectItem(root, "base_path");
    const char *base_path = (cJSON_IsString(bp)) ? bp->valuestring : "";

    const char *kernel_files[] = {
        "naif0012.tls",      "pck00011.tpc",      "gm_de440.tpc",
        "de442.bsp",         "mar099.bsp",        "jup349.bsp",
        "sat459.bsp",        "ura184_part-1.bsp", "ura184_part-2.bsp",
        "ura184_part-3.bsp", "nep105.bsp",        "plu060.bsp",
    };
    int nfiles = (int)(sizeof(kernel_files) / sizeof(kernel_files[0]));

    char full_paths[MAX_PATHS][4096];
    const char *paths[MAX_PATHS];
    for (int i = 0; i < nfiles; i++) {
      snprintf(full_paths[i], sizeof(full_paths[i]), "%s/%s", base_path,
               kernel_files[i]);
      paths[i] = full_paths[i];
    }

    char err[1024] = "";
    if (ops_load_kernels(paths, nfiles, err, sizeof(err)) == 0)
      send_ok_str(id, "ok");
    else
      send_error(id, err);

    /* ── utc_to_et ── */
  } else if (strcmp(op, "utc_to_et") == 0) {
    cJSON *utc_item = cJSON_GetObjectItem(root, "utc");
    const char *utc = cJSON_IsString(utc_item) ? utc_item->valuestring : "";

    double et;
    char err[1024] = "";
    if (ops_utc_to_et(utc, &et, err, sizeof(err)) == 0)
      send_ok_double(id, et);
    else
      send_error(id, err);

    /* ── state ── */
  } else if (strcmp(op, "state") == 0) {
    cJSON *t = cJSON_GetObjectItem(root, "target");
    cJSON *o = cJSON_GetObjectItem(root, "observer");
    cJSON *f = cJSON_GetObjectItem(root, "frame");
    cJSON *ab = cJSON_GetObjectItem(root, "abcorr");
    cJSON *et = cJSON_GetObjectItem(root, "et");

    const char *target = cJSON_IsString(t) ? t->valuestring : "";
    const char *observer = cJSON_IsString(o) ? o->valuestring : "EARTH";
    const char *frame = cJSON_IsString(f) ? f->valuestring : "ECLIPJ2000";
    const char *abcorr = cJSON_IsString(ab) ? ab->valuestring : "LT+S";
    double et_val = cJSON_IsNumber(et) ? et->valuedouble : 0.0;

    SpiceState s;
    char err[1024] = "";
    if (ops_state(target, et_val, observer, frame, abcorr, &s, err,
                  sizeof(err)) == 0)
      send_ok_state(id, &s);
    else
      send_error(id, err);

    /* ── lunar_node ── */
  } else if (strcmp(op, "lunar_node") == 0) {
    cJSON *calc_item = cJSON_GetObjectItem(root, "calculation");
    cJSON *et = cJSON_GetObjectItem(root, "et");

    const char *calculation =
        cJSON_IsString(calc_item) ? calc_item->valuestring : "";
    double et_val = cJSON_IsNumber(et) ? et->valuedouble : 0.0;

    ErfaCalcType calc_type;
    if (strcmp(calculation, "mean_lunar_node") == 0) {
      calc_type = ERFA_CALC_MEAN_LUNAR_NODE;
    } else if (strcmp(calculation, "true_lunar_node") == 0) {
      calc_type = ERFA_CALC_TRUE_LUNAR_NODE;
    } else {
      char msg[128];
      snprintf(msg, sizeof(msg), "unknown lunar node calculation: %s",
               calculation);
      send_error(id, msg);
      cJSON_Delete(root);
      return;
    }

    double longitude;
    char err[1024] = "";
    if (ops_lunar_node(calc_type, et_val, &longitude, err, sizeof(err)) == 0)
      send_ok_lunar_node(id, longitude, et_val);
    else
      send_error(id, err);

    /* ── unknown ── */
  } else {
    char msg[128];
    snprintf(msg, sizeof(msg), "unknown op: %s", op);
    send_error(id, msg);
  }

  cJSON_Delete(root);
}

/* ── Entry point ─────────────────────────────────────────────────────────── */

int main(void) {

  ops_init();

  char *packet;
  while ((packet = read_packet()) != NULL) {
    dispatch(packet);
    free(packet);
  }

  return 0;
}
