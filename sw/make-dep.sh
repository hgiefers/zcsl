#!/bin/bash

# Checkout Power Service Layer Simulation Engine (PSLSE). Contains the simulation version of libcxl.c.
if [ ! -d "pslse" ]; then
  git clone https://github.com/ibm-capi/pslse.git
	cd pslse
  git git checkout tags/v2.0
	cd ..
else
	git pull pslse
fi

# Checkout HW libcxl
if [ ! -d "libcxl" ]; then
  git clone https://github.com/ibm-capi/libcxl.git
else
	git pull libcxl
fi

if uname -a | grep "x86" 1> /dev/null
then 
	make -C ./pslse/afu_driver/src
	make -C ./pslse/pslse
	make -C ./pslse/libcxl
	make -C ./pslse/debug
elif uname -a | grep ppc64 1> /dev/null
then
	make -C ./libcxl
fi


