#!/bin/bash
if pgrep -x easyeffects; then
    pkill -x easyeffects
else
    easyeffects --gapplication-service &
fi
