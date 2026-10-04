# 一键配置 VS Code Java 编译环境

在 Windows 上双击一次，自动完成 VS Code 编写、编译、运行、调试 Java 所需的全部配置。

## 它会做什么

| 步骤 | 内容 |
| --- | --- |
| 1. JDK | 已有 JDK 17 及以上版本就直接使用；否则通过 winget 安装 Eclipse Temurin JDK 21 |
| 2. JAVA_HOME | 把当前用户的 `JAVA_HOME` 设置为上述 JDK |
| 3. VS Code | 未安装时通过 winget 安装 Visual Studio Code |
| 4. Java 扩展 | 安装 **Extension Pack for Java**（`vscjava.vscode-java-pack`），包括语言支持、调试器、测试运行器、Maven/Gradle 和项目管理 |
| 5. 示例项目 | 在“文档\JavaHello”生成可直接运行的项目，并用 VS Code 打开 |

## 使用方法

1. 下载本仓库（Code → Download ZIP）并解压。
2. 双击 `配置VSCode-Java环境.bat`。
3. 安装 JDK 时如果弹出管理员授权窗口，点“是”。
4. 完成后 VS Code 会自动打开示例项目。打开 `src/App.java`，点击 `main` 方法上方的 **Run**，或按 **F5** 运行。

### 可选参数

在本目录中打开 PowerShell，运行：

```powershell
# 安装其他版本的 JDK（可选 17 / 21 / 25，默认 21）
powershell -ExecutionPolicy Bypass -File .\SetupJavaVSCode.ps1 -JdkVersion 17

# 指定示例项目位置
powershell -ExecutionPolicy Bypass -File .\SetupJavaVSCode.ps1 -SampleProjectPath D:\code\hello

# 只配置环境，不创建示例项目
powershell -ExecutionPolicy Bypass -File .\SetupJavaVSCode.ps1 -SkipSampleProject
```

## 生成的示例项目

```
JavaHello
├─ .vscode
│  ├─ settings.json   # 源码目录 src、输出目录 bin、JDK 路径、UTF-8 编码
│  └─ launch.json     # F5 运行配置（主类 App，在集成终端输出）
└─ src
   └─ App.java
```

## 注意事项

- **系统要求**：Windows 10（1809 及以上）或 Windows 11，需要联网。
- **需要 winget**：Windows 11 和较新的 Windows 10 一般自带。如果提示找不到 winget，请先在 Microsoft Store 安装或更新“应用安装程序（App Installer）”。
- **管理员权限**：JDK 按系统级安装，可能会弹出授权窗口；VS Code 和扩展装在当前用户下，不需要管理员权限。
- **已有 JDK**：如果 `java` 命令能找到 JDK 17 或更高版本，就不会重复安装，`JAVA_HOME` 会指向这个 JDK。版本低于 17（例如 JDK 8）时会另外安装新版 JDK，旧版本保留不动。
- **重开窗口**：脚本修改了环境变量。之前已打开的命令行、PowerShell 或 VS Code 窗口不会自动更新；如果找不到 `java`，关掉重开即可。
- **不会覆盖文件**：示例项目目录已存在且不为空时，会跳过创建。
- **中文乱码**：示例项目统一使用 UTF-8 编码。如果自己的旧代码是 GBK 编码，在 VS Code 右下角点击编码，选择“通过编码重新打开”→ GBK。
- **执行策略**：`.bat` 启动器使用 `-ExecutionPolicy Bypass` 只为本次运行放行脚本，不会修改系统的执行策略设置。
- **杀毒软件**：少数安全软件可能拦截脚本安装软件，放行或临时关闭后重试即可。
- **网络问题**：winget 或扩展市场下载失败时，可以换个网络重试，也可以手动安装 [Temurin JDK](https://adoptium.net/) 和 [VS Code](https://code.visualstudio.com/)，再运行本脚本完成剩下的配置。

## 卸载

- JDK、VS Code：在“设置 → 应用”中卸载。
- Java 扩展：在 VS Code 扩展面板中卸载 Extension Pack for Java。
- `JAVA_HOME`：在“系统属性 → 环境变量 → 用户变量”中删除。
