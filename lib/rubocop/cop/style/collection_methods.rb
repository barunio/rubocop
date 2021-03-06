# encoding: utf-8

module Rubocop
  module Cop
    module Style
      # This cop checks for uses of unidiomatic method names
      # from the Enumerable module.
      #
      # The current definition of the check is flawed and should be
      # enhanced by check for by blocks & procs as arguments of the
      # methods.
      class CollectionMethods < Cop
        MSG = 'Prefer `%s` over `%s`.'

        def on_block(node)
          method, _args, _body = *node

          check_method_node(method)
        end

        def on_send(node)
          _receiver, _method_name, *args = *node

          if args.size == 1 && args.first.type == :block_pass
            check_method_node(node)
          end
        end

        def autocorrect(node)
          @corrections << lambda do |corrector|
            corrector.replace(node.loc.selector,
                              preferred_method(node.loc.selector.source))
          end
        end

        private

        def check_method_node(node)
          _receiver, method_name, *_args = *node

          if preferred_methods[method_name]
            add_offense(
              node, :selector,
              format(MSG,
                     preferred_method(method_name),
                     method_name)
            )
          end
        end

        def preferred_method(method)
          preferred_methods[method.to_sym]
        end

        def preferred_methods
          @preferred_methods ||=
            begin
              # Make sure default configuration 'foo' => 'bar' is removed from
              # the total configuration if there is a 'bar' => 'foo' override.
              default = default_cop_config['PreferredMethods']
              merged = cop_config['PreferredMethods']
              overrides = merged.values - default.values
              merged.reject { |key, _| overrides.include?(key) }.symbolize_keys
            end
        end

        def default_cop_config
          ConfigLoader.default_configuration[cop_name]
        end
      end
    end
  end
end
