The resource schema analysis needed for computed and sensitive attribute
cleanup is time-consuming, due to the size of the resource schemas. In order to
avoid slow model calls, schema analysis should use local tools to build a
lookup table of sensitive attributes by resource type and to build a lookup
table of computed attributes by resource type that also records whether each
computed attribute is optional.
