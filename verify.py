import filecmp
import sys

if __name__ == "__main__":
	same = filecmp.cmp(sys.argv[1], sys.argv[2])
	print(sys.argv[1] + " and " + sys.argv[2] + " are ", end="")
	if same == True:
		print("identical.", end="\n")
	else:
		print("different.", end="\n\n")