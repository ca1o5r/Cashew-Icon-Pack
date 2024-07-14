#!/bin/bash

Src_APP_Filter_XML_File_Name="$1"/app/src/main/res/xml/appfilter.xml

if [ ! -f "$Src_APP_Filter_XML_File_Name" ]; then
    echo "Error: Src Icon XML file not found: $Src_APP_Filter_XML_File_Name"
    exit 1
fi

ADB_Path=/opt/Android-SDK-Platform-Tools/adb
Packages=$($ADB_Path shell pm list packages)

APP_Filter_XML_Begin_Line_Number=$(grep -n "<resources>" "$Src_APP_Filter_XML_File_Name" | cut -d: -f 1)

while read -r Line; do
    Package_Name=$(echo "$Line" | cut -d ":" -f2)
    Launch_Activity=$($ADB_Path shell -n cmd package resolve-activity --brief "$Package_Name" | tail -n 1 | cut -d "/" -f2-)
    if [ "No activity found" != "$Launch_Activity" ]; then
        APP_Filter_XML_Simple_Line_Number=$(grep -n "<item component=\"ComponentInfo{$Package_Name/$Launch_Activity}\"" "$Src_APP_Filter_XML_File_Name" | cut -d: -f 1)

        if [ -z "$APP_Filter_XML_Simple_Line_Number" ]; then
            if [ "${Launch_Activity:0:1}" = "." ] ; then
                APP_Filter_XML_Full_Line_Number=$(grep -n "<item component=\"ComponentInfo{$Package_Name/$Package_Name$Launch_Activity}\"" "$Src_APP_Filter_XML_File_Name" | cut -d: -f 1)

                if [ -z "$APP_Filter_XML_Full_Line_Number" ]; then
                    APP_Filter_XML_Begin_Line_Number=$((APP_Filter_XML_Begin_Line_Number + 1))
                    APP_Filter_XML_Insert_Contents="	<item component=\"ComponentInfo{$Package_Name/$Package_Name$Launch_Activity}\" drawable=\"sleep_as_android\" />"
                    awk -v line="$APP_Filter_XML_Begin_Line_Number" -v text="$APP_Filter_XML_Insert_Contents" 'NR == line {print text} 1' "$Src_APP_Filter_XML_File_Name" > tmp && mv tmp "$Src_APP_Filter_XML_File_Name"
                    echo "Append APP Filter XML: $APP_Filter_XML_Insert_Contents at line $APP_Filter_XML_Begin_Line_Number"
                    echo "------------------"
                fi
            else
                APP_Filter_XML_Begin_Line_Number=$((APP_Filter_XML_Begin_Line_Number + 1))
                APP_Filter_XML_Insert_Contents="	<item component=\"ComponentInfo{$Package_Name/$Launch_Activity}\" drawable=\"sleep_as_android\" />"
                awk -v line="$APP_Filter_XML_Begin_Line_Number" -v text="$APP_Filter_XML_Insert_Contents" 'NR == line {print text} 1' "$Src_APP_Filter_XML_File_Name" > tmp && mv tmp "$Src_APP_Filter_XML_File_Name"
                echo "Append APP Filter XML: $APP_Filter_XML_Insert_Contents at line $APP_Filter_XML_Begin_Line_Number"
                echo "------------------"
            fi
        fi
    fi
done <<< "$Packages"
