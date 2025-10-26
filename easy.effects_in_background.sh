#!/bin/bash
if pgrep -x easyeffects >/dev/null; then
    pkill -x easyeffects
else
    easyeffects --gapplication-service >/dev/null 2>&1 &
fi
