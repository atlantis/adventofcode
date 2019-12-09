class ImageLayer
	TRANSPARENT = 2
	BLACK = 0
	WHITE = 1

	def initialize(image, layer_data)
		@image = image
		@rows = layer_data.each_slice(@image.width).to_a
	end

  def count(digit)
  	@rows.map{|row| row.count(digit) }.inject(0){|sum,x| sum + x }
  end

  def inspect
  	"Layer#{@rows.inspect}"
  end

  def underlay(other_layer)
  	other_layer.each_with_index do |other_row, ri|
  		self[ri].each_with_index do |v, ci|
  			self[ri][ci] = other_row[ci] if v == TRANSPARENT
  		end
  	end
  end

  def opaque?
  	self.count(2) == 0
  end

  def print
  	s = ""
  	@rows.each do |row|
  		s << row.map{|v| v == BLACK ? ' ' : "X"}.join('') + "\n"
  	end
  	s
  end

  def [](key)
    @rows[key]
  end

  def []=(key, value)
    @rows[key] = value
  end

  def each
    @rows.each{|row| yield row }
  end

  def each_with_index
    @rows.each_with_index{|row, i| yield row, i }
  end
end

class Image
	attr_reader :layers, :width, :height

	def initialize(data, width, height)
		@width, @height = width, height
		parse_layers(data)
	end

	def inspect
		s = "Image width=#{@width} height=#{height}"
		@layers.each_with_index do |layer, i|
			s << "***********************\n"
			s << "Layer #{i}\n"
			s << layer.print + "\n"
		end
		s << "***********************\n"
		s << "Decoded:\n"
		s << decoded.print
		s
	end

	def decoded
		decoded_layer = @layers.first.clone
		
		@layers.each do |each_layer|
			decoded_layer.underlay(each_layer)
			break if decoded_layer.opaque?
		end

		decoded_layer
	end

	protected
		def parse_layers(data)
			chars_per_layer = @width * @height
			@layers = []
			
			data.chars.to_a.each_slice(chars_per_layer) do |layer_data|
				@layers << ImageLayer.new(self, layer_data.map{|v|v.to_i})
			end
		end
end

data = File.read('./data/day8.txt')
image = Image.new(data, 25, 6)

#part 1
layer_with_least_zeros = image.layers.sort_by{|layer| layer.count(0) }.first
puts "Checksum for layer with least zeros: #{layer_with_least_zeros.count(1) * layer_with_least_zeros.count(2)}"

#part 2
puts image.decoded.print