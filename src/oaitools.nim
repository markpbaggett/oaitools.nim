import httpclient, xmltools, strutils, options

var client = newHttpClient()

proc get_text_value_of_attributeless_node(xml: string, node: string): seq[string] =
  for value in xml.split("<" & node & ">"):
    let new_value = value.replace("</" & node & ">")
    if len(new_value) > 0:
      result.add(new_value)

proc get_attribute_value_of_node(xml: string, attribute: string): seq[string] =
  for value in xml.split(" "):
    if value.contains(attribute):
      result.add(value.split("=")[1].replace("\"", ""))

type 
  OaiRequest* = ref object of RootObj
    base_url*: string
    oai_set*: string

method make_request(this: OaiRequest, request: string): Node {.base.} =
  let response = client.getContent(request)
  Node.fromStringE(response)

method get_token(this: OaiRequest, node: string): string {.base.} =
  try:
    node.split(">")[1].replace("</resumptionToken", "")
  except IndexError:
    "" 

method count_documents_on_page(this: OaiRequest, node: string): int {.base.} =
  count(node, "<header>")

method get_complete_size*(this: OaiRequest, request: string): int {.base.} =
  let xml_response = this.make_request(request)
  let node = $(xml_response // "resumptionToken")
  try:
    parseInt(get_attribute_value_of_node(node, "completeListSize")[0])
  except IndexError:
    this.count_documents_on_page($(xml_response // "header"))

method list_sets*(this: OaiRequest): seq[string] {.base.} =
  let xml_response = this.make_request(this.base_url & "?verb=ListSets")
  let results = $(xml_response // "setSpec")
  get_text_value_of_attributeless_node(results, "setSpec")

method list_sets_and_descriptions*(this: OaiRequest): seq[(string, string)] {.base.} =
  let xml_response = this.make_request(this.base_url & "?verb=ListSets")
  let set_specs = $(xml_response // "setSpec")
  let spec_seq = get_text_value_of_attributeless_node(set_specs, "setSpec")
  let set_names = $(xml_response // "setName")
  let name_seq = get_text_value_of_attributeless_node(set_names, "setName")
  var i = 0
  while i < len(name_seq) - 1:
    result.add((spec_seq[i], name_seq[i]))
    i += 1

method list_metadata_formats*(this: OaiRequest): seq[string] {.base.} =
  let xml_response = this.make_request(this.base_url & "?verb=ListMetadataFormats")
  let prefixes = $(xml_response // "metadataPrefix")
  get_text_value_of_attributeless_node(prefixes, "metadataPrefix")

method identify*(this: OaiRequest): string {.base.} =
  $(this.make_request(this.base_url & "?verb=Identify"))

method list_identifiers*(this: OaiRequest, metadata_format: string): seq[string] {.base.} =
  var set_string = ""
  var xml_response: Node
  var token = "first_pass"
  if this.oai_set != "":
    set_string = "&set=" & this.oai_set
  var request = this.base_url & "?verb=ListIdentifiers&metadataPrefix=" & metadata_format & set_string
  #let total_size = this.get_complete_size(request)
  #echo total_size
  var identifiers: seq[string] = @[]
  while token.len > 0:
    xml_response = this.make_request(request)
    identifiers = get_text_value_of_attributeless_node($(xml_response // "identifier"), "identifier")
    for identifier in identifiers:
      result.add(identifier)
    token = this.get_token($(xml_response // "resumptionToken"))
    request = this.base_url & "?verb=ListIdentifiers&resumptionToken=" & token


when isMainModule:
  let test_oai = OaiRequest(base_url: "https://dpla.lib.utk.edu/repox/OAIHandler", oai_set: "utk_wderfilms")
  block:
    echo test_oai.list_sets()
  block:
    echo test_oai.list_sets_and_descriptions()
  block:
    echo test_oai.list_metadata_formats()
  block:
    echo test_oai.identify()
  block:
    echo test_oai.list_identifiers("MODS")
