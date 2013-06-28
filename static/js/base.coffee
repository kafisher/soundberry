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
    show_loading = ($container) ->
        $container.css
            'min-height': $(window).height() - $container.offset().top
        $loading = $('#loading').clone().addClass('loading')
        $loading.appendTo $container
        $loading.show()
        $loading.height($container.height())
        $loading.width($container.width())
        $loading.offset
            top: $container.offset().top
        $loading.find('.loader').css
            left: $loading.width()/2 - 16
            top: $loading.height()/2 - 16
    hide_loading = ($container) ->
        setTimeout =>
            $loading = $container.find('.loading')
            $loading.fadeOut =>
                $loading.remove()
        , 100

    # Song playback
    hammer = $('body').hammer()
    hammer.on 'tap', 'a', (e) ->
        if $(this).attr('href')
            e.preventDefault()
            console.log "tapped #{ $(this).attr('href') }"
            if $(this).hasClass('tab')
                load_content $(this).attr('href'), $(this).closest('.tabbed').find('.tab-content')
            else
                load_content $(this).attr('href')
    hammer.on 'tap', 'a.tab', (e) ->
        $('a.tab').removeClass('selected')
        $(this).addClass('selected')
    hammer.on 'hold', 'a', ->
        console.log "held #{ $(this).attr('href') }"
        #$.get "/info/#{ $(this).attr('href').split('/')[2] }", (data)
        #   -> $('#info').html(data)
    $('body').on 'click', 'a', (e) -> e.preventDefault()

    # Playback buttons
    hammer.on 'tap', 'a.next', (e) -> e.preventDefault(); $.get '/next', load_now_playing
    hammer.on 'tap', 'a.last', (e) -> e.preventDefault(); $.get '/last', load_now_playing
    hammer.on 'tap', 'a.stop', (e) -> e.preventDefault(); $.get '/stop', -> $('#now_playing').empty()
    hammer.on 'tap', 'a.refresh', (e) -> location.reload(true)

    load_content = (content_url, into) ->
        $container = if into? then into else $('.container')
        $container.empty()
        show_loading $container
        $.get content_url, (data) ->
            console.log "done loading so i'll hide"
            $container.html(data)
            console.log "is the container set with #{ data }?"
            console.log $container
            hide_loading $container
            selected_tab = $container.find('.tab.selected')
            if selected_tab.length
                console.log "Guess i'll look for #{ selected_tab.attr('href') }"
                setTimeout ->
                    load_content selected_tab.attr('href'), $container.find('.tab-content')
                , 10

    load_now_playing = ->
        $.get '/now_playing', (data) ->
            $('#now_playing').html data
    load_now_playing()
    setInterval load_now_playing, 1000*10

    load_favorites = -> load_content '/favorites'
    $('a.load-favorites').on 'click', ->
        load_favorites()
        close_menu()

    # Searching
    window.search_type = 'tracks'
    hammer.on 'tap', '.search a.btn-mini', ->
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
    hammer.on 'tap', 'a.menu', toggle_menu

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

    # Initialization
    #open_menu()
    load_favorites()
    #load_content '/users/56303'
    console.log 'loaded?'
