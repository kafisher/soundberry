sc = require './soundcloud'
exec = require('child_process').exec
argv = require('optimist').argv
http = require 'http'
ecstatic = require('ecstatic')(__dirname + '/static')
url = require 'url'
fs = require 'fs'
coffee = require 'coffee-script'
jade = require 'jade'
styl = require 'styl'

console.log 'Starting up...'
root = {}

play_track = (track, cb) ->
    console.log "[info] Playing #{ track.title }"
    stream_url = "#{ track.stream_url }?consumer_key=#{ sc.consumer_key }"
    root.play_process = exec "mpg123 #{ stream_url }", (error, stdout, stderr) ->
        cb() if not error

play_next = (cb) ->
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

root.play_process = null

sc.users.get 929224, (user) ->
    user.favorites (favorites) ->
        root.favorites = favorites
        root.current_set = (f.id for f in favorites)
        root.now_playing = favorites[0]
        play_from_now()

render_base = ->
    jade.compile(fs.readFileSync('views/base.jade').toString())()
render_songs = (songs) ->
    jade.compile(fs.readFileSync('views/songs.jade').toString())({songs: songs})
render_now_playing = ->
    jade.compile(fs.readFileSync('views/now_playing.jade').toString())({song: root.now_playing})

server = http.createServer (req, res) ->
    console.log "[debug] Handling #{ req.url }"

    # Base & song lists
    if req.url == '/'
        res.setHeader 'Content-Type', 'text/html'
        res.end render_base()
    else if req.url == '/favorites'
        res.setHeader 'Content-Type', 'text/html'
        res.end render_songs root.favorites
    else if req.url.indexOf('/search') == 0
        query = url.parse(req.url, true).query
        sc.tracks.search query.q, (found) ->
            root.searched = found
            root.current_set = (f.id for f in found)
            res.end render_songs found
    else if req.url == '/now_playing'
        res.setHeader 'Content-Type', 'text/html'
        res.end render_now_playing()

    # Playback actions
    else if matched = req.url.match /\/play\/(\d+)/
        root.play_process.kill 'SIGHUP'
        sc.tracks.get Number(matched[1]), (track) ->
            root.now_playing = track
            play_from_now()
            res.end "playing #{ root.now_playing.title }."
    else if req.url == '/next'
        root.play_process.kill 'SIGHUP'
        play_next ->
            res.end 'nexted.'
    else if req.url == '/last'
        root.play_process.kill 'SIGHUP'
        play_last ->
            res.end 'lasted.'
    else if req.url == '/stop'
        root.play_process.kill 'SIGHUP'
        res.end 'stopped.'
    else if req.url == '/status'
        res.end "playing #{ root.now_playing.title }."
    else if matched = req.url.match /\/volume\/(\d+)/
        exec "amixer -M set PCM #{ matched[1] }%"
        res.end "set volume to #{ matched[1] }%"

    # Static files
    else if req.url == '/base.js'
        res.end coffee.compile(fs.readFileSync('static/base.coffee').toString())
    else if req.url == '/base.css'
        res.end styl(fs.readFileSync('static/base.sass').toString(), {whitespace: true}).toString()
    else
        ecstatic(req, res)

server.listen 8080, console.log '[info] HTTP server listening.'
