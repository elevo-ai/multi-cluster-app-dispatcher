BIN_DIR=_output/bin
CAT_CMD=$(if $(filter $(OS),Windows_NT),type,cat)
RELEASE_VER:=
CURRENT_DIR=$(shell pwd)
GIT_BRANCH:=$(shell git symbolic-ref --short HEAD 2>&1 | grep -v fatal)
#define the GO_BUILD_ARGS if you need to pass additional arguments to the go build
GO_BUILD_ARGS?=

## Location to install dependencies to
LOCALBIN ?= $(shell pwd)/bin
$(LOCALBIN):
	mkdir -p $(LOCALBIN)

## Tool Versions
CONTROLLER_TOOLS_VERSION ?= v0.9.2
CODEGEN_VERSION ?= v0.27.2

## Tool Binaries
CONTROLLER_GEN ?= $(LOCALBIN)/controller-gen
APPLYCONFIGURATION_GEN ?= $(LOCALBIN)/applyconfiguration-gen
CLIENT_GEN ?= $(LOCALBIN)/client-gen
LISTER_GEN ?= $(LOCALBIN)/lister-gen
INFORMER_GEN ?= $(LOCALBIN)/informer-gen

TAG:=$(shell echo "")

# Check for current branch name and update 'RELEASE_VER' and 'TAG'
ifneq ($(strip $(GIT_BRANCH)),)
	RELEASE_VER:= $(shell git describe --tags --abbrev=0)
	TAG:=${TAG}${GIT_BRANCH}
	# replace invalid characters that might exist in the branch name
	TAG:=$(shell echo ${TAG} | sed 's/[^a-zA-Z0-9]/-/g')
	TAG:=${TAG}-${RELEASE_VER}
	TAG:=0.0.1
endif

.PHONY: print-global-variables

# Build the controller executable for use in docker image build
mcad-controller: init generate-code
ifeq ($(strip $(GO_BUILD_ARGS)),)
	$(info Compiling controller)
	CGO_ENABLED=0 go build -o ${BIN_DIR}/mcad-controller ./cmd/kar-controllers/
else
	$(info Compiling controller with build arguments: '${GO_BUILD_ARGS}')
	go build $(GO_BUILD_ARGS) -o ${BIN_DIR}/mcad-controller ./cmd/kar-controllers/
endif	

print-global-variables:
	$(info "---")
	$(info "MAKE GLOBAL VARIABLES:")
	$(info "  "BIN_DIR="$(BIN_DIR)")
	$(info "  "GIT_BRANCH="$(GIT_BRANCH)")
	$(info "  "RELEASE_VER="$(RELEASE_VER)")
	$(info "  "TAG="$(TAG)")
	$(info "  "GO_BUILD_ARGS="$(GO_BUILD_ARGS)")
	$(info "---")

verify: generate-code
#	hack/verify-gofmt.sh
#	hack/verify-golint.sh
#	hack/verify-gencode.sh

init:
	mkdir -p ${BIN_DIR}

verify-tag-name: print-global-variables
	# Check for invalid tag name
	t=${TAG} && [ $${#t} -le 128 ] || { echo "Target name $$t has 128 or more chars"; false; }
.PHONY: generate-client ## Generate client packages
generate-client: code-generator
	rm -rf pkg/client/applyconfiguration pkg/client/clientset/versioned pkg/client/informers/externalversions pkg/client/listers/controller/v1beta1 pkg/client/listers/quotasubtree/v1alpha1
	$(APPLYCONFIGURATION_GEN) \
		--input-dirs="github.com/project-codeflare/multi-cluster-app-dispatcher/pkg/apis/controller/v1beta1" \
		--go-header-file="hack/boilerplate/boilerplate.go.txt" \
		--output-package="github.com/project-codeflare/multi-cluster-app-dispatcher/pkg/client/applyconfiguration" \
		--trim-path-prefix "github.com/project-codeflare/multi-cluster-app-dispatcher"
	$(CLIENT_GEN) \
 		--input="pkg/apis/controller/v1beta1" \
		--input="pkg/apis/quotaplugins/quotasubtree/v1alpha1" \
 		--input-base="github.com/project-codeflare/multi-cluster-app-dispatcher" \
 		--go-header-file="hack/boilerplate/boilerplate.go.txt" \
 		--clientset-name "versioned"  \
 		--output-package="github.com/project-codeflare/multi-cluster-app-dispatcher/pkg/client/clientset" \
 		--output-base="." \
		--trim-path-prefix "github.com/project-codeflare/multi-cluster-app-dispatcher"
	$(LISTER_GEN) \
 		--input-dirs="github.com/project-codeflare/multi-cluster-app-dispatcher/pkg/apis/controller/v1beta1" \
		--input-dirs="github.com/project-codeflare/multi-cluster-app-dispatcher/pkg/apis/quotaplugins/quotasubtree/v1alpha1" \
 		--go-header-file="hack/boilerplate/boilerplate.go.txt" \
 		--output-base="." \
		--output-package="github.com/project-codeflare/multi-cluster-app-dispatcher/pkg/client/listers" \
 		--trim-path-prefix "github.com/project-codeflare/multi-cluster-app-dispatcher"
	$(INFORMER_GEN) \
 		--input-dirs="github.com/project-codeflare/multi-cluster-app-dispatcher/pkg/apis/controller/v1beta1" \
		--input-dirs="github.com/project-codeflare/multi-cluster-app-dispatcher/pkg/apis/quotaplugins/quotasubtree/v1alpha1" \
 		--versioned-clientset-package="github.com/project-codeflare/multi-cluster-app-dispatcher/pkg/client/clientset/versioned" \
 		--listers-package="github.com/project-codeflare/multi-cluster-app-dispatcher/pkg/client/listers" \
 		--go-header-file="hack/boilerplate/boilerplate.go.txt" \
 		--output-base="." \
 		--output-package="github.com/project-codeflare/multi-cluster-app-dispatcher/pkg/client/informers" \
		--trim-path-prefix "github.com/project-codeflare/multi-cluster-app-dispatcher"

.PHONY: controller-gen
controller-gen: $(CONTROLLER_GEN) ## Download controller-gen locally if necessary.
$(CONTROLLER_GEN): $(LOCALBIN)
	test -s $(LOCALBIN)/controller-gen || GOBIN=$(LOCALBIN) go install sigs.k8s.io/controller-tools/cmd/controller-gen@$(CONTROLLER_TOOLS_VERSION)

.PHONY: code-generator
code-generator: $(APPLYCONFIGURATION_GEN) $(CLIENT_GEN) $(LISTER_GEN) $(INFORMER_GEN) $(CONTROLLER_GEN)

.PHONY: applyconfiguration-gen
applyconfiguration-gen: $(APPLYCONFIGURATION_GEN)
$(APPLYCONFIGURATION_GEN): $(LOCALBIN)
	test -s $(LOCALBIN)/applyconfiguration-gen || GOBIN=$(LOCALBIN) go install k8s.io/code-generator/cmd/applyconfiguration-gen@$(CODEGEN_VERSION)

.PHONY: client-gen
client-gen: $(CLIENT_GEN)
$(CLIENT_GEN): $(LOCALBIN)
	test -s $(LOCALBIN)/client-gen || GOBIN=$(LOCALBIN) go install k8s.io/code-generator/cmd/client-gen@$(CODEGEN_VERSION)

.PHONY: lister-gen
lister-gen: $(LISTER_GEN)
$(LISTER_GEN): $(LOCALBIN)
	test -s $(LOCALBIN)/lister-gen || GOBIN=$(LOCALBIN) go install k8s.io/code-generator/cmd/lister-gen@$(CODEGEN_VERSION)

.PHONY: informer-gen
informer-gen: $(INFORMER_GEN)
$(INFORMER_GEN): $(LOCALBIN)
	test -s $(LOCALBIN)/informer-gen || GOBIN=$(LOCALBIN) go install k8s.io/code-generator/cmd/informer-gen@$(CODEGEN_VERSION)	

.PHONY: manifests
manifests: controller-gen ## Generate CustomResourceDefinition objects.
	$(CONTROLLER_GEN) crd:allowDangerousTypes=true paths="./pkg/apis/..." output:crd:artifacts:config=config/crd/bases

.PHONY: generate-code
generate-code: controller-gen ## Generate code containing DeepCopy, DeepCopyInto, and DeepCopyObject method implementations.
	$(CONTROLLER_GEN) object:headerFile="hack/boilerplate/boilerplate.go.txt" paths="./pkg/apis/..."

# Build the docker image and tag it.  
images: verify-tag-name generate-code update-deployment-crds
	$(info List executable directory)
	$(info repo id: ${git_repository_id})
	$(info branch: ${GIT_BRANCH})
	$(info Build the docker image)
	@HOST_ARCH=$$(uname -m); \
	if [ "$$HOST_ARCH" = "aarch64" ]; then \
		if [ "$(strip $(GO_BUILD_ARGS))" = "" ]; then \
			docker buildx build --quiet --no-cache --platform=linux/amd64 --tag mcad-controller:${TAG} -f ${CURRENT_DIR}/Dockerfile  ${CURRENT_DIR}; \
		else \
			docker buildx build --no-cache --platform=linux/amd64 --tag mcad-controller:${TAG} --build-arg GO_BUILD_ARGS=$(GO_BUILD_ARGS) -f ${CURRENT_DIR}/Dockerfile  ${CURRENT_DIR}; \
		fi \
	else \
		if [ "$(strip $(GO_BUILD_ARGS))" = "" ]; then \
			docker build --quiet --no-cache --tag mcad-controller:${TAG} -f ${CURRENT_DIR}/Dockerfile  ${CURRENT_DIR}; \
		else \
			docker build --no-cache --tag mcad-controller:${TAG} --build-arg GO_BUILD_ARGS=$(GO_BUILD_ARGS) -f ${CURRENT_DIR}/Dockerfile  ${CURRENT_DIR}; \
		fi \
	fi

images-podman: verify-tag-name generate-code update-deployment-crds
	$(info List executable directory)
	$(info repo id: ${git_repository_id})
	$(info branch: ${GIT_BRANCH})
	$(info Build the docker image)
ifeq ($(strip $(GO_BUILD_ARGS)),)
	podman build --quiet --no-cache --tag mcad-controller:${TAG} -f ${CURRENT_DIR}/Dockerfile  ${CURRENT_DIR}
else
	podman build --no-cache --tag mcad-controller:${TAG} --build-arg GO_BUILD_ARGS=$(GO_BUILD_ARGS) -f ${CURRENT_DIR}/Dockerfile  ${CURRENT_DIR}
endif	

push-images: verify-tag-name
ifeq ($(strip $(quay_repository)),)
	$(info No registry information provided.  To push images to a docker registry please set)
	$(info environment variables: quay_repository, quay_token, and quay_id.  Environment)
else
	$(info Log into quay)
	docker login quay.io -u ${quay_id} --password ${quay_token}
	$(info Tag the latest image)
	docker tag mcad-controller:${TAG}  ${quay_repository}/mcad-controller:${TAG}
	$(info Push the docker image to registry)
	docker push ${quay_repository}/mcad-controller:${TAG}
ifeq ($(strip $(git_repository_id)),main)
	$(info Update the `dev` tag when built from `main`)
	docker tag mcad-controller:${TAG}  ${quay_repository}/mcad-controller:latest
	docker push ${quay_repository}/mcad-controller:latest
endif
ifneq ($(TAG:release-v%=%),$(TAG))
	$(info Update the `stable` tag to point `latest` release image)
	docker tag mcad-controller:${TAG} ${quay_repository}/mcad-controller:stable
	docker push ${quay_repository}/mcad-controller:stable
endif
endif

# easy-deploy can be used for building and pushing a custom image of MCAD and deploying it on your K8s cluster for development.
# Example: "make easy-deploy TAG=<image tag> USERNAME=<quay.io username>"
easy-deploy: images-podman
	podman tag localhost/mcad-controller:${TAG} quay.io/${USERNAME}/mcad-controller:${TAG}
	podman push quay.io/${USERNAME}/mcad-controller:${TAG}
	cd deployment && helm install mcad-controller mcad-controller --namespace kube-system --wait --set image.repository=quay.io/${USERNAME}/mcad-controller --set image.tag=${TAG}

run-test:
	$(info Running unit tests...)
	go test -v -coverprofile cover.out -race -parallel 8  ./pkg/...

run-e2e: verify-tag-name update-deployment-crds
ifeq ($(strip $(quay_repository)),)
	echo "Running e2e with MCAD local image: mcad-controller ${TAG} IfNotPresent."
	hack/run-e2e-kind.sh mcad-controller ${TAG} IfNotPresent
else
	echo "Running e2e with MCAD registry image image: ${quay_repository}/mcad-controller ${TAG}."
	hack/run-e2e-kind.sh ${quay_repository}/mcad-controller ${TAG}
endif

coverage:
#	KUBE_COVER=y hack/make-rules/test.sh $(WHAT) $(TESTS)

clean:
	rm -rf _output/

#CRD file maintenance rules
DEPLOYMENT_CRD_DIR=deployment/mcad-controller/crds
CRD_BASE_DIR=config/crd/bases
MCAD_CRDS= ${DEPLOYMENT_CRD_DIR}/quota.codeflare.dev_quotasubtrees.yaml  \
		   ${DEPLOYMENT_CRD_DIR}/workload.codeflare.dev_appwrappers.yaml \
		   ${DEPLOYMENT_CRD_DIR}/workload.codeflare.dev_schedulingspecs.yaml

update-deployment-crds: ${MCAD_CRDS}

${DEPLOYMENT_CRD_DIR}/quota.codeflare.dev_quotasubtrees.yaml : ${CRD_BASE_DIR}/quota.codeflare.dev_quotasubtrees.yaml
${DEPLOYMENT_CRD_DIR}/workload.codeflare.dev_appwrappers.yaml : ${CRD_BASE_DIR}/workload.codeflare.dev_appwrappers.yaml
${DEPLOYMENT_CRD_DIR}/workload.codeflare.dev_schedulingspecs.yaml : ${CRD_BASE_DIR}/workload.codeflare.dev_schedulingspecs.yaml

$(DEPLOYMENT_CRD_DIR)/%: ${CRD_BASE_DIR}/%
	cp $< $@
