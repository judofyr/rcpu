# Libraries

All your programs are also libraries; executables are merely libraries
that includes a `main`-block. By using `library` you can include other
libraries.

In Ruby:

```ruby
# Use the built-in screen-library
library :screen

# Use a library called "foo.rcpu" in the same directory
library "foo.rcpu"
```

In Notch-style:

```dasm
; Use the built-in screen-library
library screen

; Use a library called "foo.dasm" in the same directory
library "foo.dasm"
```

RCPU ships with some built-in libraries:

## screen

`screen` maps 0x8000-0x8400 to a 32x16 terminal:

* 0x8000 is first row, first column
* 0x8001 is first row, second column
* ...
* 0x8020 is second row; first column


```ruby
# examples/hello.rcpu
library :screen

block :main do
  SET i, 0                             # Init loop counter, for clarity

  label :nextchar
  IFE [i+:string], 0                   # If the character is 0 ..
    SET pc, :end                       # .. jump to the end

  SET [i+0x8000], [i+:string]          # Video ram starts at 0x8000, copy char there
  ADD i, 1                             # Increase loop counter
  SET pc, :nextchar                    # Loop

  data :string, "Hello world!\0"       # Zero terminated string

  label :end
  SUB pc, 1                            # Freeze the CPU forever
end
```

### Colors

*Note: This may change in the future to match 0x10c more closely.*

Only the 7 (least-significent) bits describes the character. The rest
describes the color:

```
FFFF BBBB _CCC CCCC
```

* The first 4 bits describes the text color.
* The second 4 bits describes the background color.
* The 9th bit is ignored.
* The final 7 bits is the character (ASCII).

Each color follows this structure:

* The first bit in a color describes the brightness (1 = bright/bold; 0
  = normal).
* The second is red.
* The third is green.
* The fourth is blue.

Examples:

```
Black:         0000
White:         0111
Blue:          0001
Bright yellow: 1110
```

See also Notch's example script:

```ruby
# examples/hello2.rcpu
# Notch's second "hello word" program.
# http://i.imgur.com/XIXc4.jpg
# Supposed to show formatting.

library :screen

block :main do
  SET i, 0
  SET j, 0
  SET b, 0xf100

  label :nextchar
  SET a, [i+:data]
  IFE a, 0
    SET pc, :end
  IFG a, 0xff
    SET pc, :setcolor
  BOR a, b
  SET [j+0x8000], a
  ADD i, 1
  ADD j, 1
  SET pc, :nextchar

  label :setcolor
  SET b, a
  AND b, 0xff
  SHL b, 8
  IFG a, 0x1ff
    ADD b, 0x80
  ADD i, 1
  SET pc, :nextchar

  data :data, [0x170, "Hello ", 0x2E1, "world", 0x170, ", how are you?", 0]
  # Color format:
  # After processing:
  # 0x170 -> b = 0x7000 -> 0111 0000 0XXX XXXX = white(grey) on black
  # 0x2e1 -> b = 0xe180 -> 1110 0001 1XXX XXXX = yellow on blue
  #                        FORE BACK ? CHAR
  # Each color is: Brbg (where B = bold/brightness)

  label :end
  SUB pc, 1
end
```

## input

The `input` library defines two blocks which reads input: `read` and
`readline`. Both requires a memory-mapped extension (which takes 2 words).

```ruby
# examples/input.rcpu
library :screen
library :input
extension 0x9000, StringInput, "Hello world! overflow"
extension 0x9002, StdinInput

block :main do
  SET a, 12
  SET b, 0x9000
  SET c, 0x8000
  JSR :_read

  SET a, 10
  SET b, 0x9002
  SET c, 0x8020
  JSR :_readline

  SUB pc, 1
end
```

The first address mapped by an input extension is the *length* address.
Reading from this address returns the amount of buffered data that is
ready to be read. If this address returns 0, the input stream is closed.

The second address is the *data* address. Reading from this address reads
one character from the input stream.

Most of the time you don't need to worry about this, but rather use the
blocks that this library provides.

### read

<table>
  <tr>
    <th>A</th><td>Number characters allowed to read</td>
  </tr>
  <tr>
    <th>B</th><td>Input stream location</td>
  </tr>
  <tr>
    <th>C</th><td>Destination buffer</td>
  </tr>
</table>

```ruby
SET a, 10
SET b, 0x9000
SET c, 0x8000
JSR :_read
```

The code above will fetch characters from the memory-mapped input at
0x9000 and write them to 0x8000-0x800F until the input stream closes or
10 (`A`) characters has been read.

The number of characters sucessfully read will be substracted from `A`.

### readline

<table>
  <tr>
    <th>A</th><td>Number characters allowed to read</td>
  </tr>
  <tr>
    <th>B</th><td>Input stream location</td>
  </tr>
  <tr>
    <th>C</th><td>Destination buffer</td>
  </tr>
</table>

```ruby
SET a, 10
SET b, 0x9000
SET c, 0x8000
JSR :_readline
```

The code above will fetch characters from the memory-mapped input at
0x9000 and write them to 0x8000-0x800F until it reaches a newline (which
is then discarded), the stream closes or 10 (`A`) characters has been
read.

### StringInput

StringInput maps up a string as input:

```ruby
extension 0x9000, StringInput, "Hello world! overflow"
```

### StdinInput

StdinInput maps up STDIN as input:

```ruby
extension 0x9002, StdinInput
```
