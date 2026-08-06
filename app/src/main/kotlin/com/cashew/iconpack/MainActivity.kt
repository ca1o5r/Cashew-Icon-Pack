package com.cashew.iconpack

import android.app.Activity
import android.app.Application
import android.content.Intent
import android.os.Bundle
import android.view.View
import androidx.activity.ComponentActivity
import dev.jahir.blueprint.R as BlueprintR
import dev.jahir.blueprint.ui.activities.IconsCategoryActivity

/**
 * Invisible splash/trampoline activity.
 *
 * Shows the branded splash screen while icon data loads,
 * then launches [IconsCategoryActivity] with the first category
 * and finishes itself. The user sees: splash → full icon grid.
 * No Blueprint scaffold, no category page, no toolbar flash.
 */
class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Remove toolbar from IconsCategoryActivity before it becomes visible
        registerActivityLifecycleCallbacks(object : Application.ActivityLifecycleCallbacks {
            override fun onActivityCreated(a: Activity, s: Bundle?) {
                if (a is IconsCategoryActivity) {
                    a.window.decorView.viewTreeObserver
                        .addOnPreDrawListener(object :
                            android.view.ViewTreeObserver.OnPreDrawListener {
                            override fun onPreDraw(): Boolean {
                                a.window.decorView.viewTreeObserver
                                    .removeOnPreDrawListener(this)
                                // Hide the entire AppBarLayout (toolbar + title)
                                a.findViewById<View>(BlueprintR.id.toolbar)
                                    ?.parent?.let { it as? View }
                                    ?.visibility = View.GONE
                                return true
                            }
                        })
                }
            }

            override fun onActivityStarted(a: Activity) {}
            override fun onActivityResumed(a: Activity) {}
            override fun onActivityPaused(a: Activity) {}
            override fun onActivityStopped(a: Activity) {}
            override fun onActivitySaveInstanceState(a: Activity, s: Bundle) {}
            override fun onActivityDestroyed(a: Activity) {}
        })

        // Observe the icons ViewModel; launch the grid when data is ready
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
