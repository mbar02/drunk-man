#include <metal_stdlib>
#include <metal_atomic>

#include "../libs/pcg/pcg_basic.c"
#include "./MetalDrunkMan.hpp"

using namespace metal;

kernel void initialize(
  device       pcg32_random_t *rng     [[buffer(0)]],
  device const uint64_t       *random  [[buffer(1)]],
  uint         index          [[thread_position_in_grid]]
) {
  pcg32_random_t local_rng = rng[index];
  pcg32_srandom_r( &local_rng, random[2*index], random[2*index+1] );
  rng[index] = local_rng;
}

kernel void simulation(
  device       pcg32_random_t *rng        [[buffer(0)]],
  device       int64_t        *xI64r      [[buffer(1)]],
  device       float          *xF32r      [[buffer(2)]],
  device       int64_t        *yI64r      [[buffer(3)]],
  device       float          *yF32r      [[buffer(4)]],
  device const uint32_t       &UPS        [[buffer(5)]],
  device const uint64_t       &offset     [[buffer(6)]],
  uint index   [[thread_position_in_grid]]
) {
  pcg32_random_t local_rng = rng[index];

  int64_t xI64 = 0;
  int64_t yI64 = 0;
  float   xF32 = 0.0f;
  float   yF32 = 0.0f;

  float   deltax;
  float   deltay;

  float deltaxI64;
  float deltayI64;

  float random;

  for(uint32_t i = 0; i < UPS; i+=FTIFREQUENCY) {
    for(uint32_t j = 0; j < FTIFREQUENCY; j++) {
      random = pcg32_random_r( &local_rng ) / 4294967296.0f;
      deltay = sincos(random * 2.0f * M_PI_F, deltax);

      xF32 += deltax;
      yF32 += deltay;
    }
    xF32 = modf(xF32, deltaxI64);
    yF32 = modf(yF32, deltayI64);

    xI64 += (int64_t)deltaxI64;
    yI64 += (int64_t)deltayI64;
  }

  xI64r[offset + index] = xI64;
  xF32r[offset + index] = xF32;
  yI64r[offset + index] = yI64;
  yF32r[offset + index] = yF32;

  rng[index] = local_rng;

  return;
}
