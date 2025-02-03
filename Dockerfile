FROM elixir:1.18 as builder

ENV MIX_ENV="prod"

WORKDIR /app
RUN mix local.hex --force && mix local.rebar --force
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV

RUN mkdir config
COPY config config
RUN mix deps.compile

COPY priv priv
COPY lib lib
COPY .git .git

RUN mix release

FROM elixir:1.18

WORKDIR /app

COPY --from=builder /app/_build/prod/rel/charlie ./

CMD ["sh", "-c", "/app/bin/charlie start"]

