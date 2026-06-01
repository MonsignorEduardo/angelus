/*
 * defaults.c — default SPICE kernel set path construction.
 */

#include "defaults.h"

#include <stdio.h>

KernelPaths default_kernel_paths(const char *base_path) {
  KernelPaths result = {0};
  static const char *kernel_files[] = {
      "naif0012.tls",      "pck00011.tpc",      "gm_de440.tpc",
      "de442.bsp",         "mar099.bsp",        "jup349.bsp",
      "sat459.bsp",        "ura184_part-1.bsp", "ura184_part-2.bsp",
      "ura184_part-3.bsp", "nep105.bsp",        "plu060.bsp",
  };
  int nfiles = (int)(sizeof(kernel_files) / sizeof(kernel_files[0]));

  for (int i = 0; i < nfiles; i++) {
    snprintf(result.storage[i], DEFAULT_KERNEL_PATH_SIZE, "%s/%s", base_path,
             kernel_files[i]);
    result.paths[i] = result.storage[i];
  }

  result.count = nfiles;
  return result;
}
