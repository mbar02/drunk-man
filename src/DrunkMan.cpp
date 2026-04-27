#include <cstdint>
#include <iostream>
#include <fstream>
#include <cstdlib>
#include <sys/ioctl.h>
#include <cmath>

#define NS_PRIVATE_IMPLEMENTATION
#define CA_PRIVATE_IMPLEMENTATION
#define MTL_PRIVATE_IMPLEMENTATION

#include "./MetalDrunkMan.hpp"

#include "../libs/pcg/pcg_basic.h"
#include "../libs/errors.h"

int main(int argc, char** argv) {
  if(argc < 4) {
    std::cout << "Sintassi: " << argv[0] << " [steps per samples] [samples] [outputfile]\n";
    return TEINVAL;
  }
  uint32_t UPS,SAMPLES;

  UPS     = (uint32_t)std::stoul(argv[1]);
  SAMPLES = (uint32_t)std::stoul(argv[2]);

  // Check che SAMPLES sia multiplo di block_size
  uint32_t block_size = MSL_THS * SAMPLES_PER_COMMIT;
  if( SAMPLES % block_size )
    SAMPLES = SAMPLES + block_size - (SAMPLES % block_size);

  if( UPS % FTIFREQUENCY )
    UPS = UPS + FTIFREQUENCY - (UPS % FTIFREQUENCY);

  /*
  // Ottengo larghezza terminale
  struct winsize w;
  int retval_winsize = ioctl(STDOUT_FILENO, TIOCGWINSZ, &w) == -1;
  const uint32_t COLUMNS = (
      retval_winsize == -1 ? 80 : ( (uint32_t)w.ws_col > 80 ? 80 : w.ws_col )
  );
  */

  // Inizializza generatore di numeri casuali
  std::ifstream randomFile("/dev/random",std::ios::binary);
  uint64_t init_rng[2];
  randomFile.read((char*) init_rng, 2*sizeof(uint64_t));
  randomFile.close();

  pcg32_random_t rng;
  pcg32_srandom_r(&rng, init_rng[0], init_rng[1]);

  // Inizializza output file
  std::ofstream outputFile(argv[3]);

  // Inizializza GPU e oggetto
  MetalDrunkMan *mdm = new MetalDrunkMan(
    argv[0],
    &rng
  );

  // Esperimento
  outputFile << "[x], [y]" << std::endl;

  std::cout << "Inizio simulazione." << std::endl << std::flush;

  mdm->simulation(UPS, SAMPLES, outputFile);

  std::cout << "Simulazione terminata. " << std::endl;

  outputFile.flush();
  outputFile.close();

  delete mdm;

  return 0;
}
