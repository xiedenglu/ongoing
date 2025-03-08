PYTEST_SMOKE_TESTS=(
                    "/opt/tests/image_tests/install/test_vsa_deploy.py::TestVSADeploy"
                    "/opt/tests/platform_tests/cluster/test_cluster_create_all_appliances.py::TestClusterCreateAllAppliances"
                    "/opt/tests/platform_tests/vsa/test_vsa_ppds_check.py::TestVsaPpdsCheck"
                    "/opt/tests/platform_tests/vsa/test_vsa_hardware_verification.py::TestVsaHardwareVerification"
                    "/opt/tests/common_test/SPT/Configuration/io_host_setup.py"
                    "/opt/tests/common_test/BBT/Configuration/bbt_create_and_delete_lun.py"
                    "/opt/tests/common_test/BBT/IO/bbt_io_iox_block.py"
                    "/opt/tests/platform_tests/vsa/test_system_cleanup.py"
                    "-m \'platformsmoke\'"
                   )

RESULTS_XML=(
       "test_vsa_deploy.xml"
       "test_cluster_create_all_appliances.xml"
       "test_vsa_ppds_check.xml"
       "test_vsa_hardware_verification.xml"
       "io_host_setup.xml"
       "bbt_create_and_delete_lun.xml"
       "bbt_io_iox_block.xml"
       "test_system_cleanup.xml"
       "platformsmoke.xml"
       )


PARAM_FILE="$CYC_TEST_RESULTS_DIRECTORY/params.json"
PARAM_FILE_IN_DOCKER=/opt/results/$(basename $PARAM_FILE)
cat <<EOF | jq 'del(.[][] | select(. == ""))' > $PARAM_FILE
{
    "/opt/tests/image_tests/install/test_vsa_deploy.py": {
        "deploy_docker": "$DEPLOY_DOCKER",
        "deploy_image": "$DEPLOY_IMAGE",
        "deploy_interface": "cli",
        "username": "$TEST_USERNAME",
        "engineering_key": "$ENGINEERING_KEY",
        "use_auto_cc": "$USE_AUTO_CC",
        "nimbus_model": "$NIMBUS_MODEL"
    },
    "/opt/tests/platform_tests/cluster/test_cluster_create_all_appliances.py": {
        "post_only": "1"
    },
    "/opt/tests/common_test/SPT/Configuration/io_host_setup.py":{
        "host_label_list":[
            "L0"
        ]
    },
    "/opt/tests/common_test/BBT/Configuration/bbt_create_and_delete_lun.py":{
        "action":"create",
        "name_prefix":"vol1",
        "num_of_volumes":"10",
        "volume_size":"10 GB",
        "map_to_host":"yes",
        "host_map_mode":"all",
        "host_label_list":[
            "L0"
        ]
    },
    "/opt/tests/platform_tests/ha/test_ha_dp_kill.py": {
        "dp_kill_both_nodes": "0"
    },
    "/opt/tests/common_test/BBT/IO/bbt_io_iox_block.py":{
        "iterations":[
            "1",
            "1"
        ],
        "io_iterations":"1",
        "io_duration":"300 S",
        "stop_at_io_duration":"yes",
        "host_label":"L0",
        "logs_postcleanup":"False",
        "logs_precleanup":"True",
        "iox_status_interval":"30 S",
        "pass_timeout":"2 H",
        "data_source":"generate_data",
        "start_io_only":"True",
        "no_log":"False"
    }
}
EOF
