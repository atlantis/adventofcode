Node = Struct.new(:value, :parent_name, :parent, :children) do
  def ancestors
    nodes = []
    current_node = self
    while current_parent = current_node.parent
      nodes << current_parent
      current_node = current_parent      
    end
    nodes
  end

  def is_leaf
    children.count == 0
  end

  def inspect
    "Node{name: #{value}, parent:#{parent_name} children: #{children.map{|c|c.value}}"
  end

  def <=>(other)
    value <=> other.value
  end
end

class OrbitMap
	attr_reader :nodes
  attr_reader :root

	def initialize(data)
		pairs = Hash.new
		data.split("\n").map(&:strip).compact.each do |raw_orbit|
			orbitee, orbiter = raw_orbit.split(')')
			pairs[orbiter] = orbitee
		end

		@nodes = []
    hang_pairs_on_tree(pairs)
	end

	def count_direct_orbits
    @nodes.map{|node|node.ancestors.count}.inject(0){|sum,x| sum + x }
	end

  def find(node_name)
    @nodes.find{|node|node.value == node_name}
  end

  def path(src, dest)
    src_ancestors = src.ancestors
    dest_ancestors = dest.ancestors
    common_ancestor = src.ancestors.find{|src_ancestor| dest_ancestors.include?(src_ancestor)}
    raise "No common ancestor" unless common_ancestor

    src_path_to_common = src_ancestors.slice(0, src_ancestors.find_index(common_ancestor))
    dest_path_to_common = dest_ancestors.slice(0, dest_ancestors.find_index(common_ancestor))

    src_path_to_common + [common_ancestor] + dest_path_to_common.reverse + [dest]
  end

	protected
		def hang_pairs_on_tree(pairs)
			orbiters = pairs.keys
			orbitees = pairs.values
			root = orbitees.reject{|orbitee| orbiters.include?(orbitee)}
			raise "No root element found!" unless root && root.count == 1
			@root = Node.new(root.first, nil, nil, [])
      @nodes << @root

			pairs.each do |orbiter, orbitee|
				@nodes << Node.new(orbiter, orbitee, nil, [])
			end

      @nodes.each do |node|
        unless node == @root
          parent = @nodes.find{|possible_parent| possible_parent.value == node.parent_name}
          raise "No parent found for #{node.inspect}!" unless parent
          parent.children << node
          node.parent = parent
        end
      end		
		end
end

raw_data = File.read('./data/day6.txt')

map = OrbitMap.new(raw_data)
puts "Number of direct orbits: #{map.count_direct_orbits}"

your_planet = map.find('YOU').parent
santa_planet = map.find('SAN').parent

puts "Transfers to get to santa: #{map.path(your_planet, santa_planet).count}"