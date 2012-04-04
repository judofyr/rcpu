$LOAD_PATH.unshift(File.expand_path("../../lib", __FILE__))

require 'minitest/autorun'
require 'rcpu'
require 'rcpu/emulator'

module RCPU
  class TestEmulator < MiniTest::Unit::TestCase
    def rcpu(&blk)
      linker = Linker.new
      linker.instance_eval(&blk)
      @emu = Emulator.new(linker.finalize)
      @emu.run
    end

    def memory
      @emu.memory
    end

    def register(name)
      @emu.registers[name]
    end

    def block(&blk)
      rcpu do
        program :main do
          block :init do
            instance_eval(&blk)
            jump :crash
          end

          block :crash do
            jump :crash
          end
        end
      end
    end

    def test_set
      block do
        SET a, 0x30
        SET [0x2000], a

        SET b, 0x2001
        SET [b], 0x10
        jump :crash
      end

      assert_equal 0x30, memory[0x2000]
      assert_equal 0x10, memory[0x2001]
    end

    def test_add
      block do
        SET [0x1000], 0x5678    # low word
        SET [0x1001], 0x1234    # high word
        ADD [0x1000], 0xCCDD    # add low words, sets O to either 0 or 1 (in this case 1)
        ADD [0x1001], o         # add O to the high word
        ADD [0x1001], 0xAABB
        ADD [0x1001], o
        jump :crash
      end

      assert_equal 0x2355, memory[0x1000]
      assert_equal 0xBCF0, memory[0x1001]
    end

    def test_sub
      block  do
        SET [0x1000], 0x5678
        SUB [0x1000], 0xCCDD
        jump :crash
      end

      assert_equal 0x899B, memory[0x1000]
      assert_equal 0xFFFF, register(:O)
    end
  end
end

