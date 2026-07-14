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

static int handle_clear_kernels(int id) {
  OpResult result = ops_clear_kernels();

  if (result.ok)
    return send_ok_str(id, "ok");
  else
    return send_error(id, result.error);
}

static int handle_load_kernels(int id, const LoadKernelsArgs *args) {
  OpResult result = ops_load_kernels(args->paths, args->path_count);

  if (result.ok)
    return send_ok_str(id, "ok");
  else
    return send_error(id, result.error);
}

static int handle_body(int id, const BodyArgs *args) {
  BodyResult result = get_position(args->target, args->utc);

  if (result.ok)
    return send_ok_body(id, &result.state);
  else
    return send_error(id, result.error);
}

static int handle_math_point(int id, const MathPointArgs *args) {
  PointResult result = ops_math_point(args->point, args->utc);

  if (result.ok)
    return send_ok_point(id, &result.state);
  else
    return send_error(id, result.error);
}

static int dispatch_action(ParsedAction *action) {
  switch (action->name) {
  case ACTION_PING:
    return send_ok_str(action->id, "pong");
  case ACTION_CLEAR_KERNELS:
    return handle_clear_kernels(action->id);
  case ACTION_LOAD_KERNELS:
    return handle_load_kernels(action->id, &action->args.load_kernels);
  case ACTION_BODY:
    return handle_body(action->id, &action->args.body);
  case ACTION_MATH_POINT:
    return handle_math_point(action->id, &action->args.math_point);
  case ACTION_UNKNOWN: {
    char msg[128];
    snprintf(msg, sizeof(msg), "unknown op: %s", action->op);
    return send_error(action->id, msg);
  }
  case ACTION_INVALID:
    return send_error(action->id, action->error);
  }

  return -1;
}

int main(void) {
  set_cspice_errors();

  char *packet;
  while ((packet = read_packet()) != NULL) {
    ParsedAction action = parse_packet(packet);
    int rc = dispatch_action(&action);
    parsed_action_free(&action);
    free(packet);
    if (rc != 0)
      return EXIT_FAILURE;
  }

  fclose(stdin);
  fclose(stdout);

  return 0;
}
