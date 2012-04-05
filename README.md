RCPU
====

Assembler and emulator for [DCPU](http://0x10c.com/doc/dcpu-16.txt) written in Ruby:

```ruby
# Open it in the debugger: bin/rcpu examples/simple.rcpu

block :main do
  SET a, 2
  SET b, 2
  ADD a, b

  label :crash
  SET pc, :crash
end

```

Then you can step through it (or run it).

## Block

A program is a piece of executable code (like a lightweight function)
that has internal labels.

### Labels

Each code block has a label which you can refer to in any expression.
Notice how you're *not* restricted to using labels only for jumping; it
behaves more like a constant:

```ruby
# examples/modify.rcpu
block :main do
  SET i, 1
  # Change the constant in the block below.
  SET [i + :example], 0x2000

  label :example
  # Even though we set A to 0x1000, the code above sets it to 0x2000.
  SET a, 0x1000
  
  label :crash
  SET pc, :crash
end

```

### Data

You can use `data` to insert raw data with a label.

```ruby
# examples/data.rcpu
block :main do
  SET a, [:word]
  SET b, [:bytestring]
  SET c, [:string]

  label :crash
  SET pc, :crash

  # 1 word, filled with zeros
  data :word, 1

  # 3 words, filled with [1, 2, 3]
  data :bytestring, [1, 2, 3]

  # 6 words, filld with "hello\0"
  data :string, "hello\0"
end

```

### External labels

External labels starts with an underscore and refers to another code
block:

```ruby
# examples/plus1.rcpu
block :main do
  JSR :_plus1
  JSR :_plus1
  JSR :_plus1

  label :crash
  SET pc, :crash
end

block :plus1 do
  ADD a, 1
  SET pc, pop
end
```


