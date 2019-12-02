# Nim OAI Tools


![Travis icon](https://travis-ci.org/markpbaggett/noaitools.png)

A high-level OAI-PMH library for Nim.

# Examples

``` nim
import oaitools

var x = newOaiRequest("https://dpla.lib.utk.edu/repox/OAIHandler")
echo x.get_complete_size("MODS")
```

# Documentation

All [documentation and code examples](https://markpbaggett.github.io/noaitools/) can be found in this repository.