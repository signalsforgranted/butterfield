# Build a release with the same Elixir and OTP as development
FROM hexpm/elixir:1.20.4-erlang-28.4.3-alpine-3.24.3 AS build

ENV MIX_ENV=prod
WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

# Dependencies first, so they're cached until mix.lock changes
COPY mix.exs mix.lock ./
COPY config config
RUN mix deps.get --only prod && mix deps.compile

COPY lib lib
RUN mix release

FROM alpine:3.24.3

RUN apk add --no-cache libstdc++ libgcc ncurses-libs openssl \
    && adduser -D -H butterfield

WORKDIR /app
COPY --from=build --chown=butterfield /app/_build/prod/rel/butterfield ./

USER butterfield
ENV LANG=C.UTF-8
EXPOSE 5319/udp 5319/tcp

CMD ["/app/bin/butterfield", "start"]
