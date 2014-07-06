#!/usr/bin/env coffee

sc = require './soundcloud'
exec = require('child_process').exec
http = require 'http'
ecstatic = require('ecstatic')(__dirname + '/static')
url = require 'url'
fs = require 'fs'
coffee = require 'coffee-script'
jade = require 'jade'
styl = require 'styl'
log = require './log'

log 'Starting up...'
root = {}

play_track = (track, cb) ->
    log "Playing #{ track.title }"
    stream_url = "#{ track.stream_url }?consumer_key=#{ sc.consumer_key }"
    root.play_process = exec "mpg123 #{ stream_url }", (error, stdout, stderr) ->
        cb() if not error

play_next = (cb) ->
    return if !root.current_set?
    now_index = root.current_set.indexOf root.now_playing.id
    sc.tracks.get root.current_set[now_index + 1], (track) ->
        root.now_playing = track
        play_from_now()
        cb() if cb?

play_last = (cb) ->
    now_index = root.current_set.indexOf root.now_playing.id
    sc.tracks.get root.current_set[now_index - 1], (track) ->
        root.now_playing = track
        play_from_now()
        cb() if cb?

play_from_now = ->
    play_track root.now_playing, play_next

stop_playing = ->
    if root.play_process?
        root.play_process.kill 'SIGHUP'
        delete root.play_process

root =
    play_process: null
    interpolationTimeout: null
    currentVolume: 50

setVolume = (v) ->
    root.mu = 0
    root.targetVolume = v
    root.startingVolume = root.currentVolume
    root.dmu = 0.25
    clearTimeout root.interpolationTimeout
    interpolateVolumes()

interpolateVolumes = ->
    if root.mu <= 1.0
        v = root.startingVolume*(1-root.mu)+root.targetVolume*root.mu
        setSystemVolume v
        root.mu += root.dmu
        root.interpolationTimeout = setTimeout interpolateVolumes, 150

setSystemVolume = (v) ->
    root.currentVolume = v
    exec "amixer -M set PCM #{ v }%"
    console.log "[setSystemVolume] #{ v }%"

render_base = (options) -> jade.compile(fs.readFileSync('views/base.jade').toString())(options)
render_now_playing = -> jade.compile(fs.readFileSync('views/now_playing.jade').toString())({track: root.now_playing})
render_ = (type, data) ->
    type_data = {}; type_data[type] = data
    jade.compile(fs.readFileSync("views/#{ type }.jade").toString())(type_data)

#
# User views
user_resource_views =
    tracks: 'tracks'
    favorites: 'tracks'
    followings: 'users'
    followers: 'users'

track_resource_views =
    comments: 'comments'
    favoriters: 'users'

#
# Main server
server = http.createServer (req, res) ->
    log 'debug', "Handling #{ req.url }"
    url_parsed = url.parse(req.url, true)
    query = url_parsed.query
    pathname = url_parsed.pathname
    res.setHeader 'Access-Control-Allow-Origin', '*'

    # Base & song lists
    if pathname == '/'
        res.setHeader 'Content-Type', 'text/html'
        res.end render_base query
    else if req.url == '/stream'
        res.setHeader 'Content-Type', 'text/html'
        if root.stream?
            root.current_set = (t.id for t in root.stream)
            res.end render_ 'tracks', root.stream
        else
            root.me.stream (stream) ->
                root.current_set = (t.id for t in stream)
                root.stream = stream
                res.end render_ 'tracks', root.stream
    else if req.url == '/favorites'
        res.setHeader 'Content-Type', 'text/html'
        if root.favorites?
            root.current_set = (t.id for t in root.favorites)
            res.end render_ 'tracks', root.favorites
        else
            root.me.favorites (favorites) ->
                root.current_set = (t.id for t in favorites)
                root.favorites = favorites
                res.end render_ 'tracks', root.favorites
    else if req.url == '/followers'
        res.setHeader 'Content-Type', 'text/html'
        if root.followers?
            res.end render_ 'users', root.followers
        else
            root.me.followers (followers) ->
                root.followers = followers
                res.end render_ 'users', root.followers
    else if req.url == '/followings'
        res.setHeader 'Content-Type', 'text/html'
        if root.followings?
            res.end render_ 'users', root.followings
        else
            root.me.followings (followings) ->
                root.followings = followings
                res.end render_ 'users', root.followings
    else if pathname == '/search.json'
        res.setHeader 'Content-Type', 'application/json'
        log "query.type is #{ query.type }"
        type_class = sc[query.type]
        type_class.search query.q, (found) ->
            res.end JSON.stringify found
    else if pathname == '/search'
        res.setHeader 'Content-Type', 'text/html'
        log "query.type is #{ query.type }"
        type_class = sc[query.type]
        type_class.search query.q, (found) ->
            root.searched = found
            if query.type == 'tracks'
                root.current_set = (t.id for t in found)
            res.end render_ query.type, found
    else if req.url == '/now_playing'
        res.setHeader 'Content-Type', 'text/html'
        if root.now_playing?
            res.end render_now_playing()
        else
            res.end '<div class="error">Error loading now playing</div>'

    # User views
    else if matched = req.url.match /\/users\/(\d+)\/(\w+)/
        res.setHeader 'Content-Type', 'text/html'
        user_id = Number matched[1]
        types = matched[2]
        sc.users.get user_id, (user) ->
            user[types] (got) ->
                if types == 'tracks'
                    root.current_set = (t.id for t in got)
                res.end render_ user_resource_views[types], got
    else if matched = req.url.match /\/users\/(\d+)/
        res.setHeader 'Content-Type', 'text/html'
        sc.users.get Number(matched[1]), (user) ->
            res.end render_ 'user', user

    # Track views
    else if matched = req.url.match /\/tracks\/(\d+)\/(\w+)/
        res.setHeader 'Content-Type', 'text/html'
        track_id = Number matched[1]
        types = matched[2]
        sc.tracks.get track_id, (track) ->
            track[types] (got) ->
                if types == 'tracks'
                    root.current_set = (t.id for t in got)
                res.end render_ track_resource_views[types], got
    else if matched = req.url.match /\/tracks\/(\d+)/
        res.setHeader 'Content-Type', 'text/html'
        sc.tracks.get Number(matched[1]), (track) ->
            res.end render_ 'track', track

    # Playback actions
    else if matched = req.url.match /\/play\/(\d+)/
        stop_playing()
        sc.tracks.get Number(matched[1]), (track) ->
            root.now_playing = track
            play_from_now()
            res.end "playing #{ root.now_playing.title }."
    else if req.url == '/next'
        stop_playing()
        play_next ->
            res.end 'nexted.'
    else if req.url == '/last'
        stop_playing()
        play_last ->
            res.end 'lasted.'
    else if req.url == '/stop'
        stop_playing()
        res.end 'stopped.'
    else if req.url == '/current'
        res.setHeader 'Content-Type', 'application/json'
        res.end JSON.stringify root.now_playing
    else if req.url == '/status'
        res.end "playing #{ root.now_playing.title }."
    else if matched = req.url.match /\/volume\/(\+|-)?(\d+)/
        vol_dir = matched[1]
        vol_num = Number(matched[2])
        vol_now = root.targetVolume || root.currentVolume
        if vol_dir == '+'
            vol_num = vol_now + vol_num
        else if vol_dir == '-'
            vol_num = vol_now - vol_num
        setVolume vol_num
        res.end "set volume to #{ vol_num }%"

    # Static files
    else if req.url == '/js/base.js'
        res.end coffee.compile(fs.readFileSync('static/js/base.coffee').toString())
    else if matched = req.url.match /\/css\/(\w+).css/
        res.end styl(fs.readFileSync("static/css/#{ matched[1] }.sass").toString(), {whitespace: true}).toString()
    else
        ecstatic(req, res)

server.listen 8080, '0.0.0.0', log 'HTTP server listening.'

log 'Finding root user...'
sc.users.get 929224, (user) ->
    root.me = user

