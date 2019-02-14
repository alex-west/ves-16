seed = 0x0000

# This should be logically equivalent to the game's RNG
def rollRNG(seed):
	temp = (((seed * 2) << 8) + (seed & 0xFF00)) & 0xFF00 | ((seed*2) & 0x00FF)
	#temp = temp * 2
	temp = temp * 2
	temp = temp + seed
	temp = temp + 0x3619
	seed = temp & 0xFFFF
	return seed
	
for x in range(0, 100):
	seed = rollRNG(seed)
	print("{0:04X}".format(seed),end='\n')