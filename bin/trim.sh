#!/bin/sh
awk '{$1=$1};1' | tr -d "\n"
