require 'benchmark'

valid_range = 254032..789860

#Inefficient solution: ~4.4s... efficient solution ~0.011s

Benchmark.bm(20) do |bm|
	part_a_matches = 0
	part_b_matches = 0

	bm.report("Inefficient solution:\n") do 
		(254032..789860).each do |number|
			digits = number.to_s.split('').map(&:to_i)
			num_not_decending = 0
			adjacent = {}
			digits.each_with_index do |d, i| 
				num_not_decending += 1 if digits[i+1].nil? || digits[i+1] >= d
				if digits[i+1] == d
					adjacent[d] = 1 if adjacent[d].nil?	#starting at 1 cause we immediately go from 0 adjacent digits to 2 adjacent digits
					adjacent[d] += 1 
				end
			end
			if adjacent.size > 0 && num_not_decending == digits.count 
				part_a_matches += 1
				if adjacent.values.include?(2)
					part_b_matches += 1
				end
			end
		end
	end

	part_a_matches = 0
	part_b_matches = 0
	bm.report("Efficient solution:\n") do 
		#fast-forwards to the next number which meets the no-decending-digits criterion
		def fast_forward(digits)
			min = digits[0]
			digits.each_with_index do |d, i|
				min = d if d > min
				digits[i] = min if d < min
			end
			digits
		end

		def increment(digits)
			if digits[-1] != 9
				digits[-1] += 1
				digits
			else
				int_to_digits(digits_to_int(digits) + 1)
			end
		end

		def int_to_digits(i)
			i.to_s.split('').map(&:to_i)
		end

		def digits_to_int(digits)
			digits.join('').to_i
		end

		digits = int_to_digits(valid_range.begin)

		while digits_to_int(digits) <= valid_range.end
			num_not_decending = 0
			adjacent = {}
			digits.each_with_index do |d, i| 
				num_not_decending += 1 if digits[i+1].nil? || digits[i+1] >= d
				if digits[i+1] == d
					adjacent[d] = 1 if adjacent[d].nil?	#starting at 1 cause we immediately go from 0 adjacent digits to 2 adjacent digits
					adjacent[d] += 1 
				end
			end
			
			if adjacent.size > 0 && num_not_decending == digits.count 
				part_a_matches += 1
				if adjacent.values.include?(2)
					part_b_matches += 1
				end
			end

			digits = fast_forward(increment(digits))
		end
	end

	puts "Part A matches: #{part_a_matches}"
	puts "Part B matches: #{part_b_matches}"
end