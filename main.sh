#!/bin/bash
echo ""
echo "### ---------------------------"
echo "### START OF INITIALIZATION ###"
echo "### Checking the host system"
echo "### Must be run as \"root\""
echo "### ---------------------------"

echo ""
echo "... Validating the environment"
if [ $(whoami) != "$1" ]
  then
    echo "!! Fatal Error 2: Must be run as $1"
    exit 2
fi
if [ $( readlink -f /bin/sh ) != "/bin/bash" ]
then
    echo "!! Fatal Error 3: /bin/sh is not symlinked to /bin/bash"
    echo "sudo rm /bin/sh && sudo ln -s /bin/bash /bin/sh"
    exit 3
fi

echo ""
echo "... Self check"
#self_check

echo ""
echo "... Validating required software versions"
sh version-check.sh
echo ""
echo "... Validating required libraries"
sh lib-check.sh
echo "--> Either all three (libgmp.la, libmpfr.la, libmpc.la) should be present or absent, but not only one or two. If the problem exists on your system, either rename or delete the .la files or install the appropriate missing package."
echo ""

echo ""
echo "///// HUMAN REQUIRED \\\\\\\\\\\\\\\\\\\\"
echo "### Please follow the instructions below:"
echo "### Verify that the versions match"
echo "### Also cross check with the book 7.8"
echo ""
echo "- Bash-3.2"
echo "- >= Binutils-2.17 -> Binutils-2.25.1 (Versions greater than 2.25.1 are not recommended as they have not been tested)"
echo "- >= Bison-2.3 (/usr/bin/yacc should be a link to bison or small script that executes bison)"
echo "- >= Bzip2-1.0.4"
echo "- >= Coreutils-6.9"
echo "- >= Diffutils-2.8.1"
echo "- >= Findutils-4.2.31"
echo "- >= Gawk-4.0.1 (/usr/bin/awk should be a link to gawk)"
echo "- >= GCC-4.1.2 -> GCC-5.2.0 including the C++ compiler, g++ (Versions greater than 5.2.0 are not recommended as they have not been tested)"
echo "- >= Glibc-2.11 -> Glibc-2.22 (Versions greater than 2.22 are not recommended as they have not been tested)"
echo "- >= Grep-2.5.1a"
echo "- >= Gzip-1.3.12"
echo "- >= Linux Kernel-2.6.32"
echo "- >= M4-1.4.10"
echo "- >= Make-3.81"
echo "- >= Patch-2.5.4"
echo "- >= Perl-5.8.8"
echo "- >= Sed-4.1.5"
echo "- >= Tar-1.22"
echo "- >= Texinfo-4.7"
echo "- >= Xz-5.0.0"
echo ""

mkfs -v -t ext4 /dev/sdb1 &&
mkswap /dev/sdb2

export LFS=/mnt/lfs

mkdir -pv $LFS
mount -v -t ext4 /dev/sdb1 $LFS &&
sbin/swapon -v /dev/sdb2

mkdir -v $LFS/sources &&
chmod -v a+wt $LFS/sources



pushd $LFS/sources
md5sum -c md5sums
popd

mkdir -v $LFS/tools &&
ln -sv $LFS/tools /

groupadd lfs &&
useradd -s /bin/bash -g lfs -m -k /dev/null lfs &&
passwd lfs

chown -v lfs $LFS/tools &&
chown -v lfs $LFS/sources &&
su - lfs

cat > ~/.bash_profile << "EOF"
exec env -i HOME=$HOME TERM=$TERM PS1='\u:\w\$ ' /bin/bash
EOF

cat > ~/.bashrc << "EOF"
set +h
umask 022
LFS=/mnt/lfs
LC_ALL=POSIX
LFS_TGT=$(uname -m)-lfs-linux-gnu
PATH=/tools/bin:/bin:/usr/bin
export LFS LC_ALL LFS_TGT PATH
EOF

source ~/.bash_profile

---------------------------------------------------------------------------------------

tar -xf binutils-2.25.1.tar.bz2 &&
cd binutils-2.25.1 &&
mkdir -v ../binutils-build &&
cd ../binutils-build &&
../binutils-2.25.1/configure   \
    --prefix=/tools            \
    --with-sysroot=$LFS        \
    --with-lib-path=/tools/lib \
    --target=$LFS_TGT          \
    --disable-nls              \
    --disable-werror &&
make

case $(uname -m) in
  x86_64) mkdir -v /tools/lib && ln -sv lib /tools/lib64 ;;
esac &&
make install &&
cd $LFS/sources &&
rm -rf binutils-2.25.1 binutils-build

---------------------------------------------------------------------------------------

tar -xf gcc-5.2.0.tar.bz2 &&
cd gcc-5.2.0 &&
tar -xf ../mpfr-3.1.3.tar.xz &&
mv -v mpfr-3.1.3 mpfr &&
tar -xf ../gmp-6.0.0a.tar.xz &&
mv -v gmp-6.0.0 gmp &&
tar -xf ../mpc-1.0.3.tar.gz &&
mv -v mpc-1.0.3 mpc

for file in \
 $(find gcc/config -name linux64.h -o -name linux.h -o -name sysv4.h)
do
  cp -uv $file{,.orig}
  sed -e 's@/lib\(64\)\?\(32\)\?/ld@/tools&@g' \
      -e 's@/usr@/tools@g' $file.orig > $file
  echo '
#undef STANDARD_STARTFILE_PREFIX_1
#undef STANDARD_STARTFILE_PREFIX_2
#define STANDARD_STARTFILE_PREFIX_1 "/tools/lib/"
#define STANDARD_STARTFILE_PREFIX_2 ""' >> $file
  touch $file.orig
done

mkdir -v ../gcc-build &&
cd ../gcc-build &&
../gcc-5.2.0/configure                             \
    --target=$LFS_TGT                              \
    --prefix=/tools                                \
    --with-glibc-version=2.11                      \
    --with-sysroot=$LFS                            \
    --with-newlib                                  \
    --without-headers                              \
    --with-local-prefix=/tools                     \
    --with-native-system-header-dir=/tools/include \
    --disable-nls                                  \
    --disable-shared                               \
    --disable-multilib                             \
    --disable-decimal-float                        \
    --disable-threads                              \
    --disable-libatomic                            \
    --disable-libgomp                              \
    --disable-libquadmath                          \
    --disable-libssp                               \
    --disable-libvtv                               \
    --disable-libstdcxx                            \
    --enable-languages=c,c++ &&
make

make install &&
cd $LFS/sources &&
rm -rf gcc-5.2.0 gcc-build

---------------------------------------------------------------------------------------

tar -xf linux-4.2.tar.xz &&
cd linux-4.2 &&
make mrproper &&
make INSTALL_HDR_PATH=dest headers_install &&
cp -rv dest/include/* /tools/include &&
cd $LFS/sources &&
rm -rf linux-4.2

---------------------------------------------------------------------------------------

tar -xf glibc-2.22.tar.xz &&
cd glibc-2.22 &&
patch -Np1 -i ../glibc-2.22-upstream_i386_fix-1.patch &&
mkdir -v ../glibc-build &&
cd ../glibc-build &&
../glibc-2.22/configure                             \
      --prefix=/tools                               \
      --host=$LFS_TGT                               \
      --build=$(../glibc-2.22/scripts/config.guess) \
      --disable-profile                             \
      --enable-kernel=2.6.32                        \
      --enable-obsolete-rpc                         \
      --with-headers=/tools/include                 \
      libc_cv_forced_unwind=yes                     \
      libc_cv_ctors_header=yes                      \
      libc_cv_c_cleanup=yes &&
make

make install &&
cd $LFS/sources &&
rm -rf glibc-2.22 glibc-build

echo 'int main(){}' > dummy.c &&
$LFS_TGT-gcc dummy.c &&
readelf -l a.out | grep ': /tools' &&
rm -v dummy.c a.out

---------------------------------------------------------------------------------------

tar -xf gcc-5.2.0.tar.bz2 &&
cd gcc-5.2.0 &&
mkdir -v ../gcc-build &&
cd ../gcc-build &&
../gcc-5.2.0/libstdc++-v3/configure \
    --host=$LFS_TGT                 \
    --prefix=/tools                 \
    --disable-multilib              \
    --disable-nls                   \
    --disable-libstdcxx-threads     \
    --disable-libstdcxx-pch         \
    --with-gxx-include-dir=/tools/$LFS_TGT/include/c++/5.2.0 &&
make

make install &&
cd $LFS/sources &&
rm -rf gcc-5.2.0 gcc-build

---------------------------------------------------------------------------------------


tar -xf binutils-2.25.1.tar.bz2 &&
cd binutils-2.25.1 &&
mkdir -v ../binutils-build &&
cd ../binutils-build &&
CC=$LFS_TGT-gcc                \
AR=$LFS_TGT-ar                 \
RANLIB=$LFS_TGT-ranlib         \
../binutils-2.25.1/configure   \
    --prefix=/tools            \
    --disable-nls              \
    --disable-werror           \
    --with-lib-path=/tools/lib \
    --with-sysroot &&
make

make install &&
make -C ld clean &&
make -C ld LIB_PATH=/usr/lib:/lib &&
cp -v ld/ld-new /tools/bin &&
cd $LFS/sources &&
rm -rf binutils-build binutils-2.25.1

---------------------------------------------------------------------------------------

tar -xf gcc-5.2.0.tar.bz2 &&
cd gcc-5.2.0

cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
  `dirname $($LFS_TGT-gcc -print-libgcc-file-name)`/include-fixed/limits.h

for file in \
 $(find gcc/config -name linux64.h -o -name linux.h -o -name sysv4.h)
do
  cp -uv $file{,.orig}
  sed -e 's@/lib\(64\)\?\(32\)\?/ld@/tools&@g' \
      -e 's@/usr@/tools@g' $file.orig > $file
  echo '
#undef STANDARD_STARTFILE_PREFIX_1
#undef STANDARD_STARTFILE_PREFIX_2
#define STANDARD_STARTFILE_PREFIX_1 "/tools/lib/"
#define STANDARD_STARTFILE_PREFIX_2 ""' >> $file
  touch $file.orig
done

tar -xf ../mpfr-3.1.3.tar.xz &&
mv -v mpfr-3.1.3 mpfr &&
tar -xf ../gmp-6.0.0a.tar.xz &&
mv -v gmp-6.0.0 gmp &&
tar -xf ../mpc-1.0.3.tar.gz &&
mv -v mpc-1.0.3 mpc &&
mkdir -v ../gcc-build &&
cd ../gcc-build &&
CC=$LFS_TGT-gcc                                    \
CXX=$LFS_TGT-g++                                   \
AR=$LFS_TGT-ar                                     \
RANLIB=$LFS_TGT-ranlib                             \
../gcc-5.2.0/configure                             \
    --prefix=/tools                                \
    --with-local-prefix=/tools                     \
    --with-native-system-header-dir=/tools/include \
    --enable-languages=c,c++                       \
    --disable-libstdcxx-pch                        \
    --disable-multilib                             \
    --disable-bootstrap                            \
    --disable-libgomp &&
make

make install &&
ln -sv gcc /tools/bin/cc &&
cd $LFS/sources &&
rm -rf gcc-5.2.0 gcc-build

echo 'int main(){}' > dummy.c &&
cc dummy.c &&
readelf -l a.out | grep ': /tools' &&
rm -v dummy.c a.out

---------------------------------------------------------------------------------------

tar -xf tcl-core8.6.4-src.tar.gz &&
cd $LFS/sources/tcl8.6.4/unix

./configure --prefix=/tools &&
make

TZ=UTC make test

make install &&
chmod -v u+w /tools/lib/libtcl8.6.so &&
make install-private-headers &&
ln -sv tclsh8.6 /tools/bin/tclsh &&
cd $LFS/sources &&
rm -rf tcl8.6.4

---------------------------------------------------------------------------------------

tar -xf expect5.45.tar.gz &&
cd expect5.45

cp -v configure{,.orig} &&
sed 's:/usr/local/bin:/bin:' configure.orig > configure

./configure --prefix=/tools       \
            --with-tcl=/tools/lib \
            --with-tclinclude=/tools/include &&
make

make SCRIPTS="" install &&
cd $LFS/sources &&
rm -rf expect5.45

---------------------------------------------------------------------------------------

tar -xf dejagnu-1.5.3.tar.gz &&
cd dejagnu-1.5.3 &&
./configure --prefix=/tools &&
make install &&
cd $LFS/sources &&
rm -rf dejagnu-1.5.3

---------------------------------------------------------------------------------------

tar -xf check-0.10.0.tar.gz &&
cd check-0.10.0 &&
PKG_CONFIG= ./configure --prefix=/tools &&
make

make install &&
cd $LFS/sources &&
rm -rf check-0.10.0

---------------------------------------------------------------------------------------

tar -xf ncurses-6.0.tar.gz &&
cd ncurses-6.0 &&
sed -i s/mawk// configure &&
./configure --prefix=/tools \
            --with-shared   \
            --without-debug \
            --without-ada   \
            --enable-widec  \
            --enable-overwrite &&
make

make install &&
cd $LFS/sources &&
rm -rf ncurses-6.0

---------------------------------------------------------------------------------------

tar -xf bash-4.3.30.tar.gz &&
cd bash-4.3.30 &&
./configure --prefix=/tools --without-bash-malloc &&
make

make install &&
ln -sv bash /tools/bin/sh &&
cd $LFS/sources &&
rm -rf bash-4.3.30

---------------------------------------------------------------------------------------

tar -xf bzip2-1.0.6.tar.gz &&
cd bzip2-1.0.6 &&
make

make PREFIX=/tools install &&
cd $LFS/sources &&
rm -rf bzip2-1.0.6

---------------------------------------------------------------------------------------

tar -xf coreutils-8.24.tar.xz &&
cd coreutils-8.24 &&
./configure --prefix=/tools --enable-install-program=hostname &&
make

make install &&
cd $LFS/sources &&
rm -rf coreutils-8.24

---------------------------------------------------------------------------------------

tar -xf diffutils-3.3.tar.xz &&
cd diffutils-3.3 &&
./configure --prefix=/tools &&
make

make install &&
cd $LFS/sources &&
rm -rf diffutils-3.3

---------------------------------------------------------------------------------------

tar -xf file-5.24.tar.gz &&
cd file-5.24 &&
./configure --prefix=/tools &&
make

make install &&
cd $LFS/sources &&
rm -rf file-5.24

---------------------------------------------------------------------------------------

tar -xf findutils-4.4.2.tar.gz &&
cd findutils-4.4.2 &&
./configure --prefix=/tools &&
make

make install &&
cd $LFS/sources &&
rm -rf findutils-4.4.2

---------------------------------------------------------------------------------------

tar -xf gawk-4.1.3.tar.xz &&
cd gawk-4.1.3 &&
./configure --prefix=/tools &&
make

make install &&
cd $LFS/sources &&
rm -rf gawk-4.1.3

---------------------------------------------------------------------------------------

tar -xf gettext-0.19.5.1.tar.xz &&
cd gettext-0.19.5.1/gettext-tools

EMACS="no" ./configure --prefix=/tools --disable-shared &&
make -C gnulib-lib &&
make -C intl pluralx.c &&
make -C src msgfmt &&
make -C src msgmerge &&
make -C src xgettext

cp -v src/{msgfmt,msgmerge,xgettext} /tools/bin

cd $LFS/sources &&
rm -rf gettext-0.19.5.1

---------------------------------------------------------------------------------------

tar -xf grep-2.21.tar.xz &&
cd grep-2.21 &&
./configure --prefix=/tools &&
make

make install &&
cd $LFS/sources &&
rm -rf grep-2.21

---------------------------------------------------------------------------------------

tar -xf gzip-1.6.tar.xz &&
cd gzip-1.6 &&
./configure --prefix=/tools &&
make

make install &&
cd $LFS/sources &&
rm -rf gzip-1.6

---------------------------------------------------------------------------------------

tar -xf m4-1.4.17.tar.xz &&
cd m4-1.4.17 &&
./configure --prefix=/tools &&
make

make install &&
cd $LFS/sources &&
rm -rf m4-1.4.17

---------------------------------------------------------------------------------------

tar -xf make-4.1.tar.bz2 && 
cd make-4.1 &&
./configure --prefix=/tools --without-guile &&
make

make install &&
cd $LFS/sources &&
rm -rf make-4.1

---------------------------------------------------------------------------------------

tar -xf patch-2.7.5.tar.xz &&
cd patch-2.7.5 &&
./configure --prefix=/tools &&
make

make install &&
cd $LFS/sources &&
rm -rf patch-2.7.5

---------------------------------------------------------------------------------------

tar -xf perl-5.22.0.tar.bz2 &&
cd perl-5.22.0 &&
sh Configure -des -Dprefix=/tools -Dlibs=-lm &&
make

cp -v perl cpan/podlators/pod2man /tools/bin &&
mkdir -pv /tools/lib/perl5/5.22.0 &&
cp -Rv lib/* /tools/lib/perl5/5.22.0 &&
cd $LFS/sources &&
rm -rf perl-5.22.0

---------------------------------------------------------------------------------------

tar -xf sed-4.2.2.tar.bz2 &&
cd sed-4.2.2 &&
./configure -prefix=/tools &&
make

make install &&
cd $LFS/sources &&
rm -rf sed-4.2.2

---------------------------------------------------------------------------------------

tar -xf tar-1.28.tar.xz &&
cd tar-1.28 &&
./configure --prefix=/tools &&
make

make install &&
cd $LFS/sources &&
rm -rf tar-1.28

---------------------------------------------------------------------------------------

tar -xf texinfo-6.0.tar.xz &&
cd texinfo-6.0 &&
./configure --prefix=/tools &&
make

make install &&
cd $LFS/sources &&
rm -rf texinfo-6.0

---------------------------------------------------------------------------------------

tar -xf util-linux-2.27.tar.xz &&
cd util-linux-2.27 &&
./configure --prefix=/tools                \
            --without-python               \
            --disable-makeinstall-chown    \
            --without-systemdsystemunitdir \
            PKG_CONFIG="" &&
make

make install &&
cd $LFS/sources &&
rm -rf util-linux-2.27

---------------------------------------------------------------------------------------

tar -xf xz-5.2.1.tar.xz &&
cd xz-5.2.1 &&
./configure --prefix=/tools &&
make

make install &&
cd $LFS/sources &&
rm -rf xz-5.2.1

---------------------------------------------------------------------------------------

cd $LFS/tools
tar -czf tools.tar.gz *

strip --strip-debug /tools/lib/*
/usr/bin/strip --strip-unneeded /tools/{,s}bin/*
rm -rf /tools/{,share}/{info,man,doc}
exit
chown -R root:root $LFS/tools

---------------------------------------------------------------------------------------

exit 0
