#pragma once

#define MSL_THGS       16
#define MSL_THSPTHG    64
#define MSL_THSPTHGSQR 8
#define MSL_THS        ( MSL_THSPTHG * MSL_THGS )

#define SAMPLES_PER_COMMIT 1
#define FTIFREQUENCY       1

#ifndef __METAL_VERSION__

#include <cstddef>
#include <cstdint>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wgnu-anonymous-struct"

#include <Foundation/Foundation.hpp>
#include <Metal/Metal.hpp>
#include <QuartzCore/QuartzCore.hpp>

#pragma clang diagnostic pop

#include "../libs/pcg/pcg_basic.h"

class MetalDrunkMan {
  public:
    MetalDrunkMan(
      const char*    exePath,
      pcg32_random_t *rng
    );
    ~MetalDrunkMan();

    void simulation(
      uint32_t      UPS, // updates per sample
      uint32_t      SAMPLES,
      std::ofstream &ofile
    );

  private:
    MTL::Device *_device;
    MTL::CommandQueue *_cmdQueue;
    MTL::ComputePipelineState *_initializePipeline;
    MTL::ComputePipelineState *_simulationPipeline;
    
    MTL::Buffer *rng;

    MTL::Buffer **resultsF32;
    float       **resultsF32CPU;
    MTL::Buffer **resultsI64;
    int64_t     **resultsI64CPU;
};

#endif