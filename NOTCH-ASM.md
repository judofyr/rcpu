# Notch assembler

## Syntax

What's a better example than Notch's code?

```dasm
; Assembler test for DCPU
; by Markus Persson
.library screen

             set i, 0                             ; Init loop counter, for clarity
:nextchar    ife [data+i], 0                      ; If the character is 0 ..
                 set PC, end                      ; .. jump to the end
             set [0x8000+i], [data+i]             ; Video ram starts at 0x8000, copy char there
             add i, 1                             ; Increase loop counter
             set PC, nextchar                     ; Loop
  
:data        dat "Hello world!", 0                ; Zero terminated string

:end         sub PC, 1                            ; Freeze the CPU forever
```

## Extensions

RCPU supports a few extensions to make your life easier.

### Blocks

Everything in RCPU is based around block; if you don't define a block in
assembly, you're actually working in the `main` block. The example above
could be written like this and the binary would be 100% the same:

```dasm
; Assembler test for DCPU
; by Markus Persson
.library screen

.block main

             set i, 0                             ; Init loop counter, for clarity
:nextchar    ife [data+i], 0                      ; If the character is 0 ..
                 set PC, end                      ; .. jump to the end
; ...
```

Blocks have three useful features:

* All labels within a block is local within that block. It will never
  clash with any labels in other blocks.

* You can refer to code in libraries in a position-independent way. RCPU
  will automatically place the blocks next to each other and resolve all
  labels for you.

* RCPU will not include blocks that aren't used anywhere. This means you
  can write a library full of different blocks (functions), and the
  program will only include the blocks it's actually using.

Let's write a program with two blocks:

```dasm
.block main
  JSR _plus1
  JSR _plus1
  JSR _plus1

  :crash SET PC, crash

.block plus1
  ADD A, 1
  SET PC, POP
```

To refer to a block, you simply prepend the name with an underscore.

### Libraries

Every file in RCPU is also a library. A program is just a library that
happens to have a `main` block:

```dasm
; examples/using_plus1.dasm

.library "plus1.dasm"
JSR _plus1
:crash SET PC, crash
```

Although plus1.dasm has a `main` block too, the `main` block in
using_plus1.dasm takes precedence over plus1's.

#### Standard Libraries

See [LIBRARIES.md](https://github.com/judofyr/rcpu/blob/master/LIBRARIES.md)
for a list of available library that ships with RCPU.

All standard libraries are included without quotes:

```dasm
; Setup the screen
.library screen
```

