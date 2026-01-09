#!/bin/bash

sleep 5

copyq --start-server &
copyq_exit_code=$?

keepassxc &
keepassxc_exit_code=$?

easyeffects --hide-window --service-mode &
easyeffects_exit_code=$?

while [ $copyq_exit_code -ne 0 ]; do
    kill -9 $pid_copyq
    copyq --start-server &
    pid_copyq=$!
    copyq_exit_code=$?
    sleep 2
done &

while [ $keepassxc_exit_code -ne 0 ]; do
    kill -9 $pid_keepassxc
    keepassxc &
    pid_keepassxc=$!
    keepassxc_exit_code=$?
    sleep 2
done &

while [ $easyeffects_exit_code -ne 0 ]; do
    kill -9 $pid_easyeffects
    easyeffects --hide-window --service-mode &
    pid_easyeffects=$!
    easyeffects_exit_code=$?
    sleep 2
done &
