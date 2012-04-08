require 'helper'

module RCPU
  class TestABI < TestCase
    def test_call
      rcpu do
        block :main do
          call :_library, 1, 2, 3, 4, 5
          data :done, [123]
        end

        block :library do
          label :crash
          SET pc, :crash
        end
      end

      assert_equal 1, register(:A)
      assert_equal 2, register(:B)
      assert_equal 3, register(:C)
      assert_equal 4, memory[register(:S)-2]
      assert_equal 5, memory[register(:S)-1]
      assert_equal 123, memory[memory[register(:SP)]+1]
    end

    def test_fun
      rcpu do
        block :main do
          call :_library, 1, 2, 3, 4, 5
          SUB pc, 1
        end

        block :library do
          fun do |a1, a2, a3, a4, a5|
            # a1 == a
            SUB a, a2
            ADD a, a3
            SUB a, a4
            ADD a, a5
          end
        end
      end

      before = register(:SP)
      assert_equal (1-2+3-4+5), register(:A)
      assert_equal before, register(:SP)
    end

    def test_fun_locals
      rcpu do
        block :main do
          call :_library, 1, 2, 3, 4, 5
          SUB pc, 1
        end

        block :library do
          fun do |a1, a2, a3, a4, a5|
            locals do |l|
              ADD l, a1
              SUB l, a2
              ADD l, a3
              SUB l, a4
              ADD l, a5
              SET a, l
            end
          end
        end
      end

      before = register(:SP)
      assert_equal (1-2+3-4+5), register(:A)
      assert_equal before, register(:SP)
    end

    def test_fun_reg
      # Verify that it handles input stored in A, B and C.
      [1, 2, 3].permutation.each do |v1, v2, v3|
        rcpu do
          block :main do
            args = []
            args[v1] = a
            args[v2] = b
            args[v3] = c

            SET a, v1
            SET b, v2
            SET c, v3
            call :_library, args[1], args[2], args[3], 4, 5
            SUB pc, 1
          end

          block :library do
            fun do |a1, a2, a3, a4, a5|
              # a1 == a
              SUB a, a2
              ADD a, a3
              SUB a, a4
              ADD a, a5
            end
          end
        end

        assert_equal (1-2+3-4+5), register(:A)
      end
    end
  end
end

