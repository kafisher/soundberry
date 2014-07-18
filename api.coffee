sc = require './soundcloud'
exec = require('child_process').exec
log = require './log'
barge = require 'barge/src'
_ = require 'underscore'

SoundBerry =
    play_process: null
    interpolationTimeout: null
    currentVolume: 50
    current_set: []

# Playback
# --------------------------------------------------------------------------------

SoundBerry.playSong = (song, cb) ->
    log "Playing #{ song.title }"
    stream_url = "#{ song.stream_url }?consumer_key=#{ sc.consumer_key }"
    SoundBerry.play_process = exec "mpg123 #{ stream_url }", (error, stdout, stderr) ->
        if error
        else
            soundberry_service.emit 'change:song', song
            cb() if cb?

SoundBerry.playNext = (cb) ->
    return cb() if !SoundBerry.current_set.length
    if !SoundBerry.now_playing
        now_index = -1
    else
        now_index = SoundBerry.current_set.indexOf SoundBerry.now_playing.id
        if now_index >= SoundBerry.current_set.length
            now_index = -1
    sc.tracks.get SoundBerry.current_set[now_index + 1], (err, song) ->
        SoundBerry.now_playing = song
        SoundBerry.playFromNow()
        cb(null, song) if cb?

SoundBerry.playPrevious = (cb) ->
    return cb() if !SoundBerry.current_set.length
    now_index = SoundBerry.current_set.indexOf SoundBerry.now_playing.id
    sc.tracks.get SoundBerry.current_set[now_index - 1], (err, song) ->
        SoundBerry.now_playing = song
        SoundBerry.playFromNow()
        cb(null, song) if cb?

SoundBerry.playFromNow = ->
    SoundBerry.playSong SoundBerry.now_playing, SoundBerry.playNext

SoundBerry.stopPlaying = ->
    if SoundBerry.play_process?
        SoundBerry.play_process.kill 'SIGHUP'
        delete SoundBerry.play_process

# Volume setting and interpolation
# --------------------------------------------------------------------------------

SoundBerry.setVolume = (v) ->
    SoundBerry.mu = 0
    SoundBerry.targetVolume = v
    SoundBerry.startingVolume = SoundBerry.currentVolume
    SoundBerry.dmu = 0.25
    clearTimeout SoundBerry.interpolationTimeout
    SoundBerry.interpolateVolumes()
    soundberry_service.emit 'change:volume', v

SoundBerry.interpolateVolumes = ->
    if SoundBerry.mu <= 1.0
        v = SoundBerry.startingVolume*(1-SoundBerry.mu)+SoundBerry.targetVolume*SoundBerry.mu
        SoundBerry.setSystemVolume v
        SoundBerry.mu += SoundBerry.dmu
        SoundBerry.interpolationTimeout = setTimeout SoundBerry.interpolateVolumes, 150

SoundBerry.setSystemVolume = (v) ->
    SoundBerry.currentVolume = v
    exec "amixer -M set PCM #{ v }%"
    log "[setSystemVolume] #{ v }%"

# Control methods
# --------------------------------------------------------------------------------

soundberry_service = new barge.Service 'soundberry',

    search: (kind, query, cb) ->
        if arguments.length != 3
            cb = _.find(arguments, _.isFunction)
            return cb "Usage: search {songs/users} {query}"
        log "query.type is #{ kind }"
        type_class = sc[kind]
        type_class.search query, cb

    play: (song_id, cb) ->
        if arguments.length != 2
            cb = _.find(arguments, _.isFunction)
            return cb "Usage: play {song id}"
        SoundBerry.stopPlaying()
        sc.tracks.get song_id, (err, song) ->
            SoundBerry.now_playing = song
            SoundBerry.playFromNow()
            cb null, song

    queue: (song_id, cb) ->
        if arguments.length != 2
            cb = _.find(arguments, _.isFunction)
            return cb "Usage: queue {song id}"
        SoundBerry.current_set.push song_id
        cb null, SoundBerry.current_set

    setPlaylist: (song_ids, cb) ->
        SoundBerry.current_set = song_ids
        log('Set: ' + SoundBerry.current_set)
        cb null, SoundBerry.current_set

    next: (cb) ->
        SoundBerry.stopPlaying()
        SoundBerry.playNext (err, song) ->
            cb null, song

    previous: (cb) ->
        SoundBerry.stopPlaying()
        SoundBerry.playPrevious (err, song) ->
            cb null, song

    stop: (cb) ->
        SoundBerry.stopPlaying()
        cb null, 'stopped.'

    nowPlaying: (cb) ->
        cb null, SoundBerry.now_playing

    currentSet: (cb) ->
        cb null, SoundBerry.current_set

    status: (cb) ->
        cb null, "playing #{ SoundBerry.now_playing.title }."

    volume: (vol, cb) ->
        vol_now = SoundBerry.targetVolume || SoundBerry.currentVolume
        if arguments.length != 2
            cb = vol
            return cb null, vol_now
        if typeof vol == 'number'
            vol_num = vol
        else if typeof vol == 'string'
            if vol[0] in ['-', '+']
                vol_dir = vol[0]
                vol_num = Number(vol[1..])
            else
                vol_num = Number(vol)
            if vol_dir == '+'
                vol_num = vol_now + vol_num
            else if vol_dir == '-'
                vol_num = vol_now - vol_num
        SoundBerry.setVolume vol_num
        cb null, vol_num

    state: (cb) ->
        cb null,
            volume: SoundBerry.targetVolume || SoundBerry.currentVolume
            now_playing: SoundBerry.now_playing

