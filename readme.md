# Dodge It (Videocart 16)
A disassembly of a game for the Fairchild Video Entertainment System.

Build Instructions
> dasm dodge_it.asm -f3 -ododge_it.bin

Current status of the project: ~55%

Every chunk of code has been deciphered to one degree or another. What remains is various clean-up tasks: adding clear documentation, bringing the coding style up to par, answering some remaining unknowns (like what certain bitfields mean).

## Interesting Bits

There are four unused characters in the character set which are, in order, "F", "A", "S", and "T". There does not appear to be any place in the code where they could be displayed, though hacking the timer to $CDEF just before it's drawn would get it to be displayed.

When initializing the game, there is a table that is referenced and an index is calculated for it, but it is never read from. I have no idea what the table could have been for.

There is an unused function that flashes the screen. Given how it reads from the same register as that game over procedure uses to determine who died, I suspect it was used for game overs before the iconic multicolored spiral effect was written.

After the last line of code in the game, there is a random byte (0xB2). I have no idea what it could mean.

## Sundry Technical Notes

### Calling Convention

The F8 processor does not have support for a hardware call stack to save return addresses when calling functions. Instead, it has a main program counter (PC0) and a secondary program counter (PC1). When calling a function using the opcode "PI", the return address is pushed from PC0 to PC1. When returning from a function using "POP", the return address is popped from PC1 back into PC0.

Fortunately, the F8 has the ability to save and write to the secondary program counter (PC1). Using "LR K,P" saves it to the "K register" (really registers 12 and 13), and using "LR P,K" does the opposite. Also, using "PK" allows us to jump to wherever the "K register" points. Using these facts, we can have our function calls go two levels deep.

A Channel F programmer is faced with two options at this point:
  1) Create a subroutines that can push and pull from a software stack, thus either wasting several of the machine's 64 registers or necessitating on-cart RAM.
  2) Limit function calls to 2 levels deep.

Several games, including the built-in ones, go with the first approach (usually piggybacking off the routines from the built-in games). This game, in order to maximize is register space, goes with the second approach.

With this second approach, I thought it useful to make up some terminology to describe each function:
  - Top-Level Procedures - The procedures that make up the core of the game. They can be jumped between, and other functions can jump to them, but they cannot be returned from.
  - Mid-Level Functions - Functions called from the top level that can call a lower level function. These functions need to be bookended by "LR K,P" and "PK" in order to work.
  - Leaf Function - Called such because they form the leaves of the call tree, being called either from the top or mid level. Since they do not call any other functions, they can be exited with a simple "POP".