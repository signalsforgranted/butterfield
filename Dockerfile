FROM elixir:1.19.0-alpine

WORKDIR /usr/src/app

COPY . .

RUN mix local.rebar
RUN mix deps.get
RUN mix compile
