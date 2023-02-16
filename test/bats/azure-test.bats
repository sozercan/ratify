#!/usr/bin/env bats

load helpers

BATS_TESTS_DIR=${BATS_TESTS_DIR:-test/bats/tests}
WAIT_TIME=60
SLEEP_TIME=1

@test "notary test" {
    teardown() {
        echo "cleaning up"
        wait_for_process ${WAIT_TIME} ${SLEEP_TIME} 'kubectl delete pod demo --namespace default --force --ignore-not-found=true'
        wait_for_process ${WAIT_TIME} ${SLEEP_TIME} 'kubectl delete pod demo1 --namespace default --force --ignore-not-found=true'
    }

    run kubectl apply -f ./library/default/template.yaml
    assert_success
    sleep 5
    run kubectl apply -f ./library/default/samples/constraint.yaml
    assert_success
    sleep 5
    run kubectl run demo --namespace default --image=wabbitnetworks.azurecr.io/test/notary-image:signed
    assert_success
    run kubectl run demo1 --namespace default --image=wabbitnetworks.azurecr.io/test/notary-image:unsigned
    assert_failure
}

@test "cosign test" {
    teardown() {
        echo "cleaning up"
        wait_for_process ${WAIT_TIME} ${SLEEP_TIME} 'kubectl delete pod cosign-demo --namespace dSefault --force --ignore-not-found=true'
        wait_for_process ${WAIT_TIME} ${SLEEP_TIME} 'kubectl delete pod cosign-demo2 --namespace default --force --ignore-not-found=true'
        wait_for_process ${WAIT_TIME} ${SLEEP_TIME} 'kubectl delete verifiers.config.ratify.deislabs.io/verifier-cosign --namespace default --ignore-not-found=true'
    }

    run kubectl apply -f ./library/default/template.yaml
    assert_success
    sleep 5
    run kubectl apply -f ./library/default/samples/constraint.yaml
    assert_success
    sleep 5
    run kubectl apply -f ./config/samples/config_v1alpha1_verifier_cosign.yaml
    sleep 5

    run kubectl run cosign-demo --namespace default --image=wabbitnetworks.azurecr.io/test/cosign-image:signed
    assert_success
    run kubectl run cosign-demo2 --namespace default --image=wabbitnetworks.azurecr.io/test/cosign-image:unsigned
    assert_failure
}

@test "licensechecker test" {
    teardown() {
        echo "cleaning up"
        wait_for_process ${WAIT_TIME} ${SLEEP_TIME} 'kubectl delete pod license-checker --namespace default --force --ignore-not-found=true'
        wait_for_process ${WAIT_TIME} ${SLEEP_TIME} 'kubectl delete pod license-checker2 --namespace default --force --ignore-not-found=true'
        wait_for_process ${WAIT_TIME} ${SLEEP_TIME} 'kubectl delete verifiers.config.ratify.deislabs.io/verifier-license-checker --namespace default --ignore-not-found=true'
    }

    run kubectl apply -f ./library/default/template.yaml
    assert_success
    sleep 5
    run kubectl apply -f ./library/default/samples/constraint.yaml
    assert_success
    sleep 5

    run kubectl apply -f ./config/samples/config_v1alpha1_verifier_partial_licensechecker.yaml
    sleep 5
    run kubectl run license-checker --namespace default --image=wabbitnetworks.azurecr.io/test/license-checker-image:v1
    assert_failure

    run kubectl apply -f ./config/samples/config_v1alpha1_verifier_complete_licensechecker.yaml
    # wait for the httpserver cache to be invalidated
    sleep 15
    run kubectl run license-checker2 --namespace default --image=wabbitnetworks.azurecr.io/test/license-checker-image:v1
    assert_success
}

@test "sbom verifier test" {
     teardown() {
        echo "cleaning up"
        wait_for_process ${WAIT_TIME} ${SLEEP_TIME} 'kubectl delete pod sbom --namespace default --force --ignore-not-found=true'
        wait_for_process ${WAIT_TIME} ${SLEEP_TIME} 'kubectl delete pod sbom2 --namespace default --force --ignore-not-found=true'
    }

    run kubectl apply -f ./library/default/template.yaml
    assert_success
    sleep 5
    run kubectl apply -f ./library/default/samples/constraint.yaml
    assert_success
    sleep 5

    run kubectl apply -f ./config/samples/config_v1alpha1_verifier_sbom.yaml
    sleep 5
    run kubectl run sbom --namespace default --image=wabbitnetworks.azurecr.io/test/sbom-image:signed
    assert_success

    run kubectl delete verifiers.config.ratify.deislabs.io/verifier-sbom
    assert_success
    # wait for the httpserver cache to be invalidated
    sleep 15
    run kubectl run sbom2 --namespace default --image=wabbitnetworks.azurecr.io/test/sbom-image:signed
    assert_failure
}

@test "schemavalidator verifier test" {
    teardown() {
        echo "cleaning up"
        wait_for_process ${WAIT_TIME} ${SLEEP_TIME} 'kubectl delete verifiers.config.ratify.deislabs.io/verifier-license-checker --namespace default --ignore-not-found=true'
        wait_for_process ${WAIT_TIME} ${SLEEP_TIME} 'kubectl delete verifiers.config.ratify.deislabs.io/verifier-sbom --namespace default --ignore-not-found=true'
        wait_for_process ${WAIT_TIME} ${SLEEP_TIME} 'kubectl delete verifiers.config.ratify.deislabs.io/verifier-schemavalidator --namespace default --ignore-not-found=true'
        wait_for_process ${WAIT_TIME} ${SLEEP_TIME} 'kubectl delete pod schemavalidator --namespace default --force --ignore-not-found=true'
        wait_for_process ${WAIT_TIME} ${SLEEP_TIME} 'kubectl delete pod schemavalidator2 --namespace default --force --ignore-not-found=true'
    }

    run kubectl apply -f ./library/default/template.yaml
    assert_success
    sleep 5
    run kubectl apply -f ./library/default/samples/constraint.yaml
    assert_success
    sleep 5

    run kubectl apply -f ./config/samples/config_v1alpha1_verifier_schemavalidator.yaml
    sleep 5
    # TODO
    # It's best to use an image with individual artifact types vs an all-in-one so any failures can be isolated.
    # Replace this image reference once we have a local private registry for Ratify.
    run kubectl run schemavalidator --namespace default --image=wabbitnetworks.azurecr.io/test/all-in-one-image:signed
    assert_success

    run kubectl apply -f ./config/samples/config_v1alpha1_verifier_schemavalidator_bad.yaml
    # wait for the httpserver cache to be invalidated
    sleep 15
    run kubectl run schemavalidator2 --namespace default --image=wabbitnetworks.azurecr.io/test/all-in-one-image:signed
    assert_failure
}

@test "sbom/notary/cosign/licensechecker/schemavalidator verifiers test" {
    teardown() {
        echo "cleaning up"
        wait_for_process ${WAIT_TIME} ${SLEEP_TIME} 'kubectl delete verifiers.config.ratify.deislabs.io/verifier-license-checker --namespace default --ignore-not-found=true'
        wait_for_process ${WAIT_TIME} ${SLEEP_TIME} 'kubectl delete verifiers.config.ratify.deislabs.io/verifier-sbom --namespace default --ignore-not-found=true'
        wait_for_process ${WAIT_TIME} ${SLEEP_TIME} 'kubectl delete verifiers.config.ratify.deislabs.io/verifier-schemavalidator --namespace default --ignore-not-found=true'
        wait_for_process ${WAIT_TIME} ${SLEEP_TIME} 'kubectl delete verifiers.config.ratify.deislabs.io/verifier-cosign --namespace default --ignore-not-found=true'
        wait_for_process ${WAIT_TIME} ${SLEEP_TIME} 'kubectl delete pod all-in-one --namespace default --force --ignore-not-found=true'
    }

    run kubectl apply -f ./library/default/template.yaml
    assert_success
    sleep 5
    run kubectl apply -f ./library/default/samples/constraint.yaml
    assert_success
    sleep 5

    run kubectl apply -f ./config/samples/config_v1alpha1_verifier_cosign.yaml
    sleep 5
    run kubectl apply -f ./config/samples/config_v1alpha1_verifier_sbom.yaml
    sleep 5
    run kubectl apply -f ./config/samples/config_v1alpha1_verifier_complete_licensechecker.yaml
    sleep 5
    run kubectl apply -f ./config/samples/config_v1alpha1_verifier_schemavalidator.yaml
    sleep 5

    run kubectl run all-in-one --namespace default --image=wabbitnetworks.azurecr.io/test/all-in-one-image:signed
    assert_success
}

@test "validate crd add, replace and delete" {
    teardown() {
        echo "cleaning up"
        wait_for_process ${WAIT_TIME} ${SLEEP_TIME} 'kubectl delete pod crdtest --namespace default --force --ignore-not-found=true'
    }

    echo "adding license checker, delete notary verifier and validate deployment fails due to missing notary verifier"
    run kubectl apply -f ./config/samples/config_v1alpha1_verifier_complete_licensechecker.yaml
    assert_success
    run kubectl delete verifiers.config.ratify.deislabs.io/verifier-notary
    assert_success
    # wait for the httpserver cache to be invalidated
    sleep 15
    run kubectl run crdtest --namespace default --image=wabbitnetworks.azurecr.io/test/notary-image:signed
    assert_failure

    echo "Add notary verifier and validate deployment succeeds"
    run kubectl apply -f ./config/samples/config_v1alpha1_verifier_notary.yaml
    assert_success

    # wait for the httpserver cache to be invalidated
    sleep 15
    run kubectl run crdtest --namespace default --image=wabbitnetworks.azurecr.io/test/notary-image:signed
    assert_success
}

@test "configmap update test" {
    skip "Skipping test for now as we are no longer watching for configfile update in a k8 environment.This test ensures we are watching config file updates in a non-kub scenario"
    run kubectl apply -f ./library/default/template.yaml
    assert_success
    sleep 5
    run kubectl apply -f ./library/default/samples/constraint.yaml
    assert_success
    sleep 5
    run kubectl run demo2 --image=wabbitnetworks.azurecr.io/test/net-monitor:signed
    assert_success

    run kubectl get configmaps ratify-configuration --namespace=gatekeeper-system -o yaml >currentConfig.yaml
    run kubectl delete -f ./library/default/samples/constraint.yaml

    wait_for_process ${WAIT_TIME} ${SLEEP_TIME} "kubectl replace --namespace=gatekeeper-system -f ${BATS_TESTS_DIR}/configmap/invalidconfigmap.yaml"
    echo "Waiting for 150 second for configuration update"
    sleep 150

    run kubectl apply -f ./library/default/samples/constraint.yaml
    assert_success
    run kubectl run demo3 --image=wabbitnetworks.azurecr.io/test/net-monitor:signed
    echo "Current time after validate : $(date +"%T")"
    assert_failure

    wait_for_process ${WAIT_TIME} ${SLEEP_TIME} "kubectl replace --namespace=gatekeeper-system -f currentConfig.yaml"
}

@test "dynamic plugins disabled test" {
    teardown() {
        wait_for_process ${WAIT_TIME} ${SLEEP_TIME} 'kubectl delete verifiers.config.ratify.deislabs.io/verifier-dynamic --namespace default --ignore-not-found=true'
    }

    start=$(date --iso-8601=seconds)
    latestpod=$(kubectl -n gatekeeper-system get pod -l=app.kubernetes.io/name=ratify --sort-by=.metadata.creationTimestamp -o=name | tail -n 1)

    run kubectl apply -f ./config/samples/config_v1alpha1_verifier_dynamic.yaml
    sleep 5

    run bash -c "kubectl -n gatekeeper-system logs $latestpod --since-time=$start | grep 'dynamic plugins are currently disabled'"
    assert_success
}

@test "dynamic plugins enabled test" {
    # only run this test against a live cluster 

    # ensure that the chart deployment is reset to a clean state for other tests
    teardown() {
        wait_for_process ${WAIT_TIME} ${SLEEP_TIME} 'kubectl delete verifiers.config.ratify.deislabs.io/verifier-dynamic --namespace default --ignore-not-found=true'
        pod=$(kubectl -n gatekeeper-system get pod -l=app.kubernetes.io/name=ratify --sort-by=.metadata.creationTimestamp -o=name | tail -n 1)
        helm upgrade --atomic --namespace gatekeeper-system --reuse-values --set featureFlags.RATIFY_DYNAMIC_PLUGINS=false ratify ./charts/ratify
        wait_for_process ${WAIT_TIME} ${SLEEP_TIME} 'kubectl -n gatekeeper-system delete $pod --force --grace-period=0'
    }

    # enable dynamic plugins
    helm upgrade --atomic --namespace gatekeeper-system --reuse-values --set featureFlags.RATIFY_DYNAMIC_PLUGINS=true ratify ./charts/ratify
    sleep 5
    latestpod=$(kubectl -n gatekeeper-system get pod -l=app.kubernetes.io/name=ratify --sort-by=.metadata.creationTimestamp -o=name | tail -n 1)

    run kubectl apply -f ./config/samples/config_v1alpha1_verifier_dynamic.yaml
    sleep 5

    # parse the logs for the newly created ratify pod
    run bash -c "kubectl -n gatekeeper-system logs $latestpod | grep 'downloaded verifier plugin dynamic from .* to .*'"
    assert_success
}

@test "validate mutation tag to digest" {
    teardown() {
        echo "cleaning up"
        wait_for_process ${WAIT_TIME} ${SLEEP_TIME} kubectl delete pod mutate-demo --namespace default
    }
    run kubectl apply -f ./library/default/template.yaml
    assert_success
    sleep 5
    run kubectl apply -f ./library/default/samples/constraint.yaml
    assert_success
    sleep 5
    run kubectl run mutate-demo --namespace default --image=wabbitnetworks.azurecr.io/test/notary-image:signed
    assert_success
    result=$(kubectl get pod mutate-demo --namespace default -o json | jq -r ".spec.containers[0].image" | grep @sha)
    assert_mutate_success
}
