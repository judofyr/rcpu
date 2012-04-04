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
      end

      assert_equal 0x2355, memory[0x1000]
      assert_equal 0xBCF0, memory[0x1001]
    end

    def test_sub
      block  do
        SET [0x1000], 0x5678
        SUB [0x1000], 0xCCDD
      end

      assert_equal 0x899B, memory[0x1000]
      assert_equal 0xFFFF, register(:O)
    end

    def test_mul
      block do
        SET [0x1000], 0x5678
        MUL [0x1000], 0x3
      end

      assert_equal 0x0368, memory[0x1000]
      assert_equal 0x1, register(:O)
    end

    def test_div
      block do
        SET [0x1000], 15
        DIV [0x1000], 4
      end

      assert_equal 3, memory[0x1000]
      assert_equal 0xC000, register(:O)

      block do
        SET [0x1000], 15
        DIV [0x1000], 0
      end

      assert_equal 0, memory[0x1000]
      assert_equal 0, register(:O)
    end

    def test_mod
      block do
        SET [0x1000], 15
        MOD [0x1000], 4
      end

      assert_equal 3, memory[0x1000]

      block do
        SET [0x1000], 15
        MOD [0x1000], 0
      end

      assert_equal 0, memory[0x1000]
    end

    def test_shl
      block do
        SET [0x1000], 0xFFFF
        SHL [0x1000], 4
      end

      assert_equal 0xFFF0, memory[0x1000]
      assert_equal 0xF, register(:O)
    end

    def test_shr
      block do
        SET [0x1000], 0xFF
        SHR [0x1000], 4
      end

      assert_equal 0xF, memory[0x1000]
      assert_equal 0xF000, register(:O)
    end

    def test_and
      block do
        SET [0x1000], 5
        AND [0x1000], 4
      end

      assert_equal (5 & 4), memory[0x1000]
    end

    def test_bor
      block do
        SET [0x1000], 5
        BOR [0x1000], 4
      end

      assert_equal (5 | 4), memory[0x1000]
    end

    def test_xor
      block do
        SET [0x1000], 5
        XOR [0x1000], 4
      end

      assert_equal (5 ^ 4), memory[0x1000]
    end
  end
end

