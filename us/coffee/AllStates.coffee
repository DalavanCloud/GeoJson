class @AllStates extends @BubbleChart
  constructor: (id, data, color, domain) ->
    super(id, data, color)
    @height = 900
    @max_range = 90
    @scale()
    @arrange = false

    @domain = if domain? then domain else d3.range(100, 1700, 200)
    @color_class =
      d3.scale.threshold().domain(@domain).range(("q#{i}-9" for i in [8..0]))

    @tips = {}
    # map for sorting bubbles based on their category
    @map_group = d3.scale.threshold().domain(@domain).range([4..-4])

    @legend_text =
      () =>
        text = ("< #{e}" for e in @domain)
        text.push("#{@domain[@domain.length - 1]} or more")
        text

    @crimes = []
    @boundingRadius = @width / 3

  update_data: (set_crime_only) =>
    @data
    .forEach(
              (d) =>
                  if @crimes.length > 0
                    d.group = d3.sum(d[crime] for crime in @crimes) / d.value * 100000

                  if !set_crime_only? or set_crime_only == false
                    d.radius = @radius_scale(d.value)
                    d.x = Math.random() * @width
                    d.y = Math.random() * @height
                    delete d.px
                    delete d.py
            )

  create_vis: () =>
    super()

    # since we are using a threshold scale, we need to make sure we fall into the bucket
    # we promise to fall into in the legend text
    @legend = new Legend(@vis,
                         ((i) => @color_class(@domain[i] - 1)),
                         @legend_text(),
                         'Crime per 100,000 population',
                         {x: 75, y: 40}
                         )
    @legend.show(true)
    @create_scale({x:@width, y: -@height + 30})
    @search = new Search(@id, this, ((d) -> d.name),((data, text) -> $.grep(data, (d) -> d.name == text)[0]), {x: @width, y: -800})
    @search.create_search_box()

  show_details: (data) =>
    content =
      "Population: #{@fixed_formatter(data.value)}<br/>Crime: #{@fixed_formatter(d3.sum(data[crime] for crime in @crimes))}<br />"
    content += "Crime per 100,000: #{@percent_formatter(data.group)}"

    d3.select("##{data.id}").attr("stroke", "black").attr("stroke-width", 4)
    tip = @tips[data.id]
    if !tip?
      tip = new Opentip("##{data.id}", content, data.name, {style: "glass", fixed: true, target: true, tipJoint: "left bottom"})
      @tips[data.id] = tip
    else
      tip.setContent(content)

    tip.show()

  hide_details: (data) =>
    @tips[data.id]?.hide()
    d3.select("##{data.id}").attr("stroke", (d) -> d3.rgb($(this).css("fill")).darker()).attr("stroke-width", 2)

  move_arranged: (alpha) =>
    (d) =>
      targetY = @center.y - (@map_group(d.group) / 8 ) * @boundingRadius
      d.y = d.y + (targetY - d.y + 30) * @damper * alpha * 1.8
      d.x = d.x + (@center.x - d.x) * @damper * alpha

  move_towards_center: (alpha) =>
    (d) =>
      d.x = d.x + (@center.x - d.x) * @damper * alpha
      d.y = d.y + (@center.y - d.y + 50) * @damper * alpha

  display: () =>
    @update_data()
    super()

  update_display: (sort) =>
    @update_data(true)
    circles = @get_bubble(@vis, @data)

    # chained transitions to update fill color and stroke
    circles.transition().duration(1500)
      .attr("class", (d) => @color_class(d.group))
      .each("end", (d) -> d3.select(this).attr("stroke", d3.rgb($(this).css("fill")).darker()))

    @arrange = sort
    if @arrange
      @rearrange(sort)

  rearrange: (sort) =>
    # stop all force layouts
    @cleanup()

    circles = @get_bubble(@vis, @data)
    force = @force_layout(circles, @data, [@xDelta, @yDelta], (if @arranged then @move_arranged else @move_towards_center), true, sort)
    force.start()

  # we just need to pass an extra parameter to the parent function
  force_layout: (circles, data, size, move, oneForce, arrange) =>
    arrange = if arrange? then arrange else if @arrange == true then true else false
    super(circles, data, size, move, oneForce, arrange)

  # arranging means first we will "arrange"
  # and then invoke a regular layout to create a nice spherical shape
  on_tick: (move, e, circles, arrange) =>
    if !arrange
      super(move, e, circles)
    else if arrange
      if e.alpha > 0.055
        super(@move_arranged, e, circles)
      else if e.alpha < 0.055
        @force.stop()
        @force_layout(circles, @data, [@xDelta, @yDelta], @move_towards_center, true, !arrange).start()
