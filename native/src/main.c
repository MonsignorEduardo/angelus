/*
 * main.c — angelus_worker entry point.
 */

#include "astro/cspice_ops.h"
#include "astro/erfa_ops.h"
#include "astro/result.h"
#include "io/packet.h"
#include "io/request.h"
#include "io/response.h"
#include "kernels/defaults.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static AstroState lunar_node_state(double ecliptic_longitude, double et) {
  AstroState state = {0};
  state.ecliptic_longitude = ecliptic_longitude;
  state.et = et;
  return state;
}

static int parse_lunar_node_calc(const char *calculation,
                                 ErfaCalcType *calc_type) {
  if (strcmp(calculation, "mean_lunar_node") == 0) {
    *calc_type = ERFA_CALC_MEAN_LUNAR_NODE;
    return 0;
  }

  if (strcmp(calculation, "true_lunar_node") == 0) {
    *calc_type = ERFA_CALC_TRUE_LUNAR_NODE;
    return 0;
  }

  return -1;
}

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

static void handle_load_default_kernels(int id,
                                        const LoadDefaultKernelsArgs *args) {
  KernelPaths kernel_paths = default_kernel_paths(args->base_path);
  OpResult result = ops_load_kernels(kernel_paths.paths, kernel_paths.count);

  if (result.ok)
    send_ok_str(id, "ok");
  else
    send_error(id, result.error);
}

static void handle_ephemeride(int id, const EphemerideArgs *args) {
  AstroResult result = ops_ephemeride(args->target, args->utc, args->observer,
                                      args->frame, args->abcorr, args->units);

  if (result.ok)
    send_ok_state(id, &result.state);
  else
    send_error(id, result.error);
}

static void handle_lunar_node(int id, const LunarNodeArgs *args) {
  ErfaCalcType calc_type;

  if (parse_lunar_node_calc(args->calculation, &calc_type) != 0) {
    char msg[128];
    snprintf(msg, sizeof(msg), "unknown lunar node calculation: %s",
             args->calculation);
    send_error(id, msg);
    return;
  }

  LunarNodeResult result = ops_lunar_node(calc_type, args->utc, args->units);
  if (!result.ok) {
    send_error(id, result.error);
    return;
  }

  AstroState state = lunar_node_state(result.longitude, result.et);
  send_ok_state(id, &state);
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
  case ACTION_LOAD_DEFAULT_KERNELS:
    handle_load_default_kernels(action->id, &action->args.load_default_kernels);
    break;
  case ACTION_EPHEMERIDE:
    handle_ephemeride(action->id, &action->args.ephemeride);
    break;
  case ACTION_LUNAR_NODE:
    handle_lunar_node(action->id, &action->args.lunar_node);
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
