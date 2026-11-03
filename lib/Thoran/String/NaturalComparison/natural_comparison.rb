# Thoran/String/NaturalComparison/natural_comparison.rb
# Thoran::String::NaturalComparison#natural_comparison

# 20261101
# 0.1.0

# Description: Compares two strings by the numbers in them rather than by their characters, so that 2 comes before 10.

# Changes:
# 1. + Thoran namespace.

module Thoran
  module String
    module NaturalComparison

      def natural_comparison(s, case_insensitive = nil)
        s1, s2 = (case_insensitive ? self.downcase : self), (case_insensitive ? s.downcase : s)
        m1, m2 = s1.match(/\d+/), s2.match(/\d+/)
        if m1.nil? || m2.nil? # then compare as per normal since one or more of the strings doesn't have numbers.
          s1 <=> s2
        elsif m1.pre_match == m2.pre_match # then compare the remainder of the string, since the pre_matches are the same.
          if m1[0] == m2[0]
            m1.post_match.natural_comparison(m2.post_match)
          else
            m1[0].to_i <=> m2[0].to_i
          end
        else # compare the pre_matches, since even though there are numbers the pre_matches are different anyway.
          m1.pre_match <=> m2.pre_match
        end
      end
      alias_method :natcmp, :natural_comparison

    end
  end
end

String.send(:include, Thoran::String::NaturalComparison)
