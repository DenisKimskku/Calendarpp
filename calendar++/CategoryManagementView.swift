//
//  CategoryManagementView.swift
//  calendar++
//
//  UI for managing event categories and tags
//

import SwiftUI

struct CategoryManagementView: View {
    @StateObject private var categoriesManager = EventCategoriesManager()
    @State private var showingAddCategory = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Event Categories")
                    .font(.headline)
                Spacer()
                Button {
                    showingAddCategory = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))

            // Categories List
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(categoriesManager.categories) { category in
                        CategoryRow(category: category, manager: categoriesManager)
                    }

                    if categoriesManager.categories.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "tag")
                                .font(.system(size: 50))
                                .foregroundColor(.gray.opacity(0.5))
                            Text("No categories yet")
                                .foregroundColor(.secondary)
                            Button("Add Your First Category") {
                                showingAddCategory = true
                            }
                        }
                        .padding()
                    }
                }
                .padding()
            }
        }
        .frame(width: 500, height: 400)
        .calendarppModal(isPresented: $showingAddCategory) {
            AddCategoryView(manager: categoriesManager)
        }
    }
}

struct CategoryRow: View {
    let category: EventCategory
    @ObservedObject var manager: EventCategoriesManager

    @State private var showingEditSheet = false

    var body: some View {
        HStack(spacing: 12) {
            // Icon & Color
            Image(systemName: category.icon)
                .font(.title3)
                .foregroundColor(category.displayColor)
                .frame(width: 40, height: 40)
                .background(category.displayColor.opacity(0.2))
                .clipShape(Circle())

            // Name & Keywords
            VStack(alignment: .leading, spacing: 4) {
                Text(category.name)
                    .font(.headline)

                if !category.keywords.isEmpty {
                    Text(category.keywords.prefix(3).joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Actions
            HStack(spacing: 8) {
                Button {
                    showingEditSheet = true
                } label: {
                    Image(systemName: "pencil")
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)

                Button {
                    manager.deleteCategory(category)
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
        .calendarppModal(isPresented: $showingEditSheet) {
            EditCategoryView(category: category, manager: manager)
        }
    }
}

struct AddCategoryView: View {
    @ObservedObject var manager: EventCategoriesManager
    @Environment(\.dismiss) var dismiss

    @State private var name: String = ""
    @State private var selectedColor: Color = .blue
    @State private var selectedIcon: String = "tag.fill"
    @State private var keywords: String = ""

    private let availableIcons = [
        "tag.fill", "briefcase.fill", "person.fill", "heart.fill",
        "house.fill", "car.fill", "airplane", "bicycle",
        "book.fill", "graduationcap.fill", "music.note", "film.fill",
        "gamecontroller.fill", "sportscourt.fill", "cup.and.saucer.fill", "fork.knife"
    ]

    private let availableColors: [Color] = [
        .blue, .green, .red, .orange, .purple, .yellow,
        .pink, .cyan, .indigo, .mint, .teal, .brown
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Category")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
            }
            .padding()
            .background(Color.gray.opacity(0.1))

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name")
                            .font(.caption.bold())
                        TextField("e.g. Work, Personal, Health", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }

                    Divider()

                    // Icon Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Icon")
                            .font(.caption.bold())

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 8) {
                            ForEach(availableIcons, id: \.self) { icon in
                                Button {
                                    selectedIcon = icon
                                } label: {
                                    Image(systemName: icon)
                                        .font(.title3)
                                        .frame(width: 40, height: 40)
                                        .background(selectedIcon == icon ? selectedColor.opacity(0.3) : Color.gray.opacity(0.1))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Divider()

                    // Color Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Color")
                            .font(.caption.bold())

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 12), spacing: 8) {
                            ForEach(availableColors, id: \.description) { color in
                                Button {
                                    selectedColor = color
                                } label: {
                                    Circle()
                                        .fill(color)
                                        .frame(width: 30, height: 30)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: selectedColor.description == color.description ? 3 : 0)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Divider()

                    // Keywords
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Keywords (comma-separated)")
                            .font(.caption.bold())
                        TextField("e.g. meeting, work, office", text: $keywords)
                            .textFieldStyle(.roundedBorder)
                        Text("Used for auto-categorization")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    // Preview
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Preview")
                            .font(.caption.bold())

                        HStack {
                            Image(systemName: selectedIcon)
                                .font(.title2)
                                .foregroundColor(selectedColor)
                                .frame(width: 50, height: 50)
                                .background(selectedColor.opacity(0.2))
                                .clipShape(Circle())

                            VStack(alignment: .leading) {
                                Text(name.isEmpty ? "Category Name" : name)
                                    .font(.headline)
                                if !keywords.isEmpty {
                                    Text(keywords)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(8)
                    }

                    // Add Button
                    Button {
                        let keywordArray = keywords.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }
                        let category = EventCategory(
                            name: name,
                            color: selectedColor,
                            icon: selectedIcon,
                            keywords: keywordArray
                        )
                        manager.addCategory(category)
                        dismiss()
                    } label: {
                        Text("Add Category")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(name.isEmpty ? Color.gray : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .disabled(name.isEmpty)
                }
                .padding()
            }
        }
        .frame(width: 500, height: 600)
    }
}

struct EditCategoryView: View {
    let category: EventCategory
    @ObservedObject var manager: EventCategoriesManager
    @Environment(\.dismiss) var dismiss

    @State private var name: String
    @State private var selectedColor: Color
    @State private var selectedIcon: String
    @State private var keywords: String

    init(category: EventCategory, manager: EventCategoriesManager) {
        self.category = category
        self.manager = manager
        _name = State(initialValue: category.name)
        _selectedColor = State(initialValue: category.displayColor)
        _selectedIcon = State(initialValue: category.icon)
        _keywords = State(initialValue: category.keywords.joined(separator: ", "))
    }

    var body: some View {
        VStack {
            Text("Edit Category: \(category.name)")
                .font(.headline)
                .padding()

            // Same form as AddCategoryView but with save button
            Button("Save Changes") {
                var updatedCategory = category
                updatedCategory.name = name
                updatedCategory.color = CodableColor(color: selectedColor)
                updatedCategory.icon = selectedIcon
                updatedCategory.keywords = keywords.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }

                manager.updateCategory(updatedCategory)
                dismiss()
            }
            .padding()
        }
    }
}

// MARK: - Category Picker for Events

struct CategoryPickerView: View {
    let eventID: String
    @ObservedObject var manager: EventCategoriesManager
    @Binding var isPresented: Bool

    var currentCategory: EventCategory? {
        manager.getCategory(for: eventID)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Assign Category")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    isPresented = false
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))

            ScrollView {
                LazyVStack(spacing: 8) {
                    // None option
                    CategoryOptionRow(
                        name: "None",
                        icon: "xmark",
                        color: .gray,
                        isSelected: currentCategory == nil
                    ) {
                        manager.removeCategory(from: eventID)
                    }

                    ForEach(manager.categories) { category in
                        CategoryOptionRow(
                            name: category.name,
                            icon: category.icon,
                            color: category.displayColor,
                            isSelected: currentCategory?.id == category.id
                        ) {
                            manager.assignCategory(category.id, to: eventID)
                        }
                    }
                }
                .padding()
            }
        }
        .frame(width: 300, height: 400)
    }
}

struct CategoryOptionRow: View {
    let name: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 30)

                Text(name)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(isSelected ? color.opacity(0.1) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}
