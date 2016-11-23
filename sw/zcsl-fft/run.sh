#!/bin/bash

make
vvp -m /root/zcsl/sw/pslse/afu_driver/src/libvpi.so /root/zcsl/sim/zcsl/zcsl_isim &
cd /root/zcsl/sw/pslse/pslse/
./pslse &
cd /root/zcsl/sw/zcsl-fft
./zcsl-fft-sim
