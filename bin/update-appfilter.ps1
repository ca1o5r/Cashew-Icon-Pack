# update-appfilter.ps1
# PowerShell 版本的应用过滤器更新脚本

param (
    [string]$SrcPath
)

$Src_APP_Filter_XML_File_Name = Join-Path -Path $SrcPath -ChildPath "app\src\main\res\xml\appfilter.xml"

# 检查源文件是否存在
if (-not (Test-Path -Path $Src_APP_Filter_XML_File_Name -PathType Leaf)) {
    Write-Error "Error: Src Icon XML file not found: $Src_APP_Filter_XML_File_Name"
    exit 1
}

# 设置 ADB 路径（Windows 默认路径）
$ADB_Path = "adb.exe"
if (-not (Get-Command $ADB_Path -ErrorAction SilentlyContinue)) {
    $ADB_Path = Join-Path -Path $env:LOCALAPPDATA -ChildPath "Android\Sdk\platform-tools\adb.exe"
    if (-not (Test-Path -Path $ADB_Path)) {
        Write-Error "ADB not found. Please ensure Android SDK is installed and adb is in your PATH"
        exit 1
    }
}

# 获取已安装包列表
$Packages = & $ADB_Path shell pm list packages

# 查找 XML 文件的起始行
$APP_Filter_XML_Begin_Line_Number = (Select-String -Path $Src_APP_Filter_XML_File_Name -Pattern "<resources>" | Select-Object -First 1).LineNumber

# 处理每个包
foreach ($Line in $Packages) {
    $Package_Name = $Line.Split(":")[1]
    $Launch_Activity_Output = & $ADB_Path shell -n cmd package resolve-activity --brief $Package_Name
    $Launch_Activity = $Launch_Activity_Output | Select-Object -Last 1 | ForEach-Object { $_.Split("/")[1..($_.Length)] -join "/" }
    
    if ($Launch_Activity -ne "No activity found") {
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