#include "chainerx/cuda/cuda_device.h"

#include <cmath>
#include <cstdint>

#include <cuda_runtime.h>

#include "chainerx/array.h"
#include "chainerx/cuda/cuda_runtime.h"
#include "chainerx/cuda/cuda_set_device_scope.h"
#include "chainerx/cuda/elementwise.cuh"
#include "chainerx/cuda/kernel_regist.h"
#include "chainerx/cuda/numeric.cuh"
#include "chainerx/device.h"
#include "chainerx/dtype.h"
#include "chainerx/kernels/math.h"

namespace chainerx {
namespace cuda {
namespace {

template <typename T>
struct SquareImpl {
    using CudaType = cuda_internal::DataType<T>;
    __device__ void operator()(int64_t /*i*/, CudaType x, CudaType& out) { out = x * x; }
};

class CudaSquareKernel : public SquareKernel {
public:
    void Call(const Array& x, const Array& out) override {
        Device& device = x.device();
        device.CheckDevicesCompatible(x, out);
        CudaSetDeviceScope scope{device.index()};
        VisitFloatingPointDtype(out.dtype(), [&](auto pt) {
            using T = typename decltype(pt)::type;
            Elementwise<const T, T>(SquareImpl<T>{}, x, out);
        });
    }
};

CHAINERX_CUDA_REGISTER_KERNEL(SquareKernel, CudaSquareKernel);

template <typename T>
struct SqrtImpl {
    using CudaType = cuda_internal::DataType<T>;
    __device__ void operator()(int64_t /*i*/, CudaType x, CudaType& out) { out = cuda::Sqrt(x); }
};

class CudaSqrtKernel : public SqrtKernel {
public:
    void Call(const Array& x, const Array& out) override {
        Device& device = x.device();
        device.CheckDevicesCompatible(x, out);
        const Array& x_cast = x.dtype() == out.dtype() ? x : x.AsType(out.dtype());
        CudaSetDeviceScope scope{device.index()};
        VisitFloatingPointDtype(out.dtype(), [&](auto pt) {
            using T = typename decltype(pt)::type;
            Elementwise<const T, T>(SqrtImpl<T>{}, x_cast, out);
        });
    }
};

CHAINERX_CUDA_REGISTER_KERNEL(SqrtKernel, CudaSqrtKernel);

CHAINERX_CUDA_REGISTER_ELTWISE_BINARY_KERNEL(PowerKernel, { out = cuda::Power(x1, x2); });

template <typename T>
struct PowerASImpl {
    using CudaType = cuda_internal::DataType<T>;
    __device__ void operator()(int64_t /*i*/, CudaType x1, CudaType& out) { out = cuda::Power(x1, x2); }
    CudaType x2;
};

class CudaPowerASKernel : public PowerASKernel {
public:
    void Call(const Array& x1, Scalar x2, const Array& out) {
        Device& device = x1.device();
        device.CheckDevicesCompatible(x1, out);
        const Array& x1_cast = x1.dtype() == out.dtype() ? x1 : x1.AsType(out.dtype());
        CudaSetDeviceScope scope{device.index()};
        VisitDtype(out.dtype(), [&](auto pt) {
            using T = typename decltype(pt)::type;
            using CudaType = cuda_internal::DataType<T>;
            Elementwise<const T, T>(PowerASImpl<T>{static_cast<CudaType>(x2)}, x1_cast, out);
        });
    }
};

CHAINERX_CUDA_REGISTER_KERNEL(PowerASKernel, CudaPowerASKernel);

template <typename T>
struct PowerSAImpl {
    using CudaType = cuda_internal::DataType<T>;
    __device__ void operator()(int64_t /*i*/, CudaType x2, CudaType& out) { out = cuda::Power(x1, x2); }
    CudaType x1;
};

class CudaPowerSAKernel : public PowerSAKernel {
public:
    void Call(Scalar x1, const Array& x2, const Array& out) {
        Device& device = x2.device();
        device.CheckDevicesCompatible(x2, out);
        const Array& x2_cast = x2.dtype() == out.dtype() ? x2 : x2.AsType(out.dtype());
        CudaSetDeviceScope scope{device.index()};
        VisitDtype(out.dtype(), [&](auto pt) {
            using T = typename decltype(pt)::type;
            using CudaType = cuda_internal::DataType<T>;
            Elementwise<const T, T>(PowerSAImpl<T>{static_cast<CudaType>(x1)}, x2_cast, out);
        });
    }
};

CHAINERX_CUDA_REGISTER_KERNEL(PowerSAKernel, CudaPowerSAKernel);

CHAINERX_CUDA_REGISTER_ELTWISE_FLOAT_UNARY_KERNEL(FabsKernel, { out = cuda::Fabs(x); });

CHAINERX_CUDA_REGISTER_ELTWISE_DTYPE_UNARY_KERNEL(SignKernel, { out = cuda::Sign(x); }, VisitNumericDtype);

template <typename T>
struct IsNanImpl {
    using CudaType = cuda_internal::DataType<T>;
    __device__ void operator()(int64_t /*i*/, CudaType x, bool& out) { out = cuda::IsNan(x); }
};

class CudaIsNanKernel : public IsNanKernel {
public:
    void Call(const Array& x, const Array& out) override {
        Device& device = x.device();
        device.CheckDevicesCompatible(x, out);
        CudaSetDeviceScope scope{device.index()};
        VisitDtype(x.dtype(), [&](auto pt) {
            using T = typename decltype(pt)::type;
            Elementwise<const T, bool>(IsNanImpl<T>{}, x, out);
        });
    }
};

CHAINERX_CUDA_REGISTER_KERNEL(IsNanKernel, CudaIsNanKernel);

template <typename T>
struct IsInfImpl {
    using CudaType = cuda_internal::DataType<T>;
    __device__ void operator()(int64_t /*i*/, CudaType x, bool& out) { out = cuda::IsInf(x); }
};

class CudaIsInfKernel : public IsInfKernel {
public:
    void Call(const Array& x, const Array& out) override {
        Device& device = x.device();
        device.CheckDevicesCompatible(x, out);
        CudaSetDeviceScope scope{device.index()};
        VisitDtype(x.dtype(), [&](auto pt) {
            using T = typename decltype(pt)::type;
            Elementwise<const T, bool>(IsInfImpl<T>{}, x, out);
        });
    }
};

CHAINERX_CUDA_REGISTER_KERNEL(IsInfKernel, CudaIsInfKernel);

template <typename T>
struct IsFiniteImpl {
    using CudaType = cuda_internal::DataType<T>;
    __device__ void operator()(int64_t /*i*/, CudaType x, bool& out) { out = !(cuda::IsInf(x) || cuda::IsNan(x)); }
};

class CudaIsFiniteKernel : public IsFiniteKernel {
public:
    void Call(const Array& x, const Array& out) override {
        Device& device = x.device();
        device.CheckDevicesCompatible(x, out);
        CudaSetDeviceScope scope{device.index()};
        VisitDtype(x.dtype(), [&](auto pt) {
            using T = typename decltype(pt)::type;
            Elementwise<const T, bool>(IsFiniteImpl<T>{}, x, out);
        });
    }
};

CHAINERX_CUDA_REGISTER_KERNEL(IsFiniteKernel, CudaIsFiniteKernel);

template <typename T>
struct CeilImpl {
    using CudaType = cuda_internal::DataType<T>;
    __device__ void operator()(int64_t /*i*/, CudaType x, CudaType& out) { out = cuda::Ceil(x); }
};

class CudaCeilKernel : public CeilKernel {
public:
    void Call(const Array& x, const Array& out) override {
        Device& device = x.device();
        device.CheckDevicesCompatible(x, out);
        CudaSetDeviceScope scope{device.index()};
        const Array& x_cast = x.dtype() == out.dtype() ? x : x.AsType(out.dtype());
        VisitFloatingPointDtype(out.dtype(), [&](auto pt) {
            using T = typename decltype(pt)::type;
            Elementwise<const T, T>(CeilImpl<T>{}, x_cast, out);
        });
    }
};

CHAINERX_CUDA_REGISTER_KERNEL(CeilKernel, CudaCeilKernel);

template <typename T>
struct FloorImpl {
    using CudaType = cuda_internal::DataType<T>;
    __device__ void operator()(int64_t /*i*/, CudaType x, CudaType& out) { out = cuda::Floor(x); }
};

class CudaFloorKernel : public FloorKernel {
public:
    void Call(const Array& x, const Array& out) override {
        Device& device = x.device();
        device.CheckDevicesCompatible(x, out);
        CudaSetDeviceScope scope{device.index()};
        const Array& x_cast = x.dtype() == out.dtype() ? x : x.AsType(out.dtype());
        VisitFloatingPointDtype(out.dtype(), [&](auto pt) {
            using T = typename decltype(pt)::type;
            Elementwise<const T, T>(FloorImpl<T>{}, x_cast, out);
        });
    }
};

CHAINERX_CUDA_REGISTER_KERNEL(FloorKernel, CudaFloorKernel);

}  // namespace
}  // namespace cuda
}  // namespace chainerx
