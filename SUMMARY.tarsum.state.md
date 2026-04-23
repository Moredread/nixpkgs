# tarsum: State of the Art & Reusable Crates

## Existing Implementations Compared

### tarsum-c (William Ahern, C)
- **Hashing:** OpenSSL EVP (SHA-256 default, any OpenSSL digest via `-a`). No BLAKE3.
- **Archives:** libarchive — handles all tar variants + gzip/xz/bzip2/zstd transparently.
- **Output:** Configurable printf/stat(1)-style format (`-f`). Default: `sha256sum`-compatible.
- **Extras:** Checklist verification (`-C`), hardlink dedup via LLRB tree, path substitution (`-s`).
- **Quality:** Mature, well-structured C. Single-threaded. Zstd already works (via libarchive).
- **BLAKE3 gap:** Would require linking a separate C library + EVP shim or parallel code path.

### tarsum-rust (chrismooredev, Rust)
- **Hashing:** `checksums` crate (MD5 default). Supports SHA1/2/3, BLAKE, BLAKE2, CRC, MD5/6. No BLAKE3.
- **Archives:** `tar` + `flate2`/`xz2`/`bzip2` + `zip` crates. No zstd. Extension-based format detection.
- **Output:** Fixed `<path> <HASH> [size]`. No format customization, no verification mode.
- **Quality:** Weekend project. 0 stars, 0 forks, no tests, no CI, last commit ~2021.
  - Bugs: no hardlink handling, no error propagation, unbuffered stdout, unnecessary `unsafe`.
  - Dependencies rotten: `checksums` unmaintained (Nov 2021), pulls deprecated `gcc`/`rustc-serialize`/`futures` 0.1, pre-release `clap` 3.0.0-beta.2.
- **Verdict:** Useful as structural reference only. Every dependency needs replacing.

### tarsum.go (nixpkgs Docker support, Go)
- **Purpose:** Docker layer identity — produces a single `tarsum.v1+sha256:<hex>` for the whole tar.
- **Not per-file.** SHA-256 only. Uncompressed tar on stdin only.
- **Not extensible** for the desired use case.

## Broader Search: Other Tools & Approaches

Searched: GitHub, crates.io, nixpkgs, web. **No existing tool combines tar + BLAKE3 + zstd + per-file output.**

### Other tarsum-like tools found

| Tool | Lang | Per-file | BLAKE3 | Zstd | Notes |
|------|------|----------|--------|------|-------|
| [VonC/gtarsum](https://github.com/VonC/gtarsum) | Go | Yes | No | No | Concurrent SHA-256 per-file. Order-independent global hash. |
| [Guy Rutenberg's tarsum](https://www.guyrutenberg.com/2008/10/24/tarsum-calculate-checksum-for-files-inside-tar-archive/) | Bash | Yes | Via b3sum flag | No | Extracts each file to disk then hashes. Slow. |
| [pjrinaldi/wombattools](https://github.com/pjrinaldi/wombattools) | C++ | No | Yes | Yes | Forensic disk imaging (walafus format). Uses tar+zstd+BLAKE3 together, but for whole-image hashing, not per-file-in-tar. |
| [vschwaberow/rustgenhash](https://github.com/vschwaberow/rustgenhash) | Rust | Yes | Yes | N/A | Hashes files on the **filesystem**, not inside archives. Parallel, manifests. |
| [vyrti/hash-rs (QuicHash)](https://github.com/vyrti/hash-rs) | Rust | Yes | Yes | N/A | Same — BLAKE3 default, parallel directory scanning, but **filesystem only**. |
| [rhash](https://github.com/rhash/RHash) | C | Yes | No | N/A | Multi-algorithm, filesystem only. In nixpkgs. No BLAKE3. |

### b3sum itself

b3sum has **no tar awareness**. Reads files from filesystem or stdin only. [Issue #171](https://github.com/BLAKE3-team/BLAKE3/issues/171) requests per-file + aggregate hash output, but no tar integration planned.

### FUSE-mount approaches (in nixpkgs)

| Tool | Pkg path | Zstd | Scaling | Notes |
|------|----------|------|---------|-------|
| [ratarmount](https://github.com/mxmlnkn/ratarmount) | `pkgs/development/python-modules/ratarmount/` | Yes | Linear, indexed | Best option. Parallelized decompression. Index cached for repeat access. |
| [fuse-archive](https://github.com/google/fuse-archive) | `pkgs/by-name/fu/fuse-archive/` | Via libarchive | Linear, no index | Re-scans every mount. |
| [archivemount](https://git.sr.ht/~nabijaczleweli/archivemount-ng) | `pkgs/by-name/ar/archivemount/` | Via libarchive | **O(n^2) past ~300k files** | Avoid for large archives. |

### Shell/script approaches

1. **ratarmount + find | xargs -P b3sum** — FUSE-mount tar.zst, parallel b3sum. All in nixpkgs today.
   ```bash
   ratarmount archive.tar.zst /tmp/mnt
   find /tmp/mnt -type f -print0 | xargs -0 -P$(nproc) b3sum
   fusermount -u /tmp/mnt
   ```
2. **Python streaming** — `tarfile` `r|*` mode + `blake3` PyPI package. Zero extraction, zero fork overhead. Single-threaded tar iteration but BLAKE3 parallelizes internally. Use `stream=True` on Python 3.13+ to avoid memory growth from cached TarInfo headers.
3. **`tar --to-command=b3sum`** — Works (use `tar --zstd` or `tar -I zstd`). Forks per file. Slow for many files (10k files = 10k+ fork/exec pairs).

## Recommended: Fresh Rust Tool Using Modern Crates

### Core crates stack

| Crate | Version | What it does | Maintained |
|-------|---------|-------------|------------|
| [`tar`](https://crates.io/crates/tar) | 0.4.43+ | Streaming tar reader. Entries implement `Read`. | Yes (alexcrichton) |
| [`blake3`](https://crates.io/crates/blake3) | 1.8+ | Reference BLAKE3 impl. SIMD-accelerated (SSE4.1/AVX2/AVX-512/NEON). `Hasher::update_reader()` for streaming, `update_rayon()` for parallel. Since v1.5.0: `Hasher::update_mmap_rayon` — same fast path b3sum uses internally (mmap + multithreaded, useful for large files on disk). | Yes (BLAKE3 team) |
| [`zstd`](https://crates.io/crates/zstd) | 0.13+ | Rust bindings for libzstd. `Decoder::new(reader)` wraps any `Read`. | Yes (gyscos) |
| [`flate2`](https://crates.io/crates/flate2) | 1.0.34+ | gzip decompression. `GzDecoder::new(reader)`. | Yes |
| [`xz2`](https://crates.io/crates/xz2) | 0.1+ | xz/lzma decompression. `XzDecoder::new(reader)`. | Yes |
| [`bzip2`](https://crates.io/crates/bzip2) | 0.5+ | bzip2 decompression. `BzDecoder::new(reader)`. | Yes |
| [`clap`](https://crates.io/crates/clap) | 4.5+ | CLI argument parsing. `#[derive(Parser)]`. | Yes |

### Optional crates for extra features

| Crate | What it adds |
|-------|-------------|
| [`sha2`](https://crates.io/crates/sha2) | SHA-256/384/512 if you want algorithm choice beyond BLAKE3 |
| [`rayon`](https://crates.io/crates/rayon) | Parallel hashing across entries (collect entries into work queue, hash in parallel) |
| [`bstr`](https://crates.io/crates/bstr) | Proper non-UTF8 path display without lossy conversion |

### Architecture sketch

```
stdin/file -> [zstd|gzip|xz|bzip2|raw] -> tar::Archive -> iterate entries
    for each regular file entry:
        blake3::Hasher::update_reader(&mut entry)
        println!("{hash}  {path}")
```

Key design points:
- **Single-pass streaming** — no extraction to disk, no seeking.
- **Auto-detect compression** by magic bytes (not file extension), or accept `--format` override.
- **Filter entry types** — skip directories, symlinks, hardlinks (or resolve hardlinks by caching digest of link target).
- **Buffer stdout** — `BufWriter::new(io::stdout().lock())` to avoid per-line syscalls.
- **Error propagation** — `anyhow` or `miette` for clean error reporting on truncated archives / read failures.

### What to salvage from tarsum-rust

- General structure: enum of formats, match on format to wrap reader in decompressor, iterate tar entries, hash, print.
- The `ArchiveFile` trait concept (abstracting over tar entries and zip entries) is reasonable if zip support is desired.
- Nothing else — the dependencies, error handling, output formatting, and corner case handling all need replacing.
