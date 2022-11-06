#!/bin/bash

ln -sf $ROM/insectx.rom rom.bin

jtsim -d JTFRAME_SIM_ROMRQ_NOCHECK $*
