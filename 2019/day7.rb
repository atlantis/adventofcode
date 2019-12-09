class Param
	attr_reader :raw, :mode

	def initialize(data, raw, mode)
		@data, @raw, @mode = data, raw, mode
	end

  def value
    @mode == :VALUE ? @raw : @data[@raw]
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

	protected
		def op_add(source1, source2, destination)
			@computer[destination.raw] = source1.value + source2.value
		end

		def op_mult(source1, source2, destination)
			@computer[destination.raw] = source1.value * source2.value
		end

		def op_input(destination)
      if @computer.inputs.count > 0
  			@computer[destination.raw] = @computer.inputs.shift
        @computer.waiting_for_input = false        
      elsif @computer.interactive
        print("Please enter a value: ")
        @computer[destination.raw] = $stdin.gets.to_i
        @computer.waiting_for_input = false
      else
        @computer.waiting_for_input = self
      end
		end

		def op_output(position)
      @computer.outputs << position.value
			puts "Output: #{position.value}" if @computer.interactive
		end

		def op_end
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
			@computer[destination.raw] = result
			puts "op_less_than writing #{result} to #{destination.raw}" if @computer.verbose
		end

		def op_equals(source1, source2, destination)
			result = source1.value == source2.value ? 1 : 0
			@computer[destination.raw] = result
			puts "op_equals writing #{result} to #{destination.raw}" if @computer.verbose
		end
end

class Computer
	EVENTS = [:END]

	attr_reader :stepthrough, :verbose, :running, :interactive
	attr_accessor :instruction_pointer, :inputs, :outputs, :waiting_for_input

	def initialize(data, options = {})
		@instruction_pointer = 0
		@running = false
		@data = data.split(',').map(&:to_i)
    @inputs = []
    @outputs = []
		@stepthrough = options[:stepthrough]
		@verbose = options[:verbose]
    @interactive = options[:interactive]
		@waiting_for_input = false
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

		raw_params = []
		params = []
		info = Instruction::OPCODES[opcode]
		param_modes = param_modes.reverse.ljust(info[:num_params], '0').split('').map{|v| v.to_i == 1 ? :VALUE : :POSITION}
		info[:num_params].times do |i|
			raw_param = self.next_data
			raw_params << raw_param
			params << Param.new(@data, raw_param, param_modes[i])
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
    @data[key]
  end

  def []=(key, value)
    @data[key] = value
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
		val = @data[@instruction_pointer]
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

def unique_permutations( range )
  range.to_a.permutation(range.count).to_a
end

code = File.read('./data/day7.txt')

max_output = 0
input_sets = unique_permutations(0..4)

input_sets.each do |input_set|
	o1 = Computer.new( code ).input(input_set[0]).input(0).run.output
  o2 = Computer.new( code ).input(input_set[1]).input(o1).run.output
	o3 = Computer.new( code ).input(input_set[2]).input(o2).run.output
	o4 = Computer.new( code ).input(input_set[3]).input(o3).run.output
	o5 = Computer.new( code ).input(input_set[4]).input(o4).run.output
	max_output = o5 if o5 > max_output
end

puts "Max output is #{max_output}"

num_amps = 5
max_output = 0
input_sets = unique_permutations(5..9)

last_amp_output = nil
input_sets.each do |input_set|
  amps = num_amps.times.map{|i| Computer.new( code ).input(input_set[i]).run }

  prev_amp_value = 0
  current_amp = 0
  loop do
    pr = prev_amp_value
    prev_amp_value = amps[current_amp].input(prev_amp_value).run.output
    if current_amp == num_amps - 1
      current_amp = 0
    else
      current_amp += 1
    end
    break unless amps.last.running
  end
  last_amp_output = amps.last.output
  max_output = last_amp_output if last_amp_output > max_output
end

puts "With feedback loop, max output is #{max_output}"