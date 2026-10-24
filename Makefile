.PHONY: build dev test bench

CONTAINER=docker

BASE_CMD=${CONTAINER} run -it --rm -p 5319:5319/udp \
	-v ${PWD}:/usr/src/app -w /usr/src/app \
	-e MIX_HOME=/usr/src/app/.mix -e HEX_HOME=/usr/src/app/.hex \
	elixir:1.20.0-alpine

build:
	@${BASE_CMD} mix local.hex --force --if-missing
	@${BASE_CMD} mix local.rebar --force --if-missing
	@${BASE_CMD} mix deps.get
	@${BASE_CMD} mix compile

iex:
	@${BASE_CMD} iex -S mix

shell:
	@${BASE_CMD} /bin/sh

test:
	@${BASE_CMD} mix test --no-start

analyse:
	-@${BASE_CMD} mix dialyzer --quiet --format dialyxir
	-@${BASE_CMD} mix credo --strict
	-@${BASE_CMD} mix test --cover

audit:
	@${BASE_CMD} mix sobelow --details --private
	@${BASE_CMD} mix hex.audit
	@${BASE_CMD} mix sbom.cyclonedx

bench:
	@${BASE_CMD} mix run bench/wire.exs

format:
	@${BASE_CMD} mix format

docs:
	@${BASE_CMD} mix docs

clean:
	@rm -rf _build doc deps cover .mix .hex bom.xml