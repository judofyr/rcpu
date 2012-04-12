require 'helper'

module RCPU
  class TestAssembler < TestCase
    def test_bytedata
      block do
        SET a, [:hello]
        SET [:hello], 123
        SET b, [:hello]
        SET pc, :crash

        data :hello, [12]
      end

      assert_equal 12, register(:A)
      assert_equal 123, register(:B)
    end

    def test_zerodata
      block do
        SET i, 1

        SET a, 1
        SET a, [:hello]

        SET b, 1
        SET b, [i+:hello]
        SET pc, :crash

        data :hello, 2
      end

      assert_equal 0, register(:A)
      assert_equal 0, register(:B)
    end

    def test_stringdata
      block do
        SET i, 1
        SET a, [:hello]
        SET b, [i+:hello]
        SET pc, :crash

        data :hello, "ab"
      end

      assert_equal "a".ord, register(:A)
      assert_equal "b".ord, register(:B)
    end

    def test_unknowndata
      assert_raises(AssemblerError, "unkown data type") do
        block do
          data :hello, :nope
        end
      end
    end

    def test_missing_label
      assert_raises(AssemblerError, "no label: fail") do
        block do
          SET pc, :fail
        end
      end
    end

    def test_multiple_blocks
      rcpu do
        block :main do
          JSR :_another
          label :crash
          SET pc, :crash
        end

        block :another do
          SET a, 1
          SET pc, pop
        end
      end

      assert_equal 1, register(:A)
    end

    def test_missing_block
      assert_raises(AssemblerError, "no external label: another") do
        block do
          JSR :_another
        end
      end
    end

    def test_data_label
      block do
        SUB pc, 1
        data :sp, [:stack]
        data :stack, 512
        data :sp2, [:stack]
      end

      assert_equal 0x2, memory[0x1]
      assert_equal 0x2, memory[0x1+512+0x1]
    end
  end
end
