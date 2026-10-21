# update-appfilter.ps1
# PowerShell 版本的应用过滤器更新脚本
# 用法: .\scripts\update-appfilter.ps1 [-SrcPath <项目根目录>]

param (
    # 默认取脚本所在目录的上一级（即项目根目录）
    [string]$SrcPath = (Split-Path -Path $PSScriptRoot -Parent)
)

$Src_APP_Filter_XML_File_Name = Join-Path -Path $SrcPath -ChildPath "app\src\main\res\xml\appfilter.xml"

# 检查源文件是否存在
if (-not (Test-Path -Path $Src_APP_Filter_XML_File_Name -PathType Leaf)) {
    Write-Error "Error: Src Icon XML file not found: $Src_APP_Filter_XML_File_Name"
    exit 1
}

# 解析 ADB 路径：PATH → local.properties 的 sdk.dir → ANDROID_HOME/ANDROID_SDK_ROOT → 默认安装路径
function Resolve-AdbPath {
    param ([string]$ProjectRoot)

    $FromPath = Get-Command "adb.exe" -ErrorAction SilentlyContinue
    if ($FromPath) { return $FromPath.Source }

    $Candidates = @()

    $LocalProperties = Join-Path -Path $ProjectRoot -ChildPath "local.properties"
    if (Test-Path -Path $LocalProperties -PathType Leaf) {
        $SdkLine = Select-String -Path $LocalProperties -Pattern '^\s*sdk\.dir\s*=' | Select-Object -First 1
        if ($SdkLine) {
            # .properties 转义还原：C\:\\Android-SDK -> C:\Android-SDK
            $SdkDir = ($SdkLine.Line -replace '^\s*sdk\.dir\s*=\s*', '').Trim().Replace('\:', ':').Replace('\\', '\')
            if ($SdkDir) { $Candidates += (Join-Path -Path $SdkDir -ChildPath "platform-tools\adb.exe") }
        }
    }

    foreach ($EnvSdk in @($env:ANDROID_HOME, $env:ANDROID_SDK_ROOT)) {
        if ($EnvSdk) { $Candidates += (Join-Path -Path $EnvSdk -ChildPath "platform-tools\adb.exe") }
    }

    $Candidates += (Join-Path -Path $env:LOCALAPPDATA -ChildPath "Android\Sdk\platform-tools\adb.exe")

    foreach ($Candidate in $Candidates) {
        if ($Candidate -and (Test-Path -Path $Candidate -PathType Leaf)) { return $Candidate }
    }

    return $null
}

$ADB_Path = Resolve-AdbPath -ProjectRoot $SrcPath
if (-not $ADB_Path) {
    Write-Error "ADB not found. Checked PATH, '$SrcPath\local.properties' (sdk.dir), ANDROID_HOME, ANDROID_SDK_ROOT and %LOCALAPPDATA%\Android\Sdk\platform-tools."
    exit 1
}
Write-Host "Using ADB: $ADB_Path"

# 获取已安装包列表
$Packages = & $ADB_Path shell pm list packages
if (-not $Packages) {
    Write-Error "No device/emulator connected, or 'adb shell pm list packages' returned nothing."
    exit 1
}
Write-Host "Installed packages: $($Packages.Count)"

# 查找 XML 文件的起始行
$APP_Filter_XML_Begin_Line_Number = (Select-String -Path $Src_APP_Filter_XML_File_Name -Pattern "<resources>" | Select-Object -First 1).LineNumber

# 处理每个包
foreach ($Line in $Packages) {
    $Package_Name = $Line.Split(":")[1]
    $Launch_Activity_Output = & $ADB_Path shell -n cmd package resolve-activity --brief $Package_Name
    $Launch_Activity_Raw = ($Launch_Activity_Output | Select-Object -Last 1)
    if ($Launch_Activity_Raw) { $Launch_Activity_Raw = $Launch_Activity_Raw.Trim() }

    # 无默认 Activity（输出为 "No activity found"）时跳过，避免写入 ComponentInfo{pkg/} 这类空组件
    if ([string]::IsNullOrWhiteSpace($Launch_Activity_Raw) -or $Launch_Activity_Raw -eq "No activity found" -or -not $Launch_Activity_Raw.Contains("/")) {
        continue
    }

    $Launch_Activity = $Launch_Activity_Raw.Substring($Launch_Activity_Raw.IndexOf("/") + 1)

    if ($Launch_Activity) {
        # 检查简单组件名
        $APP_Filter_XML_Simple_Line_Number = (Select-String -Path $Src_APP_Filter_XML_File_Name -Pattern "<item component=`"ComponentInfo{$Package_Name/$Launch_Activity}`"" | Select-Object -First 1).LineNumber

        if (-not $APP_Filter_XML_Simple_Line_Number) {
            if ($Launch_Activity.StartsWith(".")) {
                # 检查完整组件名（包名+活动名）
                $APP_Filter_XML_Full_Line_Number = (Select-String -Path $Src_APP_Filter_XML_File_Name -Pattern "<item component=`"ComponentInfo{$Package_Name/$Package_Name$Launch_Activity}`"" | Select-Object -First 1).LineNumber

                if (-not $APP_Filter_XML_Full_Line_Number) {
                    $APP_Filter_XML_Begin_Line_Number++
                    $APP_Filter_XML_Insert_Contents = "    <item component=`"ComponentInfo{$Package_Name/$Package_Name$Launch_Activity}`" drawable=`"sleep_as_android`" />"
                    
                    # 在指定行插入内容
                    $Content = Get-Content -Path $Src_APP_Filter_XML_File_Name
                    $Content = $Content[0..($APP_Filter_XML_Begin_Line_Number-2)] + $APP_Filter_XML_Insert_Contents + $Content[($APP_Filter_XML_Begin_Line_Number-1)..($Content.Length)]
                    $Content | Set-Content -Path $Src_APP_Filter_XML_File_Name
                    
                    Write-Output "Append APP Filter XML: $APP_Filter_XML_Insert_Contents at line $APP_Filter_XML_Begin_Line_Number"
                    Write-Output "------------------"
                }
            }
            else {
                $APP_Filter_XML_Begin_Line_Number++
                $APP_Filter_XML_Insert_Contents = "    <item component=`"ComponentInfo{$Package_Name/$Launch_Activity}`" drawable=`"sleep_as_android`" />"
                
                # 在指定行插入内容
                $Content = Get-Content -Path $Src_APP_Filter_XML_File_Name
                $Content = $Content[0..($APP_Filter_XML_Begin_Line_Number-2)] + $APP_Filter_XML_Insert_Contents + $Content[($APP_Filter_XML_Begin_Line_Number-1)..($Content.Length)]
                $Content | Set-Content -Path $Src_APP_Filter_XML_File_Name
                
                Write-Output "Append APP Filter XML: $APP_Filter_XML_Insert_Contents at line $APP_Filter_XML_Begin_Line_Number"
                Write-Output "------------------"
            }
        }
    }
}