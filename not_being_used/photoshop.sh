#!/bin/sh
param=
while [ "$1" ]
do
        param="$param Z:$1"
        shift
done
WINEPREFIX=/home/lucas/.wine_p wine 'C:\Program Files (x86)\Adobe Photoshop CS6\Photoshop.exe' $(echo $param | sed 's,/,\\,g')
