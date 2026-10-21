#!/bin/bash

# --- 配置区域 ---
# 1. 包含PNG图片的相对目录路径
RelativeImageDirectory="../app/src/main/res/drawable-nodpi"
# 2. 目标XML文件的相对路径
RelativeXmlFilePath="../app/src/main/res/xml/drawable.xml"
# 3. 用于定位“添加新文件”的目标区域的category节点的title属性值
TargetUpdateCategoryTitle="All"


# --- 脚本主体 ---

# 函数：打印带颜色的信息
print_info() { echo -e "\033[32m[INFO]\033[0m $1"; }
print_warn() { echo -e "\033[33m[WARN]\033[0m $1"; }
print_error() { echo -e "\033[31m[ERROR]\033[0m $1"; }

# --- 依赖检查与安装 ---
print_info "正在检查所需工具 'xmlstarlet'..."
if ! command -v xmlstarlet &> /dev/null; then
    print_warn "'xmlstarlet' 命令未找到。脚本将尝试自动安装。"
    if ! command -v brew &> /dev/null; then
        print_error "自动安装失败：未找到 Homebrew。请先访问 https://brew.sh 手动安装 Homebrew，然后再重新运行此脚本。"
        exit 1
    fi
    print_info "正在使用 Homebrew 更新包列表并安装 'xmlstarlet' (这可能需要几分钟，并可能需要您输入密码)..."
    if ! brew update; then
        print_warn "Homebrew 更新失败，将继续尝试安装..."
    fi
    if ! brew install xmlstarlet; then
        print_error "使用 Homebrew 安装 'xmlstarlet' 失败。请尝试手动运行 'brew install xmlstarlet'。"
        exit 1
    fi
    if ! command -v xmlstarlet &> /dev/null; then
        print_error "安装 'xmlstarlet' 后仍然无法找到该命令。请检查您的系统 PATH 环境变量或重新打开一个新的终端窗口再试。"
        exit 1
    fi
    print_info "'xmlstarlet' 已成功安装。"
else
    print_info "'xmlstarlet' 已安装。"
fi
# --- 依赖检查完毕 ---


# 获取并转换路径
ScriptBaseDir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
ImageDirectory="$ScriptBaseDir/$RelativeImageDirectory"
XmlFilePath="$ScriptBaseDir/$RelativeXmlFilePath"

# 步骤 1: 获取PNG文件名
print_info "正在从目录 \"$ImageDirectory\" 获取PNG文件名..."
if [ ! -d "$ImageDirectory" ]; then print_error "图片目录 \"$ImageDirectory\" 不存在。"; exit 1; fi
pngFileNames=$(find "$ImageDirectory" -name "*.png" -type f -exec basename {} .png \;)
pngFileCount=$(echo "$pngFileNames" | wc -l | xargs)
if [ "$pngFileCount" -eq 0 ]; then print_info "未找到任何PNG文件。"; exit 0; fi
print_info "成功获取了 $pngFileCount 个文件名。"

# 步骤 2: 加载XML文件
print_info "正在加载XML文件 \"$XmlFilePath\"..."
if [ ! -f "$XmlFilePath" ]; then print_error "XML文件 \"$XmlFilePath\" 不存在。"; exit 1; fi

# 定义用于更新的XPath
updateTargetXPath="//category[@title='$TargetUpdateCategoryTitle']"

# 步骤 3 & 4 & 5: 定位、添加和排序item (只针对目标category)
if ! xmlstarlet sel -t -c "$updateTargetXPath" "$XmlFilePath" &> /dev/null; then
    print_warn "未找到用于更新的 <category title=\"$TargetUpdateCategoryTitle\"> 节点。将只进行全局格式化。"
    changesMade="false"
else
    print_info "成功定位到用于更新的 <category title=\"$TargetUpdateCategoryTitle\"> 节点。"
    
    # 创建一个临时文件用于所有修改操作
    tempFile=$(mktemp)
    cp "$XmlFilePath" "$tempFile"

    # 获取此category之后、下一个category之前的所有item
    # xmlstarlet不支持直接的DOM遍历，我们用XPath的following-sibling和preceding-sibling组合来模拟
    nextCategoryXPath="$updateTargetXPath/following-sibling::category[1]"
    # 计算下一个category之前有多少个同级节点，以便正确选取item
    countPrecedingNextCategory=$(xmlstarlet sel -t -v "count($nextCategoryXPath/preceding-sibling::*)" "$tempFile")
    
    # 选取item的XPath
    if [ -z "$countPrecedingNextCategory" ]; then #如果没有下一个category
        itemsXPath="$updateTargetXPath/following-sibling::item"
    else
        itemsXPath="$updateTargetXPath/following-sibling::item[count(preceding-sibling::*) <= $countPrecedingNextCategory]"
    fi
    
    existingDrawables=$(xmlstarlet sel -t -v "$itemsXPath/@drawable" "$tempFile")

    changesMade="false"
    itemsToAdd=""
    for fileName in $pngFileNames; do
        if ! echo "$existingDrawables" | grep -qx "$fileName"; then
            print_info "发现新项目: \"$fileName\"，准备添加到XML中..."
            itemsToAdd="$itemsToAdd $fileName"
            changesMade="true"
        fi
    done

    if [ "$changesMade" == "true" ]; then
        # 准备批量添加操作
        add_ops=""
        for item in $itemsToAdd; do
            # -i (insert) 在指定节点前插入
            # 如果$nextCategoryXPath为空(即没有下一个category), 则-a (append)追加到末尾
            if [ -z "$countPrecedingNextCategory" ]; then
                add_ops="$add_ops -a $updateTargetXPath -t elem -n item -a drawable -v $item"
            else
                add_ops="$add_ops -i $nextCategoryXPath -t elem -n item -a drawable -v $item"
            fi
        done
        # 执行添加
        xmlstarlet ed -L $add_ops "$tempFile"
    fi

    # 排序
    print_info "正在对 <category title=\"$TargetUpdateCategoryTitle\"> 区块的item进行排序..."
    # 重新计算itemsXPath和count，因为节点数可能已变
    countPrecedingNextCategory=$(xmlstarlet sel -t -v "count($nextCategoryXPath/preceding-sibling::*)" "$tempFile")
    if [ -z "$countPrecedingNextCategory" ]; then itemsXPath="$updateTargetXPath/following-sibling::item"; else itemsXPath="$updateTargetXPath/following-sibling::item[count(preceding-sibling::*) <= $countPrecedingNextCategory]"; fi

    # 提取、排序、删除、重新插入
    itemsToSort=$(xmlstarlet sel -t -v "$itemsXPath/@drawable" "$tempFile" | sort)
    xmlstarlet ed -L -d "$itemsXPath" "$tempFile" # 删除区块内所有item
    
    insert_ops=""
    for item in $itemsToSort; do
        if [ -z "$countPrecedingNextCategory" ]; then
            insert_ops="$insert_ops -a $updateTargetXPath -t elem -n item -a drawable -v $item"
        else
            insert_ops="$insert_ops -i $nextCategoryXPath -t elem -n item -a drawable -v $item"
        fi
    done
    xmlstarlet ed -L $insert_ops "$tempFile"
    print_info "排序完成。"
    
    # 将修改后的内容作为最终要格式化的文件
    FinalXmlSourceFile="$tempFile"
fi

# 步骤 6: 如果有变动，则手动构建字符串并保存文件
if [ "$changesMade" == "true" ]; then
    print_info "XML内容已更新，正在以全局自定义缩进格式保存文件..."
    
    # 获取XML声明和根节点名
    xmlDeclaration=$(xmlstarlet sel -t -o '<?xml version="1.0" encoding="utf-8"?>' "$FinalXmlSourceFile")
    rootName=$(xmlstarlet sel -t -v "name(/*)" "$FinalXmlSourceFile")

    # 创建最终输出文件
    finalOutputFile=$(mktemp)
    echo "$xmlDeclaration" > "$finalOutputFile"
    echo "<$rootName>" >> "$finalOutputFile"

    # --- 全局格式化逻辑 ---
    # 1. 提取所有category和item的OuterXml
    allNodesOutput=$(xmlstarlet sel -t -c "//category | //item" "$FinalXmlSourceFile")

    # 2. 使用awk进行高级文本处理来添加自定义缩进
    # 'is_in_block'是一个状态标志
    # 遇到<category>时，设置标志；遇到<item>且标志被设置时，添加额外Tab
    echo "$allNodesOutput" | awk '
        /<category/ {
            print "\t" $0; 
            is_in_block=1; 
            next; 
        }
        /<item/ {
            if (is_in_block) {
                print "\t\t" $0;
            } else {
                print "\t" $0;
            }
            next;
        }
    ' >> "$finalOutputFile"

    echo "</$rootName>" >> "$finalOutputFile"

    # 将格式化后的内容写回原文件
    mv "$finalOutputFile" "$XmlFilePath"
    
    print_info "文件 \"$XmlFilePath\" 已成功保存。"
    
    # 如果使用了临时文件，则删除
    if [ -n "$tempFile" ]; then
        rm "$tempFile"
    fi
else
    print_info "未发现需要添加的新项目，XML文件未作修改。"
fi

print_info "脚本执行成功完成。"