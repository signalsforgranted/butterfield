import Config

# Butterfield only has a few options to configure, mostly around key material.
# All values must be able to be set from environment variables that are named
# with a prefix of "BTRFLD" to prevent clashing with any other system
# environment variables in play, and should always have a sensible default that
# will give the system enough to start from nothing.
config :butterfield,
  # UDP Port to listen on
  port: String.to_integer(System.get_env("BTRFLD_PORT") || "2002"),

  # Keys:
  # Both must be stored with Base 64 encoding
  #
  # Public ed25519 key
  public_key: System.get_env("BTRFLD_PUBKEY") || nil,

  # Private ed25519 key
  private_key: System.get_env("BTRFLD_PRIKEY") || nil
