#!/bin/bash

SCRIPT_HOME=$(dirname $(readlink -f $0))
. $SCRIPT_HOME/do_job_utility.sh

if [ -z "${BUILD_TARGET}" ]; then
  LOG_WARNING "No build target specified, set to default GNOSIS!"
  BUILD_TARGET="GNOSIS"
fi

if [ -z "${BUILD_FLAVOR}" ]; then
  LOG_WARNING "No build flavor specified, set to default DEBUG!"
  BUILD_FLAVOR="DEBUG"
fi

UNITY_IMAGE_FILE="OS-*.tgz.bin"
UNITY_IMAGE="output/image/${BUILD_TARGET}_${BUILD_FLAVOR}/${UNITY_IMAGE_FILE}"
UNITY_UPGRADE_PKG_FILE="Unity-*.gpg"
UNITY_UPGRADE_PKG="output/image/${BUILD_TARGET}_${BUILD_FLAVOR}/${UNITY_UPGRADE_PKG_FILE}"
UNITY_TESTS_PATH="output/tests"
UNITY_TEST_DIR="test/unity"
UNITY_TESTSET_DIR="testset"
AUTOMATOS_RUN_SCRIPT="automatos_docker_run.sh"
AUTOMATOS_ENV_VARS_FILE="env_vars.sh"
UNITY_INSTALL_TESTSET="testset/MGMT_FW_INSTALL.xml"


prepare_test_env()
{
  # this should be called after pull codes and build
  local test_host_ip="$1"
  local test_host_username="$2"
  local test_host_password="$3"
  local test_host_workspace="$4"
  local build_results="$5"

  sshpass -p ${test_host_password} ssh -o "StrictHostKeyChecking=no" ${test_host_username}@${test_host_ip} "sudo rm -rf ${test_host_workspace}; mkdir -p ${test_host_workspace}"

  # test folder
  sshpass -p ${test_host_password} scp -o "StrictHostKeyChecking=no" -r ${SCRIPT_HOME}/test ${test_host_username}@${test_host_ip}:${test_host_workspace}
    if [ $? -ne 0 ]; then
    LOG_ERROR "Failed to copy test folder to test host!"
    return 1
  fi

  # testbed file - on localhost
  local testbed_file=${TESTBED_FILE}
  sshpass -p ${test_host_password} scp -o "StrictHostKeyChecking=no" ${testbed_file} ${test_host_username}@${test_host_ip}:${test_host_workspace}/${UNITY_TEST_DIR}
  if [ $? -ne 0 ]; then
    LOG_ERROR "Failed to copy testbed file to test host!"
    return 1
  fi

  if [ ! -z "${build_results}" ]; then
    # image
    local image_file=${build_results}/../${UNITY_IMAGE}
    sshpass -p ${test_host_password} scp -o "StrictHostKeyChecking=no" ${image_file} ${test_host_username}@${test_host_ip}:${test_host_workspace}/${UNITY_TEST_DIR}

    # upgrade package
    local upgrade_pkg=${build_results}/../${UNITY_UPGRADE_PKG}
    sshpass -p ${test_host_password} scp -o "StrictHostKeyChecking=no" ${upgrade_pkg} ${test_host_username}@${test_host_ip}:${test_host_workspace}/${UNITY_TEST_DIR}

    # tests path
    local tests_path=${build_results}/../${UNITY_TESTS_PATH}
    sshpass -p ${test_host_password} scp -r -o "StrictHostKeyChecking=no" ${tests_path} ${test_host_username}@${test_host_ip}:${test_host_workspace}/${UNITY_TEST_DIR}
  fi

  # there is a link issue in tests folder, just return ok
  return 0
}

run_test()
{
  local test_host_ip="$1"
  local test_host_username="$2"
  local test_host_password="$3"
  local test_host_workspace="$4"
  local build_results="$5"
    local build_number=${BUILD_NUMBER}
  local ci_user=${CI_USER}
  local ci_password=${CI_PASSWORD}
  local cfg_artifactory_userid=${CFG_ARTIFACTORY_USERID}
  local cfg_artifactory_password=${CFG_ARTIFACTORY_PASSWORD}
  local framework_branch=${FRAMEWORK_BRANCH}
  local testcase_branch=${TESTCASE_BRANCH}

  local workspace="./install"
  local testbed=${TESTBED_FILE}
  local testset=${UNITY_INSTALL_TESTSET}
  local image_path=`basename ${UNITY_IMAGE_FILE}`
  local upgrade_path=`basename ${UNITY_UPGRADE_PKG_FILE}`
  local tests_path=`basename ${UNITY_TESTS_PATH}`
  local report_dir=""

  # create env var file on test host
  sshpass -p ${test_host_password} ssh -o "TCPKeepAlive=yes" -o "ServerAliveInterval=30" -o "StrictHostKeyChecking=no" ${test_host_username}@${test_host_ip} "echo -e \"BUILD_NUMBER=${build_number}\nCI_USER=${ci_user}\nCI_PASSWORD=${ci_password}\nCFG_ARTIFACTORY_USERID=${cfg_artifactory_userid}\nCFG_ARTIFACTORY_PASSWORD=${cfg_artifactory_password}\nFRAMEWORK_BRANCH=${framework_branch}\nTESTCASE_BRANCH=${testcase_branch}\nWORKSPACE=${workspace}\nTESTBED=${testbed}\nTESTSET=${testset}\nIMAGE_PATH=${image_path}\nUPGRADE_PATH=${upgrade_path}\nTESTS_PATH=${tests_path}\nREPORT_DIR=${report_dir}\n\" > ${test_host_workspace}/${UNITY_TEST_DIR}/${AUTOMATOS_ENV_VARS_FILE}"

  # hack the automatos script to import the env vars
  sshpass -p ${test_host_password} ssh -o "TCPKeepAlive=yes" -o "ServerAliveInterval=30" -o "StrictHostKeyChecking=no" ${test_host_username}@${test_host_ip} "sed -i '2s/^/. ${AUTOMATOS_ENV_VARS_FILE}\n/' ${test_host_workspace}/${UNITY_TEST_DIR}/${AUTOMATOS_RUN_SCRIPT}"

  if [ ! -z "${build_results}" ]; then
    # run install case
    LOG_INFO "Running install case..."
    sshpass -p ${test_host_password} ssh -o "TCPKeepAlive=yes" -o "ServerAliveInterval=30" -o "StrictHostKeyChecking=no" ${test_host_username}@${test_host_ip} "cd ${test_host_workspace}/${UNITY_TEST_DIR}; ./${AUTOMATOS_RUN_SCRIPT}"
    if [ $? -ne 0 ]; then
      LOG_ERROR "Failed to run install case!"
      return 1
    fi
  fi

  # set the real testset env vars
  workspace="."
  testset=${UNITY_TESTSET_DIR}/${TESTSET}
  report_dir=${REPORT_DIR}
  sshpass -p ${test_host_password} ssh -o "TCPKeepAlive=yes" -o "ServerAliveInterval=30" -o "StrictHostKeyChecking=no" ${test_host_username}@${test_host_ip} "echo -e \"BUILD_NUMBER=${build_number}\nCI_USER=${ci_user}\nCI_PASSWORD=${ci_password}\nCFG_ARTIFACTORY_USERID=${cfg_artifactory_userid}\nCFG_ARTIFACTORY_PASSWORD=${cfg_artifactory_password}\nFRAMEWORK_BRANCH=${framework_branch}\nTESTCASE_BRANCH=${testcase_branch}\nWORKSPACE=${workspace}\nTESTBED=${testbed}\nTESTSET=${testset}\nIMAGE_PATH=${image_path}\nUPGRADE_PATH=${upgrade_path}\nTESTS_PATH=${tests_path}\nREPORT_DIR=${report_dir}\n\" > ${test_host_workspace}/${UNITY_TEST_DIR}/${AUTOMATOS_ENV_VARS_FILE}"

  # run tests
  sshpass -p ${test_host_password} ssh -o "TCPKeepAlive=yes" -o "ServerAliveInterval=30" -o "StrictHostKeyChecking=no" ${test_host_username}@${test_host_ip} "cd ${test_host_workspace}/${UNITY_TEST_DIR}; ./${AUTOMATOS_RUN_SCRIPT}"
  if [ $? -ne 0 ]; then
    LOG_ERROR "Failed to run test!"
    return 1
  fi
}

fetch_results()
{
  local test_host_ip="$1"
  local test_host_username="$2"
  local test_host_password="$3"
  local test_host_result_folder="$4"

  local result_folder=`basename ${test_host_result_folder}`
  local test_host_result_folder_tar=${result_folder}.tar.gz

  rm -rf ${result_folder}
  rm -rf ${test_host_result_folder_tar}

  # fetch results folder
  LOG_INFO "Fetching results folder from test host ${test_host_ip}:${test_host_result_folder}"
  sshpass -p ${test_host_password} ssh -o "TCPKeepAlive=yes" -o "ServerAliveInterval=30" -o "StrictHostKeyChecking=no" ${test_host_username}@${test_host_ip} "cd ${test_host_result_folder}/..; tar --exclude=\"*_service-data.tgz\" -zcf ${test_host_result_folder_tar} ${result_folder}"

  sshpass -p ${test_host_password} scp -o "TCPKeepAlive=yes" -o "ServerAliveInterval=30" -o "StrictHostKeyChecking=no" ${test_host_username}@${test_host_ip}:${test_host_result_folder}/../${test_host_result_folder_tar} .
  tar -xf ${test_host_result_folder_tar}
#  sshpass -p ${test_host_password} ssh -o "StrictHostKeyChecking=no" ${test_host_username}@${test_host_ip} "rsync -avzhP -e \"ssh -A -i .ssh/id_rsa_rsync xiaowei@10.124.127.22 ssh -o StrictHostKeyChecking=no -i .ssh/id_rsa_rsync\" ${test_host_result_folder}/../${test_host_result_folder_tar} ."
  if [ $? -ne 0 ]; then
    LOG_INFO "Failed to fetching results folder!"
        return 1
  fi
}

trap_handler()
{
  LOG_INFO "Release testbed and host in trap_handler..."
  release_testbed ${TEST_GREENBED_ID}
  release_host ${TEST_HOST_IP}
}

# main
if [ -z "${GREENBED_ADDRESS}" ]; then
  LOG_ERROR "No GREENBED_ADDRESS is specified!"
  exit 1
fi

if [ -z "${TEST_HOST_TAG}" ]; then
  LOG_ERROR "No TEST_HOST_TAG is specified！"
  exit 1
fi

if [ -z "${TESTBED_POOL}" ]; then
  LOG_ERROR "No TESTBED_POOL is specified!"
  exit 1
fi

if [ -z "${CFG_ARTIFACTORY_PASSWORD}" ]; then
  LOG_ERROR "No artifactory password specified!"
  exit 1
fi

if [ -z "${CFG_ARTIFACTORY_SERVER}" ]; then
  LOG_ERROR "No artifactory server specified!"
  exit 1
fi
if [ -z "${CFG_ARTIFACTORY_USERID}" ]; then
  LOG_ERROR "No artifactory user id specified!"
  exit 1
fi

if [ -z "${CI_PASSWORD}" ]; then
  LOG_ERROR "No ci password specified!"
  exit 1
fi

if [ -z "${CI_USER}" ]; then
  LOG_ERROR "No ci user specified!"
  exit 1
fi

if [ -z "${FRAMEWORK_BRANCH}" ]; then
  LOG_ERROR "No automatos framework branch specified!"
  exit 1
fi

if [ -z "${TESTCASE_BRANCH}" ]; then
  LOG_ERROR "No automatos testcase branch specified!"
  exit 1
fi

if [ -z "${TEST_HOST_WORKSPACE}" ]; then
  TEST_HOST_WORKSPACE="jenkins/workspace/${JOB_NAME}"
fi

if [ -z "${TESTSET}" ]; then
  LOG_ERROR "No TESTSET is specified!"
  exit 1
else
  LOG_INFO "TESTSET is ${TESTSET}"
fi

if [ -z "${BUILD_RESULTS}" ]; then
  LOG_WARNING "No BUILD_RESULTS is specified, will skip installing..."
fi
HOST_IP=""
HOST_USERNAME=""
HOST_PASSWORD=""
get_host ${TEST_HOST_TAG}
TEST_HOST_IP=$HOST_IP
TEST_HOST_USERNAME=$HOST_USERNAME
TEST_HOST_PASSWORD=$HOST_PASSWORD
if [ ! -z "${TEST_HOST_IP}" ] && [ "${TEST_HOST_IP}" != "null" ]; then
  LOG_INFO "Retrieved test host ip: ${TEST_HOST_IP}"
else
  LOG_ERROR "Cannot get test host from greenbed!"
  release_host ${TEST_HOST_IP}
  exit 1
fi
if [ -z "${TEST_HOST_USERNAME}" ] || [ "${TEST_HOST_USERNAME}" = "null" ] \
    || [ -z "${TEST_HOST_PASSWORD}" ] || [ "${TEST_HOST_PASSWORD}" = "null" ]; then
  LOG_ERROR "Cannot get test host credentials from greenbed!"
  release_host ${TEST_HOST_IP}
  exit 1
fi

TEST_GREENBED_ID=""
get_testbed
TEST_GREENBED_ID=`awk -F 'greenbed_id="' '/greenbed_id/ {print $2} ' ${TESTBED_FILE} | awk -F '"' '{print $1}' | tr -d "\n"`
if [ ! -z "${TEST_GREENBED_ID}" ] && [ "${TEST_GREENBED_ID}" != "null" ]; then
  LOG_INFO "Retrieved testbed greenbed id: ${TEST_GREENBED_ID}"
else
  LOG_ERROR "Cannot get testbed from greenbed!"
  release_host ${TEST_HOST_IP}
  exit 1
fi

trap 'trap_handler' TERM

call_function "Preparing Test Host ENV" prepare_test_env ${TEST_HOST_IP} ${TEST_HOST_USERNAME} ${TEST_HOST_PASSWORD} ${TEST_HOST_WORKSPACE} "${BUILD_RESULTS}"
if [ $? -ne 0 ]; then
  LOG_ERROR "Failed to prepare test host!"
  release_testbed ${TEST_GREENBED_ID}
  release_host ${TEST_HOST_IP}
  exit 1
fi

RET=0
call_function "Running Tests" run_test ${TEST_HOST_IP} ${TEST_HOST_USERNAME} ${TEST_HOST_PASSWORD} ${TEST_HOST_WORKSPACE} "${BUILD_RESULTS}"
RET=$?

TEST_RESULT_FOLDER=${TEST_HOST_WORKSPACE}/${UNITY_TEST_DIR}/${REPORT_DIR}
call_function "Fetching Results" fetch_results ${TEST_HOST_IP} ${TEST_HOST_USERNAME} ${TEST_HOST_PASSWORD} ${TEST_RESULT_FOLDER}

release_testbed ${TEST_GREENBED_ID}
release_host ${TEST_HOST_IP}

exit $RET
