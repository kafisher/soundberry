$ ->
    # Set up loader
    $('.loading').height($(window).height())
    $('.loading').width($(window).width())
    $('.loader').offset
        left: $('.loading').width()/2 - 16
        top: $('.loading').height()/2 - 16

    $('#songs').on 'click', 'li a', (e) ->
        e.preventDefault()
        $.get $(this).attr('href'), ->
            load_now_playing()

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
        $('.loading').show()
        $.get '/favorites', (data) ->
            $('#songs').html data
            $('.loading').fadeOut()
    load_favorites()
    $('a.load-favorites').on 'click', ->
        load_favorites()
        close_menu()

    load_search = (q) ->
        $('#songs').empty()
        $('.loading').show()
        $.get "/search?q=#{ q }", (data) ->
            $('#songs').html data
            $('.loading').fadeOut()
    $('.search input').on 'focus', ->
        $('.search input').val('')
    $('.search input').on 'change', ->
        load_search $('.search input').val()
        $('.search input').blur()
        close_menu()

    # Side menu
    window.menu_open = false
    open_menu = -> $('#songs').addClass('opened')
    close_menu = -> $('#songs').removeClass('opened')
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
        , 500
    $('input[name=volume]').on 'changed', (e) ->
        $.get "/volume/#{ $(this).val() }"
