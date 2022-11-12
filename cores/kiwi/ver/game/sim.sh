#!/bin/bash

ARG=
SCENE=
while [ $# -gt 0 ]; do
    case $1 in
        -s) shift
            SCENE=$1
            ARG="$ARG -d NOMAIN -nosnd -video 2"
            ;;
        *) ARG="$ARG $1";;
    esac
    shift
done

if [ ! -z "$SCENE" ]; then
    if [ ! -d "$SCENE" ]; then
        echo "Requested scene $SCENE cannot be found"
        exit 1
    fi
    cp $SCENE/{pal,lut}.bin .
    cp $SCENE/seta_cfg.hex .
    dd if=$SCENE/vram.bin of=vram_lo.bin count=8
    dd if=$SCENE/vram.bin of=vram_hi.bin count=8 skip=8
fi


ln -sf $ROM/insectx.rom rom.bin

jtsim -d JTFRAME_SIM_ROMRQ_NOCHECK $ARG
