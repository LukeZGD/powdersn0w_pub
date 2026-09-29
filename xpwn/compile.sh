#!/bin/bash

arg="ipsw"
cmake=/usr/bin/cmake

for i in "$@"; do
    if [[ $i == "help" ]]; then
        echo "Usage: $0 <help>"
        echo "    <help>: Display this help prompt"
        exit 0
    elif [[ $i == "all" ]]; then
        echo "* Build all"
    fi
done

prepare() {
    if [[ $OSTYPE == "darwin"* ]]; then
        platform="macos"
        echo "* Platform: macOS"
        port=/opt/local/bin/port
        lib=/opt/local/lib
        export OPENSSL_ROOT_DIR="/opt/local/libexec/openssl11"

        export PATH="$PATH:/Applications/CMake.app/Contents/bin"
        cmake=$(command -v cmake)
        if [[ -z $cmake ]]; then
            VERS=`sw_vers -productVersion`
            VMAJ=`echo $VERS |cut -d "." -f 1`
            VMIN=`echo $VERS |cut -d "." -f 2`

            # cmake
            if [ $VMAJ -le 10 ] && [ $VMIN -lt 13 ]; then
            if [ $VMIN -lt 10 ]; then
                # < macOS 10.10
                CMAKE_URL=https://github.com/Kitware/CMake/releases/download/v3.18.6/cmake-3.18.6-Darwin-x86_64.tar.gz
                CMAKE_HASH=fe09f28c2bfe26a7b7daf0ff9444175f410bae36
            else
                # >= macOS 10.10
                CMAKE_URL=https://github.com/Kitware/CMake/releases/download/v3.20.1/cmake-3.20.1-macos10.10-universal.tar.gz
                CMAKE_HASH=668e554a7fa7ad57eaf73d374774afd7fd25f98f
            fi
            else
                # >= macOS 10.13
                CMAKE_URL=https://github.com/Kitware/CMake/releases/download/v3.20.1/cmake-3.20.1-macos-universal.tar.gz
                CMAKE_HASH=43cc6b91ca2ec711f3a1a3eafb970f9389e795e2
            fi

            echo "*** Installing cmake (in-tree)"
            CMAKE_TGZ=`basename $CMAKE_URL`
            echo "-- Downloading cmake"
            curl -L -o "$CMAKE_TGZ" "$CMAKE_URL" || exit 1
            CMAKE_PATH="`basename $CMAKE_TGZ .tar.gz`"
            echo "-- Extracting cmake (in tree)"
            tar xzf "$CMAKE_TGZ"
            cp -r "$CMAKE_PATH/CMake.app" /Applications
            cmake=$(command -v cmake)
            if [[ -z $cmake ]]; then
                echo "FATAL: cmake not found in \$PATH after trying to install it locally?!"
                exit 1
            fi
            echo "* cmake: done"
        fi

        if [[ ! -e $port ]]; then
            echo "MacPorts not installed!"
            exit 1
        fi
        sudo $port -N install openssl11
        sudo $port -N install libpng
        sudo mkdir -p ${lib}2 $OPENSSL_ROOT_DIR/lib2
        sudo mv $lib/libpng*.dylib ${lib}2/
        sudo mv $OPENSSL_ROOT_DIR/lib/*.dylib $OPENSSL_ROOT_DIR/lib2/

    elif [[ $OSTYPE == "linux"* ]]; then
        sslver="1.1.1w"
        platform="linux"
        echo "* Platform: Linux"
        . /etc/os-release
        if [[ $ID == "arch" || $ID_LIKE == "arch" ]]; then
            return
        elif [[ ! -f "/etc/lsb-release" && ! -f "/etc/debian_version" ]]; then
            echo "[Error] Ubuntu/Debian only"
            exit 1
        fi
        export BEGIN_LDFLAGS="-Wl,--allow-multiple-definition"
        export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig

        if [[ ! -e /usr/local/lib/libbz2.a || ! -e /usr/local/lib/libz.a ||
            ! -e /usr/local/lib/libcrypto.a || ! -e /usr/local/lib/libssl.a ]]; then
        #if [[ ! -e /usr/local/lib/libbz2.a || ! -e /usr/local/lib/libz.a ]]; then
            sudo apt update
            sudo apt remove -y libssl-dev libpng-dev zlib1g-dev
            sudo apt install -y pkg-config libtool automake g++ cmake git libusb-1.0-0-dev libreadline-dev git autopoint aria2 ca-certificates

            mkdir tmp
            cd tmp
            git clone https://github.com/madler/zlib
            aria2c https://sourceware.org/pub/bzip2/bzip2-1.0.8.tar.gz
            aria2c https://download.sourceforge.net/libpng/libpng-1.6.50.tar.gz
            aria2c https://www.openssl.org/source/openssl-$sslver.tar.gz

            tar -zxvf bzip2-1.0.8.tar.gz
            cd bzip2-1.0.8
            make LDFLAGS="$BEGIN_LDFLAGS"
            sudo make install
            cd ..

            cd zlib
            ./configure --static
            make LDFLAGS="$BEGIN_LDFLAGS"
            sudo make install
            cd ..

            tar -zxvf libpng-1.6.50.tar.gz
            cd libpng-1.6.50
            ./configure --disable-shared
            make $JNUM LDFLAGS="$BEGIN_LDFLAGS"
            sudo make install
            cd ..

            tar -zxvf openssl-$sslver.tar.gz
            cd openssl-$sslver
            if [[ $(uname -m) == "a"* && $(getconf LONG_BIT) == 64 ]]; then
                ./Configure no-ssl3-method linux-aarch64 "-Wa,--noexecstack -fPIC"
            elif [[ $(uname -m) == "a"* ]]; then
                ./Configure no-ssl3-method linux-generic32 "-Wa,--noexecstack -fPIC"
            else
                ./Configure no-ssl3-method enable-ec_nistp_64_gcc_128 linux-x86_64 "-Wa,--noexecstack -fPIC"
            fi
            make depend
            make
            sudo make install_sw install_ssldirs
            sudo rm -rf /usr/local/lib/libcrypto.so* /usr/local/lib/libssl.so*
            cd ..

            curl -LO https://opensource.apple.com/tarballs/cctools/cctools-927.0.2.tar.gz
            mkdir cctools-tmp
            tar -xzf cctools-927.0.2.tar.gz -C cctools-tmp/
            sed -i "s_#include_//_g" cctools-tmp/*cctools-927.0.2/include/mach-o/loader.h
            sed -i -e "s=<stdint.h>=\n#include <stdint.h>\ntypedef int integer_t;\ntypedef integer_t cpu_type_t;\ntypedef integer_t cpu_subtype_t;\ntypedef integer_t cpu_threadtype_t;\ntypedef int vm_prot_t;=g" cctools-tmp/*cctools-927.0.2/include/mach-o/loader.h
            sudo cp -r cctools-tmp/*cctools-927.0.2/include/* /usr/local/include/

            cd ..
            rm -rf tmp
        fi

    elif [[ $OSTYPE == "msys" ]]; then
        platform="win"
        echo "* Platform: Windows MSYS2"

        if [[ ! -e /usr/lib/libpng.a ]]; then
            echo "* Note that if your msys-runtime is outdated, MSYS2 prompt may close after updating."
            echo "* If this happens, reopen the MSYS2 prompt and run the script again"
            pacman -Syu --noconfirm --needed cmake git libbz2-devel make msys2-devel openssl-devel zip zlib-devel
            mkdir tmp
            cd tmp
            git clone https://github.com/glennrp/libpng
            cd libpng
            ./configure
            make
            make install
            cd ..

            curl -LO https://opensource.apple.com/tarballs/cctools/cctools-927.0.2.tar.gz
            mkdir cctools-tmp /usr/local/include
            tar -xzf cctools-927.0.2.tar.gz -C cctools-tmp/
            sed -i 's_#include_//_g' cctools-tmp/*cctools-927.0.2/include/mach-o/loader.h
            sed -i -e 's=<stdint.h>=\n#include <stdint.h>\ntypedef int integer_t;\ntypedef integer_t cpu_type_t;\ntypedef integer_t cpu_subtype_t;\ntypedef integer_t cpu_threadtype_t;\ntypedef int vm_prot_t;=g' cctools-tmp/*cctools-927.0.2/include/mach-o/loader.h
            cp -r cctools-tmp/*cctools-927.0.2/include/* /usr/local/include/

            cd ..
            rm -rf tmp
        fi

    else
        echo "[Error] Unsupported platform"
        exit 1
    fi
}

build() {
    rm -rf new
    mkdir bin new 2>/dev/null

    cd new
    $cmake ..
    make all
    cp ipsw-patch/ipsw ../bin/powdersn0w
    cp ipsw-patch/validate ../bin
    cd ..

    rm -rf new
    echo "Done! Builds at bin/"
}

cleanup() {
    if [[ $OSTYPE == "darwin"* ]]; then
        sudo mv ${lib}2/*.dylib $lib/
        sudo mv $OPENSSL_ROOT_DIR/lib2/*.dylib $OPENSSL_ROOT_DIR/lib/
    fi
}

prepare $1
build $1
cleanup
