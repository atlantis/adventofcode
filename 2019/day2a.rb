data = "1,0,0,3,1,1,2,3,1,3,4,3,1,5,0,3,2,10,1,19,1,6,19,23,1,23,13,27,2,6,27,31,1,5,31,35,2,10,35,39,1,6,39,43,1,13,43,47,2,47,6,51,1,51,5,55,1,55,6,59,2,59,10,63,1,63,6,67,2,67,10,71,1,71,9,75,2,75,10,79,1,79,5,83,2,10,83,87,1,87,6,91,2,9,91,95,1,95,5,99,1,5,99,103,1,103,10,107,1,9,107,111,1,6,111,115,1,115,5,119,1,10,119,123,2,6,123,127,2,127,6,131,1,131,2,135,1,10,135,0,99,2,0,14,0".split(',').map(&:to_i)

data[1] = 12
data[2] = 2

data.each_slice(4) do |opcode, source1, source2, destination|
	case opcode
	when 1
		data[destination] = data[source1] + data[source2]
	when 2
		data[destination] = data[source1] * data[source2]
	when 99
		puts "Value at position #0: #{data[0]}"
		break
	else
		raise "Invalid opcode: #{opcode}"
	end
end