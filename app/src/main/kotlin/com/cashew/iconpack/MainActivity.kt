package com.cashew.iconpack

import android.os.Bundle
import androidx.drawerlayout.widget.DrawerLayout
import com.github.javiersantos.piracychecker.PiracyChecker
import dev.jahir.blueprint.R as BlueprintR
import dev.jahir.blueprint.ui.activities.DrawerBlueprintActivity
import dev.jahir.blueprint.ui.fragments.IconsCategoriesFragment

class MainActivity : DrawerBlueprintActivity() {

    // Open directly on the Icons page (bypasses the Home/dashboard screen)
    override val initialItemId: Int get() = BlueprintR.id.icons
    override val initialFragmentTag: String get() = IconsCategoriesFragment.TAG

    // Null out the home fragment so no home data is loaded at all
    override val homeFragment = null

    // Lock the drawer permanently closed — no swipe-out side menu
    // Hide the FAB ("Apply to Home" button) — icon packs are applied via the launcher itself
    override fun onPostCreate(savedInstanceState: Bundle?) {
        super.onPostCreate(savedInstanceState)
        val dl = findViewById<DrawerLayout?>(BlueprintR.id.drawer_layout)
        dl?.setDrawerLockMode(DrawerLayout.LOCK_MODE_LOCKED_CLOSED)
        supportActionBar?.setDisplayHomeAsUpEnabled(false)
        supportActionBar?.setHomeButtonEnabled(false)
        hideFab()
    }

    override fun onResume() {
        super.onResume()
        hideFab()
    }

    private fun hideFab() {
        val fab = findViewById<com.google.android.material.floatingactionbutton.ExtendedFloatingActionButton?>(
            BlueprintR.id.fab_btn
        )
        fab?.hide()
        // Post again to override any delayed show triggered by Blueprint's onResume
        fab?.postDelayed({ fab.hide() }, 200)
    }

    override fun getLicKey(): String? = ""
    override fun getLicenseChecker(): PiracyChecker? = null

    override fun defaultTheme(): Int = R.style.MyApp_Default
    override fun amoledTheme(): Int = R.style.MyApp_Default_Amoled
}
