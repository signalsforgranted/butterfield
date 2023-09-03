import Config

# Butterfield only has a few options to configure, mostly around key material.
# All values must be able to be set from environment variables that are named
# with a prefix of "BTRFLD" to prevent clashing with any other system
# environment variables in play, and should always have a sensible default that
# will give the system enough to start from nothing.
config :butterfield,
  # UDP Port to listen on
  port: String.to_integer(System.get_env("BTRFLD_PORT") || "2002"),

  # Long-term keys:
  # Both must be stored with Base 64 encoding
  #
  # Long-term public ed25519 key
  public_key: System.get_env("BTRFLD_PUBKEY") || nil,

  # Long-term private ed25519 key
  # ⚠️  This may be removed once the system is running to minimise exposure risk
  private_key: System.get_env("BTRFLD_PRIKEY") || nil,

  # At start up we generate an ephemeral cert which is signed by the long term
  # public key. This value in days defines the min/max time for that cert, using
  # the time of Roughtime.CertBox.start_link/1 as the min.
  cert_duration: 90
