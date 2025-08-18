#!/bin/bash

# --- 配置区域 ---

# 1. 包含PNG图片的相对目录路径 (相对于此脚本的位置)
# 注意：路径中不要使用反斜杠 '\'
RelativeImageDirectory="../app/src/main/res/drawable-nodpi"

# 2. 目标XML文件的相对路径
RelativeXmlFilePath="../app/src/main/res/values/icon_pack.xml"

# 3. 在XML中要操作的 <string-array> 节点的 'name' 属性值
StringArrayName="icons_preview"


# --- 脚本主体 ---

# 函数：打印带颜色的信息
print_info() {
    # 绿色
    echo -e "\033[32m[INFO]\033[0m $1"
}

print_warn() {
    # 黄色
    echo -e "\033[33m[WARN]\033[0m $1"
}

print_error() {
    # 红色
    echo -e "\033[31m[ERROR]\033[0m $1"
}

# --- 依赖检查与安装 ---
print_info "正在检查所需工具 'xmlstarlet'..."
if ! command -v xmlstarlet &> /dev/null
then
    print_warn "'xmlstarlet' 命令未找到。脚本将尝试自动安装。"

    # 检查 Homebrew 是否安装
    if ! command -v brew &> /dev/null
    then
        print_error "自动安装失败：未找到 Homebrew。请先访问 https://brew.sh 手动安装 Homebrew，然后再重新运行此脚本。"
        exit 1
    fi

    # 尝试使用 Homebrew 安装 xmlstarlet
    print_info "正在使用 Homebrew 更新包列表并安装 'xmlstarlet' (这可能需要几分钟，并可能需要您输入密码)..."

    # 先更新brew，避免因包信息过旧导致安装失败
    if ! brew update; then
        print_warn "Homebrew 更新失败，将继续尝试安装..."
    fi

    if ! brew install xmlstarlet; then
        print_error "使用 Homebrew 安装 'xmlstarlet' 失败。请检查您的 Homebrew 配置或尝试手动运行 'brew install xmlstarlet'，然后再重新运行此脚本。"
        exit 1
    fi

    # 再次检查以确认安装成功
    if ! command -v xmlstarlet &> /dev/null
    then
        print_error "安装 'xmlstarlet' 后仍然无法找到该命令。请检查您的系统 PATH 环境变量或重新打开一个新的终端窗口再试。"
        exit 1
    fi

    print_info "'xmlstarlet' 已成功安装。"
else
    print_info "'xmlstarlet' 已安装。"
fi
# --- 依赖检查完毕 ---


# 获取脚本所在的目录
ScriptBaseDir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# 将相对路径转换为绝对路径
ImageDirectory="$ScriptBaseDir/$RelativeImageDirectory"
XmlFilePath="$ScriptBaseDir/$RelativeXmlFilePath"


# 步骤 1: 获取目录下所有PNG文件的文件名
print_info "正在从目录 \"$ImageDirectory\" 获取PNG文件名..."
if [ ! -d "$ImageDirectory" ]; then
    print_error "解析后的图片目录 \"$ImageDirectory\" 不存在或不是一个文件夹。"
    exit 1
fi

# 使用find和sed获取文件名（不含扩展名）
pngFileNames=$(find "$ImageDirectory" -name "*.png" -type f -exec basename {} .png \;)
pngFileCount=$(echo "$pngFileNames" | wc -l | xargs) # 计算文件数量

if [ "$pngFileCount" -eq 0 ]; then
    print_info "未在目录中找到任何PNG文件。脚本执行完毕。"
    exit 0
fi
print_info "成功获取了 $pngFileCount 个文件名。"

# 步骤 2: 检查XML文件是否存在
print_info "正在加载XML文件 \"$XmlFilePath\"..."
if [ ! -f "$XmlFilePath" ]; then
    print_error "解析后的XML文件 \"$XmlFilePath\" 不存在。"
    exit 1
fi

# 步骤 3: 查找指定的 string-array 节点
xpath="//string-array[@name='$StringArrayName']"

if ! xmlstarlet sel -t -c "$xpath" "$XmlFilePath" &> /dev/null; then
    print_error "在XML文件中未找到 <string-array> 节点，其 name 属性为 \"$StringArrayName\"。"
    exit 1
fi
print_info "成功定位到 <string-array name=\"$StringArrayName\"> 节点。"

# 步骤 4: 将现有item内容存入一个变量
existingItems=$(xmlstarlet sel -t -v "$xpath/item" "$XmlFilePath")
existingItemsCount=$(echo "$existingItems" | wc -l | xargs)
print_info "当前节点下有 $existingItemsCount 个已存在的item。"

# 步骤 5: 遍历文件名，如果不存在则准备添加
changesMade="false"
itemsToAdd=""
for fileName in $pngFileNames; do
    if ! echo "$existingItems" | grep -qx "$fileName"; then
        print_info "发现新项目: \"$fileName\"，准备添加到XML中..."
        itemsToAdd="$itemsToAdd $fileName"
        changesMade="true"
    fi
done

# 如果有变动，则执行XML修改和保存
if [ "$changesMade" == "true" ]; then

    xmlstarlet_ops=""
    for item in $itemsToAdd; do
        xmlstarlet_ops="$xmlstarlet_ops -s $xpath -t elem -n item -v $item"
    done

    print_info "正在更新XML文件..."
    tempFile=$(mktemp)
    xmlstarlet ed $xmlstarlet_ops "$XmlFilePath" > "$tempFile"

    # 步骤 5.5: 对所有item节点按内容排序
    print_info "正在对节点下的所有 <item> 进行排序..."
    sortedItems=$(xmlstarlet sel -t -v "$xpath/item" "$tempFile" | sort)

    xmlstarlet ed -L -d "$xpath/item" "$tempFile"

    final_ops=""
    for item in $sortedItems; do
        final_ops="$final_ops -s $xpath -t elem -n item -v $item"
    done
    xmlstarlet ed -L $final_ops "$tempFile"

    # 步骤 6: 格式化并保存
    print_info "XML内容已更新，正在使用Tab缩进保存文件..."
    xmlstarlet fo --indent-tab "$tempFile" > "$XmlFilePath"
    rm "$tempFile"

    print_info "文件 \"$XmlFilePath\" 已成功保存。"

else
    print_info "未发现需要添加的新项目，XML文件未作修改。"
fi

print_info "脚本执行成功完成。"