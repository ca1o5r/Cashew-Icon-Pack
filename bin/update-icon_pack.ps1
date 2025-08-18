#Requires -Version 5.0
<#
.SYNOPSIS
    从相对路径的目录获取PNG文件名，添加到XML的string-array节点中，对节点内容进行排序，并使用Tab缩进保存。

.DESCRIPTION
    此脚本综合了之前的所有需求：
    1. 使用相对于脚本位置的相对路径。
    2. 获取目录中所有PNG图片的文件名（不含扩展名）。
    3. 加载XML文件并定位到指定的<string-array>节点。
    4. 如果文件名对应的<item>不存在，则添加新节点。
    5. 在添加完成后，对<string-array>下的所有<item>节点按其内容进行字母排序。
    6. 如果XML内容发生了变化，使用Tab作为缩进字符，覆盖保存原文件。
#>

# --- 配置区域 ---

# 1. 包含PNG图片的相对目录路径 (相对于此脚本的位置)
$RelativeImageDirectory = "..\app\src\main\res\drawable-nodpi"

# 2. 目标XML文件的相对路径 (相对于此脚本的位置)
$RelativeXmlFilePath = "..\app\src\main\res\values\icon_pack.xml"

# 3. 在XML中要操作的 <string-array> 节点的 'name' 属性值
$StringArrayName = "icons_preview" # 请按需修改

# --- 脚本主体 ---

try {
    # 将相对路径转换为基于脚本位置的绝对路径
    $ScriptBaseDir = $PSScriptRoot
    $ImageDirectory = Join-Path -Path $ScriptBaseDir -ChildPath $RelativeImageDirectory
    $XmlFilePath = Join-Path -Path $ScriptBaseDir -ChildPath $RelativeXmlFilePath

    # 步骤 1: 获取目录下所有PNG文件的文件名
    Write-Host "正在从目录 `"$ImageDirectory`" 获取PNG文件名..."
    if (-not (Test-Path -Path $ImageDirectory -PathType Container)) {
        throw "错误：解析后的图片目录 `"$ImageDirectory`" 不存在或不是一个文件夹。"
    }

    $pngFileNames = @((Get-ChildItem -Path $ImageDirectory -Filter *.png).BaseName)

    if ($pngFileNames.Count -eq 0) {
        Write-Host "未在目录中找到任何PNG文件。脚本执行完毕。"
        exit 0
    }
    Write-Host "成功获取了 $($pngFileNames.Count) 个文件名。"

    # 步骤 2: 加载XML文件
    Write-Host "正在加载XML文件 `"$XmlFilePath`"..."
    if (-not (Test-Path -Path $XmlFilePath -PathType Leaf)) {
        throw "错误：解析后的XML文件 `"$XmlFilePath`" 不存在。"
    }

    $xmlDoc = [xml](Get-Content -Path $XmlFilePath -Raw)

    # 步骤 3: 查找指定的 string-array 节点
    $xpath = "//string-array[@name='$StringArrayName']"
    $targetArrayNode = $xmlDoc.SelectSingleNode($xpath)

    if (-not $targetArrayNode) {
        throw "错误：在XML文件中未找到 <string-array> 节点，其 name 属性为 `"$StringArrayName`"。"
    }
    Write-Host "成功定位到 <string-array name=`"$StringArrayName`"> 节点。"

    # 步骤 4: 将现有item内容存入哈希集以便快速查找
    $existingItems = [System.Collections.Generic.HashSet[string]]::new([string[]]$targetArrayNode.item)
    Write-Host "当前节点下有 $($existingItems.Count) 个已存在的item。"

    # 步骤 5: 遍历文件名，如果不存在则添加新节点
    $changesMade = $false
    foreach ($fileName in $pngFileNames) {
        if (-not $existingItems.Contains($fileName)) {
            Write-Host "发现新项目: `"$fileName`"，正在添加到XML中..."

            $newItem = $xmlDoc.CreateElement("item")
            $newItem.InnerText = $fileName
            $targetArrayNode.AppendChild($newItem) | Out-Null

            $changesMade = $true
        }
    }

    # =================================================================
    # 新增步骤 5.5: 对所有item节点按内容排序
    # =================================================================
    Write-Host "正在对节点下的所有 <item> 进行排序..."

    # 获取所有当前的 item 子节点
    $childNodes = $targetArrayNode.SelectNodes("item")

    # 基于节点的内部文本（内容）进行排序
    $sortedChildNodes = $childNodes | Sort-Object -Property InnerText

    # 先移除所有旧的 item 节点
    # 我们遍历原始列表进行删除，以避免在迭代时修改集合的问题
    foreach ($node in $childNodes) {
        $targetArrayNode.RemoveChild($node) | Out-Null
    }

    # 再将排序后的节点重新添加回去
    foreach ($node in $sortedChildNodes) {
        $targetArrayNode.AppendChild($node) | Out-Null
    }
    Write-Host "排序完成。"


    # 步骤 6: 如果有变动，则使用自定义设置重新保存XML文件
    if ($changesMade) {
        Write-Host "XML内容已更新，正在使用Tab缩进保存文件..."

        $writerSettings = New-Object System.Xml.XmlWriterSettings
        $writerSettings.Indent = $true
        $writerSettings.IndentChars = "`t"
        $writerSettings.Encoding = [System.Text.Encoding]::UTF8

        $xmlWriter = $null
        try {
            $xmlWriter = [System.Xml.XmlWriter]::Create($XmlFilePath, $writerSettings)
            $xmlDoc.Save($xmlWriter)
            Write-Host "文件 `"$XmlFilePath`" 已成功保存。"
        }
        finally {
            if ($xmlWriter -ne $null) {
                $xmlWriter.Close()
            }
        }

    } else {
        # 如果没有添加新文件，我们仍然可以考虑是否需要因排序而保存。
        # 为简化逻辑，当前脚本仅在添加新文件时才触发保存。
        # 如果您希望即使没有新文件也要强制重写并排序，可以将此处的 if 条件放宽。
        Write-Host "未发现需要添加的新项目，XML文件未作修改。"
    }

    Write-Host "脚本执行成功完成。"

}
catch {
    # 捕获任何在try块中发生的错误
    Write-Error "脚本执行失败: $_"
    # 使用非零退出码表示失败
    exit 1
}