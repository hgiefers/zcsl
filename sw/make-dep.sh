#!/bin/bash -e

cd "$(dirname "${BASH_SOURCE[0]}")"

# Checkout Power Service Layer Simulation Engine (PSLSE). Contains the simulation version of libcxl.c.
if [ ! -d "pslse" ]; then
	git clone https://github.com/ibm-capi/pslse.git
	cd pslse
	git checkout tags/v2.0
	cd ..
else
	cd pslse
	git fetch origin
	git checkout tags/v2.0
	cd ..
fi

# Checkout HW libcxl
if [ ! -d "libcxl" ]; then
	git clone https://github.com/ibm-capi/libcxl.git
else
	cd libcxl
	git pull --ff-only
	cd ..
fi

if uname -a | grep "x86" 1> /dev/null
then
	make -B -C pslse/afu_driver/src
	make -B -C pslse/pslse
	make -B -C pslse/libcxl
	make -B -C pslse/debug
elif uname -a | grep ppc64 1> /dev/null
then
	make -C ./libcxl
fi


