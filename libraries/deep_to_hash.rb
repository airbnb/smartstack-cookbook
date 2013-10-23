class Chef
  class Node
   class ImmutableMash
      def deep_to_hash
        h = {}
        self.each do |k,v|
          if v.respond_to?('deep_to_hash')
            h[k] = v.deep_to_hash
          elsif v.respond_to?('deep_to_a')
            h[k] = v.deep_to_a
          else
            h[k] = v
          end
        end
        return h
      end
    end

    class ImmutableArray
      def deep_to_a
        a = []
        self.each do |v|
          if v.respond_to?('deep_to_hash')
            a << v.deep_to_hash
          elsif v.respond_to?('deep_to_a')
            a << v.deep_to_a
          else
            a << v
          end
        end
        return a
      end
    end
  end
end

