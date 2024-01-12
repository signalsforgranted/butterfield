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

## License

Copyright 2023-

Licensed under the Apache License, Version 2.0 (the "License"); you may not use
this file except in compliance with the License.  You may obtain a copy of the
License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed
under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
CONDITIONS OF ANY KIND, either express or implied.  See the License for the
specific language governing permissions and limitations under the License.

