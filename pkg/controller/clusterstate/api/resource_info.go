/*
Copyright 2019, 2021 The Multi-Cluster App Dispatcher Authors.

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

package api

import (
	"fmt"
	"math"

	v1 "k8s.io/api/core/v1"
)

type Resource struct {
	MilliCPU float64
	Memory   float64
	GPU      int64
}

const (
	// need to follow https://github.com/NVIDIA/k8s-device-plugin/blob/66a35b71ac4b5cbfb04714678b548bd77e5ba719/server.go#L20
	GPUResourceName = "nvidia.com/gpu"
)

func EmptyResource() *Resource {
	return &Resource{
		MilliCPU: 0,
		Memory:   0,
		GPU:      0,
	}
}

func MinResource() *Resource {
	return &Resource{
		MilliCPU: 0.1,
		Memory:   10,
		GPU:      0,
	}
}

func (r *Resource) Clone() *Resource {
	clone := &Resource{
		MilliCPU: r.MilliCPU,
		Memory:   r.Memory,
		GPU:      r.GPU,
	}
	return clone
}

var minMilliCPU float64 = 10
var minMemory float64 = 10 * 1024 * 1024

func NewResource(rl v1.ResourceList) *Resource {
	r := EmptyResource()
	for rName, rQuant := range rl {
		switch rName {
		case v1.ResourceCPU:
			r.MilliCPU += float64(rQuant.MilliValue())
		case v1.ResourceMemory:
			r.Memory += float64(rQuant.Value())
		case GPUResourceName:
			q, _ := rQuant.AsInt64()
			r.GPU += q
		}
	}
	return r
}

func (r *Resource) IsEmpty() bool {
	return r.MilliCPU < minMilliCPU && r.Memory < minMemory && r.GPU == 0
}

func (r *Resource) IsZero(rn v1.ResourceName) (bool, error) {
	switch rn {
	case v1.ResourceCPU:
		return r.MilliCPU < minMilliCPU, nil
	case v1.ResourceMemory:
		return r.Memory < minMemory, nil
	case GPUResourceName:
		return r.GPU == 0, nil
	default:
		e := fmt.Errorf("unknown resource %v", rn)
		return false, e
	}
}

func (r *Resource) Add(rr *Resource) *Resource {
	r.MilliCPU += rr.MilliCPU
	r.Memory += rr.Memory
	r.GPU += rr.GPU
	return r
}

func (r *Resource) Replace(rr *Resource) *Resource {
	r.MilliCPU = rr.MilliCPU
	r.Memory = rr.Memory
	r.GPU = rr.GPU
	return r
}

// Sub subtracts two Resource objects.
func (r *Resource) Sub(rr *Resource) (*Resource, error) {
	return r.NonNegSub(rr)
}

// Sub subtracts two Resource objects and return zero for negative subtractions.
func (r *Resource) NonNegSub(rr *Resource) (*Resource, error) {
	// Check for negative calculation
	var isNegative bool
	var err error = nil
	var rCopy *Resource = nil
	if r.MilliCPU < rr.MilliCPU {
		r.MilliCPU = 0
		isNegative = true
		rCopy = r.Clone()
	} else {
		r.MilliCPU -= rr.MilliCPU
	}
	if r.Memory < rr.Memory {
		r.Memory = 0
		isNegative = true
		if rCopy == nil {
			rCopy = r.Clone()
		}
	} else {
		r.Memory -= rr.Memory
	}

	if r.GPU < rr.GPU {
		r.GPU = 0
		isNegative = true
		if rCopy == nil {
			rCopy = r.Clone()
		}
	} else {
		r.GPU -= rr.GPU
	}
	if isNegative {
		err = fmt.Errorf("resource subtraction resulted in negative value, total resource: %v, subtracting resource: %v", rCopy, rr)
	}
	return r, err
}

func (r *Resource) Less(rr *Resource) bool {
	return r.MilliCPU < rr.MilliCPU && r.Memory < rr.Memory && r.GPU < rr.GPU
}

func (r *Resource) LessEqual(rr *Resource) bool {
	return (r.MilliCPU < rr.MilliCPU || math.Abs(rr.MilliCPU-r.MilliCPU) < 0.01) &&
		(r.Memory < rr.Memory || math.Abs(rr.Memory-r.Memory) < 1) &&
		(r.GPU <= rr.GPU)
}

func (r *Resource) String() string {
	return fmt.Sprintf("cpu %0.2f, memory %0.2f, GPU %d",
		r.MilliCPU, r.Memory, r.GPU)
}

func (r *Resource) Get(rn v1.ResourceName) (float64, error) {
	switch rn {
	case v1.ResourceCPU:
		return r.MilliCPU, nil
	case v1.ResourceMemory:
		return r.Memory, nil
	case GPUResourceName:
		return float64(r.GPU), nil
	default:
		err := fmt.Errorf("resource not supported %v", rn)
		return 0.0, err
	}
}

func ResourceNames() []v1.ResourceName {
	return []v1.ResourceName{v1.ResourceCPU, v1.ResourceMemory, GPUResourceName}
}
