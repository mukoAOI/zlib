# zlib or zlib-ng

用 Zig 构建系统编译 zlib 静态库，支持两种后端：

- **zlib-ng** — [zlib-ng/zlib-ng](https://github.com/zlib-ng/zlib-ng) develop 快照（2.3.90，commit `1239e88`，ZLIB_COMPAT 兼容模式，默认后端）
- **zlib** — [madler/zlib](https://github.com/madler/zlib) v1.3.1

两种后端均包含 **gzFile API**（`gzopen` / `gzread` / `gzwrite` / `gzclose`）。

## 目录结构

```
build.zig / build.zig.zon   # 包入口
build/
  package.zig               # Backend 路由与选项
  simd_level.zig            # x86 SIMD 层级枚举
  zlib.zig / zlib_ng.zig    # 后端配置
  zlib_ng_arch.zig          # 架构 SIMD 路由
  arch/                     # 按架构拆分的 SIMD 源组与 mcpu
  headers.zig / headers_lib.zig  # 头文件生成（WriteFile 缓存）
test/smoke.c                # compress + gzFile 冒烟测试
.github/workflows/ci.yml    # CI 矩阵
```



## 要求

- Zig 0.16.0 或更高版本



## 作为依赖使用

在 `build.zig.zon` 中添加：

```zon
.dependencies = .{
    .zlib_build = .{
        .url = "git+https://github.com/mukoAOI/zig-zlib#0.1.0",
        .hash = "<运行 zig build 后填入>",
    },
},
```

在 `build.zig` 中链接（默认 zlib-ng，ZLIB_COMPAT 兼容 zlib API，SIMD 开启）：

```zig
const zlib_build = b.dependency("zlib_build", .{
    .target = target,
    .optimize = optimize, // 生产环境建议 ReleaseFast / ReleaseSafe
});
const z = zlib_build.artifact("z");

exe.root_module.linkLibrary(z);
```

选用 stock zlib 后端：

```zig
const zlib_build = b.dependency("zlib_build", .{
    .target = target,
    .optimize = optimize,
    .backend = "zlib",
});
```

可选配置：


| 选项                      | 默认值         | 说明                                                            |
| ----------------------- | ----------- | ------------------------------------------------------------- |
| `backend`               | `"zlib-ng"` | `"zlib"` 或 `"zlib-ng"`                                        |
| `linkage`               | `"static"`  | `"static"` 或 `"dynamic"`                                      |
| `symbol_prefix`         | `""`        | 导出符号前缀，如 `"z_"` 或 `"mylib_"`                                  |
| `runtime_cpu_detection` | `true`      | 运行时 CPU 特性检测 + 多路径 dispatch（zlib-ng）                          |
| `native_instructions`   | `false`     | 编译期绑定本机 ISA（`-mcpu=native`），无 runtime dispatch                |
| `simd_level`            | `"max"`     | x86 最高 SIMD 层级：`generic` / `sse2` / `avx2` / `avx512` / `max` |
| `reduced_mem`           | `false`     | 降低内存占用（`WITH_REDUCED_MEM`，略降性能）                               |
| `inflate_strict`        | `false`     | 严格 inflate 距离检查（`WITH_INFLATE_STRICT`）                        |


```zig
const zlib_build = b.dependency("zlib_build", .{
    .target = target,
    .optimize = .ReleaseFast,
    .backend = "zlib-ng",
    .linkage = "dynamic",
    .symbol_prefix = "mylib_",
    .runtime_cpu_detection = true,
    .simd_level = "avx2",
    .reduced_mem = false,
    .inflate_strict = false,
});
```

本机单路径优化（等价于上游 `WITH_NATIVE_INSTRUCTIONS`）：

```zig
const zlib_build = b.dependency("zlib_build", .{
    .target = target,
    .optimize = .ReleaseFast,
    .backend = "zlib-ng",
    .native_instructions = true,
    .simd_level = "max",
});
```

> **说明**
>
> - stock zlib 的 `symbol_prefix` 仅支持空字符串或 `"z_"`（等价于 `-DZ_PREFIX`）；自定义前缀请使用 zlib-ng 后端。
> - `runtime_cpu_detection=true` 时按目标架构编译多档 SIMD 源文件并在运行时选择最优路径（x86、ARM、PowerPC、RISC-V 等）。x86 通过 per-object `-mcpu baseline+…` 编译，兼容 `x86_64-windows-gnu` 与 `x86_64-windows-msvc`。
> - `simd_level` 仅影响 x86 运行时 dispatch 的上限（累积式：`sse2` ⊂ `avx2` ⊂ `avx512` = `max`）。设为 `generic` 等效于不编译任何架构 SIMD 源文件。
> - `native_instructions=true` 自动关闭 runtime dispatch，整个库以 `-mcpu=native` 编译；**仅适用于本机默认 target**，不可交叉编译。
> - `reduced_mem` 设置 `HASH_SIZE=32768`、`GZBUFSIZE=8192`、`NO_LIT_MEM`。
> - 两个上游源码包均为 eager 依赖（拉取 `zlib_build` 时一并下载）。未选用 lazy：嵌套消费方在 configure 阶段调用 `.artifact("z")` 时，Zig 尚不能在「子包 lazy 未就绪」时安全重试，会导致父构建直接 panic。
> - **TODO（待 Zig 官方修复后启用）**：Zig 修复该 bug 后，在 `build.zig.zon` 两个依赖上加 `.lazy = true`，并将 `build.zig` 中的 `b.dependency()` 换成 `b.lazyDependency()`（返回 `?*Dependency`，`null` 时 `return` 让 build runner fetch 后重跑 configure），即可恢复只下载所选后端的懒加载。
> - 未暴露：`WITH_DFLTCC_*`（IBM Z 专用）、`ZLIB_COMPAT=0`（原生 zlib-ng API，会破坏兼容头）。



## 优化模式与体积

**生产环境请使用** `-Doptimize=ReleaseFast` **或** `ReleaseSafe`。默认 Debug 会显著增大静态库体积。

zlib-ng 静态库体积参考（x86_64，大致范围，随 CPU / 工具链略有浮动）：


| 配置                                       | Debug       | ReleaseFast |
| ---------------------------------------- | ----------- | ----------- |
| generic（`-Druntime_cpu_detection=false`） | ~200 KB     | ~150 KB     |
| native（`-Dnative_instructions=true`）     | ~400–700 KB | ~300–500 KB |
| runtime + `simd_level=sse2`              | ~800 KB     | ~600 KB     |
| runtime + `simd_level=avx2`              | ~1.0 MB     | ~800 KB     |
| runtime + `simd_level=max`               | ~1.3 MB     | ~1.1 MB     |
| dynamic DLL（ReleaseFast, max）            | —           | ~315 KB     |


MSVC ABI 静态库通常比 GNU 大约 30–40%（COFF 格式、调试节、LTO 差异）。对比体积时请统一 `optimize` 级别。

## 本地开发

```powershell
zig build                                    # 默认 zlib-ng（ZLIB_COMPAT + SIMD），Debug 静态库
zig build -Doptimize=ReleaseFast             # 推荐生产配置
zig build -Dbackend=zlib-ng                  # zlib-ng（SIMD + runtime 检测）
zig build -Dlinkage=dynamic                  # 动态库
zig build -Dsymbol_prefix=z_                 # stock zlib，z_ 符号前缀
zig build -Dbackend=zlib-ng -Dsymbol_prefix=mylib_
zig build -Dbackend=zlib-ng -Druntime_cpu_detection=false   # 仅 generic C
zig build -Dbackend=zlib-ng -Dnative_instructions=true       # 本机 ISA 单路径
zig build -Dbackend=zlib-ng -Dsimd_level=avx2                 # 不含 AVX512
zig build -Dbackend=zlib-ng -Dreduced_mem=true
zig build -Dbackend=zlib-ng -Dinflate_strict=true
zig build test                               # compress('hello') + gzFile 冒烟测试
zig build test -Dbackend=zlib-ng -Doptimize=ReleaseFast
```

产物安装到 `zig-out/`：


| 平台      | 静态库                  | 动态库                                  | 头文件                        |
| ------- | -------------------- | ------------------------------------ | -------------------------- |
| Windows | `zig-out/lib/z.lib`  | `zig-out/lib/z.dll` + `z.lib` import | `zig-out/include/zlib.h` 等 |
| Unix    | `zig-out/lib/libz.a` | `zig-out/lib/libz.so` 等              | `zig-out/include/zlib.h` 等 |




## CI

GitHub Actions（`.github/workflows/ci.yml`）覆盖：

- stock zlib / zlib-ng × static / dynamic
- x86 `simd_level=avx2`
- `x86_64-windows-msvc`
- `native_instructions`（本机路径）
- `zig build test` 冒烟（含 `compress("hello")` 已知输出与 gzFile 往返）



## 许可证

本仓库仅为构建脚本。zlib 与 zlib-ng 源码各自遵循其上游许可证。