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
			print("Please enter a value: ")
			@computer[destination.raw] = $stdin.gets.to_i
		end

		def op_output(position)
			puts "Output: #{position.value}"
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
			result = (source1.value == source2.value ? 1 : 0)
			@computer[destination.raw] = result
			puts "op_equals writing #{result} to #{destination.raw}" if @computer.verbose
		end
end

class Computer
	EVENTS = [:END]

	attr_reader :stepthrough, :verbose
	attr_writer :instruction_pointer

	def initialize(data, options = nil)
		@instruction_pointer = 0
		@running = false
		@data = data.split(',').map(&:to_i)
		@stepthrough = options[:stepthrough]
		@verbose = options[:verbose]
		
		@event_handlers = {
			:END => [lambda{|computer| computer.stop }]
		}
	end

	def run
		@running = true
		while @running && instruction = self.next_instruction
			instruction.execute
			(print("Press enter to process the next instruction..."); $stdin.gets) if @stepthrough
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


data = "3,225,1,225,6,6,1100,1,238,225,104,0,1001,191,50,224,101,-64,224,224,4,224,1002,223,8,223,101,5,224,224,1,224,223,223,2,150,218,224,1001,224,-1537,224,4,224,102,8,223,223,1001,224,2,224,1,223,224,223,1002,154,5,224,101,-35,224,224,4,224,1002,223,8,223,1001,224,5,224,1,224,223,223,1102,76,17,225,1102,21,44,224,1001,224,-924,224,4,224,102,8,223,223,1001,224,4,224,1,224,223,223,101,37,161,224,101,-70,224,224,4,224,1002,223,8,223,101,6,224,224,1,223,224,223,102,46,157,224,1001,224,-1978,224,4,224,102,8,223,223,1001,224,5,224,1,224,223,223,1102,5,29,225,1101,10,7,225,1101,43,38,225,1102,33,46,225,1,80,188,224,1001,224,-73,224,4,224,102,8,223,223,101,4,224,224,1,224,223,223,1101,52,56,225,1101,14,22,225,1101,66,49,224,1001,224,-115,224,4,224,1002,223,8,223,1001,224,7,224,1,224,223,223,1101,25,53,225,4,223,99,0,0,0,677,0,0,0,0,0,0,0,0,0,0,0,1105,0,99999,1105,227,247,1105,1,99999,1005,227,99999,1005,0,256,1105,1,99999,1106,227,99999,1106,0,265,1105,1,99999,1006,0,99999,1006,227,274,1105,1,99999,1105,1,280,1105,1,99999,1,225,225,225,1101,294,0,0,105,1,0,1105,1,99999,1106,0,300,1105,1,99999,1,225,225,225,1101,314,0,0,106,0,0,1105,1,99999,108,226,226,224,1002,223,2,223,1005,224,329,101,1,223,223,108,677,677,224,1002,223,2,223,1006,224,344,1001,223,1,223,8,677,677,224,102,2,223,223,1006,224,359,101,1,223,223,7,226,677,224,102,2,223,223,1005,224,374,101,1,223,223,107,226,226,224,102,2,223,223,1006,224,389,101,1,223,223,7,677,226,224,1002,223,2,223,1006,224,404,1001,223,1,223,1107,677,226,224,1002,223,2,223,1006,224,419,1001,223,1,223,1007,226,226,224,102,2,223,223,1005,224,434,101,1,223,223,1008,226,677,224,102,2,223,223,1005,224,449,1001,223,1,223,1007,677,677,224,1002,223,2,223,1006,224,464,1001,223,1,223,1008,226,226,224,102,2,223,223,1006,224,479,101,1,223,223,1007,226,677,224,1002,223,2,223,1005,224,494,1001,223,1,223,108,226,677,224,1002,223,2,223,1006,224,509,101,1,223,223,8,226,677,224,102,2,223,223,1005,224,524,1001,223,1,223,107,677,677,224,1002,223,2,223,1005,224,539,101,1,223,223,107,226,677,224,1002,223,2,223,1006,224,554,101,1,223,223,1107,226,677,224,1002,223,2,223,1006,224,569,1001,223,1,223,1108,677,226,224,102,2,223,223,1005,224,584,1001,223,1,223,1008,677,677,224,102,2,223,223,1005,224,599,1001,223,1,223,1107,677,677,224,102,2,223,223,1006,224,614,101,1,223,223,7,226,226,224,102,2,223,223,1005,224,629,1001,223,1,223,1108,677,677,224,102,2,223,223,1006,224,644,1001,223,1,223,8,677,226,224,1002,223,2,223,1005,224,659,101,1,223,223,1108,226,677,224,102,2,223,223,1005,224,674,101,1,223,223,4,223,99,226"
Computer.new(data, stepthrough: ARGV.include?('-s'), verbose: ARGV.include?('-v')).run