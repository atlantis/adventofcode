class Param
	attr_reader :raw, :mode
  MODES = {
    0 => :POSITION,
    1 => :VALUE,
    2 => :RELATIVE
  }
  
	def initialize(computer, raw, mode)
		@computer, @raw, @mode = computer, raw, mode
	end

  def value
    case @mode 
    when :VALUE 
      @raw
    when :POSITION
      @computer[@raw]
    when :RELATIVE
      @computer[@computer.relative_base + @raw]
    else
      raise "Invalid mode: #{@mode}"
    end
  end

  def write_address
    case @mode 
    when :POSITION
      @raw
    when :RELATIVE
      @computer.relative_base + @raw
    else
      raise "Invalid write_address mode: #{@mode}"
    end
  end

  def to_s
  	"Param{raw: #{@raw}, mode: #{@mode}, val: #{self.value}}"
  end
end

class Instruction
	OPCODES = {
		1 	=> {num_params: 3, function: :add},
		2 	=> {num_params: 3, function: :mult},
		3 	=> {num_params: 1, function: :input},
		4 	=> {num_params: 1, function: :output},
		5 	=> {num_params: 2, function: :jump_if_true},
		6 	=> {num_params: 2, function: :jump_if_false},
		7 	=> {num_params: 3, function: :less_than},
		8 	=> {num_params: 3, function: :equals},
    9   => {num_params: 1, function: :adjust_relative_base},
		99	=> {num_params: 0, function: :end},
	}

	attr_reader :opcode, :params, :param_modes

	def initialize(computer, opcode, params)
		@computer, @opcode, @params = computer, opcode, params
	end

	def execute
		puts "Executing #{self.to_s}" if @computer.verbose
		self.method("op_#{OPCODES[@opcode][:function]}").call(*params)
	end

	def to_s
		"Instruction: #{OPCODES[@opcode][:function]} params: #{params.join(',')}"
	end

  def inspect
    self.to_s
  end

	protected
		def op_add(source1, source2, destination)
      @computer[destination.write_address] = source1.value + source2.value
      puts "op_add wrote #{@computer[destination.write_address]} to #{destination.write_address}" if @computer.verbose  
		end

		def op_mult(source1, source2, destination)
			@computer[destination.write_address] = source1.value * source2.value
      puts "op_mult wrote #{@computer[destination.write_address]} to #{destination.write_address}" if @computer.verbose  
		end

		def op_input(destination)
      if @computer.inputs.count > 0
  			@computer[destination.write_address] = @computer.inputs.shift
        @computer.waiting_for_input = false
        puts "op_input wrote #{@computer[destination.write_address]} to #{destination.write_address}" if @computer.verbose  
      elsif @computer.interactive
        print("Please enter a value: ")
        @computer[destination.write_address] = $stdin.gets.to_i
        @computer.waiting_for_input = false
      else
        @computer.waiting_for_input = self
      end
		end

		def op_output(position)
      @computer.outputs << position.value
			puts "Output: #{position.value}" if (@computer.interactive || @computer.verbose)
		end

		def op_end
      puts "op_end triggering event END" if @computer.verbose  
			@computer.trigger_event(:END)
		end

		def op_jump_if_true(source1, destination)
			if source1.value != 0 
				@computer.instruction_pointer = destination.value
				puts "op_jump_if_true changing instruction pointer to  #{destination.value}" if @computer.verbose
			else
				puts "op_jump_if_true noop" if @computer.verbose
			end
		end

		def op_jump_if_false(source1, destination)
			if source1.value == 0 
				@computer.instruction_pointer = destination.value
				puts "op_jump_if_false changing instruction pointer to  #{destination.value}" if @computer.verbose
			else
				puts "op_jump_if_false noop" if @computer.verbose
			end
		end

		def op_less_than(source1, source2, destination)
			result = source1.value < source2.value ? 1 : 0
			@computer[destination.write_address] = result
			puts "op_less_than writing #{result} to #{destination.write_address}" if @computer.verbose
		end

		def op_equals(source1, source2, destination)
			result = source1.value == source2.value ? 1 : 0
			@computer[destination.write_address] = result
			puts "op_equals writing #{result} to #{destination.write_address}" if @computer.verbose
		end

    def op_adjust_relative_base(increment)
      @computer.relative_base += increment.value
      puts "op_adjust_relative_base adjusting relative base by #{increment.value}... new relative_base #{@computer.relative_base}" if @computer.verbose
    end
end

class Computer
	EVENTS = [:END]

	attr_reader :stepthrough, :verbose, :running, :interactive
	attr_accessor :instruction_pointer, :inputs, :outputs, :waiting_for_input, :relative_base

	def initialize(data, options = {})
		@instruction_pointer = 0
		@running = false
		@data = {}
    data.split(',').map(&:to_i).each_with_index{|v, i| @data[i] = v}
    @inputs = []
    @outputs = []
		@stepthrough = options[:stepthrough]
		@verbose = options[:verbose]
    @interactive = options[:interactive]
		@waiting_for_input = false
    @relative_base = 0
		@event_handlers = {
			:END => [lambda{|computer| computer.stop }]
		}
	end

	def run
		@running = true
    @waiting_for_input.execute if @waiting_for_input
    return self if @waiting_for_input

		while @running && instruction = self.next_instruction
			instruction.execute
			(print("Press enter to process the next instruction..."); $stdin.gets) if @stepthrough
      return self if @waiting_for_input
		end

		@running = false

		self
	end

	def next_instruction
		raw_opcode = self.next_data
		opcode, param_modes = self.parse_raw_opcode(raw_opcode)
    
		info = Instruction::OPCODES[opcode]
    raise "Invalid opcode: #{opcode}" unless info

    raw_params = []
    params = []

		param_modes = param_modes.reverse.ljust(info[:num_params], '0').split('').map{|v| Param::MODES[v.to_i] }
		info[:num_params].times do |i|
			raw_param = self.next_data
			raw_params << raw_param
			params << Param.new(self, raw_param, param_modes[i])
		end

		puts "Raw instruction data: opcode=#{raw_opcode} params=#{raw_params.join(',')} param_modes=#{param_modes.join(',')}" if @verbose

		Instruction.new(self, opcode, params)
	end

	def stop
		@running = false	
	end

  def input(val)
    @inputs << val.to_i
    self
  end

  def output
    @outputs.last
  end

	def [](key)
    @data.has_key?(key.to_i) ? @data[key.to_i] : 0
  end

  def []=(key, value)
    @data[key.to_i] = value
  end

	def add_handler(event, handler)
		if EVENTS.include?(event)
			@event_handlers[event] << handler 
		else
			raise "Invalid event: #{event.inspect}"
		end
	end

	def trigger_event(event)
		if @event_handlers[event]
			@event_handlers[event].each do |handler|
				handler.call(self)
			end
		end
	end

	def next_data
		val = @data.has_key?(@instruction_pointer) ? @data[@instruction_pointer] : 0
    @instruction_pointer += 1
		val
	end		

  protected
		def parse_raw_opcode(raw_opcode)
			if raw_opcode > 99
				digits = raw_opcode.to_s
				opcode = digits[-2..-1].to_i
				param_modes = digits[0...-2]
			else
				opcode = raw_opcode
				param_modes = ""
			end
			[opcode, param_modes]
		end
end

code = File.read('./data/day9.txt')
puts "Part 1) #{Computer.new( code).input(1).run.output}"
puts "Part 2) #{Computer.new( code).input(2).run.output}"