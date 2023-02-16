/*
Copyright 2022.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package controllers

import (
	"context"
	"crypto/x509"
	"encoding/json"
	"fmt"

	configv1alpha1 "github.com/deislabs/ratify/api/v1alpha1"
	"github.com/deislabs/ratify/pkg/certificateprovider/azurekeyvault"
	"github.com/deislabs/ratify/pkg/certificateprovider/inline"

	"github.com/sirupsen/logrus"
	apierrors "k8s.io/apimachinery/pkg/api/errors"
	"k8s.io/apimachinery/pkg/runtime"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
)

// CertificateStoreReconciler reconciles a CertificateStore object
type CertificateStoreReconciler struct {
	client.Client
	Scheme *runtime.Scheme
}

var (
	// a map between CertificateStore name to array of x509 certificates
	certificatesMap = map[string][]*x509.Certificate{}
)

//+kubebuilder:rbac:groups=config.ratify.deislabs.io,resources=certificatestores,verbs=get;list;watch;create;update;patch;delete
//+kubebuilder:rbac:groups=config.ratify.deislabs.io,resources=certificatestores/status,verbs=get;update;patch
//+kubebuilder:rbac:groups=config.ratify.deislabs.io,resources=certificatestores/finalizers,verbs=update

// Reconcile is part of the main kubernetes reconciliation loop which aims to
// move the current state of the cluster closer to the desired state.
// the CertificateStore object against the actual cluster state, and then
// perform operations to make the cluster state reflect the state specified by
// the user.
//
// For more details, check Reconcile and its Result here:
// - https://pkg.go.dev/sigs.k8s.io/controller-runtime@v0.12.2/pkg/reconcile
func (r *CertificateStoreReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	logger := logrus.WithContext(ctx)

	var resource = req.Name
	var certStore configv1alpha1.CertificateStore

	logger.Infof("reconciling certificate store '%v'", resource)

	if err := r.Get(ctx, req.NamespacedName, &certStore); err != nil {
		if apierrors.IsNotFound(err) {
			logger.Infof("deletion detected, removing certificate store %v", req.Name)
			delete(certificatesMap, resource)
		} else {
			logger.Error(err, "unable to fetch certificate store")
		}

		return ctrl.Result{}, client.IgnoreNotFound(err)
	}

	// get cert provider attributes
	attributes, err := getCertStoreConfig(certStore.Spec)
	if err != nil {
		return ctrl.Result{}, err
	}

	// fetch certificates based on the provider
	switch certStore.Spec.Provider {
	case "azurekeyvault":
		certificates, err := azurekeyvault.GetCertificates(ctx, attributes)
		if err != nil {
			return ctrl.Result{}, fmt.Errorf("Error fetching certificates in store %v with azure key vault provider, error: %w", resource, err)
		}
		certificatesMap[resource] = certificates
		logger.Infof("%v certificates fetched for certificate store %v", len(certificates), resource)
	case "inline":
		certificates, err := inline.GetCertificates(ctx, attributes)
		if err != nil {
			return ctrl.Result{}, fmt.Errorf("Error fetching certificate in store %v with inline provider, error: %w", resource, err)
		}
		certificatesMap[resource] = certificates
		logger.Infof("%v certificates fetched for certificate store %v", len(certificates), resource)
	default:

		return ctrl.Result{}, fmt.Errorf("Unknown provider value %v defined in certificate store %v", certStore.Spec.Provider, resource)
	}

	// returning empty result and no error to indicate we’ve successfully reconciled this object
	return ctrl.Result{}, nil
}

// returns the internal certificate map
func GetCertificatesMap() map[string][]*x509.Certificate {
	return certificatesMap
}

// SetupWithManager sets up the controller with the Manager.
func (r *CertificateStoreReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&configv1alpha1.CertificateStore{}).
		Complete(r)
}

func getCertStoreConfig(spec configv1alpha1.CertificateStoreSpec) (map[string]string, error) {
	attributes := map[string]string{}

	if string(spec.Parameters.Raw) == "" {
		return nil, fmt.Errorf("Received empty parameters")
	}

	if err := json.Unmarshal(spec.Parameters.Raw, &attributes); err != nil {
		logrus.Error(err, "unable to decode cert store parameters", "Parameters.Raw", spec.Parameters.Raw)
		return attributes, err
	}

	return attributes, nil
}
