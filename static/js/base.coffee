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
    window.router = new MainRouter()
    window.main_view = new MainView()
    Backbone.history.start()

chooseTab = ($tab) ->
    $('.tab').removeClass('selected')
    $tab.addClass('selected')

class MainView extends Backbone.View
    initialize: ->
        @menu_open = false
        @$el = $('body')
        hammer = @$el.hammer()
        hammer.on 'tap', 'a.menu', @toggle_menu
        self = this
        # Event delegation
        @$el.on 'click', 'a', (e) -> e.preventDefault()
        hammer.on 'tap', 'a', (e) ->
            if $(this).attr('target') == '_blank'
                return
            if $(this).attr('href')
                e.preventDefault()
                e.stopPropagation()
                router.navigate $(this).attr('href'), true
                self.close_menu()
        hammer.on 'hold', 'a.track', (e) ->
            track_id = $(this).data('track_id')
            $.get "/play/#{ track_id }"
        hammer.on 'tap', 'a.tab', (e) ->
            $('a.tab').removeClass('selected')
            $(this).addClass('selected')
        hammer.on 'hold', 'a', ->
        hammer.on 'tap', '.search a.btn-mini', ->
            self.search_type = $(this).attr('id').split('-')[2]
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

    load_search: (q) ->
        param_str = decodeURIComponent $.param
            q: q
            type: @search_type
        @load_content "/search?#{ param_str }"

    open_menu: -> $('#content').addClass('opened'); @menu_open = true
    close_menu: -> $('#content').removeClass('opened'); @menu_open = false
    toggle_menu: (e) =>
        e.preventDefault()
        e.stopPropagation()
        if @menu_open then @close_menu() else @open_menu()

    # Loading indicator
    
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
        $loading = $container.find('.loading')
        $loading.fadeOut =>
            $loading.remove()

    load_content: (content_url, into, cb) ->
        if @current_content_url == content_url
            return cb() if cb?
            return
        @current_content_url = content_url
        $container = if into? then into else $('.container')
        $container.empty()
        @show_loading $container
        @close_menu()
        $.get content_url, (data) =>
            $container.html(data)
            @hide_loading $container
            cb() if cb?

class MainRouter extends Backbone.Router
    routes:
        ':res/:obj_id/:sub_res': 'show_sub_res'
        ':res/:obj_id': 'show_obj'
        ':res': 'show_res'
        '': 'show_res'
    initialize: ->
        @on 'route:show_res', (res) ->
            res = 'favorites' if !res?
            main_view.load_content "/#{ res }"
        @on 'route:show_obj', (res, obj_id) ->
            main_view.load_content "/#{ res }/#{ obj_id }", undefined, =>
                if main_view.$el.find('.tabs')?
                    first_tab = main_view.$el.find('a.tab').first()
                    main_view.load_content first_tab.attr('href'), $('.tab-content')
                    chooseTab first_tab
        @on 'route:show_sub_res', (res, obj_id, sub_res) ->
            obj_url = "/#{ res }/#{ obj_id }"
            sub_res_url = "/#{ res }/#{ obj_id }/#{ sub_res }"
            if !main_view.current_content_url or !main_view.current_content_url.match "^/#{ res }/#{ obj_id }"
                main_view.load_content obj_url, undefined, =>
                    chooseTab $("a.tab[href=\"#{ sub_res_url }\"]")
                    main_view.load_content sub_res_url, $('.tab-content')
            else
                chooseTab $("a.tab[href=\"#{ sub_res_url }\"]")
                main_view.load_content sub_res_url, $('.tab-content')
