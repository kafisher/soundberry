barge = require 'barge'
{randomChoice} = barge.helpers

test_client = new barge.Client

# Search for tracks with "mr carmack" and choose one to play
test_client.remote 'soundberry', 'search', 'tracks', 'mr carmack', (err, tracks) ->
    track = randomChoice tracks
    test_client.remote 'soundberry', 'play', track.id, (err, playing) ->
        console.log playing
