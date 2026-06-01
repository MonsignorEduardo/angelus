/*
 * time.c — shared astronomical time conversion helpers.
 */

#include "time.h"

#include <cspice/SpiceUsr.h>

#include <string.h>

static void fill_error(char *buf, int size, const char *msg) {
  if (buf && size > 0) {
    strncpy(buf, msg, size - 1);
    buf[size - 1] = '\0';
  }
}

static void get_cspice_error(char *buf, int size) {
  SpiceChar msg[1024] = {0};
  getmsg_c("LONG", 1024, msg);
  reset_c();
  fill_error(buf, size, msg);
}

TimeResult astro_utc_to_et(const char *iso8601) {
  TimeResult result = {0};

  str2et_c(iso8601, &result.et);
  if (failed_c()) {
    get_cspice_error(result.error, sizeof(result.error));
    return result;
  }

  result.ok = 1;
  return result;
}
