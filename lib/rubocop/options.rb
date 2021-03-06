# encoding: utf-8

require 'optparse'

module Rubocop
  # This class handles command line options.
  class Options
    DEFAULT_FORMATTER = 'progress'
    EXITING_OPTIONS = [:version, :verbose_version, :show_cops]

    def initialize
      @options = {}
    end

    def parse(args)
      ignore_dropped_options(args)
      convert_deprecated_options(args)

      OptionParser.new do |opts|
        opts.banner = 'Usage: rubocop [options] [file1, file2, ...]'

        option(opts, '--only [COP1,COP2,...]',
               'Run only the given cop(s).') do |list|
          @options[:only] = list.split(',')
          validate_only_option
        end

        add_configuration_options(opts, args)
        add_formatting_options(opts)

        option(opts, '-r', '--require FILE', 'Require Ruby file.') do |f|
          require f
        end

        add_severity_option(opts)
        add_flags_with_optional_args(opts)
        add_boolean_flags(opts)
      end.parse!(args)

      if (incompat = @options.keys & EXITING_OPTIONS).size > 1
        fail ArgumentError, "Incompatible cli options: #{incompat.inspect}"
      end

      [@options, args]
    end

    private

    def add_configuration_options(opts, args)
      option(opts, '-c', '--config FILE', 'Specify configuration file.')

      option(opts, '--auto-gen-config',
             'Generate a configuration file acting as a', 'TODO list.') do
        validate_auto_gen_config_option(args)
        @options[:formatters] = [[DEFAULT_FORMATTER],
                                 [Formatter::DisabledConfigFormatter,
                                  ConfigLoader::AUTO_GENERATED_FILE]]
      end

      option(opts, '--force-exclusion',
             'Force excluding files specified in the',
             'configuration `Exclude` even if they are',
             'explicitly passed as arguments.')
    end

    FORMAT_HELP = ['Choose an output formatter. This option',
                   'can be specified multiple times to enable',
                   'multiple formatters at the same time.',
                   '  [p]rogress (default)',
                   '  [s]imple',
                   '  [c]lang',
                   '  [d]isabled cops via inline comments',
                   '  [fu]ubar',
                   '  [e]macs',
                   '  [j]son',
                   '  [fi]les',
                   '  [o]ffenses',
                   '  custom formatter class name']

    def add_formatting_options(opts)
      option(opts, '-f', '--format FORMATTER', *FORMAT_HELP) do |key|
        @options[:formatters] ||= []
        @options[:formatters] << [key]
      end

      option(opts, '-o', '--out FILE',
             'Write output to a file instead of STDOUT.',
             'This option applies to the previously',
             'specified --format, or the default format',
             'if no format is specified.') do |path|
        @options[:formatters] ||= [[DEFAULT_FORMATTER]]
        @options[:formatters].last << path
      end
    end

    def add_severity_option(opts)
      opts.on('--fail-level SEVERITY',
              Rubocop::Cop::Severity::NAMES,
              Rubocop::Cop::Severity::CODE_TABLE,
              'Minimum severity for exit with error code.') do |severity|
                @options[:fail_level] = severity
              end
    end

    def add_flags_with_optional_args(opts)
      option(opts, '--show-cops [COP1,COP2,...]',
             'Shows the given cops, or all cops by',
             'default, and their configurations for the',
             'current directory.') do |list|
        @options[:show_cops] = list.nil? ? [] : list.split(',')
      end
    end

    def add_boolean_flags(opts)
      option(opts, '-d', '--debug', 'Display debug info.')
      option(opts,
             '-D', '--display-cop-names',
             'Display cop names in offense messages.')
      option(opts, '-R', '--rails', 'Run extra Rails cops.')
      option(opts, '-l', '--lint', 'Run only lint cops.')
      option(opts, '-a', '--auto-correct', 'Auto-correct offenses.')

      @options[:color] = true
      opts.on('-n', '--no-color', 'Disable color output.') do
        @options[:color] = false
      end

      option(opts, '-v', '--version', 'Display version.')
      option(opts, '-V', '--verbose-version', 'Display verbose version.')
    end

    # Sets a value in the @options hash, based on the given long option and its
    # value, in addition to calling the block if a block is given.
    def option(opts, *args)
      opts.on(*args) do |arg|
        @options[long_opt_symbol(args)] = arg
        yield arg if block_given?
      end
    end

    # Finds the option in `args` starting with -- and converts it to a symbol,
    # e.g. [..., '--auto-correct', ...] to :auto_correct.
    def long_opt_symbol(args)
      long_opt = args.find { |arg| arg.start_with?('--') }
      long_opt[2..-1].sub(/ .*/, '').gsub(/-/, '_').to_sym
    end

    def ignore_dropped_options(args)
      # Currently we don't make -s/--silent option raise error
      # since those are mostly used by external tools.
      rejected = args.reject! { |a| %w(-s --silent).include?(a) }
      if rejected
        warn '-s/--silent options is dropped. ' \
             '`emacs` and `files` formatters no longer display summary.'
      end
    end

    def convert_deprecated_options(args)
      args.map! do |arg|
        case arg
        when '-e', '--emacs'
          deprecate("#{arg} option", '--format emacs', '1.0.0')
          %w(--format emacs)
        else
          arg
        end
      end.flatten!
    end

    def deprecate(subject, alternative = nil, version = nil)
      message =  "#{subject} is deprecated"
      message << " and will be removed in RuboCop #{version}" if version
      message << '.'
      message << " Please use #{alternative} instead." if alternative
      warn message
    end

    def validate_only_option
      @options[:only].each do |cop_to_run|
        if Cop::Cop.all.none? { |c| c.cop_name == cop_to_run }
          fail ArgumentError, "Unrecognized cop name: #{cop_to_run}."
        end
      end
    end

    def validate_auto_gen_config_option(args)
      if args.any?
        warn '--auto-gen-config can not be combined with any other arguments.'
        exit(1)
      end
    end
  end
end
