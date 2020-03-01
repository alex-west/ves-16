# Dodge It (Videocart 16)
A disassembly of a game for the Fairchild Video Entertainment System.

Build Instructions
> dasm dodge_it.asm -f3 -ododge_it.bin

Current status of the project: ~95%

Every chunk of code has been deciphered and documented. Very few questions about the game's code remain, some of which may be unanswerable. What remains is some more documentation work and a little bit of clean-up -- of particular note is ves.h, which differs significantly from the standard ves.h file out there.

## Interesting Tidbits

There are four unused characters in the character set which are, in order, "F", "A", "S", and "T". There does not appear to be any place in the code where they could be displayed, though hacking the timer to $CDEF just before it's drawn would get it to be displayed.

When initializing the game, there is a table that is referenced and an index is calculated for it, but it is never read from. I suspect that this table was somehow related to enemy speed in an earlier revision of the game.

There is an unused function that flashes the screen. Given how it reads from the same register that the game over procedure uses to determine who died, I suspect it was used for game overs before the iconic multicolored spiral effect was written.

After the last line of code in the game, there is an unused byte (0xB2). I'm not sure what it means, but it does mirror the second byte of the game's header (0x2B). Coincidence?

## Technical Information

### Scratchpad Map

The F8 has a 64 byte "scratchpad" of registers that functions similarly to RAM. The processor has a register called the ISAR, or Indirect Scratchpad Address Register, that allows the scratchpad to be accessed arbitrarily.

There are several opcodes that can read and write what the ISAR is pointing to, and read and write the ISAR itself. Of note are the instructions LISU and LISL -- one loads the upper *octal* nybble of the ISAR, and the other loads the lower octal nybble. Given this fact, it is convenient to map out the scratchpad in an 8 by 8 grid, as shown below:

<table>
  <tr>
    <th></th>
    <th>0</th>
    <th>1</th>
    <th>2</th>
    <th>3</th>
    <th>4</th>
    <th>5</th>
    <th>6</th>
    <th>7</th>
  </tr>
  <tr>
    <td>0</td>
    <td colspan="8">Locals, arguments, and returns</td>
  </tr>
  <tr>
    <td>1</td>
    <td>Locals<br>(cont.)</td>
    <td>J (flag<br>storage)</td>
    <td>Game<br>Settings</td>
    <td>Current<br>Ball</td>
    <td colspan="2">K (call "stack")</td>
    <td colspan="2">Q (for jump table)</td>
  </tr>
  <tr>
    <td>2</td>
    <td colspan="8">xpos</td>
  </tr>
  <tr>
    <td>3</td>
    <td colspan="3">xpos (cont.)</td>
    <td colspan="5">ypos</td>
  </tr>
  <tr>
    <td>4</td>
    <td colspan="6">ypos (cont.)</td>
    <td colspan="2">speed</td>
  </tr>
  <tr>
    <td>5</td>
    <td colspan="4">speed (cont.)</td>
    <td colspan="2">P1 Hi Score</td>
    <td>Num<br>Balls</td>
    <td>Delay<br>Num</td>
  </tr>
  <tr>
    <td>6</td>
    <td>R Wall<br>(Enemy)</td>
    <td>R Wall<br>(Player)</td>
    <td>L Wall</td>
    <td>S Wall<br>(Enemy)</td>
    <td>S Wall<br>(Player)</td>
    <td>N Wall</td>
    <td colspan="2">Timer</td>
  </tr>
  <tr>
    <td>7</td>
    <td>temp 1</td>
    <td>temp 2</td>
    <td>Explosion<br>Flag</td>
    <td colspan="2">P2 Hi Score</td>
    <td>Game<br>Mode</td>
    <td colspan="2">RNG</td>
  </tr>
</table>

The registers "temp 1" and "temp 2" are used, depending on the context, to store the controller inputs, some arguments of doBall(), or a local variable for collision().

The registers used for local variables differ in their usage depending on the function. Most commonly r1 is used to hold an x position and r2 to hold a y position, but that is not always the case. Also, in some functions r9 is used as a local instead of for storing the processor flags.

### Calling Convention and Graph

The F8 processor does not have support for a hardware call stack to save return addresses when calling functions. Instead, it has a main program counter (PC0) and a secondary program counter (PC1). When calling a function using the opcode "PI", the return address is pushed from PC0 to PC1. When returning from a function using "POP", the return address is popped from PC1 back into PC0.

Fortunately, the F8 has the ability to save and write to the secondary program counter (PC1). Using "LR K,P" saves it to the "K register" (scratchpad registers 12 and 13), and using "LR P,K" does the opposite. Also, using "PK" allows us to jump to wherever the "K register" points.

The simplest calling convention the hardware permits allows us to go two layers deep, with each function being in a fixed layer of the call graph. This is the calling convention that Dodge It uses. With this knowledge, we can create a call graph of the game, like so:

![Call Graph of Dodge It](https://github.com/alex-west/ves-16/blob/master/call%20graph.png "Call Graph of Dodge It")

Here is an explanation of the terminology I made for the graph:
  - Top-Level Procedures - The procedures that make up the core of the game. They can be jumped between, and other functions can jump to them (though in that case they can't be returned from).
  - Mid-Level Functions - Functions called from the top level that can call a lower level function. These functions need to be bookended by "LR K,P" and "PK" in order to work.
  - Leaf Function - Called such because they form the leaves of the call tree, being called either from the top or mid level. Since they do not call any other functions, they can be exited with a simple "POP".

Note that more sophisticated calling conventions are possible. For instance, the BIOS provides functions to push and pull return addresses from a software stack on the scratchpad. However, given that the scratchpad is so small, this is not practical in many cases (such as with this game).