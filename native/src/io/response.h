/*
 * response.h — JSON response helpers for the angelus_worker protocol.
 */

#ifndef ANGELUS_IO_RESPONSE_H
#define ANGELUS_IO_RESPONSE_H

#include "astro/result.h"

int send_ok_str(int id, const char *value);
int send_ok_body(int id, const AngelusBodyState *state);
int send_ok_point(int id, const AngelusPointState *state);
int send_error(int id, const char *reason);

#endif /* ANGELUS_IO_RESPONSE_H */
