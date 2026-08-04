package com.cashew.iconpack

import android.os.Bundle
import dev.jahir.blueprint.ui.activities.DrawerBlueprintActivity

class MainActivity : DrawerBlueprintActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
    }

    override fun getLicKey(): String? = ""

    override fun defaultTheme(): Int = R.style.MyApp_Default
    override fun amoledTheme(): Int = R.style.MyApp_Default_Amoled
}
