import httpclient, xmltools, strutils, options, strformat

proc get_text_value_of_attributeless_node(xml: string, node: string): seq[string] =
  for value in xml.split(fmt"<{node}>"):
    let new_value = value.replace(fmt"</{node}>").replace(fmt"<{node}>")
    if len(new_value) > 0:
      result.add(new_value)

proc get_attribute_value_of_node(xml: string, attribute: string): seq[string] =
  for value in xml.split(" "):
    if value.contains(attribute):
      result.add(value.split("=")[1].replace("\"", ""))

proc write_to_disk(filename: string, contents: string, destination_directory: string): string =
  try:
    let path = destination_directory & "/" & filename
    writeFile(path, contents)
    fmt"Created {filename} at {destination_directory}."
  except IOError:
    echo "Destination directory does not exist!"
    raise

type 
  OaiRequest* = ref object of RootObj
    ## This type describes an OAI request.
    base_url*: string
    oai_set*: string
    client: HttpClient

method make_request(this: OaiRequest, request: string): Node {.base.} =
  let response = this.client.getContent(request)
  Node.fromStringE(response)

method get_token(this: OaiRequest, node: string): string {.base.} =
  try:
    node.split(">")[1].replace("</resumptionToken", "")
  except IndexError:
    "" 

method count_documents_on_page(this: OaiRequest, node: string): int {.base.} =
  count(node, "<header>")

method get_complete_size*(this: OaiRequest, metadata_format: string): int {.base.} =
  ## Gets the number of records in an OAI-PMH request.
  ##
  ## If the request passes a resumptionToken, this parses size from resumptionToken[@completeListSize].
  ## If the request does not have a resumption token, the value is based on the number of headers in the response.
  ##
  ## Requires:
  ##   metadata_format(string): The metadata format of your request.
  ##
  ## Returns:
  ##   int: The total number of records in a request.
  ##
  ## Example:
  ##
  ## .. code-block:: nim
  ##
  ##   var x = newOaiRequest("https://dpla.lib.utk.edu/repox/OAIHandler")
  ##   x.get_complete_size("MODS")
  ##
  var set_string = ""
  if this.oai_set != "":
    set_string = fmt"&set={this.oai_set}"
  let xml_response = this.make_request(fmt"{this.base_url}?verb=ListIdentifiers&metadataPrefix={metadata_format}{set_string}")
  let node = $(xml_response // "resumptionToken")
  try:
    parseInt(get_attribute_value_of_node(node, "completeListSize")[0])
  except IndexError:
    this.count_documents_on_page($(xml_response // "header"))

method list_sets*(this: OaiRequest): seq[string] {.base.} =
  ## Returns a sequence of sets as strings available from an OAI-PMH provider.
  ##
  ## Example:
  ##
  ## .. code-block:: nim
  ##
  ##   var x = newOaiRequest("https://dpla.lib.utk.edu/repox/OAIHandler")
  ##   x.list_sets()
  ##
  let xml_response = this.make_request(fmt"{this.base_url}?verb=ListSets")
  let results = $(xml_response // "setSpec")
  get_text_value_of_attributeless_node(results, "setSpec")

method list_sets_and_descriptions*(this: OaiRequest): seq[(string, string)] {.base.} =
  ## Returns a sequence of tuples with set name and set description available from an OAI-PMH provider.
  ##
  ## Example:
  ##
  ## .. code-block:: nim
  ##
  ##    var x = newOaiRequest("https://dpla.lib.utk.edu/repox/OAIHandler")
  ##    x.list_sets_and_descriptions()
  ##
  let xml_response = this.make_request(fmt"{this.base_url}?verb=ListSets")
  let set_specs = $(xml_response // "setSpec")
  let spec_seq = get_text_value_of_attributeless_node(set_specs, "setSpec")
  let set_names = $(xml_response // "setName")
  let name_seq = get_text_value_of_attributeless_node(set_names, "setName")
  var i = 0
  while i < len(name_seq) - 1:
    result.add((spec_seq[i], name_seq[i]))
    i += 1

method list_metadata_formats*(this: OaiRequest): seq[string] {.base.} =
  ## Returns a sequence of metadata_formats available from an OAI-PMH provider.
  ##
  ## Example:
  ##
  ## .. code-block:: nim
  ##
  ##    var x = newOaiRequest("https://dpla.lib.utk.edu/repox/OAIHandler")
  ##    x.list_metadata_formats()
  ##
  let xml_response = this.make_request(fmt"{this.base_url}?verb=ListMetadataFormats")
  let prefixes = $(xml_response // "metadataPrefix")
  get_text_value_of_attributeless_node(prefixes, "metadataPrefix")

method identify*(this: OaiRequest): string {.base.} =
  ## Returns an XML file of information about an OAI-PMH provider as a string.
  ##
  ## Example:
  ##
  ## .. code-block:: nim
  ##
  ##    var x = newOaiRequest("https://dpla.lib.utk.edu/repox/OAIHandler")
  ##    x.identify()
  ##
  $(this.make_request(fmt"{this.base_url}?verb=Identify"))

method list_identifiers*(this: OaiRequest, metadata_format: string): seq[string] {.base.} =
  ## Returns a sequence of identifiers for records belonging to an OAI-PMH request.
  ##
  ## Example:
  ##
  ## .. code-block:: nim
  ##
  ##    var x = newOaiRequest("https://dpla.lib.utk.edu/repox/OAIHandler", "utk_wderfilms")
  ##    x.list_identifiers("MODS")
  ##
  var set_string = ""
  var xml_response: Node
  var token = "first_pass"
  if this.oai_set != "":
    set_string = fmt"&set={this.oai_set}"
  var request = fmt"{this.base_url}?verb=ListIdentifiers&metadataPrefix={metadata_format}{set_string}"
  var identifiers: seq[string] = @[]
  while token.len > 0:
    xml_response = this.make_request(request)
    identifiers = get_text_value_of_attributeless_node($(xml_response // "identifier"), "identifier")
    for identifier in identifiers:
      result.add(identifier)
    token = this.get_token($(xml_response // "resumptionToken"))
    request = fmt"{this.base_url}?verb=ListIdentifiers&resumptionToken={token}"

method harvest_metadata_records*(this: OaiRequest, metadata_format: string, output_directory: string): (int, int) {.base.} =
  ## Harvests metadata records from an OAI-PMH request to disk.
  ##
  ## Requires:
  ##
  ##   metadata_format (string): The metadata format.
  ##   output_directory (string): The full path to where you want to write your files.
  ##
  ## Example:
  ##
  ## .. code-block:: nim
  ##
  ##    var x = newOaiRequest("https://dpla.lib.utk.edu/repox/OAIHandler", "utk_wderfilms")
  ##    x.harvest_metadata_records("MODS", "/home/mark/nim_projects/oaitools/output")
  ##
  var set_string = ""
  var xml_response: Node
  var token = "first_pass"
  if this.oai_set != "":
    set_string = fmt"&set={this.oai_set}"
  var request = fmt"{this.base_url}?verb=ListRecords&metadataPrefix={metadata_format}{set_string}"
  var i = 1
  let total_size = this.get_complete_size(request)
  var records: seq[string] = @[]
  while token.len > 0:
    xml_response = this.make_request(request)
    records = get_text_value_of_attributeless_node($(xml_response // "metadata"), "metadata")
    for record in records:
      discard write_to_disk(fmt"{$(i)}.xml", record, output_directory)
      i += 1
    token = this.get_token($(xml_response // "resumptionToken"))
    request = fmt"{this.base_url}?verb=ListRecords&resumptionToken={token}"
  (i - 1, total_size)

method list_records*(this: OaiRequest, metadata_format: string): seq[string] {.base.} =
  ## Returns a sequence of XML records as strings for each record in a request.
  ##
  ## **NOTE**: Use this method with caution.  This can cause your sequence to get very big.
  ##
  ## Example:
  ##
  ## .. code-block:: nim
  ##
  ##    var x = newOaiRequest("https://dpla.lib.utk.edu/repox/OAIHandler", "utk_wderfilms")
  ##    x.list_records("MODS")
  ##
  var set_string = ""
  var xml_response: Node
  var token = "first_pass"
  if this.oai_set != "":
    set_string = fmt"&set={this.oai_set}"
  var request = fmt"{this.base_url}?verb=ListRecords&metadataPrefix={metadata_format}{set_string}"
  var records: seq[string] = @[]
  while token.len > 0:
    xml_response = this.make_request(request)
    records = get_text_value_of_attributeless_node($(xml_response // "metadata"), "metadata")
    for record in records:
      result.add(record)
    token = this.get_token($(xml_response // "resumptionToken"))
    request = fmt"{this.base_url}?verb=ListIdentifiers&resumptionToken={token}"

proc newOaiRequest*(url: string, oai_set=""): OaiRequest =
  ## Constructs a new Oai-PMH request.
  ##
  ## Example:
  ##
  ## .. code-block:: nim
  ##
  ##    var x = newOaiRequest("https://dpla.lib.utk.edu/repox/OAIHandler", "utk_wderfilms")
  ##
  OaiRequest(base_url: url, oai_set: oai_set, client: newHttpClient())
