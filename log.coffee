ansi = require('ansi')(process.stdout)
module.exports = (t, s, c) ->
    if !s?
        s=t; t='info'
    c = '#0066ff' if t == 'info'
    c = '#999999' if t == 'debug'
    c = '#ff6600' if t == 'error'
    ansi.hex(c).bold()
        .write("[#{ t }] ").reset()
        .write(s + '\n')

