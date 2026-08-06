package com.cashew.iconpack

import android.content.Intent
import dev.jahir.blueprint.ui.activities.DrawerBlueprintActivity
import dev.jahir.blueprint.ui.activities.IconsCategoryActivity

/**
 * Transparent trampoline activity.
 *
 * This activity is completely invisible (see MyApp.Transparent theme).
 * It loads the icon data from the ViewModel, and when the single "All"
 * category is available, immediately launches [IconsCategoryActivity]
 * showing the full icon grid, then finishes itself.
 *
 * The user never sees this activity — they go straight from the app
 * icon to the full icon grid.
 */
class MainActivity : DrawerBlueprintActivity() {

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        launchAllIcons()
    }

    private fun launchAllIcons() {
        val vm = androidx.lifecycle.ViewModelProvider(this)
            .get(dev.jahir.blueprint.data.viewmodels.IconsCategoriesViewModel::class.java)
        vm.observe(this) { categories ->
            if (categories.isNotEmpty() && !hasLaunched) {
                hasLaunched = true
                val intent = Intent(this, IconsCategoryActivity::class.java).apply {
                    putExtra("category", categories[0])
                    putExtra("picker_key", pickerKey)
                }
                startActivity(intent)
                finish()
            }
        }
    }

    override fun getLicKey(): String? = ""
    override fun getLicenseChecker(): com.github.javiersantos.piracychecker.PiracyChecker? = null

    override fun defaultTheme(): Int = R.style.MyApp_Default
    override fun amoledTheme(): Int = R.style.MyApp_Default_Amoled

    companion object {
        private var hasLaunched = false
    }
}
