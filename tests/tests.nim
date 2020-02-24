import unittest, oaitools, strutils

suite "Test Initialization with Full Url":
  setup:
    let test_request = newOaiRequest("https://dpla.lib.utk.edu/repox/OAIHandler")
  
  test "base_url is assigned and accessible.":
    check test_request.base_url == "https://dpla.lib.utk.edu/repox/OAIHandler"

  test "no oai_set is defined":
    check test_request.oai_set == ""

suite "Test Initialization with Full Url":
  setup:
    let test_request = newOaiRequest("dpla.lib.utk.edu/repox/OAIHandler", "utk_derris")

  test "base_url is assigned, accessible, and starts with http.":
    check test_request.base_url == "http://dpla.lib.utk.edu/repox/OAIHandler"
  
  test "oai_set is defined and accessible":
    check test_request.oai_set == "utk_derris"

suite "Sketchy HTTP tests with no Patches or Mocks":
  setup:
    let
      test_request = newOaiRequest("http://dpla.lib.utk.edu/repox/OAIHandler", "utk_heilman")
      sets_and_descriptions = test_request.list_sets_and_descriptions()
      just_sets = test_request.list_sets()
      metadata_formats = test_request.list_metadata_formats()
  
  test "Check List Sets is working as expected":
    check 200 <= len(just_sets) 

  test "Check List Sets with Descriptions is working as expected":
    check 200 <= len(sets_and_descriptions)
  
  test "Look for known items":
    check ("utk_tenngirl", "Tennessee Girl Student Handbook") in sets_and_descriptions
    check "utk_scopes" in just_sets

  test "Check List Metadata Formats":
    check "mods" in metadata_formats
    check "MODS" in metadata_formats
    check "oai_dc" in metadata_formats
    check "oai_qdc" in metadata_formats
    check "xoai" in metadata_formats
  
  test "Check List Identifiers and List Records":
    let
      records = test_request.list_records("MODS")
      identifiers = test_request.list_identifiers("MODS")
    
    check 1120 == len(records)
    check 1120 == len(identifiers)
    check identifiers[999].startswith("urn:dpla.lib.utk.edu.utk_heilman")
    check identifiers[42].startswith("urn:dpla.lib.utk.edu.utk_heilman")
    check records[1100].startswith("<mods")
    check records[300].startswith("<mods")
