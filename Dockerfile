FROM elixir:1.18.3

RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential git curl ca-certificates python-is-python3 nodejs npm \
    && npm install -g yarn@1.22.22 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

ENV MIX_ENV=dev

RUN mix local.hex --force && \
    mix local.rebar --force

COPY mix.exs mix.lock ./
COPY config config
RUN mix deps.get

COPY assets/package.json assets/yarn.lock ./assets/
RUN yarn --cwd ./assets install --frozen-lockfile

COPY priv priv
COPY assets assets
COPY lib lib

RUN yarn --cwd ./assets deploy

EXPOSE 4005

CMD ["mix", "phx.server"]
