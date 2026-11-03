# Thoran/Array/NaturalSort/natural_sort.rb
# Thoran::Array::NaturalSort#natural_sort

# 20261101
# 0.1.0

# Description: Sorts an array of strings by the numbers in them rather than by their characters, so that 2 comes before 10.

# Changes:
# 1. + Thoran namespace.

require_relative '../../String/NaturalComparison/natural_comparison'

module Thoran
  module Array
    module NaturalSort

      def natural_sort(case_insensitive = nil)
        sort{|s1, s2| s1.natural_comparison(s2, case_insensitive)}
      end
      alias_method :natsort, :natural_sort

    end
  end
end

Array.send(:include, Thoran::Array::NaturalSort)
