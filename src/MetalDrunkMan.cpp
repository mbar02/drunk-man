#include "./MetalDrunkMan.hpp"
#include <cstddef>
#include <cstdint>
#include <iostream>
#include <fstream>
#include <semaphore>
#include "../libs/errors.h"
#include "../libs/progressBar.h"

#define METAL_LIB_EXTENSION ".metallib"

inline int loadKernel(const char *name, MTL::Library* library, MTL::ComputePipelineState* &pipeline, MTL::Device* device, NS::Error** error) {
  auto nsname= NS::String::string(name, NS::ASCIIStringEncoding);
  MTL::Function *function = library->newFunction(nsname);
  if (function == nullptr)
  {
    std::cout << "Failed to find " << name << "." << std::endl;
    return TEINVAL;
  }
  pipeline = device->newComputePipelineState(function, error);
  if (pipeline == nullptr)
  {
    std::cout << "Failed to create " << name << " pipeline state object." << std::endl;
    return TEINVAL;
  }
  return 0;
}

MetalDrunkMan::MetalDrunkMan(
  const char     *exePath,
  pcg32_random_t *rng
) {

  // Get the device
  this->_device = MTL::CreateSystemDefaultDevice();
  NS::Error *error = nullptr;

  std::string libPath = std::string(exePath) + METAL_LIB_EXTENSION;

  // Load Metal library
  auto filepath = NS::String::string((const char*)libPath.c_str(), NS::ASCIIStringEncoding);
  MTL::Library *opLibrary = _device->newLibrary(filepath, &error);

  if(opLibrary == nullptr) {
    std::cerr << "Failed to find the default library. Error: "
              << error->description()->utf8String() << std::endl;
    return;
  }

  // Load Metal kernels
  assert(loadKernel("initialize", opLibrary, this->_initializePipeline, this->_device, &error) == 0);
  assert(loadKernel("simulation", opLibrary, this->_simulationPipeline, this->_device, &error) == 0);

  // Create a Command Queue
  this->_cmdQueue = this->_device->newCommandQueue();
  if (this->_cmdQueue == nullptr)
  {
      std::cerr << "Failed to find the command queue." << std::endl;
      return;
  }

  this->resultsF32 = new MTL::Buffer*[ 2 ];
  this->resultsI64 = new MTL::Buffer*[ 2 ];
  this->resultsF32CPU = new float*  [ 2 ];
  this->resultsI64CPU = new int64_t*[ 2 ];
  // Allocate needed buffers
  for(uint32_t i=0; i<2; i++) {
    this->resultsF32[i] = _device->newBuffer(
      MSL_THS*sizeof(float)*SAMPLES_PER_COMMIT*2,
      MTL::ResourceStorageModeShared
    );
    this->resultsF32CPU[i] = (float*)this->resultsF32[i]->contents();
    this->resultsI64[i] = _device->newBuffer(
      MSL_THS*sizeof(int64_t)*SAMPLES_PER_COMMIT*2,
      MTL::ResourceStorageModeShared
    );
    this->resultsI64CPU[i] = (int64_t*)this->resultsI64[i]->contents();
  }

  this->rng      = _device->newBuffer(
    (MSL_THGS * MSL_THSPTHG)*sizeof(pcg32_random_t),
    MTL::ResourceStorageModePrivate
  );
  
  // Init lattice
  MTL::CommandBuffer         *cmdBuff = this -> _cmdQueue -> commandBuffer();
  MTL::ComputeCommandEncoder *cptEnc  = cmdBuff -> computeCommandEncoder();

  // Create random
  MTL::Buffer* rndBuff = this->_device->newBuffer(
    MSL_THS*2*sizeof(uint64_t),
    MTL::ResourceStorageModeShared
  );
  uint64_t* rndBuff_CPU = (uint64_t*)rndBuff->contents();
  for(size_t i = 0; i < 2*MSL_THS; i++) {
    uint64_t random_number = 0;
    // Ensure 0x10 < random_number < 0xfffffffffffffff0
    while( random_number <= 0x10 || random_number >= 0xfffffffffffffff0 )
      random_number = ( (uint64_t)pcg32_random_r(rng) << 32 ) + pcg32_random_r(rng);
    rndBuff_CPU[i] = random_number;
  }

  // Load init parameters
  cptEnc -> setComputePipelineState(this->_initializePipeline);
  cptEnc -> setBuffer(this->rng, 0, 0);
  cptEnc -> setBuffer(rndBuff,   0, 1);

  // Prepare grid
  MTL::Size gridSize = MTL::Size::Make(MSL_THGS,1,1);
  MTL::Size thrGSize = MTL::Size::Make(MSL_THSPTHG,1,1);

  cptEnc -> dispatchThreadgroups(
    gridSize,
    thrGSize
  );

  // Commit to GPU
  cptEnc  -> endEncoding();
  cmdBuff -> commit();

  cmdBuff -> waitUntilCompleted();
  cptEnc  -> release();
  rndBuff -> release();
  cmdBuff -> release();
}

MetalDrunkMan::~MetalDrunkMan() {
  this->_initializePipeline->release();
  this->_simulationPipeline->release();
  for(uint32_t i=0; i<2; i++) {
    this->resultsF32[i]->release();
    this->resultsI64[i]->release();
  }
  delete[] this->resultsF32;
  delete[] this->resultsF32CPU;
  delete[] this->resultsI64;
  delete[] this->resultsI64CPU;
  this->rng->release();
  this->_cmdQueue->release();
  this->_device->release();
}

void MetalDrunkMan::simulation(
  uint32_t      UPS, // updates per sample
  uint32_t      SAMPLES,
  std::ofstream &ofile
) {
  const MTL::Size  thrGrpSize = MTL::Size::Make(MSL_THSPTHG, 1, 1);
  const MTL::Size  thrSize    = MTL::Size::Make(MSL_THGS,    1, 1);

  uint32_t leftSamples = SAMPLES;

  MTL::CommandBuffer* last_cmdBuff;

  asyncProgressBar* pb = new asyncProgressBar( ( SAMPLES + 1 )/(MSL_THS * SAMPLES_PER_COMMIT), 80);

  std::counting_semaphore<2> semaphore{2};
  size_t offset_for_semaphore = 0;

  while(leftSamples > 0) {
    semaphore.acquire();

    // Get CommandBuffer and ComputeCommandEncoder
    MTL::CommandBuffer* cmdBuff = this->_cmdQueue->commandBuffer();
    MTL::ComputeCommandEncoder* cptEnc = cmdBuff->computeCommandEncoder();

    leftSamples -= SAMPLES_PER_COMMIT * MSL_THS;

    cptEnc->setComputePipelineState(this->_simulationPipeline);
    cptEnc->setBuffer(this->rng,              0, 0);
    cptEnc->setBuffer(this->resultsI64[0],    0, 1);
    cptEnc->setBuffer(this->resultsF32[0],    0, 2);
    cptEnc->setBuffer(this->resultsI64[1],    0, 3);
    cptEnc->setBuffer(this->resultsF32[1],    0, 4);
    cptEnc->setBytes (&UPS, sizeof(uint32_t),    5);

    uint64_t common_offset = offset_for_semaphore * SAMPLES_PER_COMMIT * MSL_THS;

    for(uint32_t step = 0; step < SAMPLES_PER_COMMIT; step++) {
      // Do the simulation
      uint64_t offset = step * MSL_THS + common_offset;
      cptEnc->setBytes (&offset, sizeof(uint64_t), 6);
      cptEnc->dispatchThreadgroups( thrSize, thrGrpSize );
    }

    cptEnc->endEncoding();
    cptEnc->release();

    // Data handler + Commit to GPU
    cmdBuff->addCompletedHandler([this, &ofile, leftSamples, pb, &semaphore, common_offset](MTL::CommandBuffer* buffer) {
      for(uint32_t i=0; i<MSL_THS * SAMPLES_PER_COMMIT; i++) {
        long double x = (long double)resultsI64CPU[0][common_offset + i] + (long double)resultsF32CPU[0][common_offset + i];
        long double y = (long double)resultsI64CPU[1][common_offset + i] + (long double)resultsF32CPU[1][common_offset + i];
        ofile << x << ", " << y << std::endl;
      }
      semaphore.release();
      if( leftSamples > 0 )
        buffer->release();
      pb->update();
    });
    
    cmdBuff->commit();

    last_cmdBuff = cmdBuff;
    offset_for_semaphore = 1 - offset_for_semaphore;
  }

  last_cmdBuff->waitUntilCompleted();
  last_cmdBuff->release();
}