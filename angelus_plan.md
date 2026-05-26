# Ángelus

**Ángelus** será una librería Elixir para cálculo astrológico preciso, basada en SPICE/JPL y una capa astrológica propia.

## Objetivo

Crear una librería astrológica de alto nivel, con licencia MIT. El alcance de v0.1 se limita a generar efemérides geocéntricas con una base astronómica precisa.

```text
Ángelus = Elixir + NAIF SPICE Toolkit C (CSPICE) + JPL kernels + capa astrológica propia
```

Principios del proyecto:

- Licencia MIT.
- Sin código ni datos externos incompatibles con la licencia del proyecto.
- API astrológica de alto nivel.
- Motor astronómico basado en SPICE/JPL.
- Validación contra JPL Horizons.
- Diseño modular para encapsular el adaptador nativo CSPICE sin exponer detalles internos.

Decisión vigente de aislamiento nativo (2026-05-26):

```text
v0.1 ejecuta CSPICE como proceso externo supervisado por OTP vía Port.
No se ejecuta CSPICE dentro de la VM BEAM mediante NIF en el path principal.
```

Motivo:

- CSPICE no es thread-safe en términos de uso concurrente general.
- Un fallo nativo (segfault/abort) no debe tumbar la VM de Elixir.
- El aislamiento por proceso permite restart automático, timeouts duros y escalado horizontal por pool de workers.

Regla de precedencia para este documento:

- Cualquier bloque anterior o posterior que asuma NIF directo como runtime principal queda reemplazado por la arquitectura `Port + spice_worker`.
- Las menciones de NIF se consideran históricas o internas de transición mientras no contradigan este modelo.

Terminología:

- `CSPICE` significa NAIF SPICE Toolkit para C: https://naif.jpl.nasa.gov/naif/toolkit.html
- Versiones del Toolkit C: https://naif.jpl.nasa.gov/naif/toolkit_C.html
- `SPK` significa SPICE kernel de efemérides/órbitas.
- `LSK` significa leap-seconds kernel, necesario para convertir UTC a ET/TDB en SPICE.
- `PCK` significa planetary constants kernel; contiene constantes físicas, radios y modelos de orientación/rotación de cuerpos.
- `TPC` significa text PCK; por ejemplo `pck00011.tpc` y `gm_de440.tpc`.
- `ET/TDB` significa Ephemeris Time expresado como segundos TDB desde J2000, que es la escala temporal usada por CSPICE para consultar efemérides.
- `body_center` significa centro físico del cuerpo cuando el kernel lo contiene.
- `barycenter` significa baricentro del sistema planetario, no centro físico del planeta.

Fuentes documentales que fijan las decisiones técnicas de v0.1:

- NAIF `aa_summaries.txt` para confirmar cobertura y cuerpos contenidos en `de442.bsp` y en los SPK complementarios.
- Documentación CSPICE `spkezr_c` para confirmar que devuelve estado `{x, y, z, vx, vy, vz}` en km y km/s relativo al observador, con corrección de aberración configurable.
- Documentación Elixir 1.19 para convención de namespace `Angelus.*` y anti-patrón de usar application configuration en librerías.
- Regla Elixir para librerías: no usar `Application.get_env/3` ni `config :angelus, ...` para comportamiento; pasar opciones explícitas mediante keyword lists.

Nota estratégica de diferenciación:

```text
Ángelus debe diferenciarse usando SPICE/JPL moderno directamente, con un set de kernels preciso por defecto desde v0.1.
```

Decisión inicial de kernels:

- `DE442`: SPK planetario base de Ángelus v0.1. Aunque su rango NAIF confirmado es 1549-12-31 ET a 2650-01-25 ET, el rango público v0.1 queda limitado por la intersección del set completo de kernels requeridos.
- `latest_leapseconds.tls`: LSK recomendado para convertir UTC a ET/TDB; actualmente equivale al LSK vigente de NAIF e incluye el último leap second efectivo desde 2017-01-01.
- `pck00011.tpc`: PCK textual recomendado para constantes planetarias, radios y orientación IAU básica de cuerpos.
- `gm_de440.tpc`: constantes GM coherentes con la familia DE440/DE441/DE442; usarlo como complemento textual para constantes gravitacionales cuando CSPICE o validaciones lo requieran.
- SPK complementarios de satélites/planetas: cargarlos por defecto para resolver centros físicos de Marte, Júpiter, Saturno, Urano, Neptuno y Plutón en vez de usar baricentros como aproximación astrológica.
- No ocultar el kernel usado: toda respuesta debe incluir metadata de efeméride/kernel.
- La metadata de kernels debe ser estructurada, no una lista simple de strings.
- Validar contra JPL Horizons indicando explícitamente que la comparación usa `DE442`.
- Validar contra JPL Horizons usando siempre el `spice_target` real de cada cuerpo, no el nombre astrológico genérico.
- Añadir una tarea Mix `mix angelus.kernels` para descargar los kernels requeridos por v0.1, sin cargarlos durante la descarga; en runtime se cargan explícitamente con `Angelus.Spice.load_kernels/0` o rutas equivalentes.
- No usar kernels `s` reducidos en v0.1 (`de442s.bsp`).
- No usar `DE441` en v0.1 porque se fija `DE442` como SPK planetario base moderno y se reduce la matriz de validación inicial.
- No usar `DE440` en v0.1 para reducir combinaciones de validación y fijar una única efeméride.

Política oficial v0.1:

```text
default_modern: DE442
default_precision: DE442 + SPK complementarios para centros físicos
```

Ejemplo de metadata de kernel:

```elixir
%{
  ephemeris: :de442,
  kernel_policy: :default_modern,
  kernels: [
    %{type: :lsk, file: "latest_leapseconds.tls"},
    %{type: :pck, file: "pck00011.tpc"},
    %{type: :pck, file: "gm_de440.tpc"},
    %{
      type: :spk,
      file: "de442.bsp",
      ephemeris: :de442,
      policy: :default_modern,
      range: {~D[1549-12-31], ~D[2650-01-25]}
    },
    %{type: :spk, file: "mar099.bsp", role: :body_center_chain},
    %{type: :spk, file: "jup349.bsp", role: :body_center_chain},
    %{type: :spk, file: "sat459.bsp", role: :body_center_chain},
    %{type: :spk, file: "ura184_part-1.bsp", role: :body_center_chain},
    %{type: :spk, file: "ura184_part-2.bsp", role: :body_center_chain},
    %{type: :spk, file: "ura184_part-3.bsp", role: :body_center_chain},
    %{type: :spk, file: "nep105.bsp", role: :body_center_chain},
    %{type: :spk, file: "plu060.bsp", role: :body_center_chain}
  ]
}
```

Detección de kernel cargado v0.1:

```text
1. Inferir efeméride/política conocida desde el nombre del archivo.
2. Consultar CSPICE para confirmar qué kernels están cargados.
3. Guardar metadata estructurada en cada respuesta pública.
4. Distinguir SPK de efemérides, LSK de escala temporal y PCK/TPC de constantes; no mezclar sus roles en metadata.
```

Mapeo inicial:

```text
de442.bsp       -> ephemeris: :de442,  policy: :default_modern,      range: 1549-12-31..2650-01-25
mar099.bsp      -> role: :body_center_chain, target: MARS / 499
jup349.bsp      -> role: :body_center_chain, target: JUPITER / 599
sat459.bsp      -> role: :body_center_chain, target: SATURN / 699
ura184_part-*.bsp -> role: :body_center_chain, target: URANUS / 799
nep105.bsp      -> role: :body_center_chain, target: NEPTUNE / 899
plu060.bsp      -> role: :body_center_chain, target: PLUTO / 999
```

Si un kernel SPK cargado no pertenece al set preciso por defecto de v0.1, rechazarlo:

```elixir
{:error, {:unsupported_kernel, "custom.bsp"}}
{:error, {:unsupported_kernel, "de442s.bsp"}}
{:error, {:unsupported_kernel, "de441_part-1.bsp"}}
```

Set SPK por defecto v0.1:

```text
de442.bsp
mar099.bsp
jup349.bsp
sat459.bsp
ura184_part-1.bsp
ura184_part-2.bsp
ura184_part-3.bsp
nep105.bsp
plu060.bsp
```

Whitelist kernels textuales v0.1:

```text
latest_leapseconds.tls
pck00011.tpc
gm_de440.tpc
```

No hacer fallback silencioso entre kernels. Si la fecha cae fuera del rango público conocido del set completo cargado, devolver error explícito. Para el set preciso v0.1 actual, el rango público all-body es `1900-01-01` a `2100-01-24`, determinado por la intersección de los kernels requeridos. Este rango se aplica a todas las llamadas `Angelus.Ephemeris.position(s)` en v0.1 aunque un subconjunto de cuerpos pudiera tener cobertura más amplia.

Regla de validación contra JPL Horizons v0.1:

```text
Validar cada posición contra el mismo target usado por Ángelus.
Usar centros físicos para Sol, Luna, planetas y cuerpos físicos soportados cuando el set preciso por defecto esté cargado.
No comparar baricentros contra centros físicos.
```

Tolerancia inicial flexible v0.1:

```text
Longitud/latitud, Sol y planetas: <= 5 arcseconds
Longitud/latitud, Luna:           <= 15 arcseconds
Longitud/latitud, Quirón:         <= 5 arcseconds, si la referencia externa usa la misma fuente orbital
Longitud, nodos/Lilith:           <= 15 arcseconds contra la referencia elegida
Distancia, Sol y planetas:        <= 1.0e-8 AU
Distancia, Luna:                  <= 1.0e-7 AU
Distancia, puntos matemáticos:    nil o valor documentado explícitamente
```

La validación debe registrar siempre la configuración usada:

```text
kernel: de442.bsp
lsk: latest_leapseconds.tls
pck: pck00011.tpc
gm: gm_de440.tpc
observer: EARTH
abcorr: LT+S
frame base: ECLIPJ2000
salida: longitud/latitud eclíptica geocéntrica aparente, con longitud normalizada
spice_target: target real validado
target_kind: :body_center
```

Los tests de v0.1 deben usar fixtures locales generadas desde JPL Horizons:

```text
test/fixtures/horizons/de442_positions.json
```

Los tests se dividen en pruebas puras e integración nativa. `mix test` ejecuta siempre las pruebas puras y nunca usa internet. Las pruebas que requieren `priv/spice_worker` compilado y kernels locales llevan tag ExUnit `:spice_integration`, excluido por defecto, y se ejecutan explícitamente con `mix test --include spice_integration` cuando el worker nativo y los kernels están disponibles.

Formato recomendado de fixture:

```json
{
  "source": "JPL Horizons",
  "generated_at": "2026-05-25T00:00:00Z",
  "kernel": "de442.bsp",
  "lsk": "latest_leapseconds.tls",
  "pck": "pck00011.tpc",
  "gm": "gm_de440.tpc",
  "observer": "EARTH",
  "abcorr": "LT+S",
  "frame_base": "ECLIPJ2000",
  "output": "geocentric_ecliptic_longitude_latitude",
  "tolerance_arcseconds": {
    "default": 5,
    "moon": 15
  },
  "cases": [
    {
      "datetime_utc": "1990-05-24T06:30:00Z",
      "body": "jupiter",
      "spice_target": "JUPITER",
      "spice_id": 599,
      "target_kind": "body_center",
      "longitude": 102.123456789,
      "latitude": 0.123456789,
      "distance_au": 5.123456789
    }
  ]
}
```

Reglas de fixtures:

- `mix test` no debe depender de internet.
- Las fixtures deben incluir la configuración completa usada para generarlas.
- Las fixtures deben comparar contra `spice_target` real; por defecto v0.1 usa centros físicos para los planetas soportados.
- Si se regeneran fixtures, debe quedar claro en el diff qué cambió y por qué.
- Las fixtures v0.1 deben cubrir al menos estos instantes UTC: `1990-05-24T06:30:00Z`, `2026-01-01T00:00:00Z` y `1900-06-01T00:00:00Z`.
- Cada instante de fixture debe incluir los cuerpos/puntos soportados en v0.1: Sol, Luna, Mercurio, Venus, Marte, Júpiter, Saturno, Urano, Neptuno, Plutón, Nodo Norte verdadero, Nodo Norte medio, Quirón y Lilith/Luna Negra (Apogeo Lunar).
- Las fixtures guardan `longitude`, `latitude` y `distance_au`; los ángulos son grados decimales, `longitude` se normaliza a `0 <= longitude < 360` y `latitude` conserva signo.
- Las comparaciones de longitud deben usar distancia angular mínima para manejar correctamente cruces por 0°/360°.

Tarea Mix de validación Horizons:

```elixir
mix angelus.validate.horizons
```

Responsabilidad:

- Consultar JPL Horizons.
- Comparar resultados actuales contra fixtures locales.
- Regenerar fixtures solo con flag explícito.
- No ejecutarse automáticamente durante `mix test`.

Modos recomendados:

```bash
mix angelus.validate.horizons --check
mix angelus.validate.horizons --write
```

Reglas:

- `--check`: requiere `priv/spice_worker` compilado y kernels locales, calcula posiciones con Angelus, consulta Horizons y compara ambos contra `test/fixtures/horizons/de442_positions.json`.
- `--check` falla con un mensaje claro si la fixture local no existe; no crea ni modifica archivos.
- `--write`: consulta Horizons como fuente de verdad, regenera y sobrescribe determinísticamente `test/fixtures/horizons/de442_positions.json`, imprimiendo un resumen de casos cambiados. Si NIF/CSPICE/kernels locales están disponibles, también reporta diferencias Angelus-vs-nueva-fixture, pero no falla solo por mismatch de implementación.
- Si `--write` no puede completar todas las consultas Horizons o validar el set completo de respuestas, falla sin modificar la fixture existente. Debe escribir a un archivo temporal y reemplazar atómicamente solo cuando el nuevo contenido completo sea válido.
- En v0.1, consultar Horizons con una request por combinación cuerpo físico/fecha y usar fixtures equivalentes para puntos matemáticos. Mantener el volumen pequeño para priorizar parsing y errores simples sobre batching.
- Sin flags, mostrar ayuda y no modificar archivos.

Ejemplos:

```text
mercury -> validar contra MERCURY / 199
jupiter -> validar contra JUPITER / 599, no contra JUPITER BARYCENTER / 5
saturn  -> validar contra SATURN / 699, no contra SATURN BARYCENTER / 6
pluto   -> validar contra PLUTO / 999, no contra PLUTO BARYCENTER / 9
```

---

## 1. Arquitectura general

```text
Angelus.Ephemeris
Angelus.Coordinates
Angelus.Adapters.SpiceNative
  ↓
Angelus.Spice
  ↓
Angelus.Spice.Server (GenServer)
  ↓
Port (packet:4)
  ↓
spice_worker (proceso externo)
  ↓
CSPICE + JPL/SPICE kernels
```

Regla principal:

```text
Ángelus no debe exponer CSPICE directamente.
```

`Angelus.Adapters.SpiceNative` será el adaptador astronómico público para `Angelus.Ephemeris`. La ruta obligatoria es `Angelus.Ephemeris -> Angelus.Adapters.SpiceNative -> Angelus.Spice -> Angelus.Spice.Server -> Port -> spice_worker`.

Frontera de responsabilidades v0.1:

```text
spice_worker/CSPICE = NAIF SPICE Toolkit C; efemérides JPL, carga de kernels, UTC -> ET/TDB, vectores aparentes target-observer y conversión a coordenadas latitudinales
Angelus (Elixir/OTP) = semántica de efemérides geocéntricas, metadata, API pública, supervisión y tolerancia a fallos del proceso nativo
```

Decisión sobre `ex_astro`:

- Ángelus no dependerá de `ex_astro` en runtime ni como dependencia de compilación.
- `ex_astro` puede usarse solo como referencia técnica de arquitectura Elixir + SPICE.
- Ángelus tendrá un worker nativo externo mínimo (`spice_worker`) para controlar API, errores, metadata, contrato astrológico, threading y validación, aislado del proceso BEAM.

---

## 2. Estructura del proyecto

```text
angelus/
  mix.exs
  README.md
  LICENSE
  CHANGELOG.md
  THIRD_PARTY_NOTICES.md

  # --- Capa Elixir/OTP ---
  lib/
    angelus.ex                          # punto de entrada público; re-exporta API principal

    angelus/
      application.ex                    # OTP Application; arranca Angelus.Spice.Supervisor

      angle.ex                          # utilidades angulares puras (sin I/O)
      coordinates.ex                    # fachada Elixir sobre resultados del worker externo

      # Capa SPICE (OTP + protocolo Port)
      spice.ex                          # fachada pública: load_kernels, utc_to_et, state, body_target
      spice/
        supervisor.ex                   # supervisa pool de servidores SPICE
        server.ex                       # GenServer dueño de un Port hacia spice_worker
        worker_protocol.ex              # encode/decode mensajes length-prefixed JSON (packet:4)
        body_targets.ex                 # tabla canónica cuerpo astrológico -> SPICE target/id/kind
        kernel_set.ex                   # validación y metadata del set de kernels permitidos en v0.1

      # Capa efemérides (dominio astrológico)
      ephemeris.ex                      # API pública: position/2,3 y positions/2,3
      ephemeris/
        adapter.ex                      # behaviour para inyección de dependencia en tests
        body_position.ex                # struct público %Angelus.Ephemeris.BodyPosition{}

      # Adaptador concreto
      adapters/
        spice_native.ex                 # implementa Adapter delegando a Angelus.Spice

  # --- Tareas Mix ---
  lib/mix/tasks/
    angelus/
      kernels.ex                        # mix angelus.kernels [--force]
      validate/
        horizons.ex                     # mix angelus.validate.horizons [--check|--write]

  # --- Worker nativo externo (proceso C enlazado contra CSPICE) ---
  native/
    spice_worker/
      Makefile                          # compila spice_worker -> priv/spice_worker
      main.c                            # loop stdin/stdout packet:4, despachador de ops
      protocol.h                        # definición del protocolo length-prefixed JSON
      protocol.c                        # read_packet / write_packet
      cspice_ops.h                      # declaraciones de operaciones CSPICE
      cspice_ops.c                      # furnsh, kclear, str2et, spkezr, reclat, convrt, ping
    patches/
      README.md                         # patches mínimos a CSPICE si hacen falta; doc de por qué
    native_sources.lock                 # versión, URL y SHA-256 de CSPICE usados en el último build

  # --- Artefactos compilados (generados, no versionados) ---
  priv/
    spice_worker                        # ejecutable nativo compilado; generado por make
    kernels/                            # kernels JPL/NAIF; descargados por mix angelus.kernels
      latest_leapseconds.tls
      de442.bsp
      pck00011.tpc
      gm_de440.tpc
      mar099.bsp
      jup349.bsp
      sat459.bsp
      ura184_part-1.bsp
      ura184_part-2.bsp
      ura184_part-3.bsp
      nep105.bsp
      plu060.bsp

  # --- Tests ---
  test/
    test_helper.exs

    support/
      spice_stub.ex                     # stub del adapter para tests sin worker nativo

    fixtures/
      horizons/
        de442_positions.json            # fixtures generadas con mix angelus.validate.horizons --write

    angelus/
      angle_test.exs
      coordinates_test.exs
      spice/
        body_targets_test.exs
        kernel_set_test.exs
        server_test.exs                 # tag: :spice_integration
        worker_protocol_test.exs
      ephemeris/
        body_position_test.exs
        ephemeris_test.exs              # tag: :spice_integration para casos con worker real
      adapters/
        spice_native_test.exs           # tag: :spice_integration
```

Reglas de la estructura:

- `angelus.ex` re-exporta solo `Angelus.Ephemeris.position/2,3`, `Angelus.Ephemeris.positions/2,3` y `Angelus.Spice.load_kernels/0,1`. No re-exporta internals.
- `angelus/application.ex` arranca `Angelus.Spice.Supervisor` y nada más.
- `angelus/spice/supervisor.ex` gestiona el pool de `Angelus.Spice.Server` workers con `restart: :permanent`. En v0.1 puede ser un único server; la estructura permite escalar a N workers sin cambiar la API.
- `angelus/spice/server.ex` abre el Port a `priv/spice_worker` con `[:binary, :exit_status, packet: 4]`, correlaciona requests por `id` y reinicia el Port si el worker muere.
- `angelus/spice/worker_protocol.ex` encapsula toda la serialización/deserialización del protocolo; `server.ex` no debe construir JSON directamente.
- `angelus/spice/body_targets.ex` es la tabla canónica única de cuerpos soportados; nadie más duplica ese mapeo.
- `angelus/spice/kernel_set.ex` contiene la validación del set de kernels y la lógica de whitelist; `server.ex` delega ahí.
- `native/spice_worker/Makefile` compila `priv/spice_worker`; el target `all` debe ser ejecutable desde `mix compile` si hace falta.
- `priv/kernels/` no se versiona; se genera con `mix angelus.kernels`.
- `priv/spice_worker` no se versiona; se genera con `make` o CI.
- Tests con tag `:spice_integration` requieren `priv/spice_worker` compilado y `priv/kernels/` descargados; se excluyen por defecto en `mix test`.

## 3. Dependencias iniciales

En `mix.exs`:

```elixir
defp deps do
  [
    {:jason, "~> 1.4"},
    {:req, "~> 0.5"},
    {:nimble_pool, "~> 1.1"}
  ]
end
```

Notas:

- `jason` para serialización del protocolo Port y fixtures JSON de Horizons.
- `req` para HTTP en `mix angelus.kernels` y `mix angelus.validate.horizons`; en descargas grandes, escribir en streaming a archivo temporal.
- `nimble_pool` para gestionar el pool de `Angelus.Spice.Server` workers con backpressure controlada. Si v0.1 empieza con un único worker, se puede introducir en un segundo paso sin cambiar la API.
- `Angelus.Ephemeris` solo acepta `DateTime` UTC.

En `native/spice_worker/`:

```text
# Código C del worker externo.
# Compilar el ejecutable `spice_worker` enlazando contra CSPICE estáticamente.
# Mantenerlo mínimo: solo operaciones necesarias para Ángelus v0.1.
# El Makefile genera priv/spice_worker.
```

Política de build y distribución del worker nativo v0.1:

- El repositorio contiene el código fuente C propio del worker en `native/spice_worker/`.
- CSPICE se descarga desde NAIF con URL y SHA-256 fijados en `native/native_sources.lock` durante el build de release o desarrollo.
- El ejecutable `priv/spice_worker` se genera compilando `native/spice_worker/` y enlazando contra CSPICE estáticamente.
- Enlace estático preferido para evitar problemas de `DYLD_LIBRARY_PATH`/`rpath` en las plataformas soportadas. Enlace dinámico solo como fallback si una restricción legal o técnica lo obliga.
- Plataformas soportadas inicialmente en v0.1:
  - macOS Apple Silicon (`aarch64-apple-darwin`, clang, 64-bit).
  - Linux x86_64 glibc (`x86_64-linux-gnu`, GCC, 64-bit).
- Los artefactos precompilados (`priv/spice_worker`) se publican en GitHub Releases por tag y plataforma. El usuario en una plataforma soportada los restaura durante `mix deps.compile` o `mix compile`.
- No vendorizar fuentes CSPICE completas en el árbol del repositorio.
- Si hay patches mínimos a CSPICE, guardarlos en `native/patches/` con documentación del motivo.
- `mix angelus.kernels` descarga solo kernels de datos; no compila ni descarga el worker nativo.
- `priv/spice_worker` y `priv/kernels/` no se versionan en el repositorio.
- `THIRD_PARTY_NOTICES.md` debe incluir avisos de CSPICE y kernels JPL/NAIF antes de distribuir binarios.

Aspectos de `mix.exs` para compilación nativa:

```elixir
# Solo si se usa elixir_make para restaurar/compilar el worker durante mix compile:
compilers: [:elixir_make] ++ Mix.compilers(),
make_targets: ["priv/spice_worker"],
make_precompiler_url: "https://github.com/<owner>/angelus/releases/download/v#{@version}/@{artefact_filename}",
make_precompiler_filename: "spice_worker"
```

Nota: la integración con `elixir_make` es para restaurar el binario precompilado, no para compilar un NIF. El artefacto distribuido es el ejecutable `priv/spice_worker`, no una `.so`/`.dylib`.

Serialización y aislamiento CSPICE v0.1:

```text
Angelus.Spice.Server
- proceso OTP dueño de un `Port` hacia un worker externo
- v0.1 permite múltiples servidores/workers para escalar concurrentemente sin compartir estado CSPICE en el mismo proceso nativo
- ejecuta `kclear` durante `init/1` para establecer un estado nativo limpio y marca metadata como sin kernels confiables cargados
- carga explícitamente, cuando el caller invoca `load_kernels`, el set preciso por defecto de v0.1 como estado activo: LSK, TPC y todos los SPK necesarios para centros físicos
- rechaza recarga salvo `replace: true`
- ejecuta utc_to_et y position por worker de forma serial; la concurrencia global se obtiene por pool
- mantiene metadata de kernels cargados
- infiere política por nombre y verifica kernels cargados contra CSPICE
- traduce errores a {:error, reason}
```

`Angelus.Spice.Server` debe arrancarse bajo el árbol de supervisión de la aplicación Angelus, pero no debe cargar kernels automáticamente. Si no está arrancado, `Angelus.Spice` debe devolver `{:error, :spice_server_not_started}` y nunca debe invocar CSPICE fuera del servidor ni arrancarlo perezosamente desde una llamada pública.
v0.1 debe incluir `Angelus.Application` como módulo OTP de aplicación y declarar `mod: {Angelus.Application, []}` en `mix.exs`. Ese supervisor arranca `Angelus.Spice.Server` como parte del runtime normal.

`Port` debe abrirse con `:binary`, `:exit_status` y `packet: 4`. El protocolo entre Elixir y `spice_worker` será length-prefixed JSON con `id` correlativo por request/respuesta.

El worker nativo externo debe mantenerse mínimo y sin lógica OTP:

```text
spice_worker
- load_kernels(paths)
- load_default_kernels(base_path)
- utc_to_et(iso8601)
- state(target, et, observer, frame, abcorr)
- clear_kernels()
- ping()
```

Frontera worker/Elixir:

- El worker externo calcula la mayor parte posible de la capa astronómica usando CSPICE.
- El worker devuelve datos planos en JSON; no conoce structs Elixir ni semántica astrológica.
- Los structs públicos se construyen en Elixir dentro del dominio que los posee.
- Elixir se encarga principalmente de API, validación, metadata y construcción de structs.
- Evitar reimplementar en Elixir cálculos astronómicos ya disponibles y probados en CSPICE.

Ejemplo de respuesta del worker para operación `state`:

```json
{
  "id": 42,
  "ok": true,
  "result": {
    "state_km": [x, y, z, vx, vy, vz],
    "distance_au": 1.234,
    "ecliptic_longitude": 102.5,
    "ecliptic_latitude": 0.3,
    "light_time_seconds": 4.1,
    "et": 123456.0
  }
}
```

Ejemplo de error del worker:

```json
{
  "id": 42,
  "ok": false,
  "error": "SPICE(SPKINSUFFDATA): insufficient ephemeris data"
}
```

`Angelus.Spice.Server` convierte la respuesta a `{:ok, map()}` o `{:error, reason}` y la pasa a `Angelus.Adapters.SpiceNative`.

`Angelus.Ephemeris`/`Angelus.Coordinates` convierten esos datos en:

```elixir
%Angelus.Ephemeris.BodyPosition{}
```

`distance_au`, longitud eclíptica y latitud eclíptica deben calcularse en el worker usando CSPICE.

Regla de coordenadas v0.1:

- El worker devuelve `ecliptic_longitude` y `ecliptic_latitude` como floats en grados dentro del JSON de respuesta.
- Pipeline canónico v0.1: CSPICE obtiene estado aparente geocéntrico con `abcorr: "LT+S"` en el frame eclíptico soportado; CSPICE convierte el vector rectangular a coordenadas latitudinales; `Angelus.Coordinates` normaliza `longitude` a `0 <= longitude < 360` y conserva `latitude` con signo.
- Elixir no recalcula transformaciones astronómicas.
- La API pública de efemérides no devuelve signo zodiacal ni grado dentro del signo en v0.1.

Política de configuración para librería:

- Ángelus no debe usar `Application.get_env/3` ni `config :angelus, ...` para cambiar comportamiento de runtime.
- Las opciones variables deben pasarse como keyword params en la API pública o en funciones de carga.
- `Angelus.Ephemeris.positions/3` debe aceptar `adapter: Angelus.Adapters.SpiceNative` solo como opción explícita para tests o integración avanzada.
- `Angelus.Spice.load_kernels/1` debe aceptar `base_path: "priv/kernels"` como opción explícita para el set por defecto.

Ejemplos:

```elixir
Angelus.Spice.load_kernels(base_path: "priv/kernels")

Angelus.Ephemeris.positions([:sun, :moon], datetime,
  adapter: Angelus.Adapters.SpiceNative
)
```

Tarea Mix para descargar kernels v0.1:

```elixir
mix angelus.kernels
mix angelus.kernels --force
```

Responsabilidad de la tarea:

- Crear `priv/kernels/` si no existe.
- Mostrar antes de descargar un aviso no interactivo indicando que los kernels JPL/NAIF se descargan desde fuentes externas y están sujetos a sus propios términos. No pedir confirmación interactiva en v0.1 para no romper automatización/CI.
- Descargar `latest_leapseconds.tls` desde NAIF:

```text
https://naif.jpl.nasa.gov/pub/naif/generic_kernels/lsk/latest_leapseconds.tls
```

- Descargar `de442.bsp` desde NAIF:

```text
https://naif.jpl.nasa.gov/pub/naif/generic_kernels/spk/planets/de442.bsp
```

- Descargar SPK complementarios para centros físicos:

```text
https://naif.jpl.nasa.gov/pub/naif/generic_kernels/spk/satellites/mar099.bsp
https://naif.jpl.nasa.gov/pub/naif/generic_kernels/spk/satellites/jup349.bsp
https://naif.jpl.nasa.gov/pub/naif/generic_kernels/spk/satellites/sat459.bsp
https://naif.jpl.nasa.gov/pub/naif/generic_kernels/spk/satellites/ura184_part-1.bsp
https://naif.jpl.nasa.gov/pub/naif/generic_kernels/spk/satellites/ura184_part-2.bsp
https://naif.jpl.nasa.gov/pub/naif/generic_kernels/spk/satellites/ura184_part-3.bsp
https://naif.jpl.nasa.gov/pub/naif/generic_kernels/spk/satellites/nep105.bsp
https://naif.jpl.nasa.gov/pub/naif/generic_kernels/spk/satellites/plu060.bsp
```

- Descargar `pck00011.tpc` desde NAIF:

```text
https://naif.jpl.nasa.gov/pub/naif/generic_kernels/pck/pck00011.tpc
```

- Descargar `gm_de440.tpc` desde NAIF:

```text
https://naif.jpl.nasa.gov/pub/naif/generic_kernels/pck/gm_de440.tpc
```

- Guardarlos en:

```text
priv/kernels/latest_leapseconds.tls
priv/kernels/de442.bsp
priv/kernels/pck00011.tpc
priv/kernels/gm_de440.tpc
priv/kernels/mar099.bsp
priv/kernels/jup349.bsp
priv/kernels/sat459.bsp
priv/kernels/ura184_part-1.bsp
priv/kernels/ura184_part-2.bsp
priv/kernels/ura184_part-3.bsp
priv/kernels/nep105.bsp
priv/kernels/plu060.bsp
```

- No cargar kernels automáticamente.
- En v0.1, la única opción soportada es `--force`.
- Sin flags, descargar siempre todos los kernels requeridos por v0.1 si faltan.
- Si un archivo ya existe, no sobrescribir salvo `--force`.
- Validar siempre el set final completo, incluyendo archivos existentes y archivos recién descargados.
- Si un archivo existente está vacío, es claramente parcial o no cumple las validaciones mínimas, fallar con error claro y no sobrescribirlo salvo `--force`.
- No añadir `--only` ni selección parcial de kernels en v0.1.
- No añadir opción de mirror/base URL en v0.1; descargar únicamente desde las URLs NAIF directas definidas por Ángelus.
- En v0.1, verificar que cada descarga produce un archivo existente y no vacío; para `.bsp`, aplicar además un tamaño mínimo razonable por archivo para detectar descargas parciales obvias. No hardcodear checksums en v0.1.
- Usar `Req` para las descargas. Para archivos grandes, escribir mediante streaming a un archivo temporal por kernel.
- Validar `status in 200..299`, validar archivo existente y no vacío, aplicar tamaño mínimo razonable a `.bsp`, cerrar el stream y solo entonces renombrar atómicamente al path final.
- Si falla cualquier descarga, dejar intactos los archivos existentes, borrar temporales y devolver un error claro.
- Con `--force`, descargar y validar todos los kernels en temporales antes de reemplazar cualquier archivo final. Si falla cualquier descarga o validación del set, conservar intacto el set anterior completo.

---

## 4. Licencia

Ángelus debería publicarse como:

```text
MIT
```

Notas importantes para el README:

```text
Angelus source code is MIT licensed.
Native artefacts include components from NAIF CSPICE, distributed under its respective terms.
Angelus does not include third-party astrological ephemeris code or data.
Angelus is not affiliated with or endorsed by NASA, JPL, NAIF, IAU, or SOFA.
JPL/NAIF kernels are downloaded separately and distributed under their respective terms.
```

Ángelus puede ser MIT siempre que:

- No copie código de efemérides astrológicas externas.
- No copie ficheros de efemérides astrológicas externas.
- No traduzca su implementación línea por línea.
- No reutilice sus tablas comprimidas.
- Use CSPICE/JPL conforme a sus condiciones.
- No presente los artefactos nativos con CSPICE como MIT puro; la licencia MIT aplica al código propio de Ángelus.
- Verifique y documente las condiciones de CSPICE, `elixir_make` y los kernels JPL antes de distribuir binarios o scripts de descarga.
- Incluir `THIRD_PARTY_NOTICES.md` en el repositorio y en el paquete Hex con avisos de CSPICE, kernels JPL/NAIF, `elixir_make` y `cc_precompiler`.

---

## 5. API pública objetivo

La API pública estable de v0.1 debe ser `Angelus.Ephemeris.position/2,3` y `Angelus.Ephemeris.positions/2,3`, más las funciones de soporte necesarias en `Angelus.Angle`, `Angelus.Spice` y las tareas Mix de kernels/validación.

Ejemplo v0.1:

```elixir
Angelus.Ephemeris.positions(
  [:sun, :moon, :mercury, :venus, :mars, :jupiter, :saturn, :uranus, :neptune, :pluto],
  ~U[1990-05-24 06:30:00Z]
)
```

Respuesta esperada v0.1:

```elixir
{:ok,
 %{
    sun: %Angelus.Ephemeris.BodyPosition{},
    moon: %Angelus.Ephemeris.BodyPosition{},
    mercury: %Angelus.Ephemeris.BodyPosition{}
 }}
```

## 6. Módulos principales

### `Angelus.Angle`

Responsable de utilidades angulares:

```elixir
normalize/1
distance/2
signed_distance/2
deg_to_rad/1
rad_to_deg/1
dms/1
```

Este módulo es prioritario porque muchos cálculos dependen de normalizar longitudes de 0° a 360°.
Las funciones de utilidad angular devuelven valores directos para entrada numérica válida. Entrada no numérica devuelve `{:error, :invalid_angle}` en vez de lanzar excepción.

---

### `Angelus.Spice`

Responsable de:

- Cargar kernels.
- UTC a ET/TDB.
- Metadata de kernels.
- Metadata estructurada de tipo, archivo, efeméride, política y rango.
- Errores de kernel.
- Serializar llamadas CSPICE mediante `Angelus.Spice.Server`.

API:

```elixir
Angelus.Spice.load_kernels()
Angelus.Spice.load_kernels(replace: true)
Angelus.Spice.load_kernels(base_path: "priv/kernels")

Angelus.Spice.load_kernels([
  "latest_leapseconds.tls",
  "pck00011.tpc",
  "gm_de440.tpc",
  "de442.bsp",
  "mar099.bsp",
  "jup349.bsp",
  "sat459.bsp",
  "ura184_part-1.bsp",
  "ura184_part-2.bsp",
  "ura184_part-3.bsp",
  "nep105.bsp",
  "plu060.bsp"
])

Angelus.Spice.load_kernels([
  "latest_leapseconds.tls",
  "pck00011.tpc",
  "gm_de440.tpc",
  "de442.bsp",
  "mar099.bsp",
  "jup349.bsp",
  "sat459.bsp",
  "ura184_part-1.bsp",
  "ura184_part-2.bsp",
  "ura184_part-3.bsp",
  "nep105.bsp",
  "plu060.bsp"
], replace: true)
Angelus.Spice.utc_to_et(~U[1990-05-24 06:30:00Z])
Angelus.Spice.body_target(:jupiter)
# {:ok, %{spice_target: "JUPITER", spice_id: 599, target_kind: :body_center, required_spk: "jup349.bsp"}}
```

`Angelus.Spice` debe ser la fachada pública sobre `Angelus.Spice.Server`; ninguna llamada pública debe invocar CSPICE directamente fuera del servidor.
`Angelus.Spice.state/3` es API pública de soporte de bajo nivel para validación y depuración, no parte del contrato principal. En v0.1 está limitado a los targets soportados, `observer: "EARTH"`, `frame: "ECLIPJ2000"` y `abcorr: "LT+S"`; no es un wrapper SPICE general. La API estable de v0.1 sigue siendo `Angelus.Ephemeris.position/2,3` y `Angelus.Ephemeris.positions/2,3`.
`Angelus.Spice` es la fachada pública del mapeo canónico cuerpo astrológico -> SPICE target/id/target_kind para v0.1; la tabla interna vive en `Angelus.Spice.BodyTargets`. Debe exponer `body_target/1` para consultar esa metadata sin requerir kernels cargados ni ET. Para cuerpos que requieren SPK complementario, `body_target/1` incluye `required_spk`. Cuerpos no soportados devuelven `{:error, {:unsupported_body, body}}`. `Angelus.Ephemeris` no debe duplicar ese mapeo; debe obtener el estado y la metadata resuelta mediante `Angelus.Spice.state/3` o funciones de soporte del propio `Angelus.Spice`.

Regla de uso:

- `load_kernels/0` carga el set preciso por defecto desde `priv/kernels/`.
- `load_kernels/1` con keyword params permite ajustar `base_path:` y `replace:` sin usar configuración de aplicación.
- `load_kernels/1` con lista de rutas permite indicar rutas explícitas, pero debe contener el set completo de v0.1.
- Rechazar cargas con cero o múltiples `.tls`.
- Rechazar cargas sin `de442.bsp` o sin cualquiera de los SPK complementarios requeridos.
- Rechazar cargas sin `pck00011.tpc` o sin `gm_de440.tpc`.
- No permitir SPK externos al set preciso por defecto en v0.1.
- Si ya hay kernels cargados, `load_kernels/0` y `load_kernels/1` deben devolver `{:error, :kernels_already_loaded}` salvo `replace: true`.
- Para cambiar kernels, exigir `load_kernels(paths, replace: true)`, que debe ejecutar `kclear` y cargar el nuevo set de forma serializada en `Angelus.Spice.Server`.
- Antes de llamar a CSPICE, validar que el set completo de kernels existe, pertenece al whitelist de v0.1 y contiene todos los archivos requeridos. Si falta cualquier archivo o hay un kernel no soportado, rechazar la carga completa sin cargar kernels parciales.
- Después de cargar mediante CSPICE, consultar el estado de kernels cargados para construir y confirmar metadata. Si la carga o la consulta de CSPICE no coincide con el set esperado, devolver `{:error, {:kernel_load_failed, reason}}`.
- Con `replace: true`, validar primero el set de reemplazo. Solo si es válido, ejecutar `kclear` y cargar el nuevo set dentro de `Angelus.Spice.Server`; si el reemplazo es inválido, conservar activo el set anterior.
- Si `replace: true` pasa la prevalidación, ejecuta `kclear` y luego falla durante carga o confirmación CSPICE, el servidor queda sin un set de kernels confiable cargado. No debe conservar metadata anterior ni intentar restaurar automáticamente; el caller debe cargar de nuevo un set válido.
- `Angelus.Spice.Server` no ejecuta limpieza especial en `terminate/2` en v0.1. En `init/1`, ejecuta `kclear` para limpiar estado nativo residual, marca el estado Elixir como sin kernels confiables cargados y exige que el caller ejecute `load_kernels` de nuevo.
- Usar `de442.bsp` como SPK planetario base de v0.1.
- No soportar `de442s.bsp`, `de440.bsp`, `de440s.bsp` ni `DE441` en v0.1.
- Rechazar cualquier `.bsp` fuera del set preciso por defecto v0.1.
- Si la fecha queda fuera del kernel cargado, devolver error explícito; no hacer fallback silencioso.
- `Angelus.Ephemeris` debe prevalidar en Elixir el rango público all-body del set completo cargado (`1900-01-01` a `2100-01-24` para el set preciso v0.1 actual) antes de llamar a SPICE. Este rango se aplica igual a `position/2,3` y `positions/2,3`, sin expansión por subconjunto de cuerpos en v0.1. Fechas fuera de rango devuelven error explícito sin invocar native code.
- v0.1 usa carga explícita de kernels; no hay auto-download ni auto-load al arrancar.
- `load_kernels/0` existe en v0.1 y carga todos los kernels por defecto desde `priv/kernels/`.
- Si se solicitan posiciones sin kernels cargados, devolver `{:error, :kernels_not_loaded}`.

Errores esperados de carga de kernels:

```elixir
{:error, {:invalid_kernel_set, :missing_tls}}
{:error, {:invalid_kernel_set, :multiple_tls}}
{:error, {:invalid_kernel_set, :missing_bsp}}
{:error, {:invalid_kernel_set, {:missing_bsp, "jup349.bsp"}}}
{:error, {:invalid_kernel_set, {:missing_tpc, "pck00011.tpc"}}}
{:error, {:invalid_kernel_set, {:missing_tpc, "gm_de440.tpc"}}}
{:error, :kernels_already_loaded}
{:error, {:unsupported_kernel, file}}
{:error, {:kernel_load_failed, reason}}
```

Ejemplo v0.1:

```elixir
Angelus.Spice.load_kernels([
  "priv/kernels/latest_leapseconds.tls",
  "priv/kernels/pck00011.tpc",
  "priv/kernels/gm_de440.tpc",
  "priv/kernels/de442.bsp",
  "priv/kernels/mar099.bsp",
  "priv/kernels/jup349.bsp",
  "priv/kernels/sat459.bsp",
  "priv/kernels/ura184_part-1.bsp",
  "priv/kernels/ura184_part-2.bsp",
  "priv/kernels/ura184_part-3.bsp",
  "priv/kernels/nep105.bsp",
  "priv/kernels/plu060.bsp"
])
```

Aunque `mix angelus.kernels` descargue a rutas convencionales, `load_kernels/0` debe fallar con error explícito si falta cualquiera de los archivos del set por defecto.

Ejemplo rechazado en v0.1:

```elixir
Angelus.Spice.load_kernels([
  "priv/kernels/latest_leapseconds.tls",
  "priv/kernels/pck00011.tpc",
  "priv/kernels/gm_de440.tpc",
  "priv/kernels/de442.bsp",
  "priv/kernels/mar099.bsp",
  "priv/kernels/jup349.bsp",
  "priv/kernels/sat459.bsp",
  "priv/kernels/ura184_part-1.bsp",
  "priv/kernels/ura184_part-2.bsp",
  "priv/kernels/ura184_part-3.bsp",
  "priv/kernels/nep105.bsp",
  "priv/kernels/plu060.bsp",
  "priv/kernels/custom.bsp"
])
# {:error, {:unsupported_kernel, "custom.bsp"}}
```

URLs NAIF relevantes:

```text
https://naif.jpl.nasa.gov/pub/naif/generic_kernels/lsk/latest_leapseconds.tls
https://naif.jpl.nasa.gov/pub/naif/generic_kernels/pck/pck00011.tpc
https://naif.jpl.nasa.gov/pub/naif/generic_kernels/pck/gm_de440.tpc
https://naif.jpl.nasa.gov/pub/naif/generic_kernels/spk/planets/de442.bsp
https://naif.jpl.nasa.gov/pub/naif/generic_kernels/spk/satellites/mar099.bsp
https://naif.jpl.nasa.gov/pub/naif/generic_kernels/spk/satellites/jup349.bsp
https://naif.jpl.nasa.gov/pub/naif/generic_kernels/spk/satellites/sat459.bsp
https://naif.jpl.nasa.gov/pub/naif/generic_kernels/spk/satellites/ura184_part-1.bsp
https://naif.jpl.nasa.gov/pub/naif/generic_kernels/spk/satellites/ura184_part-2.bsp
https://naif.jpl.nasa.gov/pub/naif/generic_kernels/spk/satellites/ura184_part-3.bsp
https://naif.jpl.nasa.gov/pub/naif/generic_kernels/spk/satellites/nep105.bsp
https://naif.jpl.nasa.gov/pub/naif/generic_kernels/spk/satellites/plu060.bsp
```

No se añadirá configuración automática tipo `config :angelus, kernels: [...]`; Ángelus es una librería y debe recibir paths/opciones por argumentos.

---

### `Angelus.Ephemeris`

Responsable de:

- Posiciones geocéntricas.
- Distancias.
- Estado SPICE completo `{x, y, z, vx, vy, vz}`.
- Posición pública en `position_km` y velocidad pública en `velocity_km_s`.
- Retrogradación queda fuera de v0.1.
- API pública de efemérides geocéntricas para v0.1.

Cuerpos/puntos soportados en v0.1:

```text
sun
moon
mercury
venus
mars
jupiter
saturn
uranus
neptune
pluto
true_node
mean_node
chiron
lilith
```

Mapeo SPICE para el set preciso por defecto v0.1:

```text
sun     -> SUN                  NAIF ID 10   target_kind: :body_center
moon    -> MOON                 NAIF ID 301  target_kind: :body_center
mercury -> MERCURY              NAIF ID 199  target_kind: :body_center
venus   -> VENUS                NAIF ID 299  target_kind: :body_center
mars    -> MARS                 NAIF ID 499  target_kind: :body_center
jupiter -> JUPITER              NAIF ID 599  target_kind: :body_center
saturn  -> SATURN               NAIF ID 699  target_kind: :body_center
uranus  -> URANUS               NAIF ID 799  target_kind: :body_center
neptune -> NEPTUNE              NAIF ID 899  target_kind: :body_center
pluto   -> PLUTO                NAIF ID 999  target_kind: :body_center
chiron  -> CHIRON               NAIF ID 2060 target_kind: :minor_planet
```

Puntos matemáticos soportados en v0.1:

```text
true_node -> Nodo Norte verdadero lunar       target_kind: :lunar_node
mean_node -> Nodo Norte medio lunar           target_kind: :lunar_node
lilith    -> Lilith/Luna Negra/Apogeo Lunar   target_kind: :lunar_apogee
```

La metadata de cada posición debe exponer el target SPICE real y `target_kind`; Ángelus no debe ocultar qué target exacto se usó.

Regla crítica de centros físicos:

- CSPICE solo puede resolver un centro físico si la cadena SPK necesaria está cargada.
- En v0.1, el set preciso por defecto carga `de442.bsp` más SPK complementarios para que `MARS`, `JUPITER`, `SATURN`, `URANUS`, `NEPTUNE` y `PLUTO` resuelvan a centros físicos.
- Si falta cualquier SPK complementario, Ángelus debe rechazar la carga del set y no degradar silenciosamente a baricentros.
- Los targets baricéntricos quedan reservados para diagnósticos o futuras opciones explícitas, no para la API astrológica por defecto.

Decisión v0.1:

- Cargar por defecto el set completo de kernels necesarios para centros físicos.
- No usar baricentros como aproximación astrológica si existe kernel complementario disponible.
- No hacer fallback silencioso a baricentro si falla un kernel complementario.
- Documentar en README y metadata el set completo cargado y el target físico usado.

Kernels complementarios incluidos desde v0.1:

```text
Mars:    mar099.bsp     -> MARS (499)
Jupiter: jup349.bsp     -> JUPITER (599)
Saturn:  sat459.bsp     -> SATURN (699)
Uranus:  ura184_*.bsp   -> URANUS (799)
Neptune: nep105.bsp     -> NEPTUNE (899)
Pluto:   plu060.bsp     -> PLUTO (999)
```

Estos kernels no sustituyen a `de442.bsp`; se cargan junto a `de442.bsp` para completar la cadena desde el baricentro del sistema hasta el centro físico del planeta.

Cualquier otro cuerpo/punto debe rechazarse explícitamente:

```elixir
{:error, {:unsupported_body, :ceres}}
{:error, {:unsupported_body, :south_node}}
```

`Angelus.Ephemeris.positions/3` debe ser atómica en v0.1: si cualquier cuerpo solicitado es inválido, falla toda la llamada y no devuelve resultados parciales.

Ejemplo:

```elixir
Angelus.Ephemeris.positions([:sun, :moon, :ceres], datetime)
# {:error, {:unsupported_body, :ceres}}
```

API:

```elixir
Angelus.Ephemeris.position(:mars, ~U[1990-05-24 06:30:00Z],
  observer: :earth
)

Angelus.Ephemeris.positions([:sun, :moon, :mars], ~U[1990-05-24 06:30:00Z])
```

Retorno de `positions/3`:

```elixir
{:ok,
 %{
    sun: %Angelus.Ephemeris.BodyPosition{},
    moon: %Angelus.Ephemeris.BodyPosition{},
    mars: %Angelus.Ephemeris.BodyPosition{}
 }}
```

Reglas:

- Devolver mapa por cuerpo.
- `positions/2,3` acepta solo una lista no vacía de átomos como primer argumento.
- `positions([], datetime)` devuelve `{:error, :empty_body_list}`.
- `positions(:sun, datetime)` y `positions(["sun"], datetime)` devuelven `{:error, :invalid_body_list}`.
- Rechazar cuerpos duplicados.
- No devolver resultados parciales.

Errores:

```elixir
{:error, {:duplicate_body, :sun}}
```

Opciones permitidas en v0.1:

```elixir
[]
[adapter: Angelus.Adapters.SpiceNative]
```

`adapter:` solo existe para inyección explícita en tests o integraciones avanzadas; no debe leerse desde application config. Cualquier otra opción o valor debe rechazarse.

`positions/3` debe validar opciones, fecha/hora, forma de la lista de cuerpos, duplicados y cuerpos soportados antes de llamar a `utc_to_et` o consultar estados SPICE. La precedencia de errores de prevalidación en v0.1 es:

```text
1. Opción inválida/no soportada
2. Fecha/hora inválida o no UTC
3. Forma inválida de lista de cuerpos
4. Cuerpo duplicado
5. Cuerpo no soportado
```

Errores:

```elixir
{:error, {:unsupported_option, {:zodiac, :sidereal}}}
{:error, {:unsupported_option, {:zodiac, :tropical}}}
{:error, {:unsupported_option, {:observer, :mars}}}
{:error, {:unsupported_option, {:abcorr, "NONE"}}}
```

Tipo de fecha/hora aceptado en v0.1:

```elixir
DateTime.t() en UTC
```

Ejemplo válido:

```elixir
~U[1990-05-24 06:30:00Z]
```

`Angelus.Ephemeris` no acepta `NaiveDateTime` ni resuelve zonas horarias. El caller debe entregar un `DateTime` UTC.

Errores:

```elixir
{:error, :invalid_datetime}
{:error, :datetime_must_be_utc}
{:error, {:datetime_out_of_range, %{from: ~D[1900-01-01], to: ~D[2100-01-24]}}}
```

`position/3` debe ser un wrapper sobre `positions/3`:

```elixir
position(body, datetime, opts) = positions([body], datetime, opts) |> extraer body
```

Debe compartir exactamente la misma ruta de validación, cálculo, metadata y errores que `positions/3`.
`position/2,3` acepta solo un átomo como cuerpo. `position([:sun], datetime)` devuelve `{:error, :invalid_body}`; la forma con lista pertenece exclusivamente a `positions/2,3`.

Regla de diseño v0.1:

- La API pública devuelve posiciones geocéntricas ya procesadas.
- No expone vectores SPICE, frames internos ni detalles de CSPICE.
- Contrato de posición geocéntrica v0.1:

```text
observer: EARTH
abcorr: LT+S
frame base: ECLIPJ2000
salida: longitud/latitud eclíptica geocéntrica aparente, con longitud normalizada
```

- Internamente debe mantener capas separadas:

```text
SpiceNative -> estado crudo + coordenadas astronómicas calculadas con CSPICE (en worker externo)
Coordinates -> fachada Elixir sobre resultados del worker
Ephemeris -> resultado astrológico público
```

- Las capas internas pueden tener tests propios, pero la interfaz estable de v0.1 es `Angelus.Ephemeris.position/2,3` y `Angelus.Ephemeris.positions/2,3`.

---

### `Angelus.Coordinates`

Responsable de:

- Fachada Elixir para coordenadas calculadas por el worker externo y devueltas en el JSON de respuesta.
- Normalización angular final (`longitude` a `0 <= longitude < 360`) para la API pública.
- No reimplementar en Elixir cálculos astronómicos disponibles en CSPICE.
## 7. Structs principales

Regla numérica v0.1:

- Usar `double` en C para CSPICE.
- Usar `float` en Elixir para cálculos y campos numéricos públicos.
- El `float` de Elixir es doble precisión IEEE-754 de 64 bits, equivalente práctico al `double` de C para esta frontera.
- CSPICE trabaja con `double`; convertir a `Decimal` no aumenta la precisión real.
- No incluir `Decimal` como dependencia inicial.
- Documentar tolerancias de validación en arcseconds en vez de prometer precisión decimal arbitraria.
- No exponer `Angelus.Julian` como módulo público en v0.1.

### `Angelus.Ephemeris.BodyPosition`

```elixir
defmodule Angelus.Ephemeris.BodyPosition do
  defstruct [
    :body,
    :spice_target,
    :spice_id,
    :target_kind,
    :position_km,
    :velocity_km_s,
     :light_time_seconds,
     :longitude,
     :latitude,
     :distance_au,
     :metadata
   ]
end
```

Regla v0.1:

- `position_km` contiene `{x, y, z}` derivado del estado devuelto por `spkezr_c`.
- `velocity_km_s` contiene `{vx, vy, vz}` derivado del estado devuelto por `spkezr_c`.
- `distance_au` se calcula desde `position_km` usando la unidad astronómica definida por CSPICE/NAIF.
- `light_time_seconds` contiene el light time devuelto por `spkezr_c`.
- `metadata` contiene al menos `engine`, `adapter`, `ephemeris`, `kernel_policy`, `kernels`, `spice_target`, `spice_id`, `target_kind`, `observer`, `abcorr`, `frame_base` y `angelus_version`.

---

## 8. Adapter astronómico

Crear behaviour:

```elixir
defmodule Angelus.Ephemeris.Adapter do
  @callback load_kernels() ::
              {:ok, map()} | {:error, term()}

  @callback load_kernels(keyword() | [String.t()]) ::
              {:ok, map()} | {:error, term()}

  @callback load_kernels([String.t()], keyword()) ::
              {:ok, map()} | {:error, term()}

  @callback utc_to_et(DateTime.t()) ::
              {:ok, float()} | {:error, term()}

  @callback state(atom(), float(), keyword()) ::
              {:ok, map()} | {:error, term()}
end
```

Crear adaptador preferente:

```elixir
defmodule Angelus.Adapters.SpiceNative do
  @behaviour Angelus.Ephemeris.Adapter

  def load_kernels(), do: Angelus.Spice.load_kernels()
  def load_kernels(paths_or_opts), do: Angelus.Spice.load_kernels(paths_or_opts)
  def load_kernels(paths, opts), do: Angelus.Spice.load_kernels(paths, opts)
  def utc_to_et(datetime), do: Angelus.Spice.utc_to_et(datetime)
  def state(body, et, opts), do: Angelus.Spice.state(body, et, opts)
end
```

`Angelus.Ephemeris` es responsable de validar opciones, construir `%Angelus.Ephemeris.BodyPosition{}` y añadir metadata pública usando la metadata SPICE resuelta por `Angelus.Spice`. El adaptador no debe construir structs públicos ni duplicar el mapeo canónico cuerpo -> SPICE target.

Operaciones mínimas del worker externo:

```text
load_kernels(paths) -> furnsh/kclear controlado
load_default_kernels(base_path) -> cargar el set preciso v0.1 desde priv/kernels
utc_to_et(iso8601_utc) -> str2et
state(target, et, observer, frame, aberration) -> datos planos de spkezr_c + reclat_c + convrt_c
ping() -> healthcheck del proceso nativo
```

Funciones CSPICE relevantes:

- `furnsh_c`: cargar kernels.
- `kclear_c`: limpiar kernels en tests o cierre explícito.
- `str2et_c` / `utc2et_c`: UTC a ET/TDB, segundos desde J2000.
- `spkezr_c`: estado objetivo-observador por nombre; función principal v0.1 para obtener posición y velocidad.
- `spkez_c`: estado objetivo-observador por NAIF ID.
- `spkgeo_c`: estado geométrico sin corrección de aberración.
- `reclat_c`: convertir vector rectangular a radio, longitud y latitud.
- `convrt_c`: conversión de unidades, usar para obtener AU en km si se necesita calcular `distance_au`.

Parámetros fijados para v0.1:

- `frame`: frame eclíptico soportado por CSPICE para obtener coordenadas geocéntricas eclípticas.
- `observer`: `"EARTH"` para posiciones geocéntricas.
- `abcorr`: `"LT+S"` para posiciones aparentes comparables con astrología/JPL Horizons.
- Salida pública: longitud/latitud eclíptica geocéntrica aparente; la longitud se normaliza a `0 <= longitude < 360`.
- Worker: usar `spkezr_c`, no `spkpos_c`, para devolver estado completo `{x, y, z, vx, vy, vz}`.

Opciones como `abcorr: "NONE"`, otros observers o salidas geométricas no forman parte del contrato estable de v0.1.

`Angelus.Ephemeris` no debe saber detalles del worker C ni del protocolo Port:

```elixir
defmodule Angelus.Ephemeris do
  def position(body, datetime, opts \ []) do
    with {:ok, positions} <- positions([body], datetime, opts) do
      {:ok, Map.fetch!(positions, body)}
    end
  end

  def positions(bodies, datetime, opts \ []) do
    adapter = Keyword.get(opts, :adapter, Angelus.Adapters.SpiceNative)

    # Validar cuerpos, opciones y UTC; convertir UTC -> ET; consultar adapter.state/3;
    # construir BodyPosition con metadata.
  end
end
```

---

## 9. Alcance v0.1

### Efemérides geocéntricas validadas

Objetivo: primera versión técnica, pequeña y validable, limitada a generar efemérides geocéntricas para el set inicial.

Incluye:

- Local datetime a UTC.
- UTC a ET/TDB vía worker externo CSPICE.
- Posiciones geocéntricas de Sol, Luna, Mercurio, Venus, Marte, Júpiter, Saturno, Urano, Neptuno y Plutón.
- Centros físicos por defecto para Marte, Júpiter, Saturno, Urano, Neptuno y Plutón mediante SPK complementarios.
- Quirón.
- Nodo Norte verdadero.
- Nodo Norte medio.
- Lilith/Luna Negra, técnicamente Apogeo Lunar.
- Coordenadas eclípticas.
- Longitud eclíptica geocéntrica normalizada.
- Metadata de kernels/versiones.
- Validación contra JPL Horizons o fixtures equivalentes para posiciones geocéntricas.

## 10. Plan de implementación paso a paso

### Paso 1 — Crear repositorio

```bash
mix new angelus
cd angelus
```

Añadir:

```text
LICENSE MIT
README.md
CHANGELOG.md
```

---

### Paso 2 — Crear tipos base

Crear los structs principales en el dominio que los posee:

- `Angelus.Ephemeris.BodyPosition`

---

### Paso 3 — Implementar `Angelus.Angle`

Funciones:

```elixir
normalize/1
distance/2
signed_distance/2
deg_to_rad/1
rad_to_deg/1
dms/1
```

---

### Paso 4 — Crear adapter SPICE nativo con proceso externo supervisado

Crear:

- `Angelus.Ephemeris.Adapter` (behaviour)
- `Angelus.Adapters.SpiceNative` (implementación concreta)
- `Angelus.Spice.Server` (GenServer con Port)
- `Angelus.Spice.Supervisor`
- `Angelus.Spice.WorkerProtocol`
- `native/spice_worker/` (worker C)

El worker externo debe envolver CSPICE directamente y cubrir primero:

- `furnsh` para cargar kernels.
- `str2et` para UTC a ET/TDB.
- `spkezr` para estado de cuerpo respecto a observador.
- `reclat` y `convrt` para coordenadas latitudinales y AU.
- `kclear` solo para limpieza explícita o tests, no como operación automática por cálculo.
- `ping` para healthcheck.

Requisito de seguridad:

- Aislar CSPICE fuera de la VM BEAM usando `Port` y proceso externo supervisado con `restart: :permanent`.
- Mantener serialización por worker para evitar concurrencia peligrosa sobre el estado global mutable de CSPICE.
- Devolver errores controlados; reiniciar worker al salir/crashear; no permitir que fallos nativos tumben BEAM.
- Configurar CSPICE con `erract_c("SET", ..., "RETURN")` en el worker durante init. Capturar errores con `failed_c`, `getmsg_c`, `reset_c` y devolverlos como JSON de error al caller.
- Tests de carga/limpieza de kernels para evitar estado global contaminado entre tests.

### Riesgo 2: licencias de componentes externos

Mitigación:

- Ángelus MIT.
- README claro.
- No redistribuir kernels si hay dudas.
- Script para descargar kernels.
- Documentar términos de CSPICE/JPL.

### Riesgo 3: precisión aparente

Mitigación:

- Guardar metadata.
- Exponer warnings.
- No ocultar la fecha UTC, observer ni frame usados.

---

## 14. Orden exacto de trabajo

```text
1. Crear repo angelus con MIT.
2. Añadir tipos base (BodyPosition, Adapter behaviour).
3. Implementar Angelus.Angle.
4. Crear worker externo C (native/spice_worker) con protocolo packet:4.
5. Crear Angelus.Spice.Server + WorkerProtocol + Supervisor.
6. Crear Angelus.Adapters.SpiceNative delegando a Angelus.Spice.
7. Crear `mix angelus.kernels` para descargar el set preciso completo de v0.1.
8. Obtener posición de un cuerpo físico end-to-end.
9. Convertir posición a coordenadas eclípticas en el worker.
10. Implementar API pública de efemérides geocéntricas UTC.
11. Añadir metadata de efeméride/kernel.
12. Implementar Nodo Norte verdadero, Nodo Norte medio y Lilith/Luna Negra.
13. Fijar fuente/kernel de Quirón e implementarlo.
14. Validar posiciones contra JPL Horizons o fixtures equivalentes.
15. Publicar v0.1.
```

---

## 15. Primera meta concreta

```text
Angelus.Ephemeris.positions/2 devuelve efemérides geocéntricas de Sol, Luna, Mercurio, Venus, Marte, Júpiter, Saturno, Urano, Neptuno, Plutón, Nodo Norte verdadero, Nodo Norte medio, Quirón y Lilith/Luna Negra con metadata de kernel/cálculo y validación contra JPL Horizons o fixtures equivalentes.
```
