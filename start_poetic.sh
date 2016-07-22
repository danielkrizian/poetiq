#!/usr/bin/env bash

source ./setenv.sh

echo "Starting hdb equitysim ..."
q hdb.q -p $((${POETICBASEPORT}+1)) -load ${KDBHDB}/equitysim </dev/null >$KDBLOGS/hdb.txt 2>&1 &
