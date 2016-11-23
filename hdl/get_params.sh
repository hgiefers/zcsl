#!/bin/bash

if [ $# -lt 3 ]
then
  echo "Use: $0 <Spiral FFT module file> <FFT size> <streaming width>"
	exit 1
fi

SIZE=$2
CSAMPLES=$3
LATENCY=`sed -n 's/^.*Latency: \([0-9]\+\) cycles.*$/\1/p' $1`
GAP=`sed -n '0,/^.*Gap:/{s/^.*Gap: \([0-9]\+\).*$/\1/p}' $1`
CHUNK=`echo "$SIZE/$CSAMPLES" | bc`
LOGCHUNK=`echo "l($CHUNK)/l(2)" | bc -l | awk '{printf("%d\n",$2 + 0.5)}'`
BUFCHUNK=$((((($LATENCY+$CHUNK-1)/$CHUNK)+1)*$CHUNK))
LOGBUFCHUNK=`echo "l($BUFCHUNK)/l(2)" | bc -l | awk '{printf("%d\n",$2 + 0.5)}'`

echo "localparam FFT_LATENCY = $LATENCY;"
echo "localparam FFT_CHUNK = $CHUNK;"
echo "localparam LOG_FFT_CHUNK = $LOGCHUNK;"
echo "localparam IN_FIFO_LOG_DEPTH = LOG_FFT_CHUNK+1;"
echo "localparam OUT_FIFO_LOG_DEPTH = $LOGBUFCHUNK;"
echo "localparam OUT_FIFO_SPACE_REQ = 2**OUT_FIFO_LOG_DEPTH - (FFT_LATENCY + FFT_CHUNK);"
echo "localparam COUNTERSIZE = 16;"


