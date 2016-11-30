#!/bin/bash

cd ../../sim/zcsl
iverilog -o zcsl_isim ../../sw/pslse/afu_driver/verilog/top.v ../../hdl/zcsl/*.v ../../hdl/3rd_party/spiral-dft.v
cd -
make
vvp -m /root/zcsl/sw/pslse/afu_driver/src/libvpi.so /root/zcsl/sim/zcsl/zcsl_isim &
sleep 7
cd /root/zcsl/sw/pslse/pslse/
./pslse &
sleep 3
cd /root/zcsl/sw/zcsl-fft
./zcsl-fft-sim
killall vvp pslse
