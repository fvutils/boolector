#!/bin/sh

mkdir -p /build
cd /build

echo "Hello from PyPi build.sh"

BUILD_DIR=`pwd`
if test -f /proc/cpuinfo; then
  echo "cpuinfo exists"
  N_CORES=`cat /proc/cpuinfo | grep processor | wc -l`
else
  echo "cpuinfo DOES NOT exist"
  N_CORES=1
fi

CMAKE_DIR=cmake-3.5.0-Linux-x86_64

if test ! -f ${CMAKE_DIR}.tar.gz; then
  curl -L -O https://cmake.org/files/v3.5/${CMAKE_DIR}.tar.gz
  if test $? -ne 0; then exit 1; fi
fi      

cp -r /boolector .

if test ! -f lingeling-master.zip; then
  curl -L -o lingeling-master.zip https://github.com/arminbiere/lingeling/archive/master.zip
  if test $? -ne 0; then exit 1; fi
fi

if test ! -f btor2tools-master.zip; then
  curl -L -o btor2tools-master.zip https://github.com/Boolector/btor2tools/archive/master.zip
  if test $? -ne 0; then exit 1; fi
fi

#rm -rf boolector-master
#rm -rf ${CMAKE_DIR}

tar xvzf ${CMAKE_DIR}.tar.gz

export PATH=${BUILD_DIR}/${CMAKE_DIR}/bin:$PATH

#unzip -o boolector-master.zip
#if test $? -ne 0; then exit 1; fi

#mkdir -p boolector/deps
#mkdir -p boolector/deps/install/lib
#mkdir -p boolector/deps/install/include/btor2parser

cd ${BUILD_DIR}/boolector
./contrib/setup-btor2tools.sh
if test $? -ne 0; then exit 1; fi
./contrib/setup-cadical.sh
if test $? -ne 0; then exit 1; fi

#********************************************************************
#* boolector
#********************************************************************
cd ${BUILD_DIR}

sed -i -e 's/add_check_c_cxx_flag("-W")/add_check_c_cxx_flag("-W")\nadd_check_c_cxx_flag("-fPIC")/g' \
  boolector/CMakeLists.txt

cd boolector

./configure.sh -fPIC --shared --prefix /usr
if test $? -ne 0; then exit 1; fi

cd build

make -j${N_CORES}
if test $? -ne 0; then exit 1; fi

make install
if test $? -ne 0; then exit 1; fi

#********************************************************************
#* pyboolector
#********************************************************************
cd ${BUILD_DIR}
rm -rf pyboolector

export CMAKELISTS_TXT=/boolector/CMakeLists.txt

cp -r /boolector/pypi pyboolector

cd pyboolector

# Add the build number to the version
export BUILD_NUM
#sed -i -e "s/{{BUILD_NUM}}/${BUILD_NUM}/g" setup.py

for py in cp35-cp35m cp36-cp36m cp37-cp37m cp38-cp38; do
  echo "Python: ${py}"
  python=/opt/python/${py}/bin/python
  cd ${BUILD_DIR}/pyboolector
  rm -rf src
  cp -r ${BUILD_DIR}/boolector/src/api/python src
  sed -i -e 's/override//g' \
     -e 's/noexcept/_GLIBCXX_USE_NOEXCEPT/g' \
     -e 's/\(BoolectorException (const.*\)/\1\n    virtual ~BoolectorException() _GLIBCXX_USE_NOEXCEPT {}/' \
       src/pyboolector_abort.cpp
  if test $? -ne 0; then exit 1; fi
  mkdir -p src/utils
  cp ${BUILD_DIR}/boolector/src/*.h src
  cp ${BUILD_DIR}/boolector/src/utils/*.h src/utils
  $python ./src/mkoptions.py ./src/btortypes.h ./src/pyboolector_options.pxd
  if test $? -ne 0; then exit 1; fi
  $python setup.py sdist bdist_wheel
  if test $? -ne 0; then exit 1; fi
done

for whl in dist/*.whl; do
  auditwheel repair $whl
  if test $? -ne 0; then exit 1; fi
done

rm -rf /boolector/result
mkdir -p /boolector/result

cp -r wheelhouse dist /boolector/result


