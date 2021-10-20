// This license applies to all the code in this repository except that written by third
// parties, namely the files in benchmarks/ext, which have their own licenses, and Jeff
// Preshing's semaphore implementation (used in the blocking queues) which has a zlib
// license (embedded in atomicops.h).
//
// Simplified BSD License:
//
// Copyright (c) 2013-2021, Cameron Desrochers
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
//
// - Redistributions of source code must retain the above copyright notice, this list of
// conditions and the following disclaimer.
// - Redistributions in binary form must reproduce the above copyright notice, this list of
// conditions and the following disclaimer in the documentation and/or other materials
// provided with the distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY
// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
// MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL
// THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
// 	OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
// 	HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR
// 	TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
// 	EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


// ©2013-2020 Cameron Desrochers.
// Distributed under the simplified BSD license (see the license file that
// should have come with this header).

// atomicops.h

// ©2013-2016 Cameron Desrochers.
// Distributed under the simplified BSD license (see the license file that
// should have come with this header).
// Uses Jeff Preshing's semaphore implementation (under the terms of its
// separate zlib license, embedded below).

#pragma once

// Provides portable (VC++2010+, Intel ICC 13, GCC 4.7+, and anything C++11 compliant) implementation
// of low-level memory barriers, plus a few semi-portable utility macros (for inlining and alignment).
// Also has a basic atomic type (limited to hardware-supported atomics with no memory ordering guarantees).
// Uses the AE_* prefix for macros (historical reasons), and the "moodycamel" namespace for symbols.

#include <cerrno>
#include <cassert>
#include <type_traits>
#include <cerrno>
#include <cstdint>
#include <ctime>

// Platform detection
#if defined(__INTEL_COMPILER)
#define AE_ICC
#elif defined(_MSC_VER)
#define AE_VCPP
#elif defined(__GNUC__)
#define AE_GCC
#endif

#if defined(_M_IA64) || defined(__ia64__)
#define AE_ARCH_IA64
#elif defined(_WIN64) || defined(__amd64__) || defined(_M_X64) || defined(__x86_64__)
#define AE_ARCH_X64
#elif defined(_M_IX86) || defined(__i386__)
#define AE_ARCH_X86
#elif defined(_M_PPC) || defined(__powerpc__)
#define AE_ARCH_PPC
#else
#define AE_ARCH_UNKNOWN
#endif


// AE_UNUSED
#define AE_UNUSED(x) ((void)x)

// AE_NO_TSAN
#if defined(__has_feature)
#if __has_feature(thread_sanitizer)
#define AE_NO_TSAN __attribute__((no_sanitize("thread")))
#else
#define AE_NO_TSAN
#endif
#else
#define AE_NO_TSAN
#endif


// AE_FORCEINLINE
#if defined(AE_VCPP) || defined(AE_ICC)
#define AE_FORCEINLINE __forceinline
#elif defined(AE_GCC)
//#define AE_FORCEINLINE __attribute__((always_inline))
#define AE_FORCEINLINE inline
#else
#define AE_FORCEINLINE inline
#endif


// AE_ALIGN
#if defined(AE_VCPP) || defined(AE_ICC)
#define AE_ALIGN(x) __declspec(align(x))
#elif defined(AE_GCC)
#define AE_ALIGN(x) __attribute__((aligned(x)))
#else
// Assume GCC compliant syntax...
#define AE_ALIGN(x) __attribute__((aligned(x)))
#endif


// Portable atomic fences implemented below:

namespace tracy {

enum memory_order {
	memory_order_relaxed,
	memory_order_acquire,
	memory_order_release,
	memory_order_acq_rel,
	memory_order_seq_cst,

	// memory_order_sync: Forces a full sync:
	// #LoadLoad, #LoadStore, #StoreStore, and most significantly, #StoreLoad
	memory_order_sync = memory_order_seq_cst
};

}    // end namespace moodycamel

#if (defined(AE_VCPP) && (_MSC_VER < 1700 || defined(__cplusplus_cli))) || (defined(AE_ICC) && __INTEL_COMPILER < 1600)
	 // VS2010 and ICC13 don't support std::atomic_*_fence, implement our own fences

#include <intrin.h>

#if defined(AE_ARCH_X64) || defined(AE_ARCH_X86)
#define AeFullSync _mm_mfence
#define AeLiteSync _mm_mfence
#elif defined(AE_ARCH_IA64)
#define AeFullSync __mf
#define AeLiteSync __mf
#elif defined(AE_ARCH_PPC)
#include <ppcintrinsics.h>
#define AeFullSync __sync
#define AeLiteSync __lwsync
#endif


#ifdef AE_VCPP
#pragma warning(push)
#pragma warning(disable: 4365)		// Disable erroneous 'conversion from long to unsigned int, signed/unsigned mismatch' error when using `assert`
#ifdef __cplusplus_cli
#pragma managed(push, off)
#endif
#endif

namespace tracy {

AE_FORCEINLINE void compiler_fence(memory_order order) AE_NO_TSAN
{
	switch (order) {
	case memory_order_relaxed: break;
	case memory_order_acquire: _ReadBarrier(); break;
	case memory_order_release: _WriteBarrier(); break;
	case memory_order_acq_rel: _ReadWriteBarrier(); break;
	case memory_order_seq_cst: _ReadWriteBarrier(); break;
	default: assert(false);
	}
}

// x86/x64 have a strong memory model -- all loads and stores have
// acquire and release semantics automatically (so only need compiler
// barriers for those).
#if defined(AE_ARCH_X86) || defined(AE_ARCH_X64)
AE_FORCEINLINE void fence(memory_order order) AE_NO_TSAN
{
	switch (order) {
	case memory_order_relaxed: break;
	case memory_order_acquire: _ReadBarrier(); break;
	case memory_order_release: _WriteBarrier(); break;
	case memory_order_acq_rel: _ReadWriteBarrier(); break;
	case memory_order_seq_cst:
		_ReadWriteBarrier();
		AeFullSync();
		_ReadWriteBarrier();
		break;
	default: assert(false);
	}
}
#else
AE_FORCEINLINE void fence(memory_order order) AE_NO_TSAN
{
	// Non-specialized arch, use heavier memory barriers everywhere just in case :-(
	switch (order) {
	case memory_order_relaxed:
		break;
	case memory_order_acquire:
		_ReadBarrier();
		AeLiteSync();
		_ReadBarrier();
		break;
	case memory_order_release:
		_WriteBarrier();
		AeLiteSync();
		_WriteBarrier();
		break;
	case memory_order_acq_rel:
		_ReadWriteBarrier();
		AeLiteSync();
		_ReadWriteBarrier();
		break;
	case memory_order_seq_cst:
		_ReadWriteBarrier();
		AeFullSync();
		_ReadWriteBarrier();
		break;
	default: assert(false);
	}
}
#endif
}    // end namespace moodycamel
#else
	 // Use standard library of atomics
#include <atomic>

namespace tracy {

AE_FORCEINLINE void compiler_fence(memory_order order) AE_NO_TSAN
{
	switch (order) {
	case memory_order_relaxed: break;
	case memory_order_acquire: std::atomic_signal_fence(std::memory_order_acquire); break;
	case memory_order_release: std::atomic_signal_fence(std::memory_order_release); break;
	case memory_order_acq_rel: std::atomic_signal_fence(std::memory_order_acq_rel); break;
	case memory_order_seq_cst: std::atomic_signal_fence(std::memory_order_seq_cst); break;
	default: assert(false);
	}
}

AE_FORCEINLINE void fence(memory_order order) AE_NO_TSAN
{
	switch (order) {
	case memory_order_relaxed: break;
	case memory_order_acquire: std::atomic_thread_fence(std::memory_order_acquire); break;
	case memory_order_release: std::atomic_thread_fence(std::memory_order_release); break;
	case memory_order_acq_rel: std::atomic_thread_fence(std::memory_order_acq_rel); break;
	case memory_order_seq_cst: std::atomic_thread_fence(std::memory_order_seq_cst); break;
	default: assert(false);
	}
}

}    // end namespace moodycamel

#endif


#if !defined(AE_VCPP) || (_MSC_VER >= 1700 && !defined(__cplusplus_cli))
#define AE_USE_STD_ATOMIC_FOR_WEAK_ATOMIC
#endif

#ifdef AE_USE_STD_ATOMIC_FOR_WEAK_ATOMIC
#include <atomic>
#endif
#include <utility>

	 // WARNING: *NOT* A REPLACEMENT FOR std::atomic. READ CAREFULLY:
	 // Provides basic support for atomic variables -- no memory ordering guarantees are provided.
	 // The guarantee of atomicity is only made for types that already have atomic load and store guarantees
	 // at the hardware level -- on most platforms this generally means aligned pointers and integers (only).
namespace tracy {
template<typename T>
class weak_atomic
{
public:
	AE_NO_TSAN weak_atomic() : value() { }
#ifdef AE_VCPP
#pragma warning(push)
#pragma warning(disable: 4100)		// Get rid of (erroneous) 'unreferenced formal parameter' warning
#endif
	template<typename U> AE_NO_TSAN weak_atomic(U&& x) : value(std::forward<U>(x)) {  }
#ifdef __cplusplus_cli
	// Work around bug with universal reference/nullptr combination that only appears when /clr is on
	AE_NO_TSAN weak_atomic(nullptr_t) : value(nullptr) {  }
#endif
	AE_NO_TSAN weak_atomic(weak_atomic const& other) : value(other.load()) {  }
	AE_NO_TSAN weak_atomic(weak_atomic&& other) : value(std::move(other.load())) {  }
#ifdef AE_VCPP
#pragma warning(pop)
#endif

	AE_FORCEINLINE operator T() const AE_NO_TSAN { return load(); }


#ifndef AE_USE_STD_ATOMIC_FOR_WEAK_ATOMIC
	template<typename U> AE_FORCEINLINE weak_atomic const& operator=(U&& x) AE_NO_TSAN { value = std::forward<U>(x); return *this; }
	AE_FORCEINLINE weak_atomic const& operator=(weak_atomic const& other) AE_NO_TSAN { value = other.value; return *this; }

	AE_FORCEINLINE T load() const AE_NO_TSAN { return value; }

	AE_FORCEINLINE T fetch_add_acquire(T increment) AE_NO_TSAN
	{
#if defined(AE_ARCH_X64) || defined(AE_ARCH_X86)
		if (sizeof(T) == 4) return _InterlockedExchangeAdd((long volatile*)&value, (long)increment);
#if defined(_M_AMD64)
		else if (sizeof(T) == 8) return _InterlockedExchangeAdd64((long long volatile*)&value, (long long)increment);
#endif
#else
#error Unsupported platform
#endif
		assert(false && "T must be either a 32 or 64 bit type");
		return value;
	}

	AE_FORCEINLINE T fetch_add_release(T increment) AE_NO_TSAN
	{
#if defined(AE_ARCH_X64) || defined(AE_ARCH_X86)
		if (sizeof(T) == 4) return _InterlockedExchangeAdd((long volatile*)&value, (long)increment);
#if defined(_M_AMD64)
		else if (sizeof(T) == 8) return _InterlockedExchangeAdd64((long long volatile*)&value, (long long)increment);
#endif
#else
#error Unsupported platform
#endif
		assert(false && "T must be either a 32 or 64 bit type");
		return value;
	}
#else
	template<typename U>
	AE_FORCEINLINE weak_atomic const& operator=(U&& x) AE_NO_TSAN
	{
		value.store(std::forward<U>(x), std::memory_order_relaxed);
		return *this;
	}

	AE_FORCEINLINE weak_atomic const& operator=(weak_atomic const& other) AE_NO_TSAN
	{
		value.store(other.value.load(std::memory_order_relaxed), std::memory_order_relaxed);
		return *this;
	}

	AE_FORCEINLINE T load() const AE_NO_TSAN { return value.load(std::memory_order_relaxed); }

	AE_FORCEINLINE T fetch_add_acquire(T increment) AE_NO_TSAN
	{
		return value.fetch_add(increment, std::memory_order_acquire);
	}

	AE_FORCEINLINE T fetch_add_release(T increment) AE_NO_TSAN
	{
		return value.fetch_add(increment, std::memory_order_release);
	}
#endif


private:
#ifndef AE_USE_STD_ATOMIC_FOR_WEAK_ATOMIC
	// No std::atomic support, but still need to circumvent compiler optimizations.
	// `volatile` will make memory access slow, but is guaranteed to be reliable.
	volatile T value;
#else
	std::atomic<T> value;
#endif
};

}	// end namespace moodycamel



	// Portable single-producer, single-consumer semaphore below:

#if defined(_WIN32)
	// Avoid including windows.h in a header; we only need a handful of
	// items, so we'll redeclare them here (this is relatively safe since
	// the API generally has to remain stable between Windows versions).
	// I know this is an ugly hack but it still beats polluting the global
	// namespace with thousands of generic names or adding a .cpp for nothing.
extern "C" {
	struct _SECURITY_ATTRIBUTES;
	__declspec(dllimport) void* __stdcall CreateSemaphoreW(_SECURITY_ATTRIBUTES* lpSemaphoreAttributes, long lInitialCount, long lMaximumCount, const wchar_t* lpName);
	__declspec(dllimport) int __stdcall CloseHandle(void* hObject);
	__declspec(dllimport) unsigned long __stdcall WaitForSingleObject(void* hHandle, unsigned long dwMilliseconds);
	__declspec(dllimport) int __stdcall ReleaseSemaphore(void* hSemaphore, long lReleaseCount, long* lpPreviousCount);
}
#elif defined(__MACH__)
#include <mach/mach.h>
#elif defined(__unix__)
#include <semaphore.h>
#endif

namespace tracy
{
// Code in the spsc_sema namespace below is an adaptation of Jeff Preshing's
// portable + lightweight semaphore implementations, originally from
// https://github.com/preshing/cpp11-on-multicore/blob/master/common/sema.h
// LICENSE:
// Copyright (c) 2015 Jeff Preshing
//
// This software is provided 'as-is', without any express or implied
// warranty. In no event will the authors be held liable for any damages
// arising from the use of this software.
//
// Permission is granted to anyone to use this software for any purpose,
// including commercial applications, and to alter it and redistribute it
// freely, subject to the following restrictions:
//
// 1. The origin of this software must not be misrepresented; you must not
//    claim that you wrote the original software. If you use this software
//    in a product, an acknowledgement in the product documentation would be
//    appreciated but is not required.
// 2. Altered source versions must be plainly marked as such, and must not be
//    misrepresented as being the original software.
// 3. This notice may not be removed or altered from any source distribution.
namespace spsc_sema
{
#if defined(_WIN32)
class Semaphore
{
private:
	void* m_hSema;

	Semaphore(const Semaphore& other);
	Semaphore& operator=(const Semaphore& other);

public:
	AE_NO_TSAN Semaphore(int initialCount = 0) : m_hSema()
	{
		assert(initialCount >= 0);
		const long maxLong = 0x7fffffff;
		m_hSema = CreateSemaphoreW(nullptr, initialCount, maxLong, nullptr);
		assert(m_hSema);
	}

	AE_NO_TSAN ~Semaphore()
	{
		CloseHandle(m_hSema);
	}

	bool wait() AE_NO_TSAN
	{
		const unsigned long infinite = 0xffffffff;
		return WaitForSingleObject(m_hSema, infinite) == 0;
	}

	bool try_wait() AE_NO_TSAN
	{
		return WaitForSingleObject(m_hSema, 0) == 0;
	}

	bool timed_wait(std::uint64_t usecs) AE_NO_TSAN
	{
		return WaitForSingleObject(m_hSema, (unsigned long)(usecs / 1000)) == 0;
	}

	void signal(int count = 1) AE_NO_TSAN
	{
		while (!ReleaseSemaphore(m_hSema, count, nullptr));
	}
};
#elif defined(__MACH__)
//---------------------------------------------------------
// Semaphore (Apple iOS and OSX)
// Can't use POSIX semaphores due to http://lists.apple.com/archives/darwin-kernel/2009/Apr/msg00010.html
//---------------------------------------------------------
class Semaphore
{
private:
	semaphore_t m_sema;

	Semaphore(const Semaphore& other);
	Semaphore& operator=(const Semaphore& other);

public:
	AE_NO_TSAN Semaphore(int initialCount = 0) : m_sema()
	{
		assert(initialCount >= 0);
		kern_return_t rc = semaphore_create(mach_task_self(), &m_sema, SYNC_POLICY_FIFO, initialCount);
		assert(rc == KERN_SUCCESS);
		AE_UNUSED(rc);
	}

	AE_NO_TSAN ~Semaphore()
	{
		semaphore_destroy(mach_task_self(), m_sema);
	}

	bool wait() AE_NO_TSAN
	{
		return semaphore_wait(m_sema) == KERN_SUCCESS;
	}

	bool try_wait() AE_NO_TSAN
	{
		return timed_wait(0);
	}

	bool timed_wait(std::uint64_t timeout_usecs) AE_NO_TSAN
	{
		mach_timespec_t ts;
		ts.tv_sec = static_cast<unsigned int>(timeout_usecs / 1000000);
		ts.tv_nsec = static_cast<int>((timeout_usecs % 1000000) * 1000);

		// added in OSX 10.10: https://developer.apple.com/library/prerelease/mac/documentation/General/Reference/APIDiffsMacOSX10_10SeedDiff/modules/Darwin.html
		kern_return_t rc = semaphore_timedwait(m_sema, ts);
		return rc == KERN_SUCCESS;
	}

	void signal() AE_NO_TSAN
	{
		while (semaphore_signal(m_sema) != KERN_SUCCESS);
	}

	void signal(int count) AE_NO_TSAN
	{
		while (count-- > 0)
		{
			while (semaphore_signal(m_sema) != KERN_SUCCESS);
		}
	}
};
#elif defined(__unix__)
//---------------------------------------------------------
// Semaphore (POSIX, Linux)
//---------------------------------------------------------
class Semaphore
{
private:
	sem_t m_sema;

	Semaphore(const Semaphore& other);
	Semaphore& operator=(const Semaphore& other);

public:
	AE_NO_TSAN Semaphore(int initialCount = 0) : m_sema()
	{
		assert(initialCount >= 0);
		int rc = sem_init(&m_sema, 0, static_cast<unsigned int>(initialCount));
		assert(rc == 0);
		AE_UNUSED(rc);
	}

	AE_NO_TSAN ~Semaphore()
	{
		sem_destroy(&m_sema);
	}

	bool wait() AE_NO_TSAN
	{
		// http://stackoverflow.com/questions/2013181/gdb-causes-sem-wait-to-fail-with-eintr-error
		int rc;
		do
		{
			rc = sem_wait(&m_sema);
		}
		while (rc == -1 && errno == EINTR);
		return rc == 0;
	}

	bool try_wait() AE_NO_TSAN
	{
		int rc;
		do {
			rc = sem_trywait(&m_sema);
		} while (rc == -1 && errno == EINTR);
		return rc == 0;
	}

	bool timed_wait(std::uint64_t usecs) AE_NO_TSAN
	{
		struct timespec ts;
		const int usecs_in_1_sec = 1000000;
		const int nsecs_in_1_sec = 1000000000;
		clock_gettime(CLOCK_REALTIME, &ts);
		ts.tv_sec += static_cast<time_t>(usecs / usecs_in_1_sec);
		ts.tv_nsec += static_cast<long>(usecs % usecs_in_1_sec) * 1000;
		// sem_timedwait bombs if you have more than 1e9 in tv_nsec
		// so we have to clean things up before passing it in
		if (ts.tv_nsec >= nsecs_in_1_sec) {
			ts.tv_nsec -= nsecs_in_1_sec;
			++ts.tv_sec;
		}

		int rc;
		do {
			rc = sem_timedwait(&m_sema, &ts);
		} while (rc == -1 && errno == EINTR);
		return rc == 0;
	}

	void signal() AE_NO_TSAN
	{
		while (sem_post(&m_sema) == -1);
	}

	void signal(int count) AE_NO_TSAN
	{
		while (count-- > 0)
		{
			while (sem_post(&m_sema) == -1);
		}
	}
};
#else
#error Unsupported platform! (No semaphore wrapper available)
#endif

//---------------------------------------------------------
// LightweightSemaphore
//---------------------------------------------------------
class LightweightSemaphore
{
public:
	typedef std::make_signed<std::size_t>::type ssize_t;

private:
	weak_atomic<ssize_t> m_count;
	Semaphore m_sema;

	bool waitWithPartialSpinning(std::int64_t timeout_usecs = -1) AE_NO_TSAN
	{
		ssize_t oldCount;
		// Is there a better way to set the initial spin count?
		// If we lower it to 1000, testBenaphore becomes 15x slower on my Core i7-5930K Windows PC,
		// as threads start hitting the kernel semaphore.
		int spin = 1024;
		while (--spin >= 0)
		{
			if (m_count.load() > 0)
			{
				m_count.fetch_add_acquire(-1);
				return true;
			}
			compiler_fence(memory_order_acquire);     // Prevent the compiler from collapsing the loop.
		}
		oldCount = m_count.fetch_add_acquire(-1);
		if (oldCount > 0)
			return true;
		if (timeout_usecs < 0)
		{
			if (m_sema.wait())
				return true;
		}
		if (timeout_usecs > 0 && m_sema.timed_wait(static_cast<uint64_t>(timeout_usecs)))
			return true;
		// At this point, we've timed out waiting for the semaphore, but the
		// count is still decremented indicating we may still be waiting on
		// it. So we have to re-adjust the count, but only if the semaphore
		// wasn't signaled enough times for us too since then. If it was, we
		// need to release the semaphore too.
		while (true)
		{
			oldCount = m_count.fetch_add_release(1);
			if (oldCount < 0)
				return false;    // successfully restored things to the way they were
								 // Oh, the producer thread just signaled the semaphore after all. Try again:
			oldCount = m_count.fetch_add_acquire(-1);
			if (oldCount > 0 && m_sema.try_wait())
				return true;
		}
	}

public:
	AE_NO_TSAN LightweightSemaphore(ssize_t initialCount = 0) : m_count(initialCount), m_sema()
	{
		assert(initialCount >= 0);
	}

	bool tryWait() AE_NO_TSAN
	{
		if (m_count.load() > 0)
		{
			m_count.fetch_add_acquire(-1);
			return true;
		}
		return false;
	}

	bool wait() AE_NO_TSAN
	{
		return tryWait() || waitWithPartialSpinning();
	}

	bool wait(std::int64_t timeout_usecs) AE_NO_TSAN
	{
		return tryWait() || waitWithPartialSpinning(timeout_usecs);
	}

	void signal(ssize_t count = 1) AE_NO_TSAN
	{
		assert(count >= 0);
		ssize_t oldCount = m_count.fetch_add_release(count);
		assert(oldCount >= -1);
		if (oldCount < 0)
		{
			m_sema.signal(1);
		}
	}

	std::size_t availableApprox() const AE_NO_TSAN
	{
		ssize_t count = m_count.load();
		return count > 0 ? static_cast<std::size_t>(count) : 0;
	}
};
}	// end namespace spsc_sema
}	// end namespace moodycamel

#if defined(AE_VCPP) && (_MSC_VER < 1700 || defined(__cplusplus_cli))
#pragma warning(pop)
#ifdef __cplusplus_cli
#pragma managed(pop)
#endif
#endif

// end of atomicops.h

#include <new>
#include <type_traits>
#include <utility>
#include <cassert>
#include <stdexcept>
#include <new>
#include <cstdint>
#include <cstdlib>		// For malloc/free/abort & size_t
#include <memory>
#if __cplusplus > 199711L || _MSC_VER >= 1700 // C++11 or VS2012
#include <chrono>
#endif


// A lock-free queue for a single-consumer, single-producer architecture.
// The queue is also wait-free in the common path (except if more memory
// needs to be allocated, in which case malloc is called).
// Allocates memory sparingly, and only once if the original maximum size
// estimate is never exceeded.
// Tested on x86/x64 processors, but semantics should be correct for all
// architectures (given the right implementations in atomicops.h), provided
// that aligned integer and pointer accesses are naturally atomic.
// Note that there should only be one consumer thread and producer thread;
// Switching roles of the threads, or using multiple consecutive threads for
// one role, is not safe unless properly synchronized.
// Using the queue exclusively from one thread is fine, though a bit silly.

#ifndef MOODYCAMEL_CACHE_LINE_SIZE
#define MOODYCAMEL_CACHE_LINE_SIZE 64
#endif

#ifndef MOODYCAMEL_EXCEPTIONS_ENABLED
#if (defined(_MSC_VER) && defined(_CPPUNWIND)) || (defined(__GNUC__) && defined(__EXCEPTIONS)) || (!defined(_MSC_VER) && !defined(__GNUC__))
#define MOODYCAMEL_EXCEPTIONS_ENABLED
#endif
#endif

#ifndef MOODYCAMEL_HAS_EMPLACE
#if !defined(_MSC_VER) || _MSC_VER >= 1800 // variadic templates: either a non-MS compiler or VS >= 2013
#define MOODYCAMEL_HAS_EMPLACE    1
#endif
#endif

#ifndef MOODYCAMEL_MAYBE_ALIGN_TO_CACHELINE
#if defined (__APPLE__) && defined (__MACH__) && __cplusplus >= 201703L
// This is required to find out what deployment target we are using
#include <CoreFoundation/CoreFoundation.h>
#if !defined(MAC_OS_X_VERSION_MIN_REQUIRED) || MAC_OS_X_VERSION_MIN_REQUIRED < MAC_OS_X_VERSION_10_14
// C++17 new(size_t, align_val_t) is not backwards-compatible with older versions of macOS, so we can't support over-alignment in this case
#define MOODYCAMEL_MAYBE_ALIGN_TO_CACHELINE
#endif
#endif
#endif

#ifndef MOODYCAMEL_MAYBE_ALIGN_TO_CACHELINE
#define MOODYCAMEL_MAYBE_ALIGN_TO_CACHELINE AE_ALIGN(MOODYCAMEL_CACHE_LINE_SIZE)
#endif

#ifdef AE_VCPP
#pragma warning(push)
#pragma warning(disable: 4324)	// structure was padded due to __declspec(align())
#pragma warning(disable: 4820)	// padding was added
#pragma warning(disable: 4127)	// conditional expression is constant
#endif

namespace tracy {

template<typename T, size_t MAX_BLOCK_SIZE = 512>
class MOODYCAMEL_MAYBE_ALIGN_TO_CACHELINE ReaderWriterQueue
{
	// Design: Based on a queue-of-queues. The low-level queues are just
	// circular buffers with front and tail indices indicating where the
	// next element to dequeue is and where the next element can be enqueued,
	// respectively. Each low-level queue is called a "block". Each block
	// wastes exactly one element's worth of space to keep the design simple
	// (if front == tail then the queue is empty, and can't be full).
	// The high-level queue is a circular linked list of blocks; again there
	// is a front and tail, but this time they are pointers to the blocks.
	// The front block is where the next element to be dequeued is, provided
	// the block is not empty. The back block is where elements are to be
	// enqueued, provided the block is not full.
	// The producer thread owns all the tail indices/pointers. The consumer
	// thread owns all the front indices/pointers. Both threads read each
	// other's variables, but only the owning thread updates them. E.g. After
	// the consumer reads the producer's tail, the tail may change before the
	// consumer is done dequeuing an object, but the consumer knows the tail
	// will never go backwards, only forwards.
	// If there is no room to enqueue an object, an additional block (of
	// equal size to the last block) is added. Blocks are never removed.

public:
	typedef T value_type;

	// Constructs a queue that can hold at least `size` elements without further
	// allocations. If more than MAX_BLOCK_SIZE elements are requested,
	// then several blocks of MAX_BLOCK_SIZE each are reserved (including
	// at least one extra buffer block).
	AE_NO_TSAN explicit ReaderWriterQueue(size_t size = 15)
#ifndef NDEBUG
		: enqueuing(false)
		,dequeuing(false)
#endif
	{
		assert(MAX_BLOCK_SIZE == ceilToPow2(MAX_BLOCK_SIZE) && "MAX_BLOCK_SIZE must be a power of 2");
		assert(MAX_BLOCK_SIZE >= 2 && "MAX_BLOCK_SIZE must be at least 2");

		Block* firstBlock = nullptr;

		largestBlockSize = ceilToPow2(size + 1);		// We need a spare slot to fit size elements in the block
		if (largestBlockSize > MAX_BLOCK_SIZE * 2) {
			// We need a spare block in case the producer is writing to a different block the consumer is reading from, and
			// wants to enqueue the maximum number of elements. We also need a spare element in each block to avoid the ambiguity
			// between front == tail meaning "empty" and "full".
			// So the effective number of slots that are guaranteed to be usable at any time is the block size - 1 times the
			// number of blocks - 1. Solving for size and applying a ceiling to the division gives us (after simplifying):
			size_t initialBlockCount = (size + MAX_BLOCK_SIZE * 2 - 3) / (MAX_BLOCK_SIZE - 1);
			largestBlockSize = MAX_BLOCK_SIZE;
			Block* lastBlock = nullptr;
			for (size_t i = 0; i != initialBlockCount; ++i) {
				auto block = make_block(largestBlockSize);
				if (block == nullptr) {
#ifdef MOODYCAMEL_EXCEPTIONS_ENABLED
					throw std::bad_alloc();
#else
					abort();
#endif
				}
				if (firstBlock == nullptr) {
					firstBlock = block;
				}
				else {
					lastBlock->next = block;
				}
				lastBlock = block;
				block->next = firstBlock;
			}
		}
		else {
			firstBlock = make_block(largestBlockSize);
			if (firstBlock == nullptr) {
#ifdef MOODYCAMEL_EXCEPTIONS_ENABLED
				throw std::bad_alloc();
#else
				abort();
#endif
			}
			firstBlock->next = firstBlock;
		}
		frontBlock = firstBlock;
		tailBlock = firstBlock;

		// Make sure the reader/writer threads will have the initialized memory setup above:
		fence(memory_order_sync);
	}

	// Note: The queue should not be accessed concurrently while it's
	// being moved. It's up to the user to synchronize this.
	AE_NO_TSAN ReaderWriterQueue(ReaderWriterQueue&& other)
		: frontBlock(other.frontBlock.load()),
		tailBlock(other.tailBlock.load()),
		largestBlockSize(other.largestBlockSize)
#ifndef NDEBUG
		,enqueuing(false)
		,dequeuing(false)
#endif
	{
		other.largestBlockSize = 32;
		Block* b = other.make_block(other.largestBlockSize);
		if (b == nullptr) {
#ifdef MOODYCAMEL_EXCEPTIONS_ENABLED
			throw std::bad_alloc();
#else
			abort();
#endif
		}
		b->next = b;
		other.frontBlock = b;
		other.tailBlock = b;
	}

	// Note: The queue should not be accessed concurrently while it's
	// being moved. It's up to the user to synchronize this.
	ReaderWriterQueue& operator=(ReaderWriterQueue&& other) AE_NO_TSAN
	{
		Block* b = frontBlock.load();
		frontBlock = other.frontBlock.load();
		other.frontBlock = b;
		b = tailBlock.load();
		tailBlock = other.tailBlock.load();
		other.tailBlock = b;
		std::swap(largestBlockSize, other.largestBlockSize);
		return *this;
	}

	// Note: The queue should not be accessed concurrently while it's
	// being deleted. It's up to the user to synchronize this.
	AE_NO_TSAN ~ReaderWriterQueue()
	{
		// Make sure we get the latest version of all variables from other CPUs:
		fence(memory_order_sync);

		// Destroy any remaining objects in queue and free memory
		Block* frontBlock_ = frontBlock;
		Block* block = frontBlock_;
		do {
			Block* nextBlock = block->next;
			size_t blockFront = block->front;
			size_t blockTail = block->tail;

			for (size_t i = blockFront; i != blockTail; i = (i + 1) & block->sizeMask) {
				auto element = reinterpret_cast<T*>(block->data + i * sizeof(T));
				element->~T();
				(void)element;
			}

			auto rawBlock = block->rawThis;
			block->~Block();
			std::free(rawBlock);
			block = nextBlock;
		} while (block != frontBlock_);
	}


	// Enqueues a copy of element if there is room in the queue.
	// Returns true if the element was enqueued, false otherwise.
	// Does not allocate memory.
	AE_FORCEINLINE bool try_enqueue(T const& element) AE_NO_TSAN
	{
		return inner_enqueue<CannotAlloc>(element);
	}

	// Enqueues a moved copy of element if there is room in the queue.
	// Returns true if the element was enqueued, false otherwise.
	// Does not allocate memory.
	AE_FORCEINLINE bool try_enqueue(T&& element) AE_NO_TSAN
	{
		return inner_enqueue<CannotAlloc>(std::forward<T>(element));
	}

#if MOODYCAMEL_HAS_EMPLACE
	// Like try_enqueue() but with emplace semantics (i.e. construct-in-place).
	template<typename... Args>
	AE_FORCEINLINE bool try_emplace(Args&&... args) AE_NO_TSAN
	{
		return inner_enqueue<CannotAlloc>(std::forward<Args>(args)...);
	}
#endif

	// Enqueues a copy of element on the queue.
	// Allocates an additional block of memory if needed.
	// Only fails (returns false) if memory allocation fails.
	AE_FORCEINLINE bool enqueue(T const& element) AE_NO_TSAN
	{
		return inner_enqueue<CanAlloc>(element);
	}

	// Enqueues a moved copy of element on the queue.
	// Allocates an additional block of memory if needed.
	// Only fails (returns false) if memory allocation fails.
	AE_FORCEINLINE bool enqueue(T&& element) AE_NO_TSAN
	{
		return inner_enqueue<CanAlloc>(std::forward<T>(element));
	}

#if MOODYCAMEL_HAS_EMPLACE
	// Like enqueue() but with emplace semantics (i.e. construct-in-place).
	template<typename... Args>
	AE_FORCEINLINE bool emplace(Args&&... args) AE_NO_TSAN
	{
		return inner_enqueue<CanAlloc>(std::forward<Args>(args)...);
	}
#endif

	// Attempts to dequeue an element; if the queue is empty,
	// returns false instead. If the queue has at least one element,
	// moves front to result using operator=, then returns true.
	template<typename U>
	bool try_dequeue(U& result) AE_NO_TSAN
	{
#ifndef NDEBUG
		ReentrantGuard guard(this->dequeuing);
#endif

		// High-level pseudocode:
		// Remember where the tail block is
		// If the front block has an element in it, dequeue it
		// Else
		//     If front block was the tail block when we entered the function, return false
		//     Else advance to next block and dequeue the item there

		// Note that we have to use the value of the tail block from before we check if the front
		// block is full or not, in case the front block is empty and then, before we check if the
		// tail block is at the front block or not, the producer fills up the front block *and
		// moves on*, which would make us skip a filled block. Seems unlikely, but was consistently
		// reproducible in practice.
		// In order to avoid overhead in the common case, though, we do a double-checked pattern
		// where we have the fast path if the front block is not empty, then read the tail block,
		// then re-read the front block and check if it's not empty again, then check if the tail
		// block has advanced.

		Block* frontBlock_ = frontBlock.load();
		size_t blockTail = frontBlock_->localTail;
		size_t blockFront = frontBlock_->front.load();

		if (blockFront != blockTail || blockFront != (frontBlock_->localTail = frontBlock_->tail.load())) {
			fence(memory_order_acquire);

		non_empty_front_block:
			// Front block not empty, dequeue from here
			auto element = reinterpret_cast<T*>(frontBlock_->data + blockFront * sizeof(T));
			result = std::move(*element);
			element->~T();

			blockFront = (blockFront + 1) & frontBlock_->sizeMask;

			fence(memory_order_release);
			frontBlock_->front = blockFront;
		}
		else if (frontBlock_ != tailBlock.load()) {
			fence(memory_order_acquire);

			frontBlock_ = frontBlock.load();
			blockTail = frontBlock_->localTail = frontBlock_->tail.load();
			blockFront = frontBlock_->front.load();
			fence(memory_order_acquire);

			if (blockFront != blockTail) {
				// Oh look, the front block isn't empty after all
				goto non_empty_front_block;
			}

			// Front block is empty but there's another block ahead, advance to it
			Block* nextBlock = frontBlock_->next;
			// Don't need an acquire fence here since next can only ever be set on the tailBlock,
			// and we're not the tailBlock, and we did an acquire earlier after reading tailBlock which
			// ensures next is up-to-date on this CPU in case we recently were at tailBlock.

			size_t nextBlockFront = nextBlock->front.load();
			size_t nextBlockTail = nextBlock->localTail = nextBlock->tail.load();
			fence(memory_order_acquire);

			// Since the tailBlock is only ever advanced after being written to,
			// we know there's for sure an element to dequeue on it
			assert(nextBlockFront != nextBlockTail);
			AE_UNUSED(nextBlockTail);

			// We're done with this block, let the producer use it if it needs
			fence(memory_order_release);		// Expose possibly pending changes to frontBlock->front from last dequeue
			frontBlock = frontBlock_ = nextBlock;

			compiler_fence(memory_order_release);	// Not strictly needed

			auto element = reinterpret_cast<T*>(frontBlock_->data + nextBlockFront * sizeof(T));

			result = std::move(*element);
			element->~T();

			nextBlockFront = (nextBlockFront + 1) & frontBlock_->sizeMask;

			fence(memory_order_release);
			frontBlock_->front = nextBlockFront;
		}
		else {
			// No elements in current block and no other block to advance to
			return false;
		}

		return true;
	}


	// Returns a pointer to the front element in the queue (the one that
	// would be removed next by a call to `try_dequeue` or `pop`). If the
	// queue appears empty at the time the method is called, nullptr is
	// returned instead.
	// Must be called only from the consumer thread.
	T* peek() const AE_NO_TSAN
	{
#ifndef NDEBUG
		ReentrantGuard guard(this->dequeuing);
#endif
		// See try_dequeue() for reasoning

		Block* frontBlock_ = frontBlock.load();
		size_t blockTail = frontBlock_->localTail;
		size_t blockFront = frontBlock_->front.load();

		if (blockFront != blockTail || blockFront != (frontBlock_->localTail = frontBlock_->tail.load())) {
			fence(memory_order_acquire);
		non_empty_front_block:
			return reinterpret_cast<T*>(frontBlock_->data + blockFront * sizeof(T));
		}
		else if (frontBlock_ != tailBlock.load()) {
			fence(memory_order_acquire);
			frontBlock_ = frontBlock.load();
			blockTail = frontBlock_->localTail = frontBlock_->tail.load();
			blockFront = frontBlock_->front.load();
			fence(memory_order_acquire);

			if (blockFront != blockTail) {
				goto non_empty_front_block;
			}

			Block* nextBlock = frontBlock_->next;

			size_t nextBlockFront = nextBlock->front.load();
			fence(memory_order_acquire);

			assert(nextBlockFront != nextBlock->tail.load());
			return reinterpret_cast<T*>(nextBlock->data + nextBlockFront * sizeof(T));
		}

		return nullptr;
	}

	// Removes the front element from the queue, if any, without returning it.
	// Returns true on success, or false if the queue appeared empty at the time
	// `pop` was called.
	bool pop() AE_NO_TSAN
	{
#ifndef NDEBUG
		ReentrantGuard guard(this->dequeuing);
#endif
		// See try_dequeue() for reasoning

		Block* frontBlock_ = frontBlock.load();
		size_t blockTail = frontBlock_->localTail;
		size_t blockFront = frontBlock_->front.load();

		if (blockFront != blockTail || blockFront != (frontBlock_->localTail = frontBlock_->tail.load())) {
			fence(memory_order_acquire);

		non_empty_front_block:
			auto element = reinterpret_cast<T*>(frontBlock_->data + blockFront * sizeof(T));
			element->~T();

			blockFront = (blockFront + 1) & frontBlock_->sizeMask;

			fence(memory_order_release);
			frontBlock_->front = blockFront;
		}
		else if (frontBlock_ != tailBlock.load()) {
			fence(memory_order_acquire);
			frontBlock_ = frontBlock.load();
			blockTail = frontBlock_->localTail = frontBlock_->tail.load();
			blockFront = frontBlock_->front.load();
			fence(memory_order_acquire);

			if (blockFront != blockTail) {
				goto non_empty_front_block;
			}

			// Front block is empty but there's another block ahead, advance to it
			Block* nextBlock = frontBlock_->next;

			size_t nextBlockFront = nextBlock->front.load();
			size_t nextBlockTail = nextBlock->localTail = nextBlock->tail.load();
			fence(memory_order_acquire);

			assert(nextBlockFront != nextBlockTail);
			AE_UNUSED(nextBlockTail);

			fence(memory_order_release);
			frontBlock = frontBlock_ = nextBlock;

			compiler_fence(memory_order_release);

			auto element = reinterpret_cast<T*>(frontBlock_->data + nextBlockFront * sizeof(T));
			element->~T();

			nextBlockFront = (nextBlockFront + 1) & frontBlock_->sizeMask;

			fence(memory_order_release);
			frontBlock_->front = nextBlockFront;
		}
		else {
			// No elements in current block and no other block to advance to
			return false;
		}

		return true;
	}

	// Returns the approximate number of items currently in the queue.
	// Safe to call from both the producer and consumer threads.
	inline size_t size_approx() const AE_NO_TSAN
	{
		size_t result = 0;
		Block* frontBlock_ = frontBlock.load();
		Block* block = frontBlock_;
		do {
			fence(memory_order_acquire);
			size_t blockFront = block->front.load();
			size_t blockTail = block->tail.load();
			result += (blockTail - blockFront) & block->sizeMask;
			block = block->next.load();
		} while (block != frontBlock_);
		return result;
	}

	// Returns the total number of items that could be enqueued without incurring
	// an allocation when this queue is empty.
	// Safe to call from both the producer and consumer threads.
	//
	// NOTE: The actual capacity during usage may be different depending on the consumer.
	//       If the consumer is removing elements concurrently, the producer cannot add to
	//       the block the consumer is removing from until it's completely empty, except in
	//       the case where the producer was writing to the same block the consumer was
	//       reading from the whole time.
	inline size_t max_capacity() const {
		size_t result = 0;
		Block* frontBlock_ = frontBlock.load();
		Block* block = frontBlock_;
		do {
			fence(memory_order_acquire);
			result += block->sizeMask;
			block = block->next.load();
		} while (block != frontBlock_);
		return result;
	}


private:
	enum AllocationMode { CanAlloc, CannotAlloc };

#if MOODYCAMEL_HAS_EMPLACE
	template<AllocationMode canAlloc, typename... Args>
	bool inner_enqueue(Args&&... args) AE_NO_TSAN
#else
	template<AllocationMode canAlloc, typename U>
	bool inner_enqueue(U&& element) AE_NO_TSAN
#endif
	{
#ifndef NDEBUG
		ReentrantGuard guard(this->enqueuing);
#endif

		// High-level pseudocode (assuming we're allowed to alloc a new block):
		// If room in tail block, add to tail
		// Else check next block
		//     If next block is not the head block, enqueue on next block
		//     Else create a new block and enqueue there
		//     Advance tail to the block we just enqueued to

		Block* tailBlock_ = tailBlock.load();
		size_t blockFront = tailBlock_->localFront;
		size_t blockTail = tailBlock_->tail.load();

		size_t nextBlockTail = (blockTail + 1) & tailBlock_->sizeMask;
		if (nextBlockTail != blockFront || nextBlockTail != (tailBlock_->localFront = tailBlock_->front.load())) {
			fence(memory_order_acquire);
			// This block has room for at least one more element
			char* location = tailBlock_->data + blockTail * sizeof(T);
#if MOODYCAMEL_HAS_EMPLACE
			new (location) T(std::forward<Args>(args)...);
#else
			new (location) T(std::forward<U>(element));
#endif

			fence(memory_order_release);
			tailBlock_->tail = nextBlockTail;
		}
		else {
			fence(memory_order_acquire);
			if (tailBlock_->next.load() != frontBlock) {
				// Note that the reason we can't advance to the frontBlock and start adding new entries there
				// is because if we did, then dequeue would stay in that block, eventually reading the new values,
				// instead of advancing to the next full block (whose values were enqueued first and so should be
				// consumed first).

				fence(memory_order_acquire);		// Ensure we get latest writes if we got the latest frontBlock

				// tailBlock is full, but there's a free block ahead, use it
				Block* tailBlockNext = tailBlock_->next.load();
				size_t nextBlockFront = tailBlockNext->localFront = tailBlockNext->front.load();
				nextBlockTail = tailBlockNext->tail.load();
				fence(memory_order_acquire);

				// This block must be empty since it's not the head block and we
				// go through the blocks in a circle
				assert(nextBlockFront == nextBlockTail);
				tailBlockNext->localFront = nextBlockFront;

				char* location = tailBlockNext->data + nextBlockTail * sizeof(T);
#if MOODYCAMEL_HAS_EMPLACE
				new (location) T(std::forward<Args>(args)...);
#else
				new (location) T(std::forward<U>(element));
#endif

				tailBlockNext->tail = (nextBlockTail + 1) & tailBlockNext->sizeMask;

				fence(memory_order_release);
				tailBlock = tailBlockNext;
			}
			else if (canAlloc == CanAlloc) {
				// tailBlock is full and there's no free block ahead; create a new block
				auto newBlockSize = largestBlockSize >= MAX_BLOCK_SIZE ? largestBlockSize : largestBlockSize * 2;
				auto newBlock = make_block(newBlockSize);
				if (newBlock == nullptr) {
					// Could not allocate a block!
					return false;
				}
				largestBlockSize = newBlockSize;

#if MOODYCAMEL_HAS_EMPLACE
				new (newBlock->data) T(std::forward<Args>(args)...);
#else
				new (newBlock->data) T(std::forward<U>(element));
#endif
				assert(newBlock->front == 0);
				newBlock->tail = newBlock->localTail = 1;

				newBlock->next = tailBlock_->next.load();
				tailBlock_->next = newBlock;

				// Might be possible for the dequeue thread to see the new tailBlock->next
				// *without* seeing the new tailBlock value, but this is OK since it can't
				// advance to the next block until tailBlock is set anyway (because the only
				// case where it could try to read the next is if it's already at the tailBlock,
				// and it won't advance past tailBlock in any circumstance).

				fence(memory_order_release);
				tailBlock = newBlock;
			}
			else if (canAlloc == CannotAlloc) {
				// Would have had to allocate a new block to enqueue, but not allowed
				return false;
			}
			else {
				assert(false && "Should be unreachable code");
				return false;
			}
		}

		return true;
	}


	// Disable copying
	ReaderWriterQueue(ReaderWriterQueue const&) {  }

	// Disable assignment
	ReaderWriterQueue& operator=(ReaderWriterQueue const&) {  }


	AE_FORCEINLINE static size_t ceilToPow2(size_t x)
	{
		// From http://graphics.stanford.edu/~seander/bithacks.html#RoundUpPowerOf2
		--x;
		x |= x >> 1;
		x |= x >> 2;
		x |= x >> 4;
		for (size_t i = 1; i < sizeof(size_t); i <<= 1) {
			x |= x >> (i << 3);
		}
		++x;
		return x;
	}

	template<typename U>
	static AE_FORCEINLINE char* align_for(char* ptr) AE_NO_TSAN
	{
		const std::size_t alignment = std::alignment_of<U>::value;
		return ptr + (alignment - (reinterpret_cast<std::uintptr_t>(ptr) % alignment)) % alignment;
	}
private:
#ifndef NDEBUG
	struct ReentrantGuard
	{
		AE_NO_TSAN ReentrantGuard(weak_atomic<bool>& _inSection)
			: inSection(_inSection)
		{
			assert(!inSection && "Concurrent (or re-entrant) enqueue or dequeue operation detected (only one thread at a time may hold the producer or consumer role)");
			inSection = true;
		}

		AE_NO_TSAN ~ReentrantGuard() { inSection = false; }

	private:
		ReentrantGuard& operator=(ReentrantGuard const&);

	private:
		weak_atomic<bool>& inSection;
	};
#endif

	struct Block
	{
		// Avoid false-sharing by putting highly contended variables on their own cache lines
		weak_atomic<size_t> front;	// (Atomic) Elements are read from here
		size_t localTail;			// An uncontended shadow copy of tail, owned by the consumer

		char cachelineFiller0[MOODYCAMEL_CACHE_LINE_SIZE - sizeof(weak_atomic<size_t>) - sizeof(size_t)];
		weak_atomic<size_t> tail;	// (Atomic) Elements are enqueued here
		size_t localFront;

		char cachelineFiller1[MOODYCAMEL_CACHE_LINE_SIZE - sizeof(weak_atomic<size_t>) - sizeof(size_t)];	// next isn't very contended, but we don't want it on the same cache line as tail (which is)
		weak_atomic<Block*> next;	// (Atomic)

		char* data;		// Contents (on heap) are aligned to T's alignment

		const size_t sizeMask;


		// size must be a power of two (and greater than 0)
		AE_NO_TSAN Block(size_t const& _size, char* _rawThis, char* _data)
			: front(0UL), localTail(0), tail(0UL), localFront(0), next(nullptr), data(_data), sizeMask(_size - 1), rawThis(_rawThis)
		{
		}

	private:
		// C4512 - Assignment operator could not be generated
		Block& operator=(Block const&);

	public:
		char* rawThis;
	};


	static Block* make_block(size_t capacity) AE_NO_TSAN
	{
		// Allocate enough memory for the block itself, as well as all the elements it will contain
		auto size = sizeof(Block) + std::alignment_of<Block>::value - 1;
		size += sizeof(T) * capacity + std::alignment_of<T>::value - 1;
		auto newBlockRaw = static_cast<char*>(std::malloc(size));
		if (newBlockRaw == nullptr) {
			return nullptr;
		}

		auto newBlockAligned = align_for<Block>(newBlockRaw);
		auto newBlockData = align_for<T>(newBlockAligned + sizeof(Block));
		return new (newBlockAligned) Block(capacity, newBlockRaw, newBlockData);
	}

private:
	weak_atomic<Block*> frontBlock;		// (Atomic) Elements are dequeued from this block

	char cachelineFiller[MOODYCAMEL_CACHE_LINE_SIZE - sizeof(weak_atomic<Block*>)];
	weak_atomic<Block*> tailBlock;		// (Atomic) Elements are enqueued to this block

	size_t largestBlockSize;

#ifndef NDEBUG
	weak_atomic<bool> enqueuing;
	mutable weak_atomic<bool> dequeuing;
#endif
};

// Like ReaderWriterQueue, but also providees blocking operations
template<typename T, size_t MAX_BLOCK_SIZE = 512>
class BlockingReaderWriterQueue
{
private:
	typedef ::tracy::ReaderWriterQueue<T, MAX_BLOCK_SIZE> ReaderWriterQueue;

public:
	explicit BlockingReaderWriterQueue(size_t size = 15) AE_NO_TSAN
		: inner(size), sema(new spsc_sema::LightweightSemaphore())
	{ }

	BlockingReaderWriterQueue(BlockingReaderWriterQueue&& other) AE_NO_TSAN
		: inner(std::move(other.inner)), sema(std::move(other.sema))
	{ }

	BlockingReaderWriterQueue& operator=(BlockingReaderWriterQueue&& other) AE_NO_TSAN
	{
		std::swap(sema, other.sema);
		std::swap(inner, other.inner);
		return *this;
	}


	// Enqueues a copy of element if there is room in the queue.
	// Returns true if the element was enqueued, false otherwise.
	// Does not allocate memory.
	AE_FORCEINLINE bool try_enqueue(T const& element) AE_NO_TSAN
	{
		if (inner.try_enqueue(element)) {
			sema->signal();
			return true;
		}
		return false;
	}

	// Enqueues a moved copy of element if there is room in the queue.
	// Returns true if the element was enqueued, false otherwise.
	// Does not allocate memory.
	AE_FORCEINLINE bool try_enqueue(T&& element) AE_NO_TSAN
	{
		if (inner.try_enqueue(std::forward<T>(element))) {
			sema->signal();
			return true;
		}
		return false;
	}

#if MOODYCAMEL_HAS_EMPLACE
	// Like try_enqueue() but with emplace semantics (i.e. construct-in-place).
	template<typename... Args>
	AE_FORCEINLINE bool try_emplace(Args&&... args) AE_NO_TSAN
	{
		if (inner.try_emplace(std::forward<Args>(args)...)) {
			sema->signal();
			return true;
		}
		return false;
	}
#endif


	// Enqueues a copy of element on the queue.
	// Allocates an additional block of memory if needed.
	// Only fails (returns false) if memory allocation fails.
	AE_FORCEINLINE bool enqueue(T const& element) AE_NO_TSAN
	{
		if (inner.enqueue(element)) {
			sema->signal();
			return true;
		}
		return false;
	}

	// Enqueues a moved copy of element on the queue.
	// Allocates an additional block of memory if needed.
	// Only fails (returns false) if memory allocation fails.
	AE_FORCEINLINE bool enqueue(T&& element) AE_NO_TSAN
	{
		if (inner.enqueue(std::forward<T>(element))) {
			sema->signal();
			return true;
		}
		return false;
	}

#if MOODYCAMEL_HAS_EMPLACE
	// Like enqueue() but with emplace semantics (i.e. construct-in-place).
	template<typename... Args>
	AE_FORCEINLINE bool emplace(Args&&... args) AE_NO_TSAN
	{
		if (inner.emplace(std::forward<Args>(args)...)) {
			sema->signal();
			return true;
		}
		return false;
	}
#endif


	// Attempts to dequeue an element; if the queue is empty,
	// returns false instead. If the queue has at least one element,
	// moves front to result using operator=, then returns true.
	template<typename U>
	bool try_dequeue(U& result) AE_NO_TSAN
	{
		if (sema->tryWait()) {
			bool success = inner.try_dequeue(result);
			assert(success);
			AE_UNUSED(success);
			return true;
		}
		return false;
	}


	// Attempts to dequeue an element; if the queue is empty,
	// waits until an element is available, then dequeues it.
	template<typename U>
	void wait_dequeue(U& result) AE_NO_TSAN
	{
		while (!sema->wait());
		bool success = inner.try_dequeue(result);
		AE_UNUSED(result);
		assert(success);
		AE_UNUSED(success);
	}


	// Attempts to dequeue an element; if the queue is empty,
	// waits until an element is available up to the specified timeout,
	// then dequeues it and returns true, or returns false if the timeout
	// expires before an element can be dequeued.
	// Using a negative timeout indicates an indefinite timeout,
	// and is thus functionally equivalent to calling wait_dequeue.
	template<typename U>
	bool wait_dequeue_timed(U& result, std::int64_t timeout_usecs) AE_NO_TSAN
	{
		if (!sema->wait(timeout_usecs)) {
			return false;
		}
		bool success = inner.try_dequeue(result);
		AE_UNUSED(result);
		assert(success);
		AE_UNUSED(success);
		return true;
	}


#if __cplusplus > 199711L || _MSC_VER >= 1700
	// Attempts to dequeue an element; if the queue is empty,
	// waits until an element is available up to the specified timeout,
	// then dequeues it and returns true, or returns false if the timeout
	// expires before an element can be dequeued.
	// Using a negative timeout indicates an indefinite timeout,
	// and is thus functionally equivalent to calling wait_dequeue.
	template<typename U, typename Rep, typename Period>
	inline bool wait_dequeue_timed(U& result, std::chrono::duration<Rep, Period> const& timeout) AE_NO_TSAN
	{
        return wait_dequeue_timed(result, std::chrono::duration_cast<std::chrono::microseconds>(timeout).count());
	}
#endif


	// Returns a pointer to the front element in the queue (the one that
	// would be removed next by a call to `try_dequeue` or `pop`). If the
	// queue appears empty at the time the method is called, nullptr is
	// returned instead.
	// Must be called only from the consumer thread.
	AE_FORCEINLINE T* peek() const AE_NO_TSAN
	{
		return inner.peek();
	}

	// Removes the front element from the queue, if any, without returning it.
	// Returns true on success, or false if the queue appeared empty at the time
	// `pop` was called.
	AE_FORCEINLINE bool pop() AE_NO_TSAN
	{
		if (sema->tryWait()) {
			bool result = inner.pop();
			assert(result);
			AE_UNUSED(result);
			return true;
		}
		return false;
	}

	// Returns the approximate number of items currently in the queue.
	// Safe to call from both the producer and consumer threads.
	AE_FORCEINLINE size_t size_approx() const AE_NO_TSAN
	{
		return sema->availableApprox();
	}

	// Returns the total number of items that could be enqueued without incurring
	// an allocation when this queue is empty.
	// Safe to call from both the producer and consumer threads.
	//
	// NOTE: The actual capacity during usage may be different depending on the consumer.
	//       If the consumer is removing elements concurrently, the producer cannot add to
	//       the block the consumer is removing from until it's completely empty, except in
	//       the case where the producer was writing to the same block the consumer was
	//       reading from the whole time.
	AE_FORCEINLINE size_t max_capacity() const {
		return inner.max_capacity();
	}

private:
	// Disable copying & assignment
	BlockingReaderWriterQueue(BlockingReaderWriterQueue const&) {  }
	BlockingReaderWriterQueue& operator=(BlockingReaderWriterQueue const&) {  }

private:
	ReaderWriterQueue inner;
	std::unique_ptr<spsc_sema::LightweightSemaphore> sema;
};

}    // end namespace moodycamel

#ifdef AE_VCPP
#pragma warning(pop)
#endif