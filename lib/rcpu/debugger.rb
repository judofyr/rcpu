module RCPU
  class Debugger
    def initialize(emulator, linker = Linker.new)
      @emulator = emulator
      @linker = linker
      @running = false
      @breakpoints = []
    end

    def pry?
      binding.respond_to?(:pry)
    end

    def help
      puts "(^C) stop execution"
      puts "(b) add breakpoint"
      puts "(d) dump state"
      puts "(e) evaluate ruby"
      puts "(h) help"
      puts "(p) ruby shell" if pry?
      puts "(r) run"
      puts "(s) step"
      puts "(q) quit"
    end

    def status_line
      pc, ins = @emulator.next_instruction
      name = @linker.symbols.key(pc)
      name &&= " (#{name})"
      "#{pc.to_s(16).rjust(4, '0')}#{name}: #{ins}"
    end

    def start
      trap(:INT) do
        @running = false
      end

      puts "Welcome to RCPU:"
      help

      while true
        begin
          puts status_line
          print "=> "
          @emulator.stop
          input = $stdin.gets
          return if input.nil?

          input.chomp!
          cmd = (input.slice!(0) || '').downcase
          input.strip!

          case cmd
          when "b"
            bp = @linker.symbols[input] || Integer(input)
            @breakpoints << bp
            puts "Added breakpoint #{@breakpoints.size} at 0x#{bp.to_s(16)}"
          when "d"
            @emulator.dump
          when "e"
            @emulator.start
            puts ">> #{@emulator.instance_eval(input)}"
          when "h"
            help
          when "p"
            @emulator.start
            @emulator.instance_eval { binding.pry }
          when "r"
            @running = true
            msg = ""
            @emulator.start

            while true
              pc, ins = @emulator.next_instruction
              if idx = @breakpoints.index(pc)
                msg = "Breakpoint #{idx + 1} reached"
                break
              end

              @emulator.tick

              # Ctrl-C
              unless @running
                msg = "Pausing"
                break
              end

              # Busy loop
              if pc == @emulator[:PC]
                msg = "Busy loop"
                break
              end

            end
            puts msg

          when "s", ""
            @emulator.start
            input = 1 if input.empty?
            Integer(input).times do
              @emulator.tick
            end
          when "q"
            exit
          else
            puts "Unknown command. Try 'h' for help."
          end
        rescue StandardError, SyntaxError
          puts "#{$!.class}: #{$!}"
        end
      end
    end
  end
end

