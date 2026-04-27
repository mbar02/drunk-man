CC=gcc
CXX=clang++
CFLAGS=-O3 -Wall -Wextra -Werror -pedantic -Wconversion -std=c99
CXXFLAGS=-O3 -Wno-gnu-statement-expression -Wall -Wextra -Werror -pedantic -Wconversion -std=gnu++20 -I../libs/metal-cpp
FRAMEWORKS=-framework Metal -framework Foundation -framework MetalKit

binaries=drunkMan

all: $(binaries)

pcg32.o:         ../libs/pcg/pcg_basic.c ../libs/pcg/pcg_basic.h
	$(CC) $(CFLAGS) -c ../libs/pcg/pcg_basic.c -o $@

progressBar.o:   ../libs/progressBar.cpp ../libs/progressBar.h
	$(CXX) $(CXXFLAGS) -c ../libs/progressBar.cpp -o $@ 

DrunkMan.metallib:    ../src/MetalDrunkMan.metal
	xcrun -sdk macosx metal -D LATTICE=1 -c ../src/MetalDrunkMan.metal -o MetalDrunkManLibrary.air
	xcrun -sdk macosx metallib MetalDrunkManLibrary.air -o $@

MetalDrunkMan.o:     ../src/MetalDrunkMan.cpp ../src/MetalDrunkMan.hpp ../libs/progressBar.h
	$(CXX) $(CXXFLAGS) -D LATTICE=1 -c ../src/MetalDrunkMan.cpp -o $@

drunkMan:    ../src/DrunkMan.cpp pcg32.o ../libs/pcg/pcg_basic.h ../libs/progressBar.h DrunkMan.metallib  ../libs/progressBar.h progressBar.o MetalDrunkMan.o
	$(CXX) $(CXXFLAGS) $(FRAMEWORKS) -D LATTICE=1 ../src/DrunkMan.cpp progressBar.o MetalDrunkMan.o pcg32.o -o $@ -lm

.PHONY: clean
clean:
	rm -f $(binaries) *.o *.air *.metallib

cleanobj:
	rm -f *.o *.air
