package com.cashew.iconpack

import android.content.Intent
import androidx.activity.ComponentActivity
import dev.jahir.blueprint.data.viewmodels.IconsCategoriesViewModel

/**
 * Splash/trampoline activity.
 *
 * Shows the branded splash screen while icon data loads,
 * then launches [AllIconsActivity] with the icon grid
 * and finishes itself.
 */
class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)

        val vm = androidx.lifecycle.ViewModelProvider(this)
            .get(IconsCategoriesViewModel::class.java)
        vm.loadIconsCategories()
        vm.observe(this) { categories ->
            if (categories.isNotEmpty() && !hasLaunched) {
                hasLaunched = true
                startActivity(Intent(this, AllIconsActivity::class.java))
                finish()
            }
        }
    }

    companion object {
        private var hasLaunched = false
    }
}
