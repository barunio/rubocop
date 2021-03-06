# encoding: utf-8

module Rubocop
  module Cop
    module Lint
      # Checks for space between a method name and the first argument for
      # method calls without parentheses.
      #
      # @example
      #
      #   something?x
      #   something!x
      #
      class SpaceBeforeFirstArg < Cop
        MSG = 'Put space between the method name and the first argument.'

        def on_send(node)
          return if parentheses?(node)

          _receiver, method_name, *args = *node
          return if args.empty?
          return if operator?(method_name)
          return if method_name.to_s.end_with?('=')

          # Setter calls with parentheses are parsed this way. The parentheses
          # belong to the argument, not the send node.
          return if args.first.type == :begin

          arg1 = args.first.loc.expression
          arg1_with_space = range_with_surrounding_space(arg1, :left)

          add_offense(nil, arg1) if arg1_with_space.source =~ /\A\S/
        end
      end
    end
  end
end
