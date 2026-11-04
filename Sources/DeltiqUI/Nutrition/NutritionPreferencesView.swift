#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import DeltiqCore
import DeltiqData

/// Phase 5.0: Ernährungspräferenzen — Ernährungsform, Halal, Allergene, ausgeschlossene Rezepte.
/// Erreichbar aus MealPlannerView und SettingsView.
/// OFF-01: Halal wird niemals automatisch abgeleitet; nur `halalVerifiedBy != nil` zählt.
@available(iOS 17.0, macOS 14.0, *)
public struct NutritionPreferencesView: View {

    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserBodyProfile]

    private let recipeCatalog: [Recipe] = RecipeCatalogData.all

    public init() {}

    private var profile: UserBodyProfile? { profiles.first }

    public var body: some View {
        VStack(spacing: 0) {
            DeltiqHeader(
                eyebrow: String(localized: "tab.nutrition", bundle: .module).uppercased(),
                title: String(localized: "nutrition.preferences.title", bundle: .module),
                onBack: { dismiss() }
            )

            if let profile {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        dietaryStyleSection(profile: profile)
                        halalSection(profile: profile)
                        allergenSection(profile: profile)
                        excludedRecipesSection(profile: profile)
                    }
                    .deltiqScreen()
                }
            }
        }
        .background(Color.Deltiq.background.ignoresSafeArea())
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        #endif
        .deltiqSwipeBackEnabled()
    }

    // MARK: - Ernährungsform

    private func dietaryStyleSection(profile: UserBodyProfile) -> some View {
        DeltiqSection(String(localized: "nutrition.preferences.style.title", bundle: .module).uppercased()) {
            ForEach(DietaryStyle.allCases, id: \.self) { style in
                let isLast = style == DietaryStyle.allCases.last
                Button {
                    profile.mealPlanDietaryStyleRaw = style.rawValue
                } label: {
                    HStack {
                        Text(style.localizedName)
                            .font(.system(size: 15))
                            .foregroundStyle(Color.primary)
                        Spacer()
                        if profile.mealPlanDietaryStyleRaw == style.rawValue {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.deltiqOrange)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                if !isLast {
                    Rectangle().fill(Color.Deltiq.divider).frame(height: 1)
                }
            }
        }
    }

    // MARK: - Halal

    private func halalSection(profile: UserBodyProfile) -> some View {
        DeltiqSection(String(localized: "nutrition.preferences.halal.title", bundle: .module).uppercased()) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("nutrition.preferences.halal.title", bundle: .module)
                        .font(.system(size: 15))
                        .foregroundStyle(Color.primary)
                    Text("nutrition.preferences.halal.subtitle", bundle: .module)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.Deltiq.textSecondary)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { profile.mealPlanRequiresHalal },
                    set: { profile.mealPlanRequiresHalal = $0 }
                ))
                .labelsHidden()
                .tint(Color.deltiqOrange)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(minHeight: 44)
            hintRow(String(localized: "nutrition.preferences.halal.hint", bundle: .module))
        }
    }

    // MARK: - Allergene

    private func allergenSection(profile: UserBodyProfile) -> some View {
        DeltiqSection(String(localized: "nutrition.preferences.allergens.title", bundle: .module).uppercased()) {
            let allergens = RecipeAllergen.allCases
            ForEach(allergens, id: \.self) { allergen in
                let isLast = allergen == allergens.last
                let isSelected = profile.mealPlanAllergenExclusionsRaw.contains(allergen.rawValue)
                Button {
                    var raw = profile.mealPlanAllergenExclusionsRaw
                    if isSelected {
                        raw.removeAll { $0 == allergen.rawValue }
                    } else {
                        raw.append(allergen.rawValue)
                    }
                    profile.mealPlanAllergenExclusionsRaw = raw.sorted()
                } label: {
                    HStack {
                        Text(allergen.localizedName)
                            .font(.system(size: 15))
                            .foregroundStyle(Color.primary)
                        Spacer()
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.deltiqOrange)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                if !isLast {
                    Rectangle().fill(Color.Deltiq.divider).frame(height: 1)
                }
            }
            if !profile.mealPlanAllergenExclusionsRaw.isEmpty {
                Rectangle().fill(Color.Deltiq.divider).frame(height: 1)
                hintRow(String(localized: "nutrition.preferences.allergens.hint", bundle: .module))
            }
        }
    }

    // MARK: - Ausgeschlossene Rezepte

    @ViewBuilder
    private func excludedRecipesSection(profile: UserBodyProfile) -> some View {
        let excluded = profile.mealPlanExcludedRecipeIDsRaw
        DeltiqSection(String(localized: "nutrition.preferences.excluded.title", bundle: .module).uppercased()) {
            if excluded.isEmpty {
                Text("nutrition.preferences.excluded.none", bundle: .module)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.Deltiq.textSecondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
            } else {
                ForEach(excluded, id: \.self) { recipeID in
                    let isLast = recipeID == excluded.last
                    HStack {
                        Text(recipeName(for: recipeID))
                            .font(.system(size: 15))
                            .foregroundStyle(Color.primary)
                        Spacer()
                        Button {
                            profile.mealPlanExcludedRecipeIDsRaw.removeAll { $0 == recipeID }
                        } label: {
                            Text("nutrition.preferences.excluded.restore", bundle: .module)
                                .font(.system(size: 13))
                                .foregroundStyle(Color.deltiqOrange)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(minHeight: 44)
                    if !isLast {
                        Rectangle().fill(Color.Deltiq.divider).frame(height: 1)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func recipeName(for id: String) -> String {
        guard let recipe = recipeCatalog.first(where: { $0.id == id }) else { return id }
        return String(localized: String.LocalizationValue(recipe.nameKey), bundle: .module)
    }
}

// MARK: - DietaryStyle Localization

extension DietaryStyle {
    var localizedName: String {
        switch self {
        case .omnivor:      return String(localized: "nutrition.preferences.style.omnivor", bundle: .module)
        case .vegetarian:   return String(localized: "nutrition.preferences.style.vegetarian", bundle: .module)
        case .vegan:        return String(localized: "nutrition.preferences.style.vegan", bundle: .module)
        case .pescetarian:  return String(localized: "nutrition.preferences.style.pescetarian", bundle: .module)
        }
    }
}

// MARK: - RecipeAllergen Localization

extension RecipeAllergen {
    var localizedName: String {
        switch self {
        case .gluten:    return String(localized: "allergen.gluten", bundle: .module)
        case .lactose:   return String(localized: "allergen.lactose", bundle: .module)
        case .nuts:      return String(localized: "allergen.nuts", bundle: .module)
        case .peanuts:   return String(localized: "allergen.peanuts", bundle: .module)
        case .eggs:      return String(localized: "allergen.eggs", bundle: .module)
        case .soy:       return String(localized: "allergen.soy", bundle: .module)
        case .fish:      return String(localized: "allergen.fish", bundle: .module)
        case .shellfish: return String(localized: "allergen.shellfish", bundle: .module)
        case .sesame:    return String(localized: "allergen.sesame", bundle: .module)
        case .celery:    return String(localized: "allergen.celery", bundle: .module)
        case .mustard:   return String(localized: "allergen.mustard", bundle: .module)
        case .sulfites:  return String(localized: "allergen.sulfites", bundle: .module)
        case .lupin:     return String(localized: "allergen.lupin", bundle: .module)
        case .molluscs:  return String(localized: "allergen.molluscs", bundle: .module)
        }
    }
}
#endif
