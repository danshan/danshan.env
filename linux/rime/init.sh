#!/bin/bash

config_folder=`pwd`
app_folder=/Users/Dan/Library/Rime

for file in `ls`
do
    rm -rf $app_folder/$file
    ln -s $config_folder/$file $app_folder/$file
done
