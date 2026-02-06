# lsmdb Development Log

## Project Overview

**What**: An LSM-tree based embedded key-value storage engine in C++20.
**Why**: Portfolio piece demonstrating production-grade C++ engineering — benchmarkable against LevelDB/RocksDB via `db_bench`.
**Architecture**: LSM-tree (MemTable → WAL → SSTables → Compaction) with lock-free internals, custom allocators, and policy-based design.

---

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                        Public API                            │
│   Put(key, value) | Get(key) | Delete(key) | Scan(range)    │
│   [virtual dispatch at boundary — DB, Iterator]              │
└──────────────────────────────────────────────────────────────┘
                              │
┌──────────────────────────────────────────────────────────────┐
│                      Write Path                              │
│  ┌─────────┐    ┌──────────────┐    ┌──────────────────┐    │
│  │   WAL   │───>│   MemTable   │───>│    Immutable     │    │
│  │ (CRC32) │    │ (Skip List)  │    │    MemTable      │    │
│  └─────────┘    └──────────────┘    └──────────────────┘    │
│                                                              │
│  Internal: static dispatch (CRTP + policies, zero-cost)      │
└──────────────────────────────────────────────────────────────┘
                              │ Flush
┌──────────────────────────────────────────────────────────────┐
│                      Storage Layer                           │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐                      │
│  │ Level 0 │  │ Level 1 │  │ Level N │  (SSTables)          │
│  └─────────┘  └─────────┘  └─────────┘                      │
│       │            │            │                            │
│  ┌──────────────────────────────────────────────────────┐   │
│  │           Bloom Filters + Block Index                │   │
│  └──────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────┘
                              │
┌──────────────────────────────────────────────────────────────┐
│                   Background Tasks                           │
│  Compaction (std::jthread) | Flush | Statistics              │
└──────────────────────────────────────────────────────────────┘
```

**Key design principle**: Virtual dispatch at API boundaries (`DB`, `Iterator`), static dispatch internally (CRTP + policies) for zero-cost abstractions in hot paths.

---

## Implementation Roadmap

### Phase 1: Foundation (~2,150 LOC + 500 LOC tests)
- [ ] CMake project setup (presets: Debug, Release, ASan, TSan, UBSan, Fuzz)
- [ ] `Slice` — non-owning view with `operator<=>`, `SliceConvertible` concept
- [ ] `Status` — error type with `std::format` integration
- [ ] `Options` — configuration structs with designated initializers
- [ ] `coding.h` — varint32/64, fixed32/64 encode/decode
- [ ] `crc32c.h` — CRC32C checksums
- [ ] `ArenaResource` — bump allocator as `pmr::memory_resource`
- [ ] `PoolAllocator` — lock-free Treiber stack for fixed-size nodes
- [ ] `EpochGC` — modulo-3 epoch-based reclamation
- [ ] `env_posix` — POSIX file I/O abstraction (read/write/sync/lock)
- **Milestone**: All allocators pass unit + multi-threaded stress tests under TSan

### Phase 2: MemTable + WAL (~1,420 LOC + 600 LOC tests)
- [ ] Lock-free skip list `<Key, Compare, Allocator, Reclaimer>`
- [ ] `InternalKey` = user_key + sequence + type
- [ ] WAL writer/reader (32KB blocks, CRC per record, fragmentation)
- [ ] `WriteBatch` encode/decode/iterate
- **Milestone**: 8-thread concurrent skip list insertion passes TSan. WAL round-trips with corruption detection.

### Phase 3: SSTable (~1,430 LOC + 500 LOC tests)
- [ ] `BlockBuilder` — prefix-compressed keys, restart points, arena-backed
- [ ] `Block` reader — binary search on restart points
- [ ] CRTP bloom filter: `FilterBase<Derived>` → `BloomFilterPolicy<HashPolicy>`
- [ ] SSTable builder/reader (data blocks + filter + index + footer)
- **Milestone**: 10K-key SSTable round-trip, bloom filter verified

### Phase 4: Database Engine (~2,230 LOC + 800 LOC tests)
- [ ] Write path: WAL → MemTable → flush to L0
- [ ] Read path: MemTable → levels → bloom → index → data block
- [ ] `ShardedCache` with CRTP eviction policy
- [ ] Level-based compaction in background `std::jthread`
- [ ] Crash recovery: lock dir → MANIFEST → WAL replay
- [ ] Merging iterator (min-heap)
- **Milestone**: 100K key lifecycle test. Crash recovery via fork+SIGKILL passes.

### Phase 5: Benchmarks + Polish (~680 LOC + 500 LOC tests)
- [ ] `db_bench` (LevelDB-compatible output)
- [ ] Component benchmarks (skip list, allocators, cache)
- [ ] Crash tests (100 trials), fuzz targets (libFuzzer)
- **Milestone**: Side-by-side comparison with LevelDB published in README

---

## C++20 Features Used

| Feature | Where | Why |
|---------|-------|-----|
| Concepts | 8+ custom concepts on all policy template params | Type safety, clean error messages |
| `operator<=>` | `Slice` | Single operator for complete comparison |
| `std::span` | Arena, bloom filter, block reader | Non-owning views replacing ptr+size |
| `std::format` | `Status`, benchmarks | Type-safe formatting |
| `[[no_unique_address]]` | Skip list, bloom filter, comparators | Modern EBO without inheritance tricks |
| `[[nodiscard]]` | All `Status` returns | Prevent ignored errors |
| `std::jthread` | Background compaction/flush | Auto-join on scope exit |
| Designated initializers | `Options` structs | Clean configuration |
| Ranges | Merging iterator | Multi-way merge composition |
| `constexpr` | Slice, CRC tables, encoding | Compile-time evaluation |

---

## Explicitly Out of Scope

- Compression (no-op policy stub, implementable later)
- Snapshots / MVCC reads
- Column families, transactions, custom merge operators

These are listed as "Future Work" — they don't diminish portfolio value.

---

## Benchmarking Strategy

**Primary**: `db_bench` with LevelDB-compatible output format
- fillseq, fillrandom, overwrite, readrandom, readseq, readmissing, compact, fill100K
- Metrics: ops/sec, latency (p50, p99, p999), MB/s

**Component**: skip list (1-8 threads), allocators (arena vs pool vs malloc), cache (zipfian)

**Target**: Within 2-5x of LevelDB. Quality over raw speed.

---

## Testing Strategy

1. **Unit tests** — GoogleTest, one per component
2. **Integration tests** — full DB lifecycle, WAL recovery
3. **Crash tests** — fork + SIGKILL simulation (100 trials)
4. **Fuzz tests** — libFuzzer on coding, block reader, full DB
5. **Sanitizers** — all tests under ASan, TSan, UBSan

---

## Session Log

### Session 1 — 2026-02-06: Project Planning

**What happened**:
- Evaluated project options: key-value store, HTTP server, storage engine, message queue
- Chose LSM-tree storage engine (C++20, portfolio piece)
- Designed full architecture and 5-phase implementation plan
- Mapped project components to C++ study notes topics
- Set up devlog for progress tracking

**Decisions made**:
- LSM-tree over B-tree: write-optimized, well-documented, clear benchmarks (db_bench)
- C++20 standard: concepts, `<=>`, `std::span`, `std::format`, `[[no_unique_address]]`
- Virtual at API boundary, CRTP/policies internally (zero-cost hot paths)
- Insert-only skip list (no node removal during active lifetime — simplifies lock-free correctness)
- Epoch GC over hazard pointers (simpler, batched reclamation, good enough for our access patterns)
- Arena as `pmr::memory_resource` (composable with std containers)

**Key insights**:
- The skip list being insert-only during its active lifetime is a critical simplification. Deletions are handled via tombstone markers (kDeletion type), and actual node memory is reclaimed only when the entire MemTable is discarded. This avoids the complexity of concurrent removal in a lock-free skip list.

**Next session**: Begin Phase 1 — CMake setup, Slice, Status, coding utils, arena allocator

### Session 2 — 2026-02-06: Phase 1 Kickoff — Build System & Tooling

**What happened**:
- Set up complete CMake build system with C++20, strict warnings, and sanitizer presets
- Configured CMake presets: Debug, Release, ASan, TSan, UBSan, Fuzz
- Integrated GoogleTest via FetchContent for unit testing
- Integrated `{fmt}` library via FetchContent (replaces `std::format` — not available on GCC 11/Clang 14)
- Added `.clang-format` (Google style, 4-space indent, 100-col limit) for consistent formatting
- Added `.clang-tidy` with bugprone, performance, modernize, readability checks and Google naming conventions
- Added GitHub Actions CI: GCC + Clang matrix build, sanitizer jobs (ASan, TSan, UBSan)
- Verified debug preset builds cleanly

**Decisions made**:
- `{fmt}` over `std::format`: GCC 11 and Clang 14 don't ship `std::format` (requires GCC 13+/Clang 17+). `{fmt}` is the reference implementation `std::format` was based on — used widely in production. Trivial to swap later.
- CMake preset version 3 (not 6): constrained by CMake 3.22 on Ubuntu 22.04. Version 3 supports `configurePresets` only — build/test presets require version 4+ (CMake 3.23+).
- Google C++ style: matches LevelDB/RocksDB conventions. `CamelCase` types/functions, `lower_case_` members with trailing underscore, `kCamelCase` constants.
- `.clang-tidy` disables `pro-bounds-pointer-arithmetic` (we're writing allocators that legitimately do pointer math) and `easily-swappable-parameters` (too noisy for low-level code).
- Warnings are function-scoped per-target (modern CMake best practice — never global `add_compile_options`).
- Sanitizers use `PUBLIC` visibility so they propagate to test binaries that link against the library.

**Key insights**:
- Always check tool versions before writing build configs. CMake preset versions, compiler C++20 feature support, and clang-tidy check availability all vary significantly across Ubuntu LTS releases.
- An empty `add_library(STATIC)` with no sources fails on CMake 3.22 — need a placeholder `.cpp` file until real sources are added.
- `-fno-sanitize-recover=all` on UBSan makes it abort on first violation — essential for CI (you want hard failures, not silent continuation).

**Files created**:
- `CMakeLists.txt`, `CMakePresets.json` — build system
- `cmake/CompilerWarnings.cmake`, `cmake/Sanitizers.cmake`, `cmake/GoogleTest.cmake`, `cmake/Fmt.cmake` — CMake modules
- `.clang-format`, `.clang-tidy` — code quality tooling
- `.github/workflows/ci.yml` — CI pipeline
- `.gitignore`, `test/CMakeLists.txt`, `src/lsmdb.cpp` (placeholder)

**Next session**: Continue Phase 1 — Slice, coding.h, Status, Options
