/*
 * packet.c — length-prefixed JSON read/write for packet:4 Port protocol.
 */

#include "packet.h"

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

static int read_exact(void *buf, size_t n) {
  size_t total = 0;
  unsigned char *ptr = (unsigned char *)buf;

  while (total < n) {
    int c = fgetc(stdin);
    if (c == EOF)
      return -1;
    ptr[total++] = (unsigned char)c;
  }
  return 0;
}

char *read_packet(void) {
  unsigned char hdr[4];

  if (read_exact(hdr, 4) != 0)
    return NULL;

  uint32_t length = ((uint32_t)hdr[0] << 24) | ((uint32_t)hdr[1] << 16) |
                    ((uint32_t)hdr[2] << 8) | (uint32_t)hdr[3];

  if (length == 0 || length > PACKET_MAX_PAYLOAD)
    return NULL;

  char *buf = malloc(length + 1);
  if (!buf)
    return NULL;

  if (read_exact(buf, length) != 0) {
    free(buf);
    return NULL;
  }

  buf[length] = '\0';
  return buf;
}

int write_packet(const char *json, uint32_t length) {
  unsigned char hdr[4];
  hdr[0] = (unsigned char)((length >> 24) & 0xFF);
  hdr[1] = (unsigned char)((length >> 16) & 0xFF);
  hdr[2] = (unsigned char)((length >> 8) & 0xFF);
  hdr[3] = (unsigned char)(length & 0xFF);

  if (fwrite(hdr, 1, 4, stdout) != 4)
    return -1;
  if (fwrite(json, 1, length, stdout) != length)
    return -1;
  fflush(stdout);
  return 0;
}
