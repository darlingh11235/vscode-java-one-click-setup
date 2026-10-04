[CmdletBinding()]
param(
    [ValidateSet('17', '21', '25')]
    [string]$JdkVersion = '21',
    [string]$SampleProjectPath = (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'JavaHello'),
    [switch]$SkipSampleProject
)

$ErrorActionPreference = 'Stop'

function Write-Step([string]$Message) {
    Write-Host ''
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Update-SessionPath {
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = "$machine;$user"
}

function Install-WingetPackage([string]$Id) {
    & winget install --id $Id --exact --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "winget 安装 $Id 返回代码 $LASTEXITCODE，将继续检测是否已可用。"
    }
    Update-SessionPath
}

# 通过 java 自身报告的 java.home 定位 JDK，可兼容 Oracle javapath 等快捷方式
function Get-JavaInfo {
    if (-not (Get-Command java -ErrorAction SilentlyContinue)) { return $null }
    $output = & cmd.exe /c 'java -XshowSettings:properties -version 2>&1'
    $versionLine = $output | Where-Object { $_ -match 'java\.specification\.version\s*=' } | Select-Object -First 1
    $homeLine = $output | Where-Object { $_ -match 'java\.home\s*=' } | Select-Object -First 1
    if (-not $versionLine -or -not $homeLine) { return $null }
    $version = ($versionLine -split '=', 2)[1].Trim()
    $javaHome = ($homeLine -split '=', 2)[1].Trim()
    if (-not (Test-Path (Join-Path $javaHome 'bin\javac.exe'))) { return $null }
    $major = if ($version -like '1.*') { [int]($version -split '\.')[1] } else { [int]$version }
    [pscustomobject]@{ Major = $major; Home = $javaHome }
}

function Find-TemurinHome([string]$Version) {
    $root = Join-Path $env:ProgramFiles 'Eclipse Adoptium'
    if (-not (Test-Path $root)) { return $null }
    Get-ChildItem -Path $root -Directory -Filter "jdk-$Version*" |
        Where-Object { Test-Path (Join-Path $_.FullName 'bin\javac.exe') } |
        Sort-Object Name -Descending |
        Select-Object -First 1 -ExpandProperty FullName
}

function Find-CodeCommand {
    $command = Get-Command code.cmd -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\Microsoft VS Code\bin\code.cmd'),
        (Join-Path $env:ProgramFiles 'Microsoft VS Code\bin\code.cmd')
    )
    $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
}

function Write-Utf8File([string]$Path, [string]$Content) {
    # 不带 BOM：javac 会把 BOM 当成非法字符
    [System.IO.File]::WriteAllText($Path, $Content, (New-Object System.Text.UTF8Encoding $false))
}

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw '未找到 winget。请先在 Microsoft Store 安装或更新“应用安装程序 (App Installer)”，然后重新运行本脚本。'
}

Write-Step '检查 JDK'
$java = Get-JavaInfo
if ($java -and $java.Major -ge 17) {
    Write-Host "已检测到 JDK $($java.Major)：$($java.Home)"
    $jdkHome = $java.Home
    $jdkMajor = $java.Major
}
else {
    if ($java) { Write-Host "当前 JDK 版本 $($java.Major) 过旧，将额外安装 JDK $JdkVersion。" }
    Write-Host "正在安装 Eclipse Temurin JDK $JdkVersion（可能弹出管理员授权窗口）..."
    Install-WingetPackage "EclipseAdoptium.Temurin.$JdkVersion.JDK"
    $jdkHome = Find-TemurinHome $JdkVersion
    if (-not $jdkHome) { throw "JDK $JdkVersion 安装后仍未找到，请检查 winget 输出。" }
    $jdkMajor = [int]$JdkVersion
    Write-Host "JDK 安装位置：$jdkHome"
}

Write-Step '设置 JAVA_HOME（当前用户）'
[Environment]::SetEnvironmentVariable('JAVA_HOME', $jdkHome, 'User')
$env:JAVA_HOME = $jdkHome
Write-Host "JAVA_HOME = $jdkHome"

Write-Step '检查 VS Code'
$code = Find-CodeCommand
if (-not $code) {
    Write-Host '正在安装 Visual Studio Code...'
    Install-WingetPackage 'Microsoft.VisualStudioCode'
    $code = Find-CodeCommand
    if (-not $code) { throw 'VS Code 安装后仍未找到 code 命令，请检查 winget 输出。' }
}
Write-Host "VS Code 命令：$code"

Write-Step '安装 Java 扩展包（Extension Pack for Java）'
& $code --install-extension vscjava.vscode-java-pack --force
if ($LASTEXITCODE -ne 0) { throw "扩展安装失败（返回代码 $LASTEXITCODE）。" }

if (-not $SkipSampleProject) {
    Write-Step '创建示例项目'
    if ((Test-Path $SampleProjectPath) -and (Get-ChildItem -Path $SampleProjectPath -Force | Select-Object -First 1)) {
        Write-Host "目录已存在且不为空，跳过创建：$SampleProjectPath"
    }
    else {
        $srcDir = Join-Path $SampleProjectPath 'src'
        $vscodeDir = Join-Path $SampleProjectPath '.vscode'
        New-Item -ItemType Directory -Force -Path $srcDir, $vscodeDir | Out-Null

        $settings = [ordered]@{
            'java.project.sourcePaths' = @('src')
            'java.project.outputPath' = 'bin'
            'java.configuration.runtimes' = @(
                [ordered]@{ name = "JavaSE-$jdkMajor"; path = $jdkHome; default = $true }
            )
            'files.encoding' = 'utf8'
        }
        $launch = [ordered]@{
            version = '0.2.0'
            configurations = @(
                [ordered]@{
                    type = 'java'
                    name = 'Run App'
                    request = 'launch'
                    mainClass = 'App'
                    console = 'integratedTerminal'
                }
            )
        }
        $app = @'
public class App {
    public static void main(String[] args) {
        System.out.println("Hello, Java! 你好，Java！");
        System.out.println("Java 版本: " + System.getProperty("java.version"));
    }
}
'@
        Write-Utf8File (Join-Path $vscodeDir 'settings.json') ($settings | ConvertTo-Json -Depth 5)
        Write-Utf8File (Join-Path $vscodeDir 'launch.json') ($launch | ConvertTo-Json -Depth 5)
        Write-Utf8File (Join-Path $srcDir 'App.java') $app
        Write-Host "示例项目已创建：$SampleProjectPath"
    }

    Write-Step '用 VS Code 打开示例项目'
    & $code $SampleProjectPath
}

Write-Host ''
Write-Host '完成！在 VS Code 中打开 App.java，点击 main 方法上方的 Run，或按 F5 运行。' -ForegroundColor Green
Write-Host '若其他已打开的终端或 VS Code 窗口仍找不到 java，请将其关闭后重新打开。' -ForegroundColor Green
