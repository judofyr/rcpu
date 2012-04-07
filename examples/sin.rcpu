screen_width = 32
screen_height = 16
vram = 0x8000
maxint = 65535
library :screen
ch = '.'.ord

block :main do
  extend TrigMacros

  label :loop

  # Lookup y value from table, flip it upside-down, and scale it to the screen.
  SET y, maxint
  SUB y, [x+:sin_table]
  DIV y, (maxint/screen_height)

  # Draw to (x, y).
  SET z, y
  MUL z, screen_width
  ADD z, x
  SET [z+vram], ch

  ADD x, 1
  IFG screen_width, x
    SET pc, :loop

  infinite_loop

  label :sin_table
  sin_lookup_table screen_width
end
