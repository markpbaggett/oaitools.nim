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

method get_token(this: OaiRequest, node: string): string {.base.}=
  node.split(">")[1].replace("</resumptionToken", "")

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

method list_identifiers*(this: OaiRequest, metadata_format: string): string {.base.} =
  let xml_response = this.make_request(this.base_url & "?verb=ListIdentifiers&metadataPrefix=" & metadata_format)
  let token = $(xml_response // "resumptionToken")
  this.get_token(token)

method get_complete_size*(this: OaiRequest, metadata_format: string): string {.base.} =
  var set_string = ""
  if this.oai_set != "":
    set_string = "&set=" & this.oai_set
  let xml_response = this.make_request(this.base_url & "?verb=ListIdentifiers&metadataPrefix=" & metadata_format & set_string)
  let token = $(xml_response // "resumptionToken")
  get_attribute_value_of_node(token, "completeListSize")[0]

when isMainModule:
  let test_oai = OaiRequest(base_url: "https://dpla.lib.utk.edu/repox/OAIHandler", oai_set: "utk_heilman")
  block:
    echo test_oai.list_sets()
  block:
    echo test_oai.list_sets_and_descriptions()
  block:
    echo test_oai.list_metadata_formats()
  block:
    echo test_oai.identify()
  block:
    echo test_oai.get_complete_size("MODS")
  block:
    echo test_oai.list_identifiers("MODS")
