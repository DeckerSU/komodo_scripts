#!/bin/bash
curl --url "http://127.0.0.1:7776" --data "{\"agent\":\"dpow\",\"method\":\"active\"}" | jq  --compact-output -r .[]