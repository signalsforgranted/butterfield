# Implementation Notes

This page is some notes produced in the development of this codebase, with the
goal of providing feedback to the protocol designers and wider community of
implementors.

## Tags

* RADI is a mandatory field, but some implementations just hard code it, 
  presumably because they are pulling from system time and don't know exactly
  what accuracy could be with values from 1-10 seconds. This tag also needs to
  factor in latency of packet transmission, which impacts lowering it given that
  there is no real mechanism to guess what that may be.
  
* MINT and MAXT have no suggested values - in theory both can be maxxed out (and
  in other implementations they are set to 0x0 and 0xffffffetc respectively).
  These values should ideally have some sort of guidance on minimum/maximum
  values that should be applied. We've decided to use 90 days, as is not unusual
  with TLS certificates.

* VER differs between request and response - in request it's a list (with no
  description of how that list is serialised), and in response it's a single
  field. No implementations I've observed appear to ever send more than one
  value.

## Structure

* Recursive handling of nesting structures is complex - because of the
  signatures, de/serialisers can't just handle deeper structures.

* In many moments I have wondered if the tagging system is perhaps 
  overengineered for the purpose, and if a more structured packet format would
  be more appropriate. A lot of effort and complexity goes into implementations,
  and it's possible to support additional, optional data by either appending it
  to the end, or by transmitting it in a separate packet.
