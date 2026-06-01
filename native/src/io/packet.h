/*
 * packet.h — length-prefixed JSON framing for angelus_worker <-> Elixir Port.
 *
 * Frame format (big-endian):
 *   [4 bytes: uint32 length][length bytes: UTF-8 JSON]
 */

#ifndef ANGELUS_IO_PACKET_H
#define ANGELUS_IO_PACKET_H

#include <stdint.h>

/* Maximum accepted JSON payload size: 4 MB. */
#define PACKET_MAX_PAYLOAD (4 * 1024 * 1024)

/* Returns a heap-allocated NUL-terminated payload. Caller must free(). */
char *read_packet(void);

/* Writes one length-prefixed frame to stdout. Returns 0 on success. */
int write_packet(const char *json, uint32_t length);

#endif /* ANGELUS_IO_PACKET_H */
