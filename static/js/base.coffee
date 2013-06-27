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
    hammer = $('.container').hammer()
    hammer.on 'tap', 'a', ->
        console.log "tapped #{ $(this).attr('href') }"
        load_content $(this).attr('href')
    hammer.on 'hold', 'a', ->
        console.log "held #{ $(this).attr('href') }"
        #$.get "/info/#{ $(this).attr('href').split('/')[2] }", (data)
        #   -> $('#info').html(data)

    # Playback buttons
    $('a.next').on 'click', (e) -> e.preventDefault(); $.get '/next', load_now_playing
    $('a.last').on 'click', (e) -> e.preventDefault(); $.get '/last', load_now_playing
    $('a.stop').on 'click', (e) -> e.preventDefault(); $.get '/stop', -> $('#now_playing').empty()
    $('a.refresh').on 'click', (e) -> location.reload(true)

    load_content = (content_url) ->
        $('.container').empty()
        show_loading()
        $.get content_url, (data) ->
            $('.container').html(data)
            hide_loading()

    load_now_playing = ->
        $.get '/now_playing', (data) ->
            $('#now_playing').html data
    load_now_playing()
    setInterval load_now_playing, 1000*10

    load_favorites = -> load_content '/favorites'
    load_favorites()
    $('a.load-favorites').on 'click', ->
        load_favorites()
        close_menu()

    # Searching
    window.search_type = 'tracks'
    $('.search a.btn-mini').on 'click', ->
        window.search_type = $(this).attr('id').split('-')[2]
        $('.search a.btn-mini').removeClass('selected')
        $(this).addClass('selected')

    load_search = (q) ->
        param_str = decodeURIComponent $.param
            q: q
            type: window.search_type
        load_content "/search?#{ param_str }"
    $('.search').on 'submit', (e) ->
        e.preventDefault()
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
