/*
 * defaults.h — default SPICE kernel set path construction.
 */

#ifndef ANGELUS_KERNELS_DEFAULTS_H
#define ANGELUS_KERNELS_DEFAULTS_H

#define DEFAULT_KERNEL_MAX_PATHS 32
#define DEFAULT_KERNEL_PATH_SIZE 4096

typedef struct {
  const char *paths[DEFAULT_KERNEL_MAX_PATHS];
  char storage[DEFAULT_KERNEL_MAX_PATHS][DEFAULT_KERNEL_PATH_SIZE];
  int count;
} KernelPaths;

KernelPaths default_kernel_paths(const char *base_path);

#endif /* ANGELUS_KERNELS_DEFAULTS_H */
