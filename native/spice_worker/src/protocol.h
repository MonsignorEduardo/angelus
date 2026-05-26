/*
 * protocol.h — length-prefixed JSON protocol for spice_worker <-> Elixir Port (packet:4).
 *
 * Frame format (big-endian):
 *   [4 bytes: uint32 length][length bytes: UTF-8 JSON]
 *
 * Requests (Elixir -> worker):
 *   {"id": <int>, "op": "<op>", ...op-specific fields...}
 *
 * Responses (worker -> Elixir):
 *   {"id": <int>, "ok": true,  "result": {...}}
 *   {"id": <int>, "ok": false, "error": "<string>"}
 */

#ifndef ANGELUS_PROTOCOL_H
#define ANGELUS_PROTOCOL_H

#include <stdint.h>

/* Maximum accepted JSON payload size: 4 MB. */
#define PROTOCOL_MAX_PAYLOAD (4 * 1024 * 1024)

/*
 * read_packet — reads one length-prefixed frame from stdin.
 *
 * Returns a heap-allocated NUL-terminated string on success.
 * Caller must free() it.
 * Returns NULL on EOF, read error or oversized payload.
 */
char *read_packet(void);

/*
 * write_packet — writes one length-prefixed frame to stdout.
 *
 * Returns 0 on success, -1 on error.
 */
int write_packet(const char *json, uint32_t length);

#endif /* ANGELUS_PROTOCOL_H */
