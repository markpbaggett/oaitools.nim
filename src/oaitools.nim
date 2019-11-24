import httpclient, xmltools, strutils

var client = newHttpClient()

proc get_text_value_of_node(xml: string, node: string): seq[string] =
  for value in xml.split("<" & node & ">"):
    let new_value = value.replace("</" & node & ">")
    if len(new_value) > 0:
      result.add(new_value)

type OaiRequest* = ref object of RootObj
  base_url*: string

method list_sets*(this: OaiRequest): seq[string] {.base.} =
  let request = this.base_url & "?verb=ListSets" 
  let response = client.getContent(request)
  let xml_response = Node.fromStringE(response)
  let results = $(xml_response // "setSpec")
  result = get_text_value_of_node(results, "setSpec")

method list_sets_and_descriptions*(this: OaiRequest): seq[(string, string)] {.base.} =
  let request = this.base_url & "?verb=ListSets"
  let response = client.getContent(request)
  let xml_response = Node.fromStringE(response)
  let set_specs = $(xml_response // "setSpec")
  let spec_seq = get_text_value_of_node(set_specs, "setSpec")
  let set_names = $(xml_response // "setName")
  let name_seq = get_text_value_of_node(set_names, "setName")
  var i = 0
  while i < len(name_seq) - 1:
    result.add((spec_seq[i], name_seq[i]))
    i += 1

when isMainModule:
  let test_oai = OaiRequest(base_url: "https://dpla.lib.utk.edu/repox/OAIHandler")
  block:
    echo test_oai.list_sets()
  block:
    echo test_oai.list_sets_and_descriptions()
