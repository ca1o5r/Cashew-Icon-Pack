#!/bin/bash

XML_File_Name="$1".xml

if [ ! -f "$XML_File_Name" ]; then
    echo "Error: XML file not found: $XML_File_Name"
    exit 1
fi

Icon_Folder="$1"

if [ ! -f "$Icon_Folder" ]; then
    echo "Error: Icon folder not found: $Icon_Folder"
    exit 1
fi

Src_Icon_Folder="$2"/app/src/main/res/drawable-nodpi

if [ ! -f "$Src_Icon_Folder" ]; then
    echo "Error: Source Icon folder not found: $Src_Icon_Folder"
    exit 1
fi

Src_Icon_XML_File_Name="$2"/app/src/main/res/values/icon_pack.xml

if [ ! -f "$Src_Icon_XML_File_Name" ]; then
    echo "Error: Src Icon XML file not found: $Src_Icon_XML_File_Name"
    exit 1
fi

Src_Drawable_XML_File_Name="$2"/app/src/main/res/xml/drawable.xml

if [ ! -f "$Src_Drawable_XML_File_Name" ]; then
    echo "Error: Src Drawable XML file not found: $Src_Drawable_XML_File_Name"
    exit 1
fi

while read Line; do
    if [[ "$Line" =~ "<icon" ]]; then
        Name=$(echo "$Line" | sed -n 's/.*name="\([^"]*\)".*/\1/p')
        Drawable=$(echo "$Line" | sed -n 's/.*drawable="\([^"]*\)".*/\1/p')
        Icon_File_Name="$Drawable".png

        Icon_File=$(find "$Icon_Folder" -name "$Icon_File_Name")

        if [ -f "$Icon_File" ]; then
            New_Icon_File_Name=$(echo "$Name" | tr '[:upper:]' '[:lower:]' | tr ' ' '_').png
            Suffix=1
            while [ -f "$Src_Icon_Folder/$New_Icon_File_Name" ]; do
                if cmp -s "$Icon_File" "$Src_Icon_Folder/$New_Icon_File_Name"; then
                    Suffix=0
                    break
                else
                    New_Icon_File_Name=$(echo "$Name" | tr '[:upper:]' '[:lower:]' | tr ' ' '_')"_$Suffix".png
                    Suffix=$((Suffix + 1))
                fi
            done
            if [ $Suffix -ge 1 ]; then
                cp "$Icon_File" "$Src_Icon_Folder/$New_Icon_File_Name"
                echo "Copy to Src Folder: $Src_Icon_Folder/$New_Icon_File_Name"
                echo "------------------"
            fi
        fi
    fi
done < "$XML_File_Name"

PNG_Files=$(find "$Src_Icon_Folder" -name "*.png" | sort -f)

Icon_XML_Begin_Line_Number=$(grep -n "<string-array" "$Src_Icon_XML_File_Name" | cut -d: -f 1)
Drawable_XML_Begin_Line_Number=$(grep -n "<category title=\"All\" />" "$Src_Drawable_XML_File_Name" | head -n 1 | cut -d: -f 1)
Drawable_XML_Append_Line_Number=0

for PNG_File in $PNG_Files; do
    PNG_File_Name=$(basename "$PNG_File" .png)

    Icon_XML_Line_Number=$(grep -n "<item>$PNG_File_Name</item>" "$Src_Icon_XML_File_Name" | cut -d: -f 1)

    if [ -z "$Icon_XML_Line_Number" ]; then
        Icon_XML_Begin_Line_Number=$((Icon_XML_Begin_Line_Number + 1))
        Icon_XML_Insert_Contents="	<item>$PNG_File_Name</item>"
        awk -v line="$Icon_XML_Begin_Line_Number" -v text="$Icon_XML_Insert_Contents" 'NR == line {print text} 1' "$Src_Icon_XML_File_Name" > tmp && mv tmp "$Src_Icon_XML_File_Name"
        echo "Append Icon XML: $Icon_XML_Insert_Contents at line $Icon_XML_Begin_Line_Number"
        echo "------------------"
    else
        Icon_XML_Begin_Line_Number=$Icon_XML_Line_Number
    fi

    Drawable_XML_Line_Number=$(awk "/<category title=\"All\" \/>/{flag=1}/<category title=\"Dynamic icon\" \/>/{flag=0;exit}flag" "$Src_Drawable_XML_File_Name" | grep -n "<item drawable=\"$PNG_File_Name\" />" | head -n 1 | cut -d: -f 1)

    if [ -z "$Drawable_XML_Line_Number" ]; then
        Drawable_XML_Append_Line_Number=$((Drawable_XML_Append_Line_Number + 1))
        Drawable_XML_Insert_Line_Number=$(($Drawable_XML_Begin_Line_Number + $Drawable_XML_Append_Line_Number))
        Drawable_XML_Insert_Contents="		<item drawable=\"$PNG_File_Name\" />"
        awk -v line="$Drawable_XML_Insert_Line_Number" -v text="$Drawable_XML_Insert_Contents" 'NR == line {print text} 1' "$Src_Drawable_XML_File_Name" > tmp && mv tmp "$Src_Drawable_XML_File_Name"
        echo "Append Drawable XML: $Drawable_XML_Insert_Contents at line $Drawable_XML_Insert_Line_Number"
        echo "------------------"
    else
        Drawable_XML_Append_Line_Number=$(($Drawable_XML_Line_Number - 1))
    fi
done
