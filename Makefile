.PHONY: build dev test bench

BASE_CMD=docker run -it --rm -p 2002:2002/udp -v ${PWD}:/usr/src/app butterfield

build:
	@docker build -t butterfield .
	@${BASE_CMD} mix deps.get

iex:
	@${BASE_CMD} iex -S mix

test:
	@${BASE_CMD} mix test

analyse:
	-@${BASE_CMD} mix dialyzer --quiet --format dialyxir
	-@${BASE_CMD} mix credo --strict
	-@${BASE_CMD} mix test --cover

audit:
	@${BASE_CMD} mix sobelow --details --private
	@${BASE_CMD} mix hex.audit

bench:
	@${BASE_CMD} mix run bench/wire.exs

format:
	@${BASE_CMD} mix format

docs:
	@${BASE_CMD} mix docs
