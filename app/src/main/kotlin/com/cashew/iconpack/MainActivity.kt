package com.cashew.iconpack

import android.content.Intent
import android.view.View
import androidx.drawerlayout.widget.DrawerLayout
import com.github.javiersantos.piracychecker.PiracyChecker
import com.google.android.material.floatingactionbutton.ExtendedFloatingActionButton
import dev.jahir.blueprint.R as BlueprintR
import dev.jahir.blueprint.ui.activities.DrawerBlueprintActivity
import dev.jahir.blueprint.ui.activities.IconsCategoryActivity

class MainActivity : DrawerBlueprintActivity() {

    // Open directly on the Icons page (bypasses the Home/dashboard screen)
    override val initialItemId: Int get() = BlueprintR.id.icons
    override val initialFragmentTag: String get() = "icons_categories_fragment"

    // Null out the home fragment so no home data is loaded at all
    override val homeFragment = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        autoLaunchAllIcons()
    }

    // Lock the drawer permanently closed — no swipe-out side menu
    override fun onPostCreate(savedInstanceState: android.os.Bundle?) {
        super.onPostCreate(savedInstanceState)
        val dl = findViewById<DrawerLayout?>(BlueprintR.id.drawer_layout)
        dl?.setDrawerLockMode(DrawerLayout.LOCK_MODE_LOCKED_CLOSED)
        supportActionBar?.setDisplayHomeAsUpEnabled(false)
        supportActionBar?.setHomeButtonEnabled(false)
        killFab()
    }

    override fun onResume() {
        super.onResume()
        killFab()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) killFab()
    }

    /**
     * Aggressively remove the "Apply to Home" FAB button.
     * Blueprint re-shows the FAB on every resume, so we zero its size,
     * remove click listeners, and hide it.
     */
    private fun killFab() {
        val fab = findViewById<ExtendedFloatingActionButton?>(BlueprintR.id.fab_btn) ?: return
        fab.setOnClickListener(null)
        fab.isClickable = false
        fab.isFocusable = false
        fab.visibility = View.GONE
        fab.layoutParams = fab.layoutParams?.apply {
            width = 0
            height = 0
        }
        fab.postDelayed({ fab.visibility = View.GONE }, 300)
    }

    /**
     * Observe the icons ViewModel and automatically launch the flat icon grid
     * (IconsCategoryActivity) when the single "All" category is loaded.
     * This bypasses the category list entirely — the user sees all icons immediately.
     */
    private fun autoLaunchAllIcons() {
        val vm = androidx.lifecycle.ViewModelProvider(this)
            .get(dev.jahir.blueprint.data.viewmodels.IconsCategoriesViewModel::class.java)
        vm.observe(this) { categories ->
            if (categories.size == 1 && !hasLaunched) {
                hasLaunched = true
                val category = categories[0]
                val intent = Intent(this, IconsCategoryActivity::class.java).apply {
                    // Use literal strings since CATEGORY_KEY / PICKER_KEY are internal
                    putExtra("category", category)
                    putExtra("picker_key", pickerKey)
                }
                startActivity(intent)
                finish()
            }
        }
    }

    override fun getLicKey(): String? = ""
    override fun getLicenseChecker(): PiracyChecker? = null

    override fun defaultTheme(): Int = R.style.MyApp_Default
    override fun amoledTheme(): Int = R.style.MyApp_Default_Amoled

    companion object {
        private var hasLaunched = false
    }
}
