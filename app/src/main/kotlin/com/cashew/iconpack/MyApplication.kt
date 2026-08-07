package com.cashew.iconpack

import android.app.Activity
import android.app.Application
import android.os.Bundle
import android.view.View
import android.view.ViewGroup
import android.view.ViewTreeObserver
import com.google.android.material.appbar.AppBarLayout
import dev.jahir.blueprint.ui.activities.IconsCategoryActivity
import dev.jahir.frames.ui.FramesApplication

class MyApplication : FramesApplication("") {
    override fun onCreate() {
        super.onCreate()
        registerActivityLifecycleCallbacks(HideToolbarCallbacks())
    }
}

/**
 * Hides the [AppBarLayout] (toolbar + "All" title + back arrow) from
 * [IconsCategoryActivity] before the first frame is drawn.
 */
private class HideToolbarCallbacks : Application.ActivityLifecycleCallbacks {

    override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {
        if (activity is IconsCategoryActivity) {
            activity.window.decorView.viewTreeObserver
                .addOnPreDrawListener(OnPreDrawHideListener(activity))
        }
    }

    override fun onActivityStarted(activity: Activity) {
        if (activity is IconsCategoryActivity) {
            hideAppBar(activity)
        }
    }

    override fun onActivityResumed(activity: Activity) {}
    override fun onActivityPaused(activity: Activity) {}
    override fun onActivityStopped(activity: Activity) {}
    override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) {}
    override fun onActivityDestroyed(activity: Activity) {}

    private fun hideAppBar(activity: Activity) {
        val root = activity.window.decorView as? ViewGroup ?: return
        val appBar = findViewByType(root, AppBarLayout::class.java)
        appBar?.visibility = View.GONE
        appBar?.layoutParams?.height = 0
        appBar?.requestLayout()
    }

    private fun <T : View> findViewByType(parent: View, type: Class<T>): T? {
        if (type.isInstance(parent)) return type.cast(parent)
        if (parent is ViewGroup) {
            for (i in 0 until parent.childCount) {
                val found = findViewByType(parent.getChildAt(i), type)
                if (found != null) return found
            }
        }
        return null
    }

    private class OnPreDrawHideListener(private val activity: Activity) :
        ViewTreeObserver.OnPreDrawListener {
        override fun onPreDraw(): Boolean {
            activity.window.decorView.viewTreeObserver.removeOnPreDrawListener(this)
            val root = activity.window.decorView as? ViewGroup ?: return true
            val appBar = findViewByTypeStatic(root, AppBarLayout::class.java)
            appBar?.visibility = View.GONE
            appBar?.layoutParams?.height = 0
            appBar?.requestLayout()
            return true
        }

        private fun <T : View> findViewByTypeStatic(parent: View, type: Class<T>): T? {
            if (type.isInstance(parent)) return type.cast(parent)
            if (parent is ViewGroup) {
                for (i in 0 until parent.childCount) {
                    val found = findViewByTypeStatic(parent.getChildAt(i), type)
                    if (found != null) return found
                }
            }
            return null
        }
    }
}
