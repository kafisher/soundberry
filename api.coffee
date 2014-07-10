sc = require './soundcloud'
exec = require('child_process').exec
log = require './log'
barge = require 'barge'
_ = require 'underscore'

SoundBerry =
    play_process: null
    interpolationTimeout: null
    currentVolume: 50
    current_set: []

# Playback
# --------------------------------------------------------------------------------

SoundBerry.playTrack = (track, cb) ->
    log "Playing #{ track.title }"
    stream_url = "#{ track.stream_url }?consumer_key=#{ sc.consumer_key }"
    SoundBerry.play_process = exec "mpg123 #{ stream_url }", (error, stdout, stderr) ->
        cb() if not error

SoundBerry.playNext = (cb) ->
    return if !SoundBerry.current_set.length
    if !SoundBerry.now_playing
        now_index = -1
    else
        now_index = SoundBerry.current_set.indexOf SoundBerry.now_playing.id
        if now_index >= SoundBerry.current_set.length
            now_index = -1
    sc.tracks.get SoundBerry.current_set[now_index + 1], (err, track) ->
        SoundBerry.now_playing = track
        SoundBerry.playFromNow()
        cb() if cb?

SoundBerry.playLast = (cb) ->
    now_index = SoundBerry.current_set.indexOf SoundBerry.now_playing.id
    sc.tracks.get SoundBerry.current_set[now_index - 1], (err, track) ->
        SoundBerry.now_playing = track
        SoundBerry.playFromNow()
        cb() if cb?

SoundBerry.playFromNow = ->
    SoundBerry.playTrack SoundBerry.now_playing, SoundBerry.playNext

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
            return cb "Usage: search {tracks/users} {query}"
        log "query.type is #{ kind }"
        type_class = sc[kind]
        type_class.search query, cb

    play: (track_id, cb) ->
        if arguments.length != 2
            cb = _.find(arguments, _.isFunction)
            return cb "Usage: play {track id}"
        SoundBerry.stopPlaying()
        sc.tracks.get track_id, (err, track) ->
            SoundBerry.now_playing = track
            SoundBerry.playFromNow()
            cb null, "playing #{ SoundBerry.now_playing.title }."

    queue: (track_id, cb) ->
        if arguments.length != 2
            cb = _.find(arguments, _.isFunction)
            return cb "Usage: queue {track id}"
        SoundBerry.current_set.push track_id
        cb null, 'set ' + SoundBerry.current_set.join(', ')

    setPlaylist: (track_ids, cb) ->
        SoundBerry.current_set = track_ids
        log('Set: ' + SoundBerry.current_set)
        cb null, 'set ' + SoundBerry.current_set.join(', ')

    next: (cb) ->
        SoundBerry.stopPlaying()
        SoundBerry.playNext ->
            cb null, 'nexted.'

    last: (cb) ->
        SoundBerry.stopPlaying()
        SoundBerry.playLast ->
            cb null, 'lasted.'

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
        cb null, "set volume to #{ vol_num }%"

    state: (cb) ->
        cb null,
            volume: SoundBerry.targetVolume || SoundBerry.currentVolume
            now_playing: SoundBerry.now_playing

