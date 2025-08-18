#Requires -Version 5.0
<#
.SYNOPSIS
    在XML中查找特定category节点，将其后的同级item节点进行更新和排序。
    在保存时，对所有category节点之后的item节点应用特殊的额外缩进。

.DESCRIPTION
    此脚本实现了复杂的逻辑更新和全局格式化：
    1. 使用相对路径查找PNG图片和XML文件。
    2. 在XML中定位 <category title="All"> 节点，并只在该节点后的区间内添加和排序item。
    3. 在最后保存文件时，识别出所有<category>节点以及它们后面的同级<item>区块。
    4. 手动构建输出字符串，为所有这些区块中的<item>节点添加额外缩进。
    5. 使用Tab作为缩进字符，覆盖保存原文件。
#>

# --- 配置区域 ---

$RelativeImageDirectory = "..\app\src\main\res\drawable-nodpi"
$RelativeXmlFilePath = "..\app\src\main\res\xml\drawable.xml"
# 这个变量现在只用于定位“添加新文件”的目标区域
$TargetUpdateCategoryTitle = "All"

# --- 脚本主体 ---

try {
    # 路径解析和文件获取部分
    $ScriptBaseDir = $PSScriptRoot
    $ImageDirectory = Join-Path -Path $ScriptBaseDir -ChildPath $RelativeImageDirectory
    $XmlFilePath = Join-Path -Path $ScriptBaseDir -ChildPath $RelativeXmlFilePath

    Write-Host "正在从目录 `"$ImageDirectory`" 获取PNG文件名..."
    if (-not (Test-Path -Path $ImageDirectory -PathType Container)) { throw "错误：图片目录 `"$ImageDirectory`" 不存在。" }
    $pngFileNames = @((Get-ChildItem -Path $ImageDirectory -Filter *.png).BaseName)
    if ($pngFileNames.Count -eq 0) {
        Write-Host "未找到任何PNG文件。脚本执行完毕。"
        exit 0
    }
    Write-Host "成功获取了 $($pngFileNames.Count) 个文件名。"

    Write-Host "正在加载XML文件 `"$XmlFilePath`"..."
    if (-not (Test-Path -Path $XmlFilePath -PathType Leaf)) { throw "错误：XML文件 `"$XmlFilePath`" 不存在。" }
    $xmlDoc = [xml](Get-Content -Path $XmlFilePath -Raw)

    # 步骤 3 & 4 & 5: 定位、添加和排序item，这些操作仍然只针对 title="All" 的区块
    $updateTargetXPath = "//category[@title='$TargetUpdateCategoryTitle']"
    $updateTargetNode = $xmlDoc.SelectSingleNode($updateTargetXPath)

    if (-not $updateTargetNode) {
        Write-Warning "未找到用于更新的 <category title=`"$TargetUpdateCategoryTitle`"> 节点。将只进行全局格式化（如果需要保存）。"
    } else {
        Write-Host "成功定位到用于更新的 <category title=`"$TargetUpdateCategoryTitle`"> 节点。"
        $endNodeForUpdate = $updateTargetNode.SelectSingleNode("following-sibling::category")

        $itemsToUpdate = New-Object System.Collections.ArrayList
        $currentNode = $updateTargetNode.NextSibling
        while ($currentNode -and ($currentNode -ne $endNodeForUpdate)) {
            if ($currentNode.Name -eq 'item') {
                $itemsToUpdate.Add($currentNode) | Out-Null
            }
            $currentNode = $currentNode.NextSibling
        }

        $existingDrawables = [System.Collections.Generic.HashSet[string]]::new()
        foreach ($item in $itemsToUpdate) {
            if ($item.HasAttribute("drawable")) {
                $existingDrawables.Add($item.drawable) | Out-Null
            }
        }

        $changesMade = $false
        $parentNode = $updateTargetNode.ParentNode
        foreach ($fileName in $pngFileNames) {
            if (-not $existingDrawables.Contains($fileName)) {
                Write-Host "发现新项目: `"$fileName`"，正在添加到XML中..."
                $newItem = $xmlDoc.CreateElement("item")
                $newItem.SetAttribute("drawable", $fileName)
                $parentNode.InsertBefore($newItem, $endNodeForUpdate) | Out-Null
                $changesMade = $true
            }
        }

        # 重新获取需要排序的item列表（因为可能已添加新节点）
        $itemsToSort = New-Object System.Collections.ArrayList
        $current = $updateTargetNode.NextSibling
        while ($current -and ($current -ne $endNodeForUpdate)) {
            if ($current.Name -eq 'item') {
                $itemsToSort.Add($current) | Out-Null
            }
            $current = $current.NextSibling
        }

        if ($itemsToSort.Count -gt 0) {
            Write-Host "正在对 <category title=`"$TargetUpdateCategoryTitle`"> 区块的item进行排序..."
            $sortedItems = $itemsToSort | Sort-Object -Property @{Expression={$_.Attributes['drawable'].Value}}
            foreach ($node in $itemsToSort) { $parentNode.RemoveChild($node) | Out-Null }
            foreach ($node in $sortedItems) { $parentNode.InsertBefore($node, $endNodeForUpdate) | Out-Null }
            Write-Host "排序完成。"
        }
    }


    # 步骤 6: 如果有变动，则手动构建字符串并保存文件
    # 注意：即使没有新文件（$changesMade为false），如果XML需要被重新格式化，也可以将此if条件移除。
    # 为安全起见，此处保留仅在有内容更新时才重写文件的逻辑。
    if ($changesMade) {
        Write-Host "XML内容已更新，正在以全局自定义缩进格式保存文件..."

        $stringBuilder = New-Object System.Text.StringBuilder
        $stringBuilder.AppendLine($xmlDoc.FirstChild.OuterXml) | Out-Null

        $rootNode = $xmlDoc.DocumentElement
        $stringBuilder.AppendLine("<$($rootNode.Name)>") | Out-Null

        # --- 全局格式化逻辑 ---
        # 1. 找到所有需要特殊缩进的item
        $itemsToIndentLookup = [System.Collections.Generic.HashSet[string]]::new()
        $allCategories = $xmlDoc.SelectNodes("//category")
        foreach ($categoryNode in $allCategories) {
            $current = $categoryNode.NextSibling
            # 找到此category之后、下一个category之前的所有item
            while ($current -and $current.Name -ne 'category') {
                if ($current.Name -eq 'item') {
                    $itemsToIndentLookup.Add($current.OuterXml) | Out-Null
                }
                $current = $current.NextSibling
            }
        }

        # 2. 遍历根节点的所有子节点，手动添加缩进
        foreach ($childNode in $rootNode.ChildNodes) {
            if ($childNode.NodeType -eq 'Element') {
                $line = "`t" # 基础缩进
                if ($itemsToIndentLookup.Contains($childNode.OuterXml)) {
                    $line += "`t" # 对目标item添加额外缩进
                }
                $line += $childNode.OuterXml
                $stringBuilder.AppendLine($line) | Out-Null
            }
        }

        $stringBuilder.AppendLine("</$($rootNode.Name)>") | Out-Null
        $stringBuilder.ToString() | Out-File -FilePath $XmlFilePath -Encoding UTF8

        Write-Host "文件 `"$XmlFilePath`" 已成功保存。"
    } else {
        Write-Host "未发现需要添加的新项目，XML文件未作修改。"
    }

    Write-Host "脚本执行成功完成。"
}
catch {
    Write-Error "脚本执行失败: $_"
    exit 1
}