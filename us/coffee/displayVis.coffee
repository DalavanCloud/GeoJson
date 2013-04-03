$ ->
  byState = null
  allStates = null
  crime_data = null
  map_data = null
  map = null
  charts = []
  colorScheme = 'Spectral'
  #colorScheme = 'PiYG'

  current_state = ''
  domain = [10, 20, 50, 100, 200, 400, 800, 1500]
  viewModel = new window.ViewModel()
  ko.applyBindings(viewModel)

  toArray = (data) -> d3.map(data).values()
  String::startsWith = (str) -> this.slice(0, str.length) == str
  String::removeLeadHash = () -> if this.startsWith("#") then this.slice(1) else this

  render_all_states = (crimes, update, sort) ->
    if !allStates?
      allStates = new @AllStates('vis', toArray(crime_data), colorScheme, domain)
      charts.push(allStates)

    allStates.crimes = crimes
    allStates.arrange = sort
    if !update? or !update
      allStates.create_vis()
      allStates.display()
    else
      allStates.update_display(sort)

  render_by_state = (state, crimes, update, sort) ->

    if !byState?
      byState = new @StatesBreakDown('vis', toArray(crime_data), colorScheme, domain)
      charts.push(byState)

    byState.crimes = crimes
    byState.arrange = sort
    if !update? or !update
      byState.create_vis()
      byState.display()
      if state?
        byState.show_cities(state, sort)
    else
      byState.update_display(state, sort)

  render_map = (state, crimes) ->
    map = new @CrimeUsMap('vis', map_data, crime_data, colorScheme, domain)
    map.create_vis()

    map.crimes = crimes
    map.display()

  render = (type, state, crimes, update, sort) ->
    switch type
      when  'all_states'
          render_all_states(crimes, update, sort)
      when 'by_state'
          render_by_state(state, crimes, update, sort)
      when 'map'
        if !map_data?
          d3.json "us.json", (map) ->
                  map_data = map
                  render_map(state, crimes)
        else
          render_map(state, crimes, update)

  load_visual = (type, state, crimes, update, sort) ->
    if !crime_data?
      d3.json "crime.json",
             (data) ->
              crime_data = data
              render(type, state, crimes, sort)
    else
      render(type, state, crimes, update, sort)

  set_current_state = (id, st) ->
    ret = id
    if st?
      [ret, st].join(";")

  $(window).bind 'hashchange', (e) ->
    states = ({id, value} for id, value of $.bbq.getState())
    view = state for state in states when state.id? and state.id != "crimes" and state.id != "sort"
    crimes = obj.value.split(";") for obj in states when obj.id == "crimes"
    sort = obj.value for obj in states when obj.id="sort"

    for chart in charts
      do (chart) -> chart?.cleanup()

    # not the first time, we are switching tabs
    if !crimes?
      crimes = viewModel.crime()
      $.bbq.pushState({crimes: crimes.join(";")})
    else
      if viewModel.crime().length == 0
        viewModel.crime(crimes)

      if !view?
        view = {id: 'all_states'}

      viewModel.crime(crimes)
      current = set_current_state(view.id, view.value)
      update = current_state == current
      current_state = current
      load_visual(view.id, (if view.value == "" then undefined else view.value), crimes, update, sort)
      $('#view_selection a').removeClass('active')
      $("#view_selection a##{view.id}").addClass('active')

  # action!
  $(window).trigger('hashchange')
