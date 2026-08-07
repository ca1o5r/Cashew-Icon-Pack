package com.cashew.iconpack

import android.content.Intent
import androidx.activity.ComponentActivity
import dev.jahir.blueprint.ui.activities.IconsCategoryActivity

/**
 * Splash/trampoline activity.
 *
 * Shows the branded splash screen while icon data loads,
 * then launches [IconsCategoryActivity] with the first category
 * and finishes itself. The user sees: splash → full icon grid.
 *
 * Toolbar hiding is handled by [MyApplication]'s lifecycle callbacks.
 */
class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)

        val vm = androidx.lifecycle.ViewModelProvider(this)
            .get(dev.jahir.blueprint.data.viewmodels.IconsCategoriesViewModel::class.java)
        vm.loadIconsCategories()
        vm.observe(this) { categories ->
            if (categories.isNotEmpty() && !hasLaunched) {
                hasLaunched = true
                startActivity(
                    Intent(this, IconsCategoryActivity::class.java).apply {
                        putExtra("category", categories[0])
                        putExtra("picker_key", 0)
                    }
                )
                finish()
            }
        }
    }

    companion object {
        private var hasLaunched = false
    }
}
