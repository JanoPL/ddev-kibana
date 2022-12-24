setup() {
  set -eu -o pipefail
  export DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )/.."
  export TESTDIR=~/tmp/testddevkibana
  mkdir -p $TESTDIR
  export PROJNAME=testddevkibana
  export DDEV_NON_INTERACTIVE=true
  ddev delete -Oy ${PROJNAME} >/dev/null 2>&1 || true
  cd "${TESTDIR}"
  ddev config --project-name=${PROJNAME}
  ddev start -y >/dev/null 2>&1
}

teardown() {
  set -eu -o pipefail
  cd ${TESTDIR} || ( printf "unable to cd to ${TESTDIR}\n" && exit 1 )
  ddev delete -Oy ${PROJNAME} >/dev/null 2>&1
  [ "${TESTDIR}" != "" ] && rm -rf ${TESTDIR}
}

@test "install from directory" {
  set -eu -o pipefail
  cd ${TESTDIR} || ( printf "unable to cd to ${TESTDIR}\n" && exit 1 )
  echo "# ddev get ${DIR} with project ${PROJNAME} in ${TESTDIR} ($(pwd))" >&3
  ddev get drud/ddev-elasticsearch
  ddev get ${DIR}
  ddev restart >/dev/null 2>&1

  ddev exec "curl -s kibana:5601"
}

@test "install from release" {
  set -eu -o pipefail
  cd ${TESTDIR} || ( printf "unable to cd to ${TESTDIR}\n" && exit 1 )
  echo "# ddev get JanoPL/ddev-kibana with project ${PROJNAME} in ${TESTDIR} ($(pwd))" >&3
  ddev get drud/ddev-elasticsearch
  ddev get JanoPL/ddev-kibana
  ddev restart >/dev/null 2>&1

  ddev exec "curl -s kibana:5601"
}
