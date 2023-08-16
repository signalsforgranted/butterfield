.PHONY: build dev test

BASE_CMD=docker run -it --rm -p 2002:2002/udp -v ${PWD}:/usr/src/app butterfield

build:
	@docker build -t butterfield .
	@${BASE_CMD} mix deps.get

iex:
	@${BASE_CMD} iex -S mix

test:
	@${BASE_CMD} mix test

fulltest:
	@${BASE_CMD} mix dialyzer
	@${BASE_CMD} mix test --cover

format:
	@${BASE_CMD} mix format

docs:
	${BASE_CMD} mix docs
