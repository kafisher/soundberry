ua = navigator.userAgent
window.is_iphone = ~ua.indexOf('iPhone') || ~ua.indexOf('iPod')
window.is_ipad = ~ua.indexOf('iPad')
window.is_ios = is_iphone || is_ipad

$ ->
    # Resizing (content height)
    handleResize = ->
        $('#content').css
            'min-height': ($(window).height())
    $(window).on 'resize', handleResize
    handleResize()
    $('#menu').show()

    # Set up loader
    show_loading = ->
        $('.loading').height($(window).height())
        $('.loading').width($('#content').width())
        #$('.loading').css
            #opacity: 1.0
        $('.loading').fadeIn()
        $('.loader').css
            left: $('.loading').width()/2 - 16
            top: $('.loading').height()/2 - 16
    hide_loading = ->
        setTimeout ->
            $('.loading').fadeOut()
        , 200

    # Song playback
    window.long_timer = null
    window.long_pressed = null
    $('#songs').on 'click', 'li a', (e) -> e.preventDefault()
    handle_down = (e) ->
        e.preventDefault()
        window.long_pressed = false
        window.long_timer = setTimeout =>
            console.log 'long press'
            $(this).closest('li').toggleClass('selected')
            window.long_pressed = true
        , 500
    handle_up = (e) ->
        e.preventDefault()
        clearTimeout window.long_timer
        if not window.long_pressed
            console.log 'short press'
            #//$.get $(this).attr('href'), ->
            #    load_now_playing()
    up_function = if is_ios then 'touchstart' else 'mouseup'
    down_function = if is_ios then 'touchend' else 'mousedown'
    #$('#songs').on up_function, 'li a', handle_up
    #$('#songs').on down_function, 'li a', handle_down

    hammer = $('#songs').hammer()
    hammer.on 'tap', 'a', ->
        console.log "tapped #{ $(this).attr('href') }"
        $.get $(this).attr('href')
    hammer.on 'hold', 'a', ->
        console.log "held #{ $(this).attr('href') }"
        #$.get "/info/#{ $(this).attr('href').split('/')[2] }", (data)
        #   -> $('#info').html(data)

    # Playback buttons
    $('a.next').on 'click', (e) -> e.preventDefault(); $.get '/next', load_now_playing
    $('a.last').on 'click', (e) -> e.preventDefault(); $.get '/last', load_now_playing
    $('a.stop').on 'click', (e) -> e.preventDefault(); $.get '/stop', -> $('#now_playing').empty()
    $('a.refresh').on 'click', (e) -> location.reload(true)

    load_now_playing = ->
        $.get '/now_playing', (data) ->
            $('#now_playing').html data
    load_now_playing()
    setInterval load_now_playing, 1000*10

    load_favorites = ->
        $('#songs').empty()
        show_loading()
        $.get '/favorites', (data) ->
            console.log 'got?'
            setTimeout ->
                $('#songs').html data
                hide_loading()
            , 50
    load_favorites()
    $('a.load-favorites').on 'click', ->
        load_favorites()
        close_menu()

    load_search = (q) ->
        $('#songs').empty()
        $('.loading').show()
        $.get "/search?q=#{ q }", (data) ->
            $('#songs').html data
            hide_loading()
    $('.search input').on 'focus', ->
        $('.search input').val('')
    $('.search input').on 'change', ->
        load_search $('.search input').val()
        $('.search input').blur()
        close_menu()

    # Side menu
    window.menu_open = false
    open_menu = -> $('#content').addClass('opened')
    close_menu = -> $('#content').removeClass('opened')
    toggle_menu = (e) ->
        e.preventDefault()
        e.stopPropagation()
        if window.menu_open
            close_menu()
        else
            open_menu()
        window.menu_open = !window.menu_open
    $('a.menu').on 'touchstart', toggle_menu
    $('a.menu').on 'click', toggle_menu
    #open_menu()

    # Volume changer
    window.volume_change_timer = null
    $('input[name=volume]').on 'change', (e) ->
        if volume_change_timer?
            clearTimeout volume_change_timer
        window.volume_change_timer = setTimeout ->
            $('input[name=volume]').trigger 'changed'
        , 150
    $('input[name=volume]').on 'changed', (e) ->
        $.get "/volume/#{ $(this).val() }"
