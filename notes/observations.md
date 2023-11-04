# Observations

In this page I will attempt to collate details about exisitng Roughtime
implementations which I've found in the course of Butterfield's development as
they have all been used to varying levels in gaining understanding of real
implications of the protocol specification.

## Implementations

| Name           | Language  | Client  | Server  |
|----------------|-----------|---------|---------|
| Roughenough    | Rust      |    Yes  |   Yes   |
| Google C++     | C++       |    Yes  |   Yes   |
| Google Go      | Go        |    Yes  |   Yes   |
| CloudFlare     | Go        |    Yes  |   Yes   |
| vroughtime     | C         |    Yes  |   No    |
| craggy         | C         |    Yes  |   No    |
| Nearenough     | Java      |    Yes  |   No    |
| Pyroughtime    | Python    |    Yes  |   Yes   |
| node-roughtime | JS        |    Yes  |   No    |

## Digest Usage 

As of draft-ietf-ntp-roughtime-02 the specification switched from using SHA-512
to using SHA-512/256. However Cloudflare's implementation does not implement this
correctly as they only truncate a SHA-512 hash - SHA-512/256 uses a different
initialisation. To compare, the string 'Roughtime' calculates to:

| Function   |                           Digest                                   |
|------------|--------------------------------------------------------------------|
| SHA256     | `a604d9a02ac70a3543d8fa2bb8e377fd0d014c2eca0ca1a7e8bc11ce03b60668` |
| SHA512/256 | `fc0c6dac02efde7e3a30ad64d9af11af3d716d8536ad10f8b4d36336f0769102` |
| SHA512     | `d54eda6ade70cae7c941f54cf3cd42fef48144087430728a2b753cdc9c55dc138b41881088dda435aaa60d62f44f14e5ceee9a7800a41964e565bb26bdaee26d` |

[Cloudflare](https://github.com/cloudflare/roughtime/blob/master/sha512trunc/hash.go):
```go

func (h *shatrunc) Sum(b []byte) []byte {
	tmp := h.inner.Sum(nil)
	return append(b, tmp[:32]...)

}
func New() hash.Hash {
	ret := new(shatrunc)
	ret.inner = sha512.New()
	return ret
}
```

