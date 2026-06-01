FROM hexpm/elixir:1.19.5-erlang-26.2.5.21-alpine-3.23.4

RUN apk add --no-cache \
    build-base \
    cjson-dev \
    curl \
    git \
    jq \
    meson \
    ninja \
    py3-pip \
    valgrind

RUN python3 -m pip install --break-system-packages 'meson>=1.11.1'

WORKDIR /app

ENV MIX_ENV=test \
    ANGELUS_FORCE_BUILD=1 \
    ANGELUS_WORKER=/app/_build/test/lib/angelus/priv/angelus_worker

COPY mix.exs mix.lock ./

RUN mix local.hex --force \
    && mix local.rebar --force \
    && mix deps.get

COPY . .

RUN mix compile

CMD ["elixir", "scripts/native_leak_check.exs"]
