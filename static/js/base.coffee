ua = navigator.userAgent
window.is_iphone = ~ua.indexOf('iPhone') || ~ua.indexOf('iPod')
window.is_ipad = ~ua.indexOf('iPad')
window.is_ios = is_iphone || is_ipad

$ ->
    # Resizing (content height)
    handleResize = ->
        $('#content').css
            'min-height': ($(window).height())
        $('#menu').height($(window).height())
    $(window).on 'resize', handleResize
    handleResize()
    $('#menu').show()

    # Song playback

    load_now_playing = ->
        $.get '/now_playing', (data) ->
            $('#now_playing').html data
    load_now_playing()
    setInterval load_now_playing, 1000*10

    $('a.load-favorites').on 'click', ->
        load_favorites()
        close_menu()

    # Side menu

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
    #load_favorites()
    console.log 'loaded?'
    window.router = new MainRouter()
    window.main_view = new MainView()
    Backbone.history.start()

chooseTab = ($tab) ->
    $('.tab').removeClass('selected')
    $tab.addClass('selected')

class MainView extends Backbone.View
    initialize: ->
        router.navigate '/users/56303', true
        @menu_open = false
        @$el = $('body')
        hammer = @$el.hammer()
        hammer.on 'tap', 'a.menu', @toggle_menu
        self = this
        @$el.on 'click', 'a', (e) -> e.preventDefault()
        hammer.on 'tap', 'a', (e) ->
            if $(this).attr('href')
                e.preventDefault()
                e.stopPropagation()
                console.log "tapped #{ $(this).attr('href') }"
                router.navigate $(this).attr('href'), true
                self.close_menu()
        hammer.on 'hold', 'a.track', (e) ->
            track_id = $(this).data('track_id')
            $.get "/play/#{ track_id }"
        hammer.on 'tap', 'a.tab', (e) ->
            $('a.tab').removeClass('selected')
            $(this).addClass('selected')
        hammer.on 'hold', 'a', ->
            console.log "held #{ $(this).attr('href') }"
        hammer.on 'tap', '.search a.btn-mini', ->
            window.search_type = $(this).attr('id').split('-')[2]
            $('.search a.btn-mini').removeClass('selected')
            $(this).addClass('selected')
        # Playback buttons
        hammer.on 'tap', 'a.play', (e) -> $.get "/play/#{ $(this).data('track_id') }"
        hammer.on 'tap', '#now_playing .track', (e) -> self.load_content "/tracks/#{ $(this).data('track_id') }"
        hammer.on 'tap', 'a.next', (e) -> $.get '/next', load_now_playing
        hammer.on 'tap', 'a.last', (e) -> $.get '/last', load_now_playing
        hammer.on 'tap', 'a.stop', (e) -> $.get '/stop', -> $('#now_playing').empty()
        hammer.on 'tap', 'a.refresh', (e) -> location.reload(true)
        # Searching
        @search_type = 'tracks'
        $('.search').on 'submit', (e) ->
            e.preventDefault()
            self.load_search $('.search input').val()
            $('.search input').blur()
            close_menu()

    load_search: (q) ->
        param_str = decodeURIComponent $.param
            q: q
            type: @search_type
        @load_content "/search?#{ param_str }"

    open_menu: -> $('#content').addClass('opened')
    close_menu: -> $('#content').removeClass('opened')
    toggle_menu: (e) ->
        e.preventDefault()
        e.stopPropagation()
        if @menu_open
            close_menu()
        else
            open_menu()
        window.menu_open = !window.menu_open
    #
    # Set up loader
    show_loading: ($container) ->
        $container.css
            'min-height': $(window).height() - $container.offset().top
        $loading = $($('#loading-template').html())
        $loading.appendTo $container
        $loading.show()
        $loading.height($container.height())
        $loading.width($container.width())
        $loading.offset
            top: $container.offset().top
        $loading.find('.loader').css
            left: $loading.width()/2 - 16
            top: $loading.height()/2 - 16
    hide_loading: ($container) ->
        setTimeout =>
            $loading = $container.find('.loading')
            $loading.fadeOut =>
                $loading.remove()
        , 500

    load_content: (content_url, into, cb) ->
        if @current_content_url == content_url
            return cb() if cb?
            return
        @current_content_url = content_url
        $container = if into? then into else $('.container')
        $container.empty()
        @show_loading $container
        $.get content_url, (data) =>
            $container.html(data)
            console.log $container
            @hide_loading $container
            cb() if cb?
    load_favorites: -> @load_content '/favorites'

class MainRouter extends Backbone.Router
    routes:
        '': 'show_favorites'
        'favorites': 'show_favorites'
        ':type/:obj_id/:sub_type': 'show_sub_res'
        ':type/:obj_id': 'show_obj'
        ':type': 'show_res'
    initialize: ->
        @on 'route:show_favorites', ->
            console.log 'yes the favorite'
            main_view.load_favorites()
        @on 'route:show_res', (res) ->
            console.log 'some res then'
            main_view.load_content "/#{ res }"
        @on 'route:show_obj', (type, obj_id) ->
            console.log 'ah an obj'
            main_view.load_content "/#{ type }/#{ obj_id }", undefined, =>
                if main_view.$el.find('.tabs')?
                    first_tab = main_view.$el.find('a.tab').first()
                    main_view.load_content first_tab.attr('href'), $('.tab-content')
                    chooseTab first_tab
        @on 'route:show_sub_res', (type, obj_id, sub_type) ->
            obj_url = "/#{ type }/#{ obj_id }"
            sub_res_url = "/#{ type }/#{ obj_id }/#{ sub_type }"
            if !main_view.current_content_url or !main_view.current_content_url.match "^/#{ type }/#{ obj_id }"
                main_view.load_content obj_url, undefined, =>
                    chooseTab $("a.tab[href=\"#{ sub_res_url }\"]")
                    main_view.load_content sub_res_url, $('.tab-content')
            else
                chooseTab $("a.tab[href=\"#{ sub_res_url }\"]")
                main_view.load_content sub_res_url, $('.tab-content')
