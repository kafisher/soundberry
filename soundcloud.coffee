qs = require 'querystring'
log = require './log'
request = require 'request'

consumer_key = "v9JXSG1dCP4hxUiDSjv5wg"

default_args =
    consumer_key: consumer_key

combine_objs = (a, b) ->
    c = {}
    for k, v of a
        c[k] = v
    for k, v of b
        c[k] = v
    return c

chunk_length = 50
default_limit = 50

fetch_data = (path, args, callback, offset=0, limit=default_limit) ->
    query_args = combine_objs default_args, {offset: offset}
    query_args = combine_objs query_args, args if args?
    query_string = qs.stringify query_args
    options = url: "http://api.soundcloud.com/#{path}.json?#{query_string}"
    log 'debug', "I will try to retreive #{ options.url }"
    req = request options, (err, res, data) ->
        if err
            log 'err', err
        else
            data_part = JSON.parse data
            if (data_part.length == chunk_length) and (offset + chunk_length < limit)
                with_more = (more_data) ->
                    callback data_part.concat more_data
                fetch_data path, args, with_more, offset + chunk_length
            else
                callback data_part

as = (type, thing) ->
    if thing instanceof Array
        (new type item for item in thing)
    else
        new type thing

class Type
    constructor: (@attrs) ->
        this[attr] = value for attr, value of @attrs
        @params()
    path: (to) -> "#{@type}s/#{@id}/#{to}"
    params: ->

getattr = (type, path) ->
    (callback) ->
        fetch_data path, {}, (result) ->
            callback as type, result

class User extends Type
    type: 'user'
    params: ->
        @tracks = getattr Track, @path "tracks"
        @favorites = getattr Track, @path "favorites"
        @followers = getattr User, @path "followers"
        @followings = getattr User, @path "followings"
        @comments = getattr Comment, @path "comments"
    stream: (callback) ->
        if @_stream?
            callback @_stream
        else
            _tracks = []
            @followings (followings) ->
                done_followings = 0
                for following in followings
                    following.tracks (tracks) ->
                        done_tracks = 0
                        for track in tracks
                            _tracks.push track
                            if ++done_tracks == tracks.length
                                console.log "now done with #{ done_tracks }"
                                if ++done_followings == followings.length
                                    console.log "Ah and done with #{ done_followings }"
                                    @_stream = _tracks
                                    callback @_stream


class Track extends Type
    type: 'track'
    params: ->
        @user = new User @attrs.user
        @favoriters = getattr User, @path "favoriters"
        @comments = getattr Comment, @path "comments"

class Comment extends Type

class Resource
    constructor: (@name, @type) ->
    cache: {}
    get: (id, callback) ->
        if @cache[id]
            if callback?
                callback @cache[id]
            else
                return @cache[id]
        else fetch_data "#{@name}/#{id}", {}, (fetched) =>
            o = new @type fetched
            @cache[o.id] = o
            callback o
    search: (q, callback) ->
        fetch_data "#{@name}", {q: q}, (fetched) =>
            fs = []
            for f in fetched
                o = new @type f
                @cache[o.id] = o
                fs.push o
            callback fs

users = new Resource 'users', User
tracks = new Resource 'tracks', Track

#users.get 929224, (user) ->
    #console.log "Got the user: #{user.username}"
    #user.favorites (favorites) ->
        #console.log "Favorites (#{favorites.length}): " + (f.title for f in favorites).join ', '
        #console.log favorites[0].user
        #console.log favorites[0].user.username
    #user.followers (followers) ->
        #console.log "Followers (#{followers.length}): " + (f.username for f in followers).join ', '
    #user.followings (followings) ->
        #console.log "Followings (#{followings.length}): " + (f.username for f in followings).join ', '
    #user.comments (comments) ->
        #console.log "Comments (#{comments.length}): " + (c.body for c in comments).join ', '
        #console.log comments[0]

exports.consumer_key = consumer_key
exports.users = users
exports.tracks = tracks
exports.fetch_data = fetch_data
