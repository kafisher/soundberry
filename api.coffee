sc = require './soundcloud'
exec = require('child_process').exec
log = require './log'
barge = require 'barge'

SoundBerry =
    play_process: null
    interpolationTimeout: null
    currentVolume: 50

# Playback
# --------------------------------------------------------------------------------

SoundBerry.playTrack = (track, cb) ->
    log "Playing #{ track.title }"
    stream_url = "#{ track.stream_url }?consumer_key=#{ sc.consumer_key }"
    SoundBerry.play_process = exec "mpg123 #{ stream_url }", (error, stdout, stderr) ->
        cb() if not error

SoundBerry.playNext = (cb) ->
    return if !SoundBerry.current_set?
    now_index = SoundBerry.current_set.indexOf SoundBerry.now_playing.id
    sc.tracks.get SoundBerry.current_set[now_index + 1], (track) ->
        SoundBerry.now_playing = track
        playFromNow()
        cb() if cb?

SoundBerry.playLast = (cb) ->
    now_index = SoundBerry.current_set.indexOf SoundBerry.now_playing.id
    sc.tracks.get SoundBerry.current_set[now_index - 1], (track) ->
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
    console.log "[setSystemVolume] #{ v }%"

# Control methods
# --------------------------------------------------------------------------------

soundberry_service = new barge.Service 'soundberry',

    play: (track_id, cb) ->
        SoundBerry.stopPlaying()
        sc.tracks.get track_id, (track) ->
            SoundBerry.now_playing = track
            SoundBerry.playFromNow()
            cb null, "playing #{ SoundBerry.now_playing.title }."

    setPlaylist: (track_ids, cb) ->
        SoundBerry.current_set = track_ids
        console.log('Set: ' + SoundBerry.current_set)
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

    current: (cb) ->
        cb null, SoundBerry.now_playing

    status: (cb) ->
        cb null, "playing #{ SoundBerry.now_playing.title }."

    volume: (vol, cb) ->
        if typeof vol == 'number'
            vol_num = vol
        else if typeof vol == 'string'
            if vol[0] in ['-', '+']
                vol_dir = vol[0]
                vol_num = Number(vol[1..])
            else
                vol_num = Number(vol)
            vol_now = SoundBerry.targetVolume || SoundBerry.currentVolume
            if vol_dir == '+'
                vol_num = vol_now + vol_num
            else if vol_dir == '-'
                vol_num = vol_now - vol_num
        SoundBerry.setVolume vol_num
        cb null, "set volume to #{ vol_num }%"

