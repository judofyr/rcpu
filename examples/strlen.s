; by Tobba
SET A, 0x0000
JSR strlen
SUB PC, 1
  
:strlen
  SET B, SP
  SET SP, A
  :loop
    IFE [SP++], 0
    SET PC, end
    
    IFE [SP++], 0
    SET PC, end
    
    IFE [SP++], 0
    SET PC, end
    
    IFE [SP++], 0
    SET PC, end
    
    SET PC, loop
  :end
    SET C, PUSH ; Decrease SP one
    SUB SP, A
    SET A, SP
    SET SP, B
    SET PC, POP
