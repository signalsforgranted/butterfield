import Config

# Butterfield only has a few options to configure, mostly around key material.
# All values must be able to be set from environment variables that are named
# with a prefix of "BTRFLD" to prevent clashing with any other system
# environment variables in play, and should always have a sensible default that
# will give the system enough to start from nothing.
config :butterfield,
  # UDP & TCP port to listen on
  port: String.to_integer(System.get_env("BTRFLD_PORT") || "5319"),

  # Long-term keys:
  # Both must be stored with Base 64 encoding
  #
  # Long-term public ed25519 key
  public_key: System.get_env("BTRFLD_PUBKEY") || nil,

  # Long-term private ed25519 key
  # ⚠️  This remains in memory for the duration of the process
  private_key: System.get_env("BTRFLD_PRIKEY") || nil,

  # Temporary certificates are signed by the long-term key. This value
  # (in hours) is how long each one is valid for (MINT is backdated by an hour);
  # a new one is made halfway through.
  cert_duration: 24,

  # Maximum time in milliseconds that TCP connections can remain idle
  idle_timeout: String.to_integer(System.get_env("BTRFLD_IDLE_TIMEOUT") || "10000"),

  # Maximum number of TCP connections concurrently
  max_connections: String.to_integer(System.get_env("BTRFLD_MAX_CONNECTIONS") || "1024"),

  # Maximum number of TCP connections waiting to be accepted
  backlog: String.to_integer(System.get_env("BTRFLD_BACKLOG") || "4096"),

  # Maximum number of UDP requests waiting for a response at once
  max_udp_requests: String.to_integer(System.get_env("BTRFLD_MAX_UDP_REQUESTS") || "4096"),

  # Maximum number of requests signed together in one batch
  batch_size: String.to_integer(System.get_env("BTRFLD_BATCH_SIZE") || "64")
