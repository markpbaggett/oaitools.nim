import httpclient, xmltools, strutils, options, strformat, os

type 
  OaiRequest* = ref object of RootObj
    ## This type describes an OAI request.
    base_url*: string
    oai_set*: string
    client: HttpClient

proc get_text_value_of_attributeless_node(xml: string, node: string): seq[string] =
  for value in xml.split(fmt"<{node}>"):
    let new_value = value.replace(fmt"</{node}>").replace(fmt"<{node}>")
    if len(new_value) > 0:
      result.add(new_value)

proc get_attribute_value_of_node(xml: string, attribute: string): seq[string] =
  for value in xml.split(" "):
    if value.contains(attribute):
      result.add(value.split("=")[1].replace("\"", ""))

proc get_header_identifiers(xml: string): seq[string] =
  let new_xml = xml.replace("</header>", "</header>|||")
  for value in new_xml.split("|||"):
    if value.contains("<identifier>"):
      let identifier = $(Node.fromStringE(value) / "identifier")
      result.add(identifier.replace("</identifier>").replace("<identifier>"))

proc write_to_disk(filename: string, contents: string, destination_directory: string): string =
  if not existsDir(destination_directory):
    createDir(destination_directory)
  try:
    let path = destination_directory & "/" & filename
    writeFile(path, contents)
    fmt"Created {filename} at {destination_directory}."
  except IOError:
    echo "Destination directory does not exist!"
    raise

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

method parse_dates(this: OaiRequest, dates: (string, string)): (string, string) {. base .} =
  var from_string, until_string = ""
  if dates[0] != "":
    from_string = fmt"&from={dates[0]}"
  if dates[1] != "":
    until_string = fmt"&until={dates[1]}"
  (from_string, until_string)

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
  var
    token = "first_pass"
    request = fmt"{this.base_url}?verb=ListSets"
  while token.len > 0:
    let
      xml_response = this.make_request(request)
      results = $(xml_response // "setSpec")
      text_values = get_text_value_of_attributeless_node(results, "setSpec")
    for oai_set in text_values:
      result.add(oai_set)
    token = this.get_token($(xml_response // "resumptionToken"))
    request = fmt"{this.base_url}?verb=ListIdentifiers&resumptionToken={token}"

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
  var
    token = "first_pass"
    request = fmt"{this.base_url}?verb=ListSets"
  while token.len > 0:
    let
      xml_response = this.make_request(request)
      set_specs = $(xml_response // "setSpec")
      spec_seq = get_text_value_of_attributeless_node(set_specs, "setSpec")
      set_names = $(xml_response // "setName")
      name_seq = get_text_value_of_attributeless_node(set_names, "setName")
    var i = 0
    while i < len(name_seq) - 1:
      result.add((spec_seq[i], name_seq[i]))
      i += 1
    token = this.get_token($(xml_response // "resumptionToken"))
    request = fmt"{this.base_url}?verb=ListIdentifiers&resumptionToken={token}"

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

method list_identifiers*(this: OaiRequest, metadata_format: string, from_date: string = "", until_date: string = ""): seq[string] {.base.} =
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
  var dates = this.parse_dates((from_date, until_date))
  var request = fmt"{this.base_url}?verb=ListIdentifiers&metadataPrefix={metadata_format}{set_string}{dates[0]}{dates[1]}"
  var identifiers: seq[string] = @[]
  while token.len > 0:
    xml_response = this.make_request(request)
    identifiers = get_text_value_of_attributeless_node($(xml_response // "identifier"), "identifier")
    for identifier in identifiers:
      result.add(identifier)
    token = this.get_token($(xml_response // "resumptionToken"))
    request = fmt"{this.base_url}?verb=ListIdentifiers&resumptionToken={token}"

method harvest_metadata_records*(this: OaiRequest, metadata_format, output_directory: string, from_date: string = "", until_date: string = "", identifier=false, replace_filename=""): (int, int) {.base.} =
  ## Harvests metadata records from an OAI-PMH request to disk.
  ##
  ## Requires:
  ##
  ##   metadata_format (string): The metadata format.
  ##   output_directory (string): The full path to where you want to write your files.
  ##
  ## Accepts:
  ##
  ##   from_date (string): Date from which to harvest
  ##   until_date (string): Date to harvest until
  ##   identifier (bool): Use header/identifier as value to serialize file to disk. Defaults to false and saves as an int.
  ##
  ## Examples:
  ##
  ## .. code-block:: nim
  ##
  ##    var x = newOaiRequest("https://dpla.lib.utk.edu/repox/OAIHandler", "utk_wderfilms")
  ##    discard x.harvest_metadata_records("MODS", "/home/mark/nim_projects/oaitools/output")
  ##
  ## .. code-block:: nim
  ##    var x = newOaiRequest("https://dpla.lib.utk.edu/repox/OAIHandler", "utk_wderfilms")
  ##    discard x.harvest_metadata_records("MODS", "/home/mark/nim_projects/oaitools/output", identifier=true)
  ##
  var set_string = ""
  var xml_response: Node
  var token = "first_pass"
  if this.oai_set != "":
    set_string = fmt"&set={this.oai_set}"
  var dates = this.parse_dates((from_date, until_date))
  var request = fmt"{this.base_url}?verb=ListRecords&metadataPrefix={metadata_format}{set_string}{dates[0]}{dates[1]}"
  var i = 1
  let total_size = this.get_complete_size(request)
  var records, header_identifiers: seq[string] = @[]
  while token.len > 0:
    xml_response = this.make_request(request)
    records = get_text_value_of_attributeless_node($(xml_response // "metadata"), "metadata")
    header_identifiers = get_header_identifiers($(xml_response // "header"))
    var header = 0
    for record in records:
      if identifier == false:
        discard write_to_disk(fmt"{$(i)}.xml", record, output_directory)
      else:
        let space = ""
        discard write_to_disk(fmt"{header_identifiers[header].replace(replace_filename, space)}.xml", record, output_directory)
      i += 1
      header += 1
    token = this.get_token($(xml_response // "resumptionToken"))
    request = fmt"{this.base_url}?verb=ListRecords&resumptionToken={token}"
  (i - 1, total_size)

method list_records*(this: OaiRequest, metadata_format: string, from_date: string = "", until_date: string = ""): seq[string] {.base.} =
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
  var dates = this.parse_dates((from_date, until_date))
  var request = fmt"{this.base_url}?verb=ListRecords&metadataPrefix={metadata_format}{set_string}{dates[0]}{dates[1]}"
  var records: seq[string] = @[]
  while token.len > 0:
    xml_response = this.make_request(request)
    records = get_text_value_of_attributeless_node($(xml_response // "metadata"), "metadata")
    for record in records:
      result.add(record)
    token = this.get_token($(xml_response // "resumptionToken"))
    request = fmt"{this.base_url}?verb=ListIdentifiers&resumptionToken={token}"

method get_record*(this: OaiRequest, metadata_format: string, oai_identifier: string): string {. base .} =
  ## Returns an XML record as a string.
  ##
  ## Example:
  ##
  ## .. code-block:: nim
  ##
  ##    var x = newOaiRequest("https://dpla.lib.utk.edu/repox/OAIHandler", "utk_wderfilms")
  ##    x.get_record("mods", "urn:dpla.lib.utk.edu.utk_comm:utkcomm_17456")
  ##
  var xml_response: Node
  xml_response = this.make_request(fmt"{this.base_url}?verb=GetRecord&identifier={oai_identifier}&metadataPrefix={metadata_format}")
  get_text_value_of_attributeless_node($(xml_response // "metadata"), "metadata")[0]

proc newOaiRequest*(url: string, oai_set=""): OaiRequest =
  ## Constructs a new Oai-PMH request.
  ##
  ## Example:
  ##
  ## .. code-block:: nim
  ##
  ##    var x = newOaiRequest("https://dpla.lib.utk.edu/repox/OAIHandler", "utk_wderfilms")
  ##
  var base_url = ""
  if url.startsWith("http") == false:
    base_url = fmt"http://{url}"
  else:
    base_url = url
  OaiRequest(base_url: base_url, oai_set: oai_set, client: newHttpClient())
