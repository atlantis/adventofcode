class SpaceObject
  ASTROID = '#'
  EMPTY = '.'

  attr_reader :type, :x, :y

  def initialize(space_map, type, x, y)
    @space_map, @type, @x, @y = space_map, type, x, y
  end

  def astroid?
    self.type == ASTROID
  end

  def can_see?(other_object)
    blocking_object = self.possible_locations_toward(other_object).find{|x, y| !@space_map[x][y].nil? }
    blocking_object.nil?
  end

  def seen_objects(type = nil)
    @space_map.objects.reject{|o| o == self || (!type.nil? && o.type != type) }.select{|o| self.can_see?(o)}
  end

  def possible_locations_toward(other_object)
    puts "Checking #{@x}:#{@y} towards #{other_object.x}:#{other_object.y}" if @space_map.verbose

    x_offset = other_object.x > @x ? 1 : -1
    y_offset = other_object.y > @y ? 1 : -1

    valid_y_range = y_offset == 1 ? (@y...other_object.y) : ((other_object.y + 1)..@y)

    cur_x, cur_y = @x, @y
    locations = []
    if cur_x == other_object.x
      loop do
        cur_y += y_offset
        break if cur_y == other_object.y 
        locations << [@x, cur_y]
        puts "   ADDED LOCATION [#{cur_x}:#{cur_y.to_i}]" if @space_map.verbose
      end
    elsif cur_y == other_object.y
      loop do 
        cur_x += x_offset
        break if cur_x == other_object.x 
        locations << [cur_x, @y]
      end
    else
      slope = ((1.0 * other_object.y) - @y) / (other_object.x - @x)
      
      puts "slope: #{slope} x_offset: #{x_offset} cur_x: #{cur_x} other_object.x: #{other_object.x} valid_y_range: #{valid_y_range.inspect}" if @space_map.verbose

      loop do
        cur_x += x_offset
        cur_y = @y + ((cur_x - @x) * slope)

        puts "   cur_x: #{cur_x} cur_y: #{cur_y}" if @space_map.verbose
        
        if cur_y.to_i == cur_y && (cur_y = cur_y.to_i) && valid_y_range.include?(cur_y)
          locations << [cur_x, cur_y] 
          puts "   ADDED LOCATION [#{cur_x}:#{cur_y}]" if @space_map.verbose
        end
        break if cur_x == other_object.x
      end
    end
    
    locations
  end

  def lame_coordinates
    {x: @x, y: @space_map.height - (@y + 1)}
  end

  def theta_relative_to(anchor_x, anchor_y)
    puts "Theta from astroid #{x}:#{@y} to laser at #{anchor_x}:#{anchor_y}" if @space_map.verbose

    our_x, our_y = @x, @y

    if our_x == anchor_x
      if our_y > anchor_y
        return 0
      else
        return 180
      end
    elsif our_x > anchor_x
      if our_y == anchor_y
        return 90
      elsif our_y <= anchor_y
        quadrant_subtract = 180
      end
    else
      if our_y == anchor_y
        return 270
      elsif our_y > anchor_y
        quadrant_subtract = 360
      else
        quadrant_add = 180
      end
    end

    x_distance = (@x - anchor_x).abs    
    y_distance = (@y - anchor_y).abs
    hypotenuse = self.distance_to(anchor_x, anchor_y)

    raw_theta = Math.asin(x_distance / hypotenuse) * (180 / Math::PI)
    
    theta = raw_theta.round(10)
    theta = quadrant_subtract - theta if quadrant_subtract
    theta = quadrant_add + theta if quadrant_add

    raise "Invalid theta: #{msg}" unless theta.is_a?(Numeric)
    msg = "x_distance #{x_distance} y_distance #{y_distance} hypotenuse #{hypotenuse} quadrant_add #{quadrant_add} quadrant_subtract #{quadrant_subtract} initial theta #{raw_theta} final theta: #{theta}"
    puts msg if @space_map.verbose

    theta
  end

  def distance_to(other_x, other_y)
    Math.sqrt( ((@x - other_x) ** 2) + ((@y - other_y) ** 2) )
  end

  def ==(other)
    @type == other.type && @x == other.x && @y == other.y
  end

  def inspect
    "SpaceObject{type: #{@type}, x: #{@x}, y: #{@y}}"
  end
end

class SpaceMap
  attr_reader :width, :height, :objects
  attr_accessor :annotations, :verbose

  def initialize(data, options = {})
    @verbose = options[:verbose]
    @objects = []
    @height = 0
    rows = data.split("\n").map(&:strip)
    @width = rows.first.chars.count
    @height = rows.count
    @annotations = @width.times.map{ @height.times.map{nil} }

    #reverse rows to translate to positive y-coordinates
    rows.reverse.each_with_index do |row, y_index| 
      row.chars.each_with_index do |char, x_index|
        @objects << SpaceObject.new(self, char, x_index, y_index) unless char == SpaceObject::EMPTY
      end
    end
  end

  def astroids
    @objects.select{|o| o.astroid? }
  end

  def [](x)
    column = {}
    @objects.select{|o| o.x == x}.each{|o| column[o.y] = o}
    column
  end

  def draw(what = nil)
    what ||= @objects
    @height.times.to_a.reverse.each do |y|
      @width.times do |x|
        found_object = what.find{|o| o.x == x && o.y == y}
        print found_object.nil? ? (@annotations[x][y].nil? ? '.' : @annotations[x][y]) : found_object.type
      end
      print "\n"
    end
    print "\n"
  end

  def draw_seen_count
    @height.times.to_a.reverse.each do |y|
      @width.times do |x|
        print self[x][y].nil? ? ' . ' : "(#{self[x][y].seen_objects.count})"
      end
      print "\n"
    end
    print "\n"
  end

  def best_monitoring_location(object_type = SpaceObject::ASTROID)
    @objects.sort_by{|o| o.seen_objects(object_type).count }.last
  end

  def delete(space_object)
    @objects.delete(space_object)
  end
end

class Laser
  def initialize(space_map, based_on_astroid, options = {})
    @space_map, @based_on_astroid, @verbose, @animate = space_map, based_on_astroid, options[:verbose], options[:animate]
    @space_map.verbose = @verbose
  end

  #returns a list of destroyed astroids
  def fire
    round = 1
    deleted_per_round = {}
    deleted_in_order = []
    i = 1
    $stdout.flush if @animate
    loop do 
      puts "BEGIN ROUND #{round}" if @verbose
      deleted_per_round[round] = [] unless deleted_per_round.has_key?(round)
      self.astroids_by_theta.each do |theta, astroids|
        puts "Astroids for theta #{theta}: #{astroids.inspect}" if @verbose
        if closest_astroid = astroids.first
          @space_map.delete( closest_astroid )
          deleted_in_order << closest_astroid
          deleted_per_round[round] << closest_astroid

          @space_map.annotations[closest_astroid.x][closest_astroid.y] = i.to_s
          
          i += 1

          if @animate
            $stdout.flush
            @space_map.draw
            sleep(1)
          end
        end
      end
      break if self.astroids_by_theta.count == 0
      puts "Deleted #{deleted_per_round[round].count} astroids this round" if @verbose
      puts "*****At the end of the round: #{round}******" if @verbose
      @space_map.draw if @verbose && !@animate
      round += 1
    end
    deleted_in_order
  end

  def astroids_by_theta
    result = {}
    @space_map.astroids.reject{|a|a == @based_on_astroid}.each do |astroid|
      theta = astroid.theta_relative_to(@based_on_astroid.x, @based_on_astroid.y)
      result[theta] = [] unless result.has_key?(theta)
      result[theta] << astroid    
    end

    result = Hash[ result.sort_by { |key, val| key } ]  

    #final sorting within theta brackets... closest to laser first
    result.each do |theta, astroids|
      result[theta] = astroids.sort_by{|astroid| astroid.distance_to(@based_on_astroid.x, @based_on_astroid.y)}
    end    
    result
  end
end

raw_data = File.read('./data/day10.txt')

map = SpaceMap.new(raw_data, verbose: false, animate: false)
map.draw

best_monitoring_location = map.best_monitoring_location
puts "Best monitoring location in top-left coordinates: x=#{best_monitoring_location.lame_coordinates[:x]} y=#{best_monitoring_location.lame_coordinates[:y]} with #{best_monitoring_location.seen_objects(SpaceObject::ASTROID).count} astroids"

destroyed_astroids = Laser.new(map, best_monitoring_location).fire

winning_astroid = destroyed_astroids[199]
puts "The 200th astroid to be destroyed is: #{winning_astroid.lame_coordinates.inspect}, with a hash of: #{(winning_astroid.lame_coordinates[:x] * 100) + winning_astroid.lame_coordinates[:y]}"