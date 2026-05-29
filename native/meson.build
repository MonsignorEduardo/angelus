# meson.build — spice_worker native executable
#
# Invocation:
#   This file is driven by the Makefile, which is called by elixir_make.
#   Do not invoke meson directly; use `mix compile` or `just build`.
#
# CSPICE build strategy:
#   Built from source via Meson wrap subproject (subprojects/cspice.wrap).
#   Meson clones https://github.com/MonsignorEduardo/cspice at tag N0067
#   and compiles libcspice.a locally — no prebuilt binary required.
#
# ERFA build strategy:
#   Bundled source files under native/vendor/erfa/ (v2.0.1).
#   Compiled as an internal static library — no system dependency required.
#
# Supported targets: aarch64-apple-darwin, x86_64-linux-gnu.

project(
    'spice_worker',
    'c',
    version: '0.0.2',
    default_options: ['c_std=c11', 'warning_level=2'],
)

cc = meson.get_compiler('c')
native_dir = meson.current_source_dir()
mix_app_path = run_command('sh', '-c', 'printf "%s" "$MIX_APP_PATH"', check: true).stdout()

# ── CSPICE: built from source via wrap subproject ─────────────────────────
cspice_dep = dependency('cspice', fallback: ['cspice', 'cspice_dep'])

# ── ERFA: bundled source, compiled as internal static library ────────────
erfa_sources = run_command(
    'sh', '-c', 'ls ' + native_dir / 'vendor/erfa' + '/*.c | grep -v erfaversion.c',
    check: true,
).stdout().strip().split('\n')

erfa_lib = static_library(
    'erfa',
    erfa_sources,
    include_directories : include_directories('vendor/erfa'),
    c_args              : ['-w'],   # suppress warnings from third-party sources
)

erfa_dep = declare_dependency(
    link_with           : erfa_lib,
    include_directories : include_directories('vendor/erfa'),
)

# ── cJSON: system dependency via pkg-config ───────────────────────────────
cjson_dep = dependency('libcjson')

# ── Sources ───────────────────────────────────────────────────────────────
sources = files(
    'src/cspice_ops.c',
    'src/erfa_ops.c',
    'src/main.c',
    'src/protocol.c',
)

# ── Executable ────────────────────────────────────────────────────────────
executable(
    'spice_worker',
    sources,
    dependencies:        [cspice_dep, cjson_dep, erfa_dep],
    include_directories: include_directories('src', 'vendor/erfa'),
    link_args:           ['-lm'],
    install:             true,
    install_dir:         mix_app_path / 'priv',
)
