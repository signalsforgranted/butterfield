FROM elixir:1.15.4-alpine

WORKDIR /usr/src/app

COPY . .

RUN mix deps.get
RUN mix compile
