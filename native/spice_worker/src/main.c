/*
 * main.c — spice_worker entry point.
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
 */

#include "cspice_ops.h"
#include "jsmn.h"
#include "protocol.h"

#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* ── JSON helpers (write-only, no external lib needed) ───────────────────── */

#define JSON_BUF 65536

static void json_escape(char *out, size_t out_size, const char *src) {
  size_t i = 0, j = 0;
  while (src[i] && j + 8 < out_size) {
    unsigned char c = (unsigned char)src[i++];
    switch (c) {
      case '"':  out[j++] = '\\'; out[j++] = '"';  break;
      case '\\': out[j++] = '\\'; out[j++] = '\\'; break;
      case '\n': out[j++] = '\\'; out[j++] = 'n';  break;
      case '\r': out[j++] = '\\'; out[j++] = 'r';  break;
      case '\t': out[j++] = '\\'; out[j++] = 't';  break;
      default:   out[j++] = (char)c;
    }
  }
  out[j] = '\0';
}

static int send_ok_str(int id, const char *value) {
  char buf[JSON_BUF];
  char esc[512];
  json_escape(esc, sizeof(esc), value);
  int n = snprintf(buf, sizeof(buf),
                   "{\"id\":%d,\"ok\":true,\"result\":\"%s\"}", id, esc);
  if (n < 0 || (size_t)n >= sizeof(buf)) return -1;
  return write_packet(buf, (uint32_t)n);
}

static int send_ok_double(int id, double value) {
  char buf[JSON_BUF];
  int n = snprintf(buf, sizeof(buf),
                   "{\"id\":%d,\"ok\":true,\"result\":%.17g}", id, value);
  if (n < 0 || (size_t)n >= sizeof(buf)) return -1;
  return write_packet(buf, (uint32_t)n);
}

static int send_ok_state(int id, const SpiceState *s) {
  char buf[JSON_BUF];
  int n = snprintf(buf, sizeof(buf),
    "{\"id\":%d,\"ok\":true,\"result\":{"
      "\"state_km\":[%.17g,%.17g,%.17g,%.17g,%.17g,%.17g],"
      "\"distance_au\":%.17g,"
      "\"ecliptic_longitude\":%.17g,"
      "\"ecliptic_latitude\":%.17g,"
      "\"light_time_seconds\":%.17g,"
      "\"et\":%.17g"
    "}}",
    id,
    s->state_km[0], s->state_km[1], s->state_km[2],
    s->state_km[3], s->state_km[4], s->state_km[5],
    s->distance_au,
    s->ecliptic_longitude,
    s->ecliptic_latitude,
    s->light_time_seconds,
    s->et);
  if (n < 0 || (size_t)n >= sizeof(buf)) return -1;
  return write_packet(buf, (uint32_t)n);
}

static int send_error(int id, const char *reason) {
  char buf[JSON_BUF];
  char esc[1024];
  json_escape(esc, sizeof(esc), reason);
  int n = snprintf(buf, sizeof(buf),
                   "{\"id\":%d,\"ok\":false,\"error\":\"%s\"}", id, esc);
  if (n < 0 || (size_t)n >= sizeof(buf)) return -1;
  return write_packet(buf, (uint32_t)n);
}

/* ── Tiny JSON parser ────────────────────────────────────────────────────── */
/*
 * We use jsmn (https://github.com/zserge/jsmn), a zero-dependency
 * tokenizer included as a single header.  The file jsmn.h must be present
 * in this directory (downloaded by the Makefile if not already present).
 */

/* Extract a NUL-terminated string for token i into dest (size dest_size). */
static void tok_str(const char *json, const jsmntok_t *tok,
                    char *dest, size_t dest_size) {
  size_t len = (size_t)(tok->end - tok->start);
  if (len >= dest_size) len = dest_size - 1;
  memcpy(dest, json + tok->start, len);
  dest[len] = '\0';
}

static int tok_eq(const char *json, const jsmntok_t *tok, const char *s) {
  size_t len = (size_t)(tok->end - tok->start);
  return (strlen(s) == len) && (memcmp(json + tok->start, s, len) == 0);
}

/* ── Dispatch ────────────────────────────────────────────────────────────── */

#define MAX_TOKENS 256
#define MAX_PATHS  32

static void dispatch(const char *json) {
  jsmn_parser parser;
  jsmntok_t   tokens[MAX_TOKENS];

  jsmn_init(&parser);
  int count = jsmn_parse(&parser, json, strlen(json), tokens, MAX_TOKENS);

  if (count < 1 || tokens[0].type != JSMN_OBJECT) {
    send_error(0, "invalid JSON object");
    return;
  }

  int id = 0;
  char op[64] = "";

  /* First pass: extract "id" and "op" */
  for (int i = 1; i + 1 < count; i += 2) {
    if (tokens[i].type != JSMN_STRING) continue;

    if (tok_eq(json, &tokens[i], "id")) {
      char tmp[32];
      tok_str(json, &tokens[i + 1], tmp, sizeof(tmp));
      id = atoi(tmp);
    } else if (tok_eq(json, &tokens[i], "op")) {
      tok_str(json, &tokens[i + 1], op, sizeof(op));
    }
  }

  /* ── ping ── */
  if (strcmp(op, "ping") == 0) {
    send_ok_str(id, "pong");
    return;
  }

  /* ── clear_kernels ── */
  if (strcmp(op, "clear_kernels") == 0) {
    char err[1024] = "";
    if (ops_clear_kernels(err, sizeof(err)) == 0)
      send_ok_str(id, "ok");
    else
      send_error(id, err);
    return;
  }

  /* ── load_kernels ── */
  if (strcmp(op, "load_kernels") == 0) {
    const char *paths[MAX_PATHS];
    char path_storage[MAX_PATHS][4096];
    int  path_count = 0;

    for (int i = 1; i + 1 < count; i += 2) {
      if (!tok_eq(json, &tokens[i], "paths")) continue;
      if (tokens[i + 1].type != JSMN_ARRAY) break;

      int arr_size = tokens[i + 1].size;
      int j = i + 2;
      for (int k = 0; k < arr_size && path_count < MAX_PATHS && j < count; k++, j++) {
        tok_str(json, &tokens[j], path_storage[path_count], 4096);
        paths[path_count] = path_storage[path_count];
        path_count++;
      }
      break;
    }

    char err[1024] = "";
    if (ops_load_kernels(paths, path_count, err, sizeof(err)) == 0)
      send_ok_str(id, "ok");
    else
      send_error(id, err);
    return;
  }

  /* ── load_default_kernels ── */
  if (strcmp(op, "load_default_kernels") == 0) {
    char base_path[4096] = "";

    for (int i = 1; i + 1 < count; i += 2) {
      if (tok_eq(json, &tokens[i], "base_path")) {
        tok_str(json, &tokens[i + 1], base_path, sizeof(base_path));
        break;
      }
    }

    /* Build paths for the default v0.1 kernel set */
    const char *kernel_files[] = {
      "naif0012.tls",
      "pck00011.tpc",
      "gm_de440.tpc",
      "de442.bsp",
      "mar099.bsp",
      "jup349.bsp",
      "sat459.bsp",
      "ura184_part-1.bsp",
      "ura184_part-2.bsp",
      "ura184_part-3.bsp",
      "nep105.bsp",
      "plu060.bsp"
    };
    int nfiles = (int)(sizeof(kernel_files) / sizeof(kernel_files[0]));

    char full_paths[MAX_PATHS][4096];
    const char *paths[MAX_PATHS];
    for (int i = 0; i < nfiles; i++) {
      snprintf(full_paths[i], sizeof(full_paths[i]), "%s/%s", base_path, kernel_files[i]);
      paths[i] = full_paths[i];
    }

    char err[1024] = "";
    if (ops_load_kernels(paths, nfiles, err, sizeof(err)) == 0)
      send_ok_str(id, "ok");
    else
      send_error(id, err);
    return;
  }

  /* ── utc_to_et ── */
  if (strcmp(op, "utc_to_et") == 0) {
    char utc[128] = "";

    for (int i = 1; i + 1 < count; i += 2) {
      if (tok_eq(json, &tokens[i], "utc")) {
        tok_str(json, &tokens[i + 1], utc, sizeof(utc));
        break;
      }
    }

    double et;
    char err[1024] = "";
    if (ops_utc_to_et(utc, &et, err, sizeof(err)) == 0)
      send_ok_double(id, et);
    else
      send_error(id, err);
    return;
  }

  /* ── state ── */
  if (strcmp(op, "state") == 0) {
    char target[128]   = "";
    char observer[128] = "EARTH";
    char frame[128]    = "ECLIPJ2000";
    char abcorr[32]    = "LT+S";
    double et = 0.0;

    for (int i = 1; i + 1 < count; i += 2) {
      if (tok_eq(json, &tokens[i], "target"))   tok_str(json, &tokens[i+1], target, sizeof(target));
      else if (tok_eq(json, &tokens[i], "observer")) tok_str(json, &tokens[i+1], observer, sizeof(observer));
      else if (tok_eq(json, &tokens[i], "frame"))    tok_str(json, &tokens[i+1], frame, sizeof(frame));
      else if (tok_eq(json, &tokens[i], "abcorr"))   tok_str(json, &tokens[i+1], abcorr, sizeof(abcorr));
      else if (tok_eq(json, &tokens[i], "et")) {
        char tmp[64];
        tok_str(json, &tokens[i+1], tmp, sizeof(tmp));
        et = atof(tmp);
      }
    }

    SpiceState s;
    char err[1024] = "";
    if (ops_state(target, et, observer, frame, abcorr, &s, err, sizeof(err)) == 0)
      send_ok_state(id, &s);
    else
      send_error(id, err);
    return;
  }

  /* Unknown op */
  char msg[128];
  snprintf(msg, sizeof(msg), "unknown op: %s", op);
  send_error(id, msg);
}

/* ── Entry point ─────────────────────────────────────────────────────────── */

int main(void) {
  /* Use binary mode on stdout/stdin to avoid CRLF translation on Windows. */
#ifdef _WIN32
  _setmode(_fileno(stdin),  _O_BINARY);
  _setmode(_fileno(stdout), _O_BINARY);
#endif

  ops_init();

  char *packet;
  while ((packet = read_packet()) != NULL) {
    dispatch(packet);
    free(packet);
  }

  return 0;
}
