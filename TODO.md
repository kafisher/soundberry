# TODO

## Interface

* Views for individual `track`s and `user`s
    * **User**: display descriptive information plus tabs for `tracks`, `favorites`, `followings` and `followers`
    * **Track**: display descriptive information, playback, queuing and playlisting controls, plus tabs for `comments` and `favoriters`
* Quick actions on tracks for queuing and adding to playlists

## API

* `/stream` grabs all followings' tracks and sorts by date posted.
* `/playlists` lists users' playlists (include *now playing* queue as a default)
    * `/playlists/<playlist_id>` lists songs in given playlist
    * `#/playlists/<playlist_id>` adds track to given playlist
    * `X/playlists/<playlist_id>` removes track from given playlist
* `#/playlists` creates new playlist

## Thoughts

* Implement playlist as linked list for easy ordering?