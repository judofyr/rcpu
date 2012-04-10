$LOAD_PATH.unshift(File.expand_path("../../lib", __FILE__))

require 'minitest/autorun'
require 'rcpu'

module RCPU
  class TestCase < MiniTest::Unit::TestCase
    def rcpu(run = true, &blk)
      lib = Library.new
      lib.instance_eval(&blk)
      @linker = Linker.new
      @linker.compile_library(lib)
      @emu = Emulator.new(@linker.finalize)
      @emu.memory.add_extensions(@linker.extensions)
      @emu.run if run
    end

    def asm(str, run = true)
      lib = Library.new
      lib.parse(str)
      @asmlinker = Linker.new
      @asmlinker.compile_library(lib)
      @asmemu = Emulator.new(@asmlinker.finalize)
      @asmemu.memory.add_extensions(@asmlinker.extensions)
      @asmemu.run if run
    end

    def debug!
      Debugger.new(@emu, @linker).start
    end

    def memory
      @emu.memory
    end

    def register(name)
      @emu.registers[name]
    end

    def block(&blk)
      rcpu do
        block :main do
          instance_eval(&blk)

          label :crash
          SET pc, :crash
        end
      end
    end
  end
end

