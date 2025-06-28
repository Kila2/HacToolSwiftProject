本文档旨在提供精确的内存偏移、大小、类型和字段说明，以便您后续在 Swift 中进行数据结构定义和二进制数据解析。所有结构都将以 Markdown 表格的形式呈现，并包含完整字段，没有任何省略。对于 `union` 类型，将详细标注其所有成员。

**注意：**
*   **对齐（Alignment）:** C 语言编译器可能会为了性能在结构体成员之间插入填充字节（Padding）。为了精确描述文件格式，我会特别关注源代码中的 `#pragma pack` 指令。如果缺少此类指令，我将基于结构体成员的自然对齐规则和上下文来推断布局，这通常意味着成员是连续排列的。
*   **指针和运行时上下文（Pointers & Runtime Contexts）：** 某些您请求的结构（如 `nca_section_ctx_t`）是 C 代码在运行时使用的上下文结构体，并非直接映射到文件格式。它们包含指针和运行时状态，其内存布局在不同架构下可能会变化（例如指针大小）。虽然我会根据请求描述这些结构，但请注意，在解析文件时，您通常不会直接从二进制缓冲区中解析它们，而是解析文件中的数据并用其填充您自己定义的 Swift 结构。
*   **`pk11_mac`:** 您请求的 `pk11_mac` 并非一个结构体，而是一个 `unsigned char[0x10]` 类型的字段。我推测您可能意指 `Package1` 相关的核心结构 `pk11_t`，因此我将 `pk11_t` 的布局包含在此文档中。

---

## 结构体内存布局分析

### 1. hfs0_header_t
**来源:** `hfs0.h`

`HFS0` (Horizon File System 0) 的头部结构，用于描述分区文件系统。

| 字段 (Field) | 偏移量 (Offset) | 大小 (Size) | 类型 (Type) | 描述 (Description) |
|---|---|---|---|---|
| `magic` | `0x00` (0) | 4 | `uint32_t` | 魔术字，应为 "HFS0" (0x30534648)。 |
| `num_files` | `0x04` (4) | 4 | `uint32_t` | HFS0 分区中的文件数量。 |
| `string_table_size` | `0x08` (8) | 4 | `uint32_t` | 存储所有文件名的字符串表的大小（字节）。 |
| `reserved` | `0x0C` (12) | 4 | `uint32_t` | 保留字段，通常为 0。 |
| **总大小 (Total Size)** | | **16 字节** | | |

---

### 2. pfs0_header_t
**来源:** `pfs0.h`

`PFS0` (Partition File System 0) 的头部结构，与 HFS0 类似，是 Switch 文件系统中常见的一种简单归档格式。

| 字段 (Field) | 偏移量 (Offset) | 大小 (Size) | 类型 (Type) | 描述 (Description) |
|---|---|---|---|---|
| `magic` | `0x00` (0) | 4 | `uint32_t` | 魔术字，应为 "PFS0" (0x30534650)。 |
| `num_files` | `0x04` (4) | 4 | `uint32_t` | PFS0 分区中的文件数量。 |
| `string_table_size` | `0x08` (8) | 4 | `uint32_t` | 存储所有文件名的字符串表的大小（字节）。 |
| `reserved` | `0x0C` (12) | 4 | `uint32_t` | 保留字段，通常为 0。 |
| **总大小 (Total Size)** | | **16 字节** | | |

---

### 3. ini1_header_t
**来源:** `kip.h`

`INI1` (Initialiser 1) 格式的头部，通常用于打包多个 `KIP1` (Kernel Initial Process) 文件。

| 字段 (Field) | 偏移量 (Offset) | 大小 (Size) | 类型 (Type) | 描述 (Description) |
|---|---|---|---|---|
| `magic` | `0x00` (0) | 4 | `uint32_t` | 魔术字，应为 "INI1" (0x31494E49)。 |
| `size` | `0x04` (4) | 4 | `uint32_t` | INI1 结构的总大小（包括头部和所有 KIP 数据）。 |
| `num_processes` | `0x08` (8) | 4 | `uint32_t` | KIP1 进程的数量。 |
| `_0xC` | `0x0C` (12) | 4 | `uint32_t` | 保留字段。 |
| `kip_data` | `0x10` (16) | 动态 | `char[]` | 柔性数组成员，包含所有连续的 KIP1 数据。 |
| **头部固定大小 (Fixed Header Size)** | | **16 字节** | | |

---

### 4. kip1_header_t
**来源:** `kip.h`

`KIP1` (Kernel Initial Process 1) 的头部结构，描述了一个内核初始进程的元数据和内存布局。

| 字段 (Field) | 偏移量 (Offset) | 大小 (Size) | 类型 (Type) | 描述 (Description) |
|---|---|---|---|---|
| `magic` | `0x00` (0) | 4 | `uint32_t` | 魔术字，应为 "KIP1" (0x3150494B)。 |
| `name` | `0x04` (4) | 12 | `char[12]` | 进程名称，通常是 ASCII 字符串。 |
| `title_id` | `0x10` (16) | 8 | `uint64_t` | 进程的 Title ID。 |
| `process_category` | `0x18` (24) | 4 | `uint32_t` | 进程分类 (例如：0=常规，1=内核内置)。 |
| `main_thread_priority`| `0x1C` (28) | 1 | `uint8_t` | 主线程的优先级。 |
| `default_core` | `0x1D` (29) | 1 | `uint8_t` | 默认运行的 CPU 核心 ID。 |
| `_0x1E` | `0x1E` (30) | 1 | `uint8_t` | 保留字段。 |
| `flags` | `0x1F` (31) | 1 | `uint8_t` | 标志位，包括是否为 64 位等信息。 |
| `section_headers` | `0x20` (32) | 96 (6 * 16) | `kip_section_header_t[6]`| 6 个段的头部信息数组。每个段描述了 .text, .rodata, .rwdata 等。 |
| `capabilities` | `0x80` (128)| 128 (32 * 4) | `uint32_t[0x20]` | 内核访问控制能力描述符。 |
| `data` | `0x100` (256) | 动态 | `unsigned char[]`| 柔性数组成员，包含实际的进程代码和数据段。 |
| **头部固定大小 (Fixed Header Size)** | | **256 字节** | | |

---

### 5. npdm_t
**来源:** `npdm.h`

`NPDM` (Nintendo Program Data Manifest) 结构，包含程序的元数据，如权限、内存映射等。

| 字段 (Field) | 偏移量 (Offset) | 大小 (Size) | 类型 (Type) | 描述 (Description) |
|---|---|---|---|---|
| `magic` | `0x00` (0) | 4 | `uint32_t` | 魔术字，应为 "META" (0x4154454D)。 |
| `acid_sign_key_index` | `0x04` (4) | 4 | `uint32_t` | ACID 签名使用的密钥索引。 |
| `_0x8` | `0x08` (8) | 4 | `uint32_t` | 保留字段。 |
| `mmu_flags` | `0x0C` (12) | 1 | `uint8_t` | MMU (内存管理单元) 标志。 |
| `_0xD` | `0x0D` (13) | 1 | `uint8_t` | 保留字段。 |
| `main_thread_prio` | `0x0E` (14) | 1 | `uint8_t` | 主线程优先级。 |
| `default_cpuid` | `0x0F` (15) | 1 | `uint8_t` | 默认 CPU 核心 ID。 |
| `_0x10` | `0x10` (16) | 8 | `uint64_t` | 保留字段。 |
| `version` | `0x18` (24) | 4 | `uint32_t` | NPDM 版本号。 |
| `main_stack_size` | `0x1C` (28) | 4 | `uint32_t` | 主线程堆栈大小。 |
| `title_name` | `0x20` (32) | 80 | `char[0x50]` | 标题名称。 |
| `aci0_offset` | `0x70` (112) | 4 | `uint32_t` | ACI0 (Access Control Info 0) 结构的偏移量。 |
| `aci0_size` | `0x74` (116) | 4 | `uint32_t` | ACI0 结构的大小。 |
| `acid_offset` | `0x78` (120) | 4 | `uint32_t` | ACID (Access Control Info Description) 结构的偏移量。 |
| `acid_size` | `0x7C` (124) | 4 | `uint32_t` | ACID 结构的大小。 |
| **总大小 (Total Size)** | | **128 字节** | | |

---

### 6. nca_keyset_t
**来源:** `settings.h`

这是一个运行时结构，用于存储从外部文件（如 `prod.keys`）加载的所有密钥。它不是文件格式的一部分，但根据您的要求，这里列出其内存布局。

| 字段 (Field) | 偏移量 (Offset) | 大小 (Size) | 类型 (Type) | 描述 (Description) |
|---|---|---|---|---|
| `secure_boot_key` | `0x0000` (0) | 16 | `unsigned char[0x10]` | 安全启动密钥 (控制台唯一)。 |
| `tsec_key` | `0x0010` (16) | 16 | `unsigned char[0x10]` | TSEC 密钥 (控制台唯一)。 |
| `device_key` | `0x0020` (32) | 16 | `unsigned char[0x10]` | 设备密钥 (控制台唯一)。 |
| `keyblob_keys` | `0x0030` (48) | 512 (32 * 16) | `unsigned char[0x20][0x10]` | 用于解密 keyblob 的密钥 (控制台唯一)。 |
| `keyblob_mac_keys` | `0x0230` (560) | 512 (32 * 16) | `unsigned char[0x20][0x10]` | 用于验证 keyblob MAC 的密钥 (控制台唯一)。 |
| `encrypted_keyblobs` | `0x0430` (1072) | 5632 (32 * 176) | `unsigned char[0x20][0xB0]` | 加密的 keyblobs (EKS) (控制台唯一)。 |
| `mariko_aes_class_keys` | `0x1A30` (6704) | 192 (12 * 16) | `unsigned char[0xC][0x10]` | Mariko bootrom 设置的 AES 类密钥。 |
| `mariko_kek` | `0x1AF0` (6896) | 16 | `unsigned char[0x10]` | Mariko 的密钥加密密钥。 |
| `mariko_bek` | `0x1B00` (6912) | 16 | `unsigned char[0x10]` | Mariko 的启动加密密钥。 |
| `keyblobs` | `0x1B10` (6928) | 4608 (32 * 144)| `unsigned char[0x20][0x90]` | 解密后的 keyblobs (EKS)。 |
| `keyblob_key_sources`| `0x2D10` (11536) | 512 (32 * 16) | `unsigned char[0x20][0x10]`| keyblob 密钥的种子。 |
| `keyblob_mac_key_source`| `0x2F10` (12048) | 16 | `unsigned char[0x10]` | keyblob MAC 密钥派生的种子。 |
| `tsec_root_kek` | `0x2F20` (12064) | 16 | `unsigned char[0x10]` | 用于生成 TSEC 根密钥。 |
| `package1_mac_kek` | `0x2F30` (12080) | 16 | `unsigned char[0x10]` | 用于生成 Package1 MAC 密钥。 |
| `package1_kek` | `0x2F40` (12096) | 16 | `unsigned char[0x10]` | 用于生成 Package1 密钥。 |
| `tsec_auth_signatures`| `0x2F50` (12112) | 512 (32 * 16) | `unsigned char[0x20][0x10]`| 用于 6.2.0+ 密钥生成的 TSEC 认证签名。|
| `tsec_root_keys` | `0x3150` (12624) | 512 (32 * 16) | `unsigned char[0x20][0x10]` | 用于主 kek 解密的密钥 (来自 6.2.0+ TSEC 固件)。 |
| `master_kek_sources`| `0x3350` (13136) | 512 (32 * 16) | `unsigned char[0x20][0x10]`| 固件主 kek 的种子。 |
| `mariko_master_kek_sources`| `0x3550` (13648) | 512 (32 * 16) | `unsigned char[0x20][0x10]`| 固件主 kek 的种子 (Mariko)。 |
| `master_keks` | `0x3750` (14160) | 512 (32 * 16) | `unsigned char[0x20][0x10]`| 固件主 kek。 |
| `master_key_source` | `0x3950` (14672) | 16 | `unsigned char[0x10]` | 主密钥派生的种子。 |
| `master_keys` | `0x3960` (14688) | 512 (32 * 16) | `unsigned char[0x20][0x10]`| 固件主密钥。 |
| `package1_mac_keys` | `0x3B60` (15200) | 512 (32 * 16) | `unsigned char[0x20][0x10]`| Package1 MAC 密钥。 |
| `package1_keys` | `0x3D60` (15712) | 512 (32 * 16) | `unsigned char[0x20][0x10]`| Package1 密钥。 |
| `package2_keys` | `0x3F60` (16224) | 512 (32 * 16) | `unsigned char[0x20][0x10]`| Package2 密钥。 |
| `package2_key_source`| `0x4160` (16736) | 16 | `unsigned char[0x10]` | Package2 密钥的种子。 |
| `per_console_key_source`| `0x4170` (16752) | 16 | `unsigned char[0x10]` | 设备密钥的种子。 |
| `aes_kek_generation_source`|`0x4180` (16768) | 16 | `unsigned char[0x10]` | GenerateAesKek 的种子。 |
| `aes_key_generation_source`|`0x4190` (16784) | 16 | `unsigned char[0x10]` | GenerateAesKey 的种子。 |
| `key_area_key_application_source`| `0x41A0` (16800)| 16 | `unsigned char[0x10]` | kaek 0 的种子。 |
| `key_area_key_ocean_source`|`0x41B0` (16816)| 16 | `unsigned char[0x10]` | kaek 1 的种子。 |
| `key_area_key_system_source`| `0x41C0` (16832)| 16 | `unsigned char[0x10]` | kaek 2 的种子。 |
| `titlekek_source` | `0x41D0` (16848)| 16 | `unsigned char[0x10]` | titlekek 的种子。 |
| `header_kek_source` | `0x41E0` (16864)| 16 | `unsigned char[0x10]` | header kek 的种子。 |
| `sd_card_kek_source` | `0x41F0` (16880)| 16 | `unsigned char[0x10]` | SD 卡 kek 的种子。 |
| `sd_card_key_sources` | `0x4200` (16896)| 64 (2 * 32) | `unsigned char[2][0x20]` | SD 卡加密密钥的种子。 |
| `save_mac_kek_source` | `0x4240` (16960)| 16 | `unsigned char[0x10]` | save kek 的种子。 |
| `save_mac_key_source` | `0x4250` (16976)| 16 | `unsigned char[0x10]` | save key 的种子。 |
| `header_key_source` | `0x4260` (16992)| 32 | `unsigned char[0x20]` | NCA header key 的种子。 |
| `header_key` | `0x4280` (17024)| 32 | `unsigned char[0x20]` | NCA header key。 |
| `titlekeks` | `0x42A0` (17056)| 512 (32 * 16) | `unsigned char[0x20][0x10]`| Title key 加密密钥。 |
| `key_area_keys` | `0x44A0` (17568)| 1536 (32*3*16)|`unsigned char[0x20][3][0x10]`| 密钥区域加密密钥。 |
| `xci_header_key` | `0x4AA0` (19104)| 16 | `unsigned char[0x10]` | 用于 XCI 部分加密头部的密钥。 |
| `save_mac_key` | `0x4AB0` (19120)| 16 | `unsigned char[0x10]` | 用于签署存档的密钥。 |
| `sd_card_keys` | `0x4AC0` (19136)| 64 (2 * 32) | `unsigned char[2][0x20]` | SD 卡密钥。 |
| `nca_hdr_fixed_key_moduli`|`0x4B00` (19200)| 512 (2 * 256)|`unsigned char[2][0x100]`| NCA 头部固定密钥 RSA 公钥模数。|
| `acid_fixed_key_moduli`| `0x4D00` (19712)| 512 (2 * 256)|`unsigned char[2][0x100]`| ACID 固定密钥 RSA 公钥模数。 |
| `package2_fixed_key_modulus`|`0x4F00` (20224)| 256 | `unsigned char[0x100]`| Package2 头部 RSA 公钥模数。 |
| **总大小 (Total Size)** | | **20480 字节**| | |

---

### 7. nca_header_t
**来源:** `nca.h`

NCA (Nintendo Content Archive) 文件的头部结构，包含了签名、密钥、分区表和文件系统头部等信息。

| 字段 (Field) | 偏移量 (Offset) | 大小 (Size) | 类型 (Type) | 描述 (Description) |
|---|---|---|---|---|
| `fixed_key_sig` | `0x000` (0) | 256 | `uint8_t[0x100]` | 使用固定密钥对头部的 RSA-PSS 签名。 |
| `npdm_key_sig` | `0x100` (256) | 256 | `uint8_t[0x100]` | 使用 NPDM 中密钥对头部的 RSA-PSS 签名。 |
| `magic` | `0x200` (512) | 4 | `uint32_t` | 魔术字，应为 "NCA3", "NCA2" 或 "NCA0"。 |
| `distribution` | `0x204` (516) | 1 | `uint8_t` | 分发类型（0=数字版, 1=卡带版）。 |
| `content_type` | `0x205` (517) | 1 | `uint8_t` | 内容类型 (0=Program, 1=Meta, 2=Control, 等)。 |
| `crypto_type` | `0x206` (518) | 1 | `uint8_t` | 主密钥修订版本（用于解密 key area）。 |
| `kaek_ind` | `0x207` (519) | 1 | `uint8_t` | 使用的密钥区域加密密钥（Key Area Encryption Key, KAEK）的索引。 |
| `nca_size` | `0x208` (520) | 8 | `uint64_t` | 整个 NCA 文件的大小。 |
| `title_id` | `0x210` (528) | 8 | `uint64_t` | 关联的 Title ID。 |
| `_0x218` | `0x218` (536) | 4 | `uint8_t[4]` | 保留字段/填充。 |
| **(union)** `sdk_version`| `0x21C` (540) | 4 | `union` | 编译此 NCA 的 SDK 版本。 |
| &nbsp;&nbsp;`sdk_version` | `0x21C` (540) | 4 | `uint32_t` | 完整的版本号。 |
| &nbsp;&nbsp;**struct** | `0x21C` (540) | 4 | `struct` | 版本号的字节表示。 |
| &nbsp;&nbsp;&nbsp;&nbsp;`sdk_revision`| `0x21C` (540) | 1 | `uint8_t` | 修订版本。 |
| &nbsp;&nbsp;&nbsp;&nbsp;`sdk_micro` | `0x21D` (541) | 1 | `uint8_t` | 微版本。 |
| &nbsp;&nbsp;&nbsp;&nbsp;`sdk_minor` | `0x21E` (542) | 1 | `uint8_t` | 次版本。 |
| &nbsp;&nbsp;&nbsp;&nbsp;`sdk_major` | `0x21F` (543) | 1 | `uint8_t` | 主版本。 |
| `crypto_type2` | `0x220` (544) | 1 | `uint8_t` | 第二个主密钥修订版本（如果 > `crypto_type` 则使用此版本）。 |
| `fixed_key_generation`| `0x221` (545) | 1 | `uint8_t` | 用于签名验证的固定密钥的代数。 |
| `_0x222` | `0x222` (546) | 14 | `uint8_t[0xE]` | 保留字段/填充。 |
| `rights_id` | `0x230` (560) | 16 | `uint8_t[0x10]`| Rights ID，用于 titlekey 加密。如果全为 0，则使用标准加密。 |
| `section_entries` | `0x240` (576) | 64 (4 * 16) | `nca_section_entry_t[4]` | 4 个分区的条目信息（偏移量和大小）。 |
| `section_hashes` | `0x280` (640) | 128 (4 * 32) | `uint8_t[4][0x20]` | 每个文件系统（FS）头部的 SHA-256 哈希。 |
| `encrypted_keys` | `0x300` (768) | 64 (4 * 16) | `uint8_t[4][0x10]` | 加密的密钥区域 (Key Area)。 |
| `_0x340` | `0x340` (832) | 192 | `uint8_t[0xC0]`| 保留字段/填充。 |
| `fs_headers` | `0x400` (1024)| 2048 (4 * 512)| `nca_fs_header_t[4]` | 4 个文件系统头部。 |
| **总大小 (Total Size)** | | **3072 字节 (0xC00)** | | |

---

### 8. nca_fs_header_t
**来源:** `nca.h`

NCA 中每个分区的头部结构，包含该分区的文件系统类型、加密类型和对应的超级块信息。

| 字段 (Field) | 偏移量 (Offset) | 大小 (Size) | 类型 (Type) | 描述 (Description) |
|---|---|---|---|---|
| `_0x0` | `0x00` (0) | 1 | `uint8_t` | 未知/填充。 |
| `_0x1` | `0x01` (1) | 1 | `uint8_t` | 未知/填充。 |
| `partition_type` | `0x02` (2) | 1 | `uint8_t` | 分区类型 (0=RomFS, 1=PFS0)。 |
| `fs_type` | `0x03` (3) | 1 | `uint8_t` | 文件系统类型 (2=PFS0, 3=RomFS)。 |
| `crypt_type` | `0x04` (4) | 1 | `uint8_t` | 加密类型 (1=None, 2=XTS, 3=CTR, 4=BKTR)。 |
| `_0x5` | `0x05` (5) | 3 | `uint8_t[3]` | 未知/填充。 |
| **(union)** Superblock |`0x08` (8)| 312 | `union` | 文件系统超级块，具体类型取决于 `fs_type`。 |
| &nbsp;&nbsp;`pfs0_superblock` | `0x08` (8) | 312 | `pfs0_superblock_t` | PFS0 超级块。 |
| &nbsp;&nbsp;`romfs_superblock`| `0x08` (8) | 312 | `romfs_superblock_t`| RomFS 超级块。 |
| &nbsp;&nbsp;`nca0_romfs_superblock`|`0x08` (8)| 312 |`nca0_romfs_superblock_t`| NCA0 RomFS 超级块。|
| &nbsp;&nbsp;`bktr_superblock` | `0x08` (8) | 312 | `bktr_superblock_t` | BKTR (Patch RomFS) 超级块。 |
| **(union)** `section_ctr`|`0x140` (320) | 8 | `union` | 用于 AES-CTR 解密的计数器。 |
| &nbsp;&nbsp;`section_ctr`|`0x140` (320) | 8 | `uint8_t[8]` | 计数器的字节数组形式。 |
| &nbsp;&nbsp;**struct** |`0x140` (320) | 8 | `struct` | 计数器的 32位 整数形式。 |
| &nbsp;&nbsp;&nbsp;&nbsp;`section_ctr_low`| `0x140` (320) | 4 | `uint32_t` | 计数器低 32 位。 |
| &nbsp;&nbsp;&nbsp;&nbsp;`section_ctr_high`|`0x144` (324) | 4 | `uint32_t` | 计数器高 32 位。 |
| `_0x148` | `0x148` (328)| 184 | `uint8_t[0xB8]`| 填充。 |
| **总大小 (Total Size)**| | **512 字节 (0x200)** | | |

---

### 9. nca_section_ctx_t
**来源:** `nca.h`

**注意:** 这是一个运行时上下文结构，不是文件格式。其大小依赖于指针大小（此处假设为 64 位/8 字节）。

| 字段 (Field) | 偏移量 (Offset) | 大小 (Size) | 类型 (Type) | 描述 (Description) |
|---|---|---|---|---|
| `is_present` | `0x00` (0) | 4 | `int` | 标记此分区是否存在。 |
| `type` | `0x04` (4) | 4 | `enum nca_section_type` | 分区类型枚举。 |
| `file` | `0x08` (8) | 8 | `FILE *` | 指向 NCA 文件的指针。 |
| `offset` | `0x10` (16) | 8 | `uint64_t` | 分区在文件中的起始偏移。 |
| `size` | `0x18` (24) | 8 | `uint64_t` | 分区的大小。 |
| `section_num` | `0x20` (32) | 4 | `uint32_t` | 分区索引 (0-3)。 |
| `header` | `0x28` (40) | 8 | `nca_fs_header_t *` | 指向 `nca_header_t` 中对应的文件系统头部。 |
| `is_decrypted` | `0x30` (48) | 4 | `int` | 标记分区数据是否已解密。 |
| `sector_size` | `0x38` (56) | 8 | `uint64_t` | 加密扇区大小（用于 XTS）。 |
| `sector_mask` | `0x40` (64) | 8 | `uint64_t` | 加密扇区掩码。 |
| `aes` | `0x48` (72) | 8 | `aes_ctx_t *` | 用于分区解密的 AES 上下文。 |
| `tool_ctx` | `0x50` (80) | 8 | `hactool_ctx_t *` | 指向主工具上下文。 |
| **(union)** Contexts|`0x58` (88)| 动态 | `union` | 包含特定文件系统类型的运行时上下文。 |
| &nbsp;&nbsp;`pfs0_ctx` | `0x58` (88) | - | `pfs0_ctx_t` | PFS0 上下文。 |
| &nbsp;&nbsp;`romfs_ctx` | `0x58` (88) | - | `romfs_ctx_t` | RomFS 上下文。 |
| &nbsp;&nbsp;`nca0_romfs_ctx` | `0x58` (88) | - | `nca0_romfs_ctx_t` | NCA0 RomFS 上下文。 |
| &nbsp;&nbsp;`bktr_ctx` | `0x58` (88) | - | `bktr_section_ctx_t`| BKTR 上下文。 |
| ... | | | | ... 剩余字段是运行时状态，非文件格式 |
| **总大小 (Total Size)** | | **> 208 字节** | | |

---

### 10. nca0_romfs_hdr_t
**来源:** `nca0_romfs.h`

用于早期 Beta 版游戏的 `RomFS` 头部结构。

| 字段 (Field) | 偏移量 (Offset) | 大小 (Size) | 类型 (Type) | 描述 (Description) |
|---|---|---|---|---|
| `header_size` | `0x00` (0) | 4 | `uint32_t`| 头部大小，应为 0x28。 |
| `dir_hash_table_offset` | `0x04` (4) | 4 | `uint32_t`| 目录哈希表偏移量。 |
| `dir_hash_table_size` | `0x08` (8) | 4 | `uint32_t`| 目录哈希表大小。 |
| `dir_meta_table_offset` | `0x0C` (12)| 4 | `uint32_t`| 目录元数据表偏移量。 |
| `dir_meta_table_size` | `0x10` (16)| 4 | `uint32_t`| 目录元数据表大小。 |
| `file_hash_table_offset`| `0x14` (20)| 4 | `uint32_t`| 文件哈希表偏移量。 |
| `file_hash_table_size`| `0x18` (24)| 4 | `uint32_t`| 文件哈希表大小。 |
| `file_meta_table_offset`| `0x1C` (28)| 4 | `uint32_t`| 文件元数据表偏移量。 |
| `file_meta_table_size`| `0x20` (32)| 4 | `uint32_t`| 文件元数据表大小。 |
| `data_offset` | `0x24` (36)| 4 | `uint32_t`| 文件数据区域的起始偏移量。 |
| **总大小 (Total Size)**| | **40 字节 (0x28)**| | |

---

### 11. nso0_header_t
**来源:** `nso.h`

`NSO0` (Nintendo Switch Object 0) 文件的头部，这是一种可执行文件格式。

| 字段 (Field) | 偏移量 (Offset) | 大小 (Size) | 类型 (Type) | 描述 (Description) |
|---|---|---|---|---|
| `magic` | `0x00` (0) | 4 | `uint32_t` | 魔术字，应为 "NSO0" (0x304F534E)。 |
| `_0x4` | `0x04` (4) | 4 | `uint32_t` | 保留字段。 |
| `_0x8` | `0x08` (8) | 4 | `uint32_t` | 保留字段。 |
| `flags` | `0x0C` (12) | 4 | `uint32_t` | 标志位，指示哪些段被压缩和哈希。 |
| `segments` | `0x10` (16) | 48 (3 * 16) | `nso0_segment_t[3]`| 三个段（.text, .rodata, .data）的头部。 |
| `build_id` | `0x40` (64) | 32 | `uint8_t[0x20]`| 程序的构建 ID。 |
| `compressed_sizes` | `0x60` (96) | 12 (3 * 4) | `uint32_t[3]` | 三个段的压缩后大小。 |
| `_0x6C` | `0x6C` (108)| 36 | `uint8_t[0x24]`| 保留字段/填充。 |
| `dynstr_extents` | `0x90` (144)| 8 | `uint64_t` | .dynstr 段的范围（偏移量和大小）。|
| `dynsym_extents` | `0x98` (152)| 8 | `uint64_t` | .dynsym 段的范围。 |
| `section_hashes` | `0xA0` (160)| 96 (3 * 32) | `uint8_t[3][0x20]` | 三个段的 SHA-256 哈希。 |
| `data` | `0x100` (256)| 动态 | `unsigned char[]`| 柔性数组成员，包含实际的代码和数据。 |
| **头部固定大小 (Fixed Header Size)** | | **256 字节** | | |

---

### 12. pk11_mariko_oem_header_t
**来源:** `packages.h`

`Package1` 文件在 Mariko (Switch v2) 平台上的 OEM 头部。

| 字段 (Field) | 偏移量 (Offset) | 大小 (Size) | 类型 (Type) | 描述 (Description) |
|---|---|---|---|---|
| `aes_mac` | `0x000` (0) | 16 | `unsigned char[0x10]` | AES-CMAC。 |
| `rsa_sig` | `0x010` (16) | 256 | `unsigned char[0x100]`| RSA 签名。 |
| `salt` | `0x110` (272)| 32 | `unsigned char[0x20]`| 随机盐值。 |
| `hash` | `0x130` (304)| 32 | `unsigned char[0x20]`| OEM bootloader 的哈希。 |
| `bl_version` | `0x150` (336)| 4 | `uint32_t` | OEM bootloader 版本。 |
| `bl_size` | `0x154` (340)| 4 | `uint32_t` | OEM bootloader 大小。 |
| `bl_load_addr` | `0x158` (344)| 4 | `uint32_t` | OEM bootloader 加载地址。 |
| `bl_entrypoint` | `0x15C` (348)| 4 | `uint32_t` | OEM bootloader 入口点。 |
| `_0x160` | `0x160` (352)| 16 | `unsigned char[0x10]`| 保留字段。 |
| **总大小 (Total Size)** | | **368 字节 (0x170)** | | |

---

### 13. pk11_metadata_t
**来源:** `packages.h`

`Package1` 文件的元数据部分。

| 字段 (Field) | 偏移量 (Offset) | 大小 (Size) | 类型 (Type) | 描述 (Description) |
|---|---|---|---|---|
| `ldr_hash` | `0x00` (0) | 4 | `uint32_t` | Package1ldr 的哈希。 |
| `sm_hash` | `0x04` (4) | 4 | `uint32_t` | Secure Monitor 的哈希。 |
| `bl_hash` | `0x08` (8) | 4 | `uint32_t` | NX Bootloader 的哈希。 |
| `_0xC` | `0x0C` (12) | 4 | `uint32_t` | 保留字段。 |
| `build_date` | `0x10` (16) | 14 | `char[0xE]` | 构建日期。 |
| `_0x1E` | `0x1E` (30) | 1 | `unsigned char`| 保留字段。 |
| `version` | `0x1F` (31) | 1 | `unsigned char`| 元数据版本。 |
| **总大小 (Total Size)** | | **32 字节 (0x20)** | | |

---

### 14. pk11_legacy_stage1_t
**来源:** `packages.h`

旧版 `Package1` 文件的 Stage1 部分，用于固件版本低于 7.0.0。

| 字段 (Field) | 偏移量 (Offset) | 大小 (Size) | 类型 (Type) | 描述 (Description) |
|---|---|---|---|---|
| `stage1` | `0x0000` (0) | 16320 | `unsigned char[0x3FC0]`| Stage1 数据。 |
| `pk11_size` | `0x3FC0` (16320)| 4 | `uint32_t` | PK11 内容的大小。 |
| `_0x3FC4` | `0x3FC4` (16324)| 12 | `unsigned char[0xC]` | 保留字段。 |
| `ctr` | `0x3FD0` (16336)| 16 | `unsigned char[0x10]` | 用于 AES-CTR 解密的计数器。 |
| **总大小 (Total Size)**| | **16352 字节 (0x3FE0)** | | |

---

### 15. pk11_modern_stage1_t
**来源:** `packages.h`

新版 `Package1` 文件的 Stage1 部分，用于固件版本 7.0.0 及以上。

| 字段 (Field) | 偏移量 (Offset) | 大小 (Size) | 类型 (Type) | 描述 (Description) |
|---|---|---|---|---|
| `stage1` | `0x0000` (0) | 28608 | `unsigned char[0x6FC0]`| Stage1 数据。 |
| `pk11_size` | `0x6FC0` (28608)| 4 | `uint32_t` | PK11 内容的大小。 |
| `_0x6FC4` | `0x6FC4` (28612)| 12 | `unsigned char[0xC]` | 保留字段。 |
| `iv` | `0x6FD0` (28624)| 16 | `unsigned char[0x10]` | 用于 AES-CBC 解密的初始化向量。|
| **总大小 (Total Size)**| | **28640 字节 (0x6FE0)** | | |

---

### 16. pk11_t
**来源:** `packages.h`

`Package1` 的核心载荷，包含了多个 bootloader 组件。

| 字段 (Field) | 偏移量 (Offset) | 大小 (Size) | 类型 (Type) | 描述 (Description) |
|---|---|---|---|---|
| `magic` | `0x00` (0) | 4 | `uint32_t` | 魔术字，应为 "PK11" (0x31314B50)。 |
| `wb_size` | `0x04` (4) | 4 | `uint32_t` | Warmboot.bin 的大小。 |
| `wb_ep` | `0x08` (8) | 4 | `uint32_t` | Warmboot.bin 的入口点。 |
| `_0xC` | `0x0C` (12) | 4 | `uint32_t` | 保留字段。 |
| `bl_size` | `0x10` (16) | 4 | `uint32_t` | NX_Bootloader.bin 的大小。 |
| `bl_ep` | `0x14` (20) | 4 | `uint32_t` | NX_Bootloader.bin 的入口点。 |
| `sm_size` | `0x18` (24) | 4 | `uint32_t` | Secure_Monitor.bin 的大小。 |
| `sm_ep` | `0x1C` (28) | 4 | `uint32_t` | Secure_Monitor.bin 的入口点。 |
| `data` | `0x20` (32) | 动态 | `unsigned char[]` | 柔性数组成员，包含三个组件的实际数据。 |
| **头部固定大小 (Fixed Header Size)** | | **32 字节** | | |

---

### 17. pk21_header_t
**来源:** `packages.h`
**注意:** 此结构体在源文件中使用了 `#pragma pack(push, 1)`，表示所有成员都是紧密排列的，没有对齐填充。

`Package2` 的头部，通常包含内核（Kernel）和 INI1。

| 字段 (Field) | 偏移量 (Offset) | 大小 (Size) | 类型 (Type) | 描述 (Description) |
|---|---|---|---|---|
| `signature` | `0x000` (0) | 256 | `unsigned char[0x100]`| RSA-PSS 签名。 |
| **(union)** `ctr`| `0x100` (256)| 16 | `union` | 用于解密头部的 AES-CTR 计数器。 |
| &nbsp;&nbsp;`ctr` | `0x100` (256)| 16 | `unsigned char[0x10]` | 字节数组形式。 |
| &nbsp;&nbsp;`ctr_dwords`|`0x100` (256)| 16 | `uint32_t[4]` | 32位整数数组形式。 |
| `section_ctrs` | `0x110` (272)| 64 (4 * 16) |`unsigned char[4][0x10]`| 四个分区的 AES-CTR 计数器。 |
| `magic` | `0x150` (336)| 4 | `uint32_t` | 魔术字，应为 "PK21" (0x31324B50)。 |
| `base_offset` | `0x154` (340)| 4 | `uint32_t` | 基地址偏移。 |
| `_0x58` | `0x158` (344)| 4 | `uint32_t` | 保留字段。 |
| `version_max` | `0x15C` (348)| 1 | `uint8_t` | 最大版本。 |
| `version_min` | `0x15D` (349)| 1 | `uint8_t` | 最小版本。 |
| `_0x5E` | `0x15E` (350)| 2 | `uint16_t` | 保留字段。 |
| `section_sizes`| `0x160` (352)| 16 (4 * 4) | `uint32_t[4]` | 四个分区的大小。 |
| `section_offsets`|`0x170` (368)| 16 (4 * 4) | `uint32_t[4]` | 四个分区的加载地址偏移。|
| `section_hashes`|`0x180` (384)| 128(4 * 32)|`unsigned char[4][0x20]`| 四个分区的 SHA-256 哈希。 |
| **总大小 (Total Size)**| | **512 字节 (0x200)**| | |

---

### 18. romfs_hdr_t
**来源:** `ivfc.h`

`RomFS` 的头部结构，描述了 RomFS 内部各个元数据表和数据区域的布局。

| 字段 (Field) | 偏移量 (Offset) | 大小 (Size) | 类型 (Type) | 描述 (Description) |
|---|---|---|---|---|
| `header_size` | `0x00` (0) | 8 | `uint64_t` | RomFS 头部的大小，应为 0x50。 |
| `dir_hash_table_offset` | `0x08` (8) | 8 | `uint64_t` | 目录哈希表的偏移量。 |
| `dir_hash_table_size` | `0x10` (16) | 8 | `uint64_t` | 目录哈希表的大小。 |
| `dir_meta_table_offset` | `0x18` (24) | 8 | `uint64_t` | 目录元数据表的偏移量。 |
| `dir_meta_table_size` | `0x20` (32) | 8 | `uint64_t` | 目录元数据表的大小。 |
| `file_hash_table_offset`| `0x28` (40) | 8 | `uint64_t` | 文件哈希表的偏移量。 |
| `file_hash_table_size`| `0x30` (48) | 8 | `uint64_t` | 文件哈希表的大小。 |
| `file_meta_table_offset`| `0x38` (56) | 8 | `uint64_t` | 文件元数据表的偏移量。 |
| `file_meta_table_size`| `0x40` (64) | 8 | `uint64_t` | 文件元数据表的大小。 |
| `data_offset` | `0x48` (72) | 8 | `uint64_t` | 文件数据区域的起始偏移量。 |
| **总大小 (Total Size)**| | **80 字节 (0x50)** | | |

---

### 19. save_header_t
**来源:** `save.h`
**注意:** 此结构体在源文件中使用了 `#pragma pack(push, 1)`，表示所有成员都是紧密排列的，没有对齐填充。

Switch 存档文件的头部结构，非常复杂，包含了多层文件系统和验证结构。

| 字段 (Field) | 偏移量 (Offset) | 大小 (Size) | 类型 (Type) | 描述 (Description) |
|---|---|---|---|---|
| `cmac` | `0x0000` (0) | 16 | `uint8_t[0x10]`| 对 `layout` 字段的 CMAC。 |
| `_0x10` | `0x0010` (16) | 240 | `uint8_t[0xF0]`| 填充。 |
| `layout` | `0x0100` (256)| 512 | `fs_layout_t` | 文件系统布局信息。 |
| `duplex_header` | `0x0300` (768)| 68 | `duplex_header_t`| Duplex 存储系统的头部。 |
| `data_ivfc_header` | `0x0344` (836) | 192 | `ivfc_save_hdr_t`| 数据区域的 IVFC 头部。 |
| `_0x404` | `0x0404` (1028)| 4 | `uint32_t` | 填充。 |
| `journal_header` | `0x0408` (1032)| 32 | `journal_header_t`| 日志区域头部。 |
| `map_header` | `0x0428` (1064)| 16 | `journal_map_header_t`| 日志映射头部。 |
| `_0x438` | `0x0438` (1080)| 464 | `uint8_t[0x1D0]`| 填充。 |
| `save_header` | `0x0608` (1544)| 24 | `save_fs_header_t`| 存档文件系统头部。 |
| `fat_header` | `0x0620` (1568)| 48 | `fat_header_t` | 文件分配表 (FAT) 头部。 |
| `main_remap_header`| `0x0650` (1616)| 64 | `remap_header_t` | 主重映射表头部。 |
| `meta_remap_header`| `0x0690` (1680)| 64 | `remap_header_t` | 元数据重映射表头部。 |
| `_0x6D0` | `0x06D0` (1744)| 8 | `uint64_t` | 填充。 |
| `extra_data` | `0x06D8` (1752)| 120 | `extra_data_t` | 额外的存档元数据。 |
| `_0x748` | `0x0750` (1872)| 912 | `uint8_t[0x390]`| 填充 (字段名在源文件中可能有误)。 |
| `fat_ivfc_header`| `0x0AE0` (2784)| 192 | `ivfc_save_hdr_t` | FAT 区域的 IVFC 头部。 |
| `_0xB98` | `0x0BA0` (2976)| 13344|`uint8_t[0x3480]`| 填充 (字段名和大小可能已修正以匹配0x4000)。|
| **总大小 (Total Size)**| | **16384 字节 (0x4000)** | | |

---

### 20. remap_entry_ctx_t
**来源:** `save.h`
**注意:** 此结构体在源文件中使用了 `#pragma pack(push, 1)`，表示所有成员都是紧密排列的。这里只描述其在文件中的 32 字节布局。

描述了存档文件中虚拟地址到物理地址的重映射条目。

| 字段 (Field) | 偏移量 (Offset) | 大小 (Size) | 类型 (Type) | 描述 (Description) |
|---|---|---|---|---|
| `virtual_offset` | `0x00` (0) | 8 | `uint64_t` | 虚拟偏移量。 |
| `physical_offset`| `0x08` (8) | 8 | `uint64_t` | 物理偏移量。 |
| `size` | `0x10` (16) | 8 | `uint64_t` | 该映射块的大小。 |
| `alignment` | `0x18` (24) | 4 | `uint32_t` | 对齐要求。 |
| `_0x1C` | `0x1C` (28) | 4 | `uint32_t` | 保留字段。 |
| **总大小 (Total Size)**| | **32 字节 (0x20)** | | |

---

### 21. xci_header_t
**来源:** `xci.h`

XCI (Game Card Image) 文件的头部结构。

| 字段 (Field) | 偏移量 (Offset) | 大小 (Size) | 类型 (Type) | 描述 (Description) |
|---|---|---|---|---|
| `header_sig` | `0x000` (0) | 256 | `uint8_t[0x100]`| 对 XCI 头部的 RSA-PKCS1 签名。 |
| `magic` | `0x100` (256)| 4 | `uint32_t` | 魔术字，应为 "HEAD" (0x44414548)。 |
| `secure_offset`| `0x104` (260)| 4 | `uint32_t` | 'secure' HFS0 分区的偏移量（以 media units 为单位）。 |
| `_0x108` | `0x108` (264)| 4 | `uint32_t` | 保留字段。 |
| `_0x10C` | `0x10C` (268)| 1 | `uint8_t` | 填充。 |
| `cart_type` | `0x10D` (269)| 1 | `uint8_t` | 卡带类型/大小。 |
| `_0x10E` | `0x10E` (270)| 1 | `uint8_t` | 填充。 |
| `_0x10F` | `0x10F` (271)| 1 | `uint8_t` | 填充。 |
| `_0x110` | `0x110` (272)| 8 | `uint64_t` | 保留字段。 |
| `cart_size` | `0x118` (280)| 8 | `uint64_t` | 卡带大小（以 media units 为单位）。 |
| `reversed_iv`| `0x120` (288)| 16 | `unsigned char[0x10]`| 反向的 IV，用于头部解密。 |
| `hfs0_offset` | `0x130` (304)| 8 | `uint64_t` | 根 HFS0 分区的偏移量。 |
| `hfs0_header_size`|`0x138` (312)| 8 | `uint64_t` | 根 HFS0 分区的大小。 |
| `hfs0_header_hash`|`0x140` (320)| 32 | `unsigned char[0x20]`| 根 HFS0 分区的 SHA-256 哈希。 |
| `crypto_header_hash`|`0x160` (352)| 32 | `unsigned char[0x20]`| 加密头部区域的 SHA-256 哈希。 |
| `_0x180` - `_0x18C`| `0x180` (384)| 16 | `uint32_t[4]`| 保留字段。 |
| `encrypted_data`| `0x190` (400)| 112 | `unsigned char[0x70]`| 加密的数据区域。 |
| **总大小 (Total Size)**| | **512 字节 (0x200)** | | |

---
