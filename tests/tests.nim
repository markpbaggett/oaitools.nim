import unittest, oaitools

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
