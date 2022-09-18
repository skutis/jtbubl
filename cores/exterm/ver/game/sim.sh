#!/bin/bash

ln -sf $ROM/insectx.rom rom.bin

jtsim -mist -sysname exterm \
    -d JTFRAME_SIM_ROMRQ_NOCHECK \
    $*
