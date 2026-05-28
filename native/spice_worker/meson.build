# meson.build — spice_worker native executable
#
# Invocation:
#   This file is driven by the Makefile, which is called by elixir_make.
#   Do not invoke meson directly; use `mix compile` or `just build`.
#
# CSPICE build strategy:
#   Link against the precompiled cspice.a shipped inside the NAIF archive.
#   fetch-libs.sh extracts it to native/libs/spice/lib/cspice.a.
#   No from-source compilation of CSPICE.
#
# Supported targets: aarch64-apple-darwin, x86_64-linux-gnu.

project('spice_worker', 'c', version: '0.0.2', default_options: ['c_std=c11', 'warning_level=2'])

# ── Paths ─────────────────────────────────────────────────────────────────
mix_app_path = run_command('sh', '-c', 'printf "%s" "$MIX_APP_PATH"', check: true).stdout()
worker_dir = meson.current_source_dir()
libs_dir = worker_dir + '/../libs'
jsmn_dir   = libs_dir + '/jsmn'
cspice_dir = libs_dir + '/spice'

# ── CSPICE: prebuilt static library ──────────────────────────────────────
cspice_lib = declare_dependency(
    link_args:    [cspice_dir + '/lib/cspice.a'],
    compile_args: ['-I' + cspice_dir + '/include'],
)

# ── Sources ───────────────────────────────────────────────────────────────
sources = files(
    'src/cspice_ops.c',
    'src/main.c',
    'src/protocol.c',
)

# ── Includes / flags ──────────────────────────────────────────────────────
inc    = include_directories('src')
c_args = ['-DJSMN_STATIC', '-DHAVE_CSPICE', '-I' + jsmn_dir, '-I' + cspice_dir + '/include']

# ── Executable ────────────────────────────────────────────────────────────
executable(
    'spice_worker',
    sources,
    include_directories: inc,
    c_args:       c_args,
    link_args:    ['-lm'],
    dependencies: [cspice_lib],
    install:      true,
    install_dir:  mix_app_path + '/priv',
)
