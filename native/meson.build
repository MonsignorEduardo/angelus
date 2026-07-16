# meson.build — angelus_worker native executable
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
#   Built from source via Meson wrap subproject (subprojects/erfa.wrap).
#   Meson clones https://github.com/MonsignorEduardo/erfa at master
#   and compiles liberfa locally — no prebuilt binary required.
#
# Supported targets: aarch64-apple-darwin, x86_64-linux-gnu.

project(
    'angelus_worker',
    'c',
    version: '1.0.1',
    default_options: ['c_std=c11', 'warning_level=2'],
)

cc = meson.get_compiler('c')
native_dir = meson.current_source_dir()
mix_app_path = run_command('sh', '-c', 'printf "%s" "$MIX_APP_PATH"', check: true).stdout()

# ── CSPICE: built from source via wrap subproject ─────────────────────────
cspice_dep = dependency('cspice', fallback: ['cspice', 'cspice_dep'])

# ── ERFA: built from source via wrap subproject ───────────────────────────
erfa_dep = dependency('erfa', fallback: ['erfa', 'erfa_dep'])

# ── cJSON: system dependency via pkg-config ───────────────────────────────
cjson_dep = dependency('libcjson')

# ── Sources ───────────────────────────────────────────────────────────────
sources = files(
    'src/astro/cspice_ops.c',
    'src/astro/erfa_ops.c',
    'src/astro/frames.c',
    'src/astro/time.c',
    'src/io/packet.c',
    'src/io/request.c',
    'src/io/response.c',
    'src/main.c',
)

# ── Executable ────────────────────────────────────────────────────────────
executable(
    'angelus_worker',
    sources,
    dependencies: [cspice_dep, cjson_dep, erfa_dep],
    include_directories: include_directories('src'),
    link_args: ['-lm'],
    install: true,
    install_dir: mix_app_path / 'priv',
)
