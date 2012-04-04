RCPU
====

Assembler and emulator for [DCPU](http://0x10c.com/doc/dcpu-16.txt) written in Ruby:

```ruby
# Run this with: bin/rcpu examples/simple.rcpu

program :main do
  block :init do
    SET a, 2
    SET b, 2
    ADD a, b
  end

  block :crash do
    SET pc, :crash
  end
end
```

RCPU detects when the program runs in a busy loop (jumps to itself) and
quits the program. Because there's no I/O in DCPU at the moment, it
dumps the registers, the memory and the stack instead.

## Program

A program is a piece of executable code (like a function) that consists
of internal code blocks.

### Code blocks and labels

Each code block has a label which you can refer to in any expression.
Notice how you're *not* restricted to using labels only for jumping; it
behaves more like a constant.

```ruby
# examples/simple.rcpu
program :main do
  block :init do
    SET i, 1
    # Change the constant in the block below.
    SET [i + :example], 0x2000
  end

  block :example do
    # Even though we set A to 0x1000, the code above sets it to 0x2000.
    SET a, 0x1000
  end

  block :crash do
    SET pc, :crash
  end
end
```

### Data

Each program has a data section at the end:

```ruby
program :main do
  # 1 word, filled with zeros
  data :word, 1

  # 3 words, filled with [1, 2, 3]
  data :bytestring, [1, 2, 3]

  # 6 words, filld with "hello\0"
  data :string, "hello\0".bytes

  block :init do
    SET a, [:word]
    SET b, [:bytestring]
    SET c, [:string]
  end

  block :crash do
    SET pc, :crash
  end
end

```

### Programs and external labels

External labels starts with an underscore and refers to the first code
block to another program:

```ruby
# examples/plus1.rcpu
program :main do
  block :init do
    JSR :_plus1
    JSR :_plus1
    JSR :_plus1
  end

  block :crash do
    SET pc, :crash
  end
end

program :plus1 do
  block :init do
    ADD a, 1
    SET pc, pop
  end
end

```


