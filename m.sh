LFS=/mnt/lfs
LFS_LOG=/mnt/lfs/logs
LFS_ROOT=/dev/sdb1
LFS_SWAP=/dev/sdb2
LFS_SOURCES=/mnt/lfs/sources

init_tar()
{
    FILE_NAME=$(ls | egrep "^$1.+tar")
    FILE_C=$(ls | egrep "^$1.+tar" | wc -l)
    if [ ! -d $LFS_SOURCES/$1*/ ]; then
        tar -xf $FILE_NAME
    fi
}

# $1 -> $LFS_LOGS/$CH/$SEC-*.log
get_error_5()
{
    WARN=0
    ERR=0

    WARN=$(grep -n " [Ww]arnings*:* " $1* | wc -l)
    ERR=$(grep -n " [Ee]rrors*:* \|^FAIL:" $1* | wc -l)

    if [ $ERR -ne 0 ]; then
        echo "!! Known error and not critical:"
        echo "!! Info: $ERR errors, however they are not all critical."
        grep -n " [Ee]rrors*:* \|^FAIL:" $1* | grep -v "_5_5\|_5_7\|_5_12\|_5_14\|_5_15\|_5_16\|_5_18\|_5_19\|_5_24\|_5_26\|_5_30"
    else
        echo "---> No errors."
    fi
}

# $1 -> $LFS_LOGS/$CH/$SEC-*.log
get_error_6()
{
    WARN=0
    ERR=0

    WARN=$(grep -n " [Ww]arnings*:* " $1* | wc -l)
    ERR=$(grep -n " [Ee]rrors*:* \|^FAIL:" $1* | wc -l)

    if [ $ERR -ne 0 ]; then
        echo "!! Known error and not critical:"
        echo "!! Info: $ERR errors, however they are not all critical."
        grep -n " [Ee]rrors*:* \|^FAIL:" $1* | grep -v ""
    else
        echo "---> No errors."
    fi
}

is_root_user()
{
    if [ $(whoami) != "root" ]; then
        echo "Before continue any task, please run this command as root."
        exit 1
    fi
}

source ./common-vars.sh
is_root_user
bash version-check.sh

echo ""
echo "Creating FS on New Partition"
echo ""
mkfs -t ext4 $LFS_ROOT && mkswap $LFS_SWAP

export $LFS

CH=2
SEC=7
echo "Mounting New Partition"
mkdir -pv $LFS
mkdir -p $LFS_LOGS/$CH
mount -v -t ext4 $LFS_ROOT $LFS &&
/sbin/swapon -v $LFS_SWAP &> $LFS_LOGS/$CH/$SEC-mounting.log

CH=3
SEC=1
mkdir -p $LFS_LOGS/$CH
echo ""
echo "Packages and Patches"
echo ""
mkdir -v $LFS/sources && 
chmod -v a+wt $LFS/sources &&
pushd $LFS/sources && md5sums -c md5sums && popd &> $LFS_LOGS/$CH/$SEC-sources.log

CH=4
SEC=2
mkdir -p $LFS_LOGS/$CH
echo ""
echo "Final Preparations"
echo ""
mkdir -v $LFS/tools && ln -sv $LFS/tools / &> $LFS_LOGS/$CH/$SEC-tools-dir.log

SEC=3
echo ""
echo "Adding lfs User"
echo ""
groupadd lfs &&
useradd -s /bin/bash -g lfs -m -k /dev/null lfs &&
passwd lfs &&
chown -v lfs $LFS/tools &&
chown -v lfs $LFS/sources &&
su - lfs &> $LFS_LOGS/$CH/$SEC-user-added.log

SEC=4
echo ""
echo "Setting Up the Environment"
echo ""
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

cd $LFS_SOURCES
CH=5
SEC=4
mkdir -p $LFS_LOGS/$CH
echo ""
echo "Setting up binutils..."
echo ""
init_tar binutils
cd $(ls -d $LFS_SOURCES/binutils*/)
mkdir build && cd build
../configure --prefix=/tools --with-sysroot=$LFS --with-lib-path=/tools/lib --target=$LFS_TGT --disable-nls --disable-werror &> $LFS_LOGS/$CH/$SEC-configure.log
make &> $LFS_LOGS/$CH/$SEC-make.log
case $(uname -m) in
  x86_64) mkdir /tools/lib && ln -s lib /tools/lib64 ;;
esac
make install &> $LFS_LOGS/$CH/$SEC-make-install.log
cd $LFS_SOURCES && rm -rf $(ls -d $LFS_SOURCES/binutils*/)

SEC=5
echo ""
echo "Setting up gcc..."
echo ""
init_tar gcc
cd $(ls -d $LFS_SOURCES/gcc*/)
tar -xf ../mpfr-3.1.5.tar.xz && mv mpfr-3.1.5 mpfr &&
tar -xf ../gmp-6.1.2.tar.xz && mv gmp-6.1.2 gmp &&
tar -xf ../mpc-1.0.3.tar.gz && mv mpc-1.0.3 mpc

for file in gcc/config/{linux,i386/linux{,64}}.h
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

case $(uname -m) in
  x86_64)
    sed -e '/m64=/s/lib64/lib/' \
        -i.orig gcc/config/i386/t-linux64
 ;;
esac

mkdir build && cd build

../configure                                       \
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
    --disable-libmpx                               \
    --disable-libquadmath                          \
    --disable-libssp                               \
    --disable-libvtv                               \
    --disable-libstdcxx                            \
    --enable-languages=c,c++ &> $LFS_LOGS/$CH/$SEC-configure.log
make &> $LFS_LOGS/$CH/$SEC-make.log
make install &> $LFS_LOGS/$CH/$SEC-make-install.log
cd $LFS_SOURCES && rm -rf $(ls -d $LFS_SOURCES/gcc*/)
