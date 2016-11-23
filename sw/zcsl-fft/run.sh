#!/bin/bash

make
vvp -m /root/zcsl/sw/pslse/afu_driver/src/libvpi.so /root/zcsl/sim/zcsl/zcsl_isim &
sleep 7
cd /root/zcsl/sw/pslse/pslse/
./pslse &
sleep 3
cd /root/zcsl/sw/zcsl-fft
./zcsl-fft-sim
killall vvp pslse
