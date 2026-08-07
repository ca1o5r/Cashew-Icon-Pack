package com.cashew.iconpack

import android.app.Activity
import android.app.Application
import android.os.Bundle
import android.view.ViewTreeObserver
import androidx.appcompat.widget.Toolbar
import dev.jahir.blueprint.ui.activities.IconsCategoryActivity
import dev.jahir.frames.ui.activities.base.BaseSearchableActivity
import dev.jahir.frames.ui.FramesApplication

class MyApplication : FramesApplication("") {
    override fun onCreate() {
        super.onCreate()
        registerActivityLifecycleCallbacks(CleanToolbarCallbacks())
    }
}

/**
 * Removes the navigation icon (back arrow) and title from
 * [IconsCategoryActivity]'s toolbar while keeping search and icon-shape
 * menu items accessible.
 */
private class CleanToolbarCallbacks : Application.ActivityLifecycleCallbacks {

    override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {
        if (activity is IconsCategoryActivity) {
            activity.window.decorView.viewTreeObserver
                .addOnPreDrawListener(OnPreDrawCleanListener(activity))
        }
    }

    override fun onActivityStarted(activity: Activity) {
        if (activity is IconsCategoryActivity) {
            cleanToolbar(activity)
        }
    }

    override fun onActivityResumed(activity: Activity) {}
    override fun onActivityPaused(activity: Activity) {}
    override fun onActivityStopped(activity: Activity) {}
    override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) {}
    override fun onActivityDestroyed(activity: Activity) {}

    private fun cleanToolbar(activity: Activity) {
        if (activity is BaseSearchableActivity<*>) {
            val toolbar = activity.toolbar ?: return
            toolbar.navigationIcon = null
            toolbar.title = ""
        }
    }

    private class OnPreDrawCleanListener(private val activity: Activity) :
        ViewTreeObserver.OnPreDrawListener {
        override fun onPreDraw(): Boolean {
            activity.window.decorView.viewTreeObserver.removeOnPreDrawListener(this)
            if (activity is BaseSearchableActivity<*>) {
                val toolbar = activity.toolbar ?: return true
                toolbar.navigationIcon = null
                toolbar.title = ""
            }
            return true
        }
    }
}
