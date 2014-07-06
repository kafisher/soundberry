barge = require 'barge'

test_client = new barge.Client
test_client.remote 'soundberry', 'play', 16253388, (err, response) ->
    console.log response
