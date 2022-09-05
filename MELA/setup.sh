#!/bin/bash

(
set -euo pipefail


getSCRAMVERSION(){
  GCCVERSION=$(gcc -dumpversion)
  if [[ "$GCCVERSION" == "4.3"* ]] || [[ "$GCCVERSION" == "4.4"* ]] || [[ "$GCCVERSION" == "4.5"* ]]; then # v1 of MCFM library
    echo slc5_amd64_gcc434
  elif [[ "$GCCVERSION" == "4"* ]] || [[ "$GCCVERSION" == "5"* ]] || [[ "$GCCVERSION" == "6"* ]]; then # v2 of MCFM library
    echo slc6_amd64_gcc630
  elif [[ "$GCCVERSION" == "7"* ]]; then # v3 of MCFM library
    echo slc7_amd64_gcc700
  elif [[ "$GCCVERSION" == "8.0"* ]] || [[ "$GCCVERSION" == "8.1"* ]] || [[ "$GCCVERSION" == "8.2"* ]]; then # v4 of MCFM library
    echo slc7_amd64_gcc820
  elif [[ "$GCCVERSION" == "8"* ]]; then
    echo slc7_amd64_gcc830
  else
  #elif [[ "$GCCVERSION" == "9"* ]]; then
    echo slc7_amd64_gcc920
  #else
  fi
}


cd $(dirname ${BASH_SOURCE[0]})

MELADIR="$(readlink -f .)"
MCFMVERSION=mcfm_707
declare -i doDeps=0
declare -i doPrintEnv=0
declare -i doPrintEnvInstr=0
declare -i hasCMSSW=0
declare -i needSCRAM=0
declare -i needROOFITSYS_ROOTSYS=0
declare -a setupArgs=()

for farg in "$@"; do
  fargl="$(echo $farg | awk '{print tolower($0)}')"
  if [[ "$fargl" == "deps" ]]; then
    doDeps=1
  elif [[ "$fargl" == "env" ]]; then
    doPrintEnv=1
  elif [[ "$fargl" == "envinstr" ]]; then
    doPrintEnvInstr=1
  else
    setupArgs+=( "$farg" ) 
  fi
done
declare -i nSetupArgs
nSetupArgs=${#setupArgs[@]}

SARCH=$(getSCRAMVERSION)

if [[ ! -z "${CMSSW_BASE+x}" ]]; then

  hasCMSSW=1

  eval $(scram ru -sh)

else

  if [[ -z "${SCRAM_ARCH+x}" ]]; then
    needSCRAM=1

    export SCRAM_ARCH="${SARCH}"
  fi

fi

if [[ -z "${ROOFITSYS+x}" ]] && [[ $doDeps -eq 0 ]]; then
  if [[ $(ls ${ROOTSYS}/lib | grep -e libRooFitCore) != "" ]]; then
    needROOFITSYS_ROOTSYS=1
  else
    echo "Cannot identify ROOFITSYS. Please set this environment variable properly."
    exit 1
  fi
fi


mela_lib_path="${MELADIR}/data/${SCRAM_ARCH}"

printenv () {
  if [[ -z "${MELA_LIB_PATH+x}" ]] || [[ "${MELA_LIB_PATH}" != "${mela_lib_path}" ]]; then
    echo "export MELA_LIB_PATH=${mela_lib_path}"
  fi

  ldlibappend="${mela_lib_path}"
  end=""
  if [[ ! -z "${LD_LIBRARY_PATH+x}" ]]; then
    end=":${LD_LIBRARY_PATH}"
  fi
  if [[ "${end}" != *"$ldlibappend"* ]]; then
    echo "export LD_LIBRARY_PATH=${ldlibappend}${end}"
  fi

  pythonappend="${MELADIR}/python"
  end=""
  if [[ ! -z "${PYTHONPATH+x}" ]]; then
    end=":${PYTHONPATH}"
  fi
  if [[ "${end}" != *"$pythonappend"* ]]; then
    echo "export PYTHONPATH=${pythonappend}${end}"
  fi

  if [[ $needSCRAM -eq 1 ]]; then
    echo "export SCRAM_ARCH=${SCRAM_ARCH}"
  fi

  if [[ $needROOFITSYS_ROOTSYS -eq 1 ]]; then
    echo "export ROOFITSYS=${ROOTSYS}"
  fi
}
doenv () {
  if [[ -z "${MELA_LIB_PATH+x}" ]] || [[ "${MELA_LIB_PATH}" != "${mela_lib_path}" ]]; then
    export MELA_LIB_PATH="${mela_lib_path}"
    echo "Temporarily using MELA_LIB_PATH as ${MELA_LIB_PATH}"
  fi

  ldlibappend="${mela_lib_path}"
  end=""
  if [[ ! -z "${LD_LIBRARY_PATH+x}" ]]; then
    end=":${LD_LIBRARY_PATH}"
  fi
  if [[ "${end}" != *"$ldlibappend"* ]]; then
    export LD_LIBRARY_PATH="${ldlibappend}${end}"
    echo "Temporarily using LD_LIBRARY_PATH as ${LD_LIBRARY_PATH}"
  fi

  pythonappend="${MELADIR}/python"
  end=""
  if [[ ! -z "${PYTHONPATH+x}" ]]; then
    end=":${PYTHONPATH}"
  fi
  if [[ "${end}" != *"$pythonappend"* ]]; then
    export PYTHONPATH="${pythonappend}${end}"
    echo "Temporarily using PYTHONPATH as ${PYTHONPATH}"
  fi

  if [[ $needROOFITSYS_ROOTSYS -eq 1 ]]; then
    export ROOFITSYS=${ROOTSYS}
    echo "Temporarily using ROOFITSYS as ${ROOTSYS}"
  fi
}
dodeps () {
  ${MELADIR}/COLLIER/setup.sh "${setupArgs[@]}"
  tcsh ${MELADIR}/data/retrieve.csh $SCRAM_ARCH $MCFMVERSION
  ${MELADIR}/downloadNNPDF.sh
}
printenvinstr () {

  echo
  echo "remember to do"
  echo
  echo 'eval $('${BASH_SOURCE[0]}' env)'
  echo "or"
  echo 'eval `'${BASH_SOURCE[0]}' env`'
  echo
  echo "if you are using a bash-related shell, or you can do"
  echo
  echo ${BASH_SOURCE[0]}' env'
  echo
  echo "and change the commands according to your shell in order to do something equivalent to set up the environment variables."
  echo
}

if [[ $doPrintEnv -eq 1 ]]; then
    printenv
    exit
elif [[ $doPrintEnvInstr -eq 1 ]]; then
    printenvinstr
    exit
fi

if [[ $nSetupArgs -eq 0 ]]; then
    setupArgs+=( -j 1 )
    nSetupArgs=2
fi


if [[ $doDeps -eq 1 ]]; then
    : ok
elif [[ "$nSetupArgs" -eq 1 ]] && [[ "${setupArgs[0]}" == *"clean"* ]]; then
    #echo "Cleaning C++"
    make clean

    #echo "Cleaning FORTRAN"
    pushd ${MELADIR}/fortran &> /dev/null
    make clean
    rm -f ../data/${SCRAM_ARCH}/libjhugenmela.so
    popd &> /dev/null

    #echo "Cleaning COLLIER"
    ${MELADIR}/COLLIER/setup.sh "${setupArgs[@]}"

    if [[ -e data/${SCRAM_ARCH}/TEMP ]]; then
      rm -rf data/${SCRAM_ARCH}
    fi

    exit
elif [[ "$nSetupArgs" -ge 1 ]] && [[ "$nSetupArgs" -le 2 ]] && [[ "${setupArgs[0]}" == *"-j"* ]]; then
    : ok
else
    echo "Unknown arguments:"
    echo "  ${setupArgs[@]}"
    echo "Should be nothing, env, or clean"
    exit 1
fi


if [[ ! -d data/${SCRAM_ARCH} ]]; then
  cp -r data/${SARCH} data/${SCRAM_ARCH}
  touch data/${SCRAM_ARCH}/TEMP
fi
doenv
dodeps
if [[ $doDeps -eq 1 ]]; then
    exit
fi

pushd ${MELADIR}/fortran &> /dev/null
make "${setupArgs[@]}"
popd &> /dev/null

make "${setupArgs[@]}"
printenvinstr

)
