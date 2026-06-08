/*
 * main.c — angelus_worker entry point.
 */

#include "astro/cspice_ops.h"
#include "astro/erfa_ops.h"
#include "astro/result.h"
#include "io/packet.h"
#include "io/request.h"
#include "io/response.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void handle_clear_kernels(int id) {
  OpResult result = ops_clear_kernels();

  if (result.ok)
    send_ok_str(id, "ok");
  else
    send_error(id, result.error);
}

static void handle_load_kernels(int id, const LoadKernelsArgs *args) {
  OpResult result = ops_load_kernels(args->paths, args->path_count);

  if (result.ok)
    send_ok_str(id, "ok");
  else
    send_error(id, result.error);
}

static void handle_body(int id, const BodyArgs *args) {
  BodyResult result = ops_body(args->target, args->utc, args->observer,
                               args->frame, args->abcorr);

  if (result.ok)
    send_ok_body(id, &result.state);
  else
    send_error(id, result.error);
}

static void handle_math_point(int id, const MathPointArgs *args) {
  PointResult result = ops_math_point(args->point, args->utc);

  if (result.ok)
    send_ok_point(id, &result.state);
  else
    send_error(id, result.error);
}

static void dispatch_action(ParsedAction *action) {
  switch (action->name) {
  case ACTION_PING:
    send_ok_str(action->id, "pong");
    break;
  case ACTION_CLEAR_KERNELS:
    handle_clear_kernels(action->id);
    break;
  case ACTION_LOAD_KERNELS:
    handle_load_kernels(action->id, &action->args.load_kernels);
    break;
  case ACTION_BODY:
    handle_body(action->id, &action->args.body);
    break;
  case ACTION_MATH_POINT:
    handle_math_point(action->id, &action->args.math_point);
    break;
  case ACTION_UNKNOWN: {
    char msg[128];
    snprintf(msg, sizeof(msg), "unknown op: %s", action->op);
    send_error(action->id, msg);
    break;
  }
  case ACTION_INVALID:
    send_error(action->id, action->error);
    break;
  }
}

int main(void) {
  set_cspice_errors();

  char *packet;
  while ((packet = read_packet()) != NULL) {
    ParsedAction action = parse_packet(packet);
    dispatch_action(&action);
    parsed_action_free(&action);
    free(packet);
  }

  fclose(stdin);
  fclose(stdout);

  return 0;
}
