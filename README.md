# macam64
macam64 is an attempt to port [macam](http://webcam-osx.sourceforge.net/) to work on recent macOS versions (macOS 10.15 at the moment).  I've removed the QuickTime integration and GUI and old build system, leaving just the USB camera drivers.

macam is 2006-2007 (c) [The macam project](http://webcam-osx.sourceforge.net/).

## Compiling
    git clone https://github.com/smokris/macam64.git
    cd macam64
    mkdir build
    cd build
    cmake ..
    cmake --build . --parallel

## Using
Currently this project only produces a static library.  See https://github.com/smokris/vuo-nodes/blob/master/smokris/smokris.macam.receive.m for sample code to use the library.

So far I've only tested the Intel QX3 camera driver.
