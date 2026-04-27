# DrunkMan: An Application of the Central Limit Theorem with the Monte Carlo method
A numerical simulation of the 2D Random Walk using the Monte Carlo method.

---

## **Description**
This project simulates the statistical properties of a 2D random walk, leveraging the **Central Limit Theorem** to demonstrate convergence to a Gaussian distribution. The simulation is implemented in C++ and accelerated using Apple's Metal API via the [metal-cpp](https://developer.apple.com/metal/cpp/) library, which allows for high-performance GPU computation. [PCG32](https://www.pcg-random.org/), a high-quality pseudo-random number generator, has been used.

---

## **Dir tree**
```
.
├── build/                  # Executables and Makefile directory
│   └── Makefile            # Build automation
├── LICENSE                 # The license
├── Makefile                # Build automation
├── README.md               # This file
├── libs/                   # External libraries
│   ├── pcg/                # PCG32 RNG implementation
│   ├── metal-cpp/          # Metal API for C++
│   ├── errors.h            # Some custom error codes
│   ├── progressBar.cpp     # Simulation progress bar (source code
│   └── progressBar.h       # Simulation progress bar (header)
├── report/                 # The report source that summarises this work
│   └── ...
├── report.pdf              # The report that summarises this work
├── simulation.jl           # Julia script for analysis/visualization
└── src/                    # Source code
    ├── DrunkMan.cpp        # Simulation launcher
    └── MetalDrunkMan.*     # Metal-accelerated simulation
```

---

## **Dependencies**
- **C++20**
- **Metal API** (macOS only)
- **PCG32 RNG** (included in `libs/pcg/`)
- **metal-cpp** (included in `libs/metal-cpp/`)

> **Note**: This project is designed for macOS with a GPU that supports Metal.

# 📄 **License**

This project is open-source and licensed under the [MIT License](LICENSE).

---

```
**Authors**: Martino Barbieri, Matteo Leonardi 
**Last Updated**: April 2026  
```
