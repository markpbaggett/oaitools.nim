# Nim OAI Tools


![Travis icon](https://travis-ci.com/markpbaggett/noaitools.png)

A high-level OAI-PMH library for Nim.

## Installation

```shell
nimble install https://github.com/markpbaggett/oaitools.nim
```

## Examples

### Get number of records in a request

``` nim
import oaitools

var x = newOaiRequest("https://dpla.lib.utk.edu/repox/OAIHandler")
echo x.get_complete_size("MODS")
```

### Get metadata prefixes from a provider

```nim
import oaitools

var x = newOaiRequest("https://dpla.lib.utk.edu/repox/OAIHandler")
echo x.list_metadata_formats()
```

### Get a list of identifiers as a sequence that match a request

```nim
import oaitools

var x = newOaiRequest("https://dpla.lib.utk.edu/repox/OAIHandler", "utk_wderfilms")
echo x.list_identifiers("MODS")
```

### More Documentation

All [documentation and code examples](https://markpbaggett.github.io/oaitools.nim/) can be found in this repository.