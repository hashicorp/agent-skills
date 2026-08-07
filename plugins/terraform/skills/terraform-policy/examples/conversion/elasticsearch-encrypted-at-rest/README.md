# Elasticsearch Encrypted at Rest

## Source Sentinel Policy
`elasticsearch-encrypted-at-rest.sentinel`

## Conversion Quality
`Good`

## Why this is Good
The original intent maps cleanly to tfpolicy, but the block shape still has to be rewritten in tfpolicy terms using `core::try()` around `encrypt_at_rest[0].enabled`.

## Key translation notes
- Nested map access becomes direct tfpolicy block access
- The conversion checks the planned end state of `encrypt_at_rest`
- The outcome is preserved even though the syntax changes substantially

## Limitations encountered
This depends on the provider exposing `encrypt_at_rest` in the expected block/list structure. As with other tfpolicy policies, raw provider schema shape matters.
