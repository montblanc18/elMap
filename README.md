#elMap
"elMap" is a ruby program which draws the elevation map of the object and Sun with gnuplot.
You have to set the RA and DEC of the object as shown in below.

#How to use
```bash
$ ruby elMap.rb -r <the ra of object> -d <the dec of object>
$ ruby elMap.rb -h  
Usage: elMap [options]  
    -r, --ra X                       Right Accension [deg]  
    -d, --dec X                      Declination [deg]  
    -t, --time X                     date of observation JST [pleas don't use]  
```