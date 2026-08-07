package com.cashew.iconpack

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ImageButton
import android.widget.ImageView
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.appcompat.widget.SearchView
import androidx.recyclerview.widget.GridLayoutManager
import androidx.recyclerview.widget.RecyclerView
import dev.jahir.blueprint.data.models.Icon
import dev.jahir.blueprint.data.models.IconsCategory
import dev.jahir.blueprint.data.viewmodels.IconsCategoriesViewModel

/**
 * Displays all icons in a grid with icon names, search, and sort.
 */
class AllIconsActivity : AppCompatActivity() {

    private lateinit var adapter: IconGridAdapter
    private var allIcons: List<Icon> = emptyList()
    private var sortAscending = true

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_all_icons)

        // Set up RecyclerView
        val recyclerView = findViewById<RecyclerView>(R.id.recycler_view)
        adapter = IconGridAdapter()
        recyclerView.layoutManager = GridLayoutManager(this, 5)
        recyclerView.adapter = adapter

        // Set up search
        val searchView = findViewById<SearchView>(R.id.search_view)
        searchView.setOnQueryTextListener(object : SearchView.OnQueryTextListener {
            override fun onQueryTextSubmit(query: String?) = false
            override fun onQueryTextChange(newText: String?): Boolean {
                filterIcons(newText.orEmpty())
                return true
            }
        })

        // Set up sort toggle
        val sortBtn = findViewById<ImageButton>(R.id.btn_sort)
        sortBtn.setOnClickListener {
            sortAscending = !sortAscending
            filterIcons(searchView.query?.toString().orEmpty())
        }

        // Load icons from ViewModel
        val vm = androidx.lifecycle.ViewModelProvider(
            this,
            androidx.lifecycle.ViewModelProvider.AndroidViewModelFactory.getInstance(application)
        ).get(IconsCategoriesViewModel::class.java)
        vm.loadIconsCategories()
        vm.observe(this) { categories: ArrayList<IconsCategory> ->
            if (categories.isNotEmpty()) {
                allIcons = categories[0].getIcons()
                filterIcons("")
            }
        }
    }

    private fun filterIcons(query: String) {
        val filtered = if (query.isBlank()) {
            allIcons
        } else {
            allIcons.filter { it.name.contains(query, ignoreCase = true) }
        }
        val sorted = if (sortAscending) {
            filtered.sortedBy { it.name.lowercase() }
        } else {
            filtered.sortedByDescending { it.name.lowercase() }
        }
        adapter.submitList(sorted)
    }

    class IconGridAdapter : RecyclerView.Adapter<IconGridAdapter.VH>() {
        private var items: List<Icon> = emptyList()

        fun submitList(newItems: List<Icon>) {
            items = newItems
            notifyDataSetChanged()
        }

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): VH {
            val view = LayoutInflater.from(parent.context)
                .inflate(R.layout.item_icon_with_name, parent, false)
            return VH(view)
        }

        override fun onBindViewHolder(holder: VH, position: Int) {
            val icon = items[position]
            holder.image.setImageResource(icon.resId)
            // Convert snake_case resource name to readable display name
            holder.name.text = icon.name
                .replace('_', ' ')
                .replaceFirstChar { it.uppercase() }
        }

        override fun getItemCount(): Int = items.size

        class VH(view: View) : RecyclerView.ViewHolder(view) {
            val image: ImageView = view.findViewById(R.id.icon_image)
            val name: TextView = view.findViewById(R.id.icon_name)
        }
    }
}
