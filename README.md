# Butterfield

This project aims to be an ongoing implementation of the Roughtime protocol, and
a tool for assisting in validating interoperability, testing servers and
behaviours. It's not, by the namesake of the protocol, aiming to have high
accuracy or precision with respect to timestamps, however will try its best not
to be deliberately terrible at it either.

Why the name? It's named after
[Butterfield dials](https://en.wikipedia.org/wiki/Butterfield_dial), which were
a form of sundial and thus, rough time.

## Building & Running

In order to get the server up and running you'll either need a container runtime
like Docker or Podman, or for containerless setups you'll need an environment
with CMake and Python3 in addition to Elixir ~> 1.15 in order to build libdecaf
which provides the eliptical functions necessary for signing and validating. The
included Makefile includes a `make build` step which will create the image built to
run; `make iex` will start the service, being available on UDP port 2002.
