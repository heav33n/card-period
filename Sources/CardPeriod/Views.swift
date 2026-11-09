#if canImport(SwiftUI)
import SwiftUI
import UIKit

private let ink = Color(uiColor: .label)
private let canvas = Color(uiColor: UIColor { traits in
    traits.userInterfaceStyle == .dark ? UIColor(red: 0.07, green: 0.10, blue: 0.09, alpha: 1) : UIColor(red: 0.96, green: 0.97, blue: 0.94, alpha: 1)
})
private let surface = Color(uiColor: UIColor { traits in
    traits.userInterfaceStyle == .dark ? UIColor(red: 0.12, green: 0.16, blue: 0.15, alpha: 1) : .white
})
private struct AppTheme {
    static let defaultRGB = 0x1F4A3D
    let rgb: Int
    var red: Double { Double((rgb >> 16) & 255) / 255 }
    var green: Double { Double((rgb >> 8) & 255) / 255 }
    var blue: Double { Double(rgb & 255) / 255 }
    var color: Color { Color(red: red, green: green, blue: blue) }
    private func linear(_ c: Double) -> Double { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
    var luminance: Double { 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue) }
    var foreground: Color { luminance > 0.179 ? .black : .white }
    var highlight: Color { rgb == Self.defaultRGB ? Color(red: 0.80, green: 0.91, blue: 0.60) : foreground }
    // Adapt the chosen color only when needed for text and controls on the page background.
    var pageAccent: Color {
        Color(uiColor: UIColor { traits in
            let dark = traits.userInterfaceStyle == .dark
            let backgroundLuminance = dark ? 0.01 : 0.93
            let contrast = (max(luminance, backgroundLuminance) + 0.05) / (min(luminance, backgroundLuminance) + 0.05)
            if contrast >= 4.5 { return UIColor(red: red, green: green, blue: blue, alpha: 1) }
            return dark ? UIColor(white: 0.88, alpha: 1) : UIColor(white: 0.18, alpha: 1)
        })
    }
}

private func cents(from text: String) -> Int? {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.generatesDecimalNumbers = true
    guard let number = formatter.number(from: text) as? NSDecimalNumber else { return nil }
    let value = number.decimalValue * 100
    guard value > 0, value <= Decimal(100_000_000_00) else { return nil }
    var original = value
    var rounded = Decimal()
    NSDecimalRound(&rounded, &original, 0, .plain)
    guard rounded == value else { return nil }
    return NSDecimalNumber(decimal: rounded).intValue
}

struct HomeView: View {
    @EnvironmentObject private var store: CardStore
    @State private var showingAdd = false
    @State private var showingAppearance = false
    @AppStorage("accentRGB") private var accentRGB = AppTheme.defaultRGB
    private var theme: AppTheme { AppTheme(rgb: accentRGB) }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("YOUR MONEY, IN VIEW").font(.system(size: 11, weight: .bold, design: .rounded)).tracking(1.8).foregroundColor(theme.pageAccent)
                            Text("Card limits").font(.system(size: 34, weight: .bold, design: .rounded)).foregroundColor(ink)
                        }
                        Spacer()
                        Button { showingAppearance = true } label: { Image(systemName: "paintpalette").font(.headline).foregroundColor(theme.pageAccent).frame(width: 44, height: 46) }.accessibilityLabel("Settings")
                        Button { showingAdd = true } label: { Image(systemName: "plus").font(.headline).foregroundColor(theme.foreground).frame(width: 46, height: 46).background(theme.color, in: Circle()) }.accessibilityLabel("Add card")
                    }.padding(.top, 18)
                    if let error = store.error { Text(error).font(.footnote).foregroundColor(.red) }
                    if store.cards.isEmpty {
                        VStack(alignment: .leading, spacing: 18) {
                            Image(systemName: "creditcard.fill").font(.system(size: 30)).foregroundColor(theme.foreground).frame(width: 64, height: 64).background(theme.color, in: RoundedRectangle(cornerRadius: 20))
                            Text("Make room for\nwhat matters.").font(.system(size: 28, weight: .bold, design: .rounded)).foregroundColor(ink)
                            Text("Add a card and set a spending limit. We’ll keep track of what’s left as you log purchases.").font(.body).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                            Button { showingAdd = true } label: { Label("Add your first card", systemImage: "plus").fontWeight(.semibold).frame(maxWidth: .infinity).padding().background(theme.color, in: RoundedRectangle(cornerRadius: 16)).foregroundColor(theme.foreground) }
                        }.padding(24).frame(maxWidth: .infinity, alignment: .leading).background(surface, in: RoundedRectangle(cornerRadius: 26))
                    } else {
                        HStack { Text("YOUR CARDS").font(.system(size: 11, weight: .bold)).tracking(1.5).foregroundColor(.secondary); Spacer(); Text("\(store.cards.count) TOTAL").font(.system(size: 11, weight: .bold)).tracking(1).foregroundColor(.secondary) }
                        ForEach(store.cards) { card in
                            NavigationLink { CardDetailView(cardID: card.id) } label: { CardTile(card: card) }.buttonStyle(.plain)
                        }
                        Text("Your cards and purchases stay on this device.").font(.footnote).foregroundColor(.secondary).frame(maxWidth: .infinity).padding(.top, 8)
                    }
                }.padding(.horizontal, 22).padding(.bottom, 32)
            }.background(canvas.ignoresSafeArea()).toolbar(.hidden, for: .navigationBar)
                .sheet(isPresented: $showingAdd) { CardForm() }
                .sheet(isPresented: $showingAppearance) { AppearanceView() }
        }.tint(theme.pageAccent)
    }
}

struct CardTile: View {
    @AppStorage("accentRGB") private var accentRGB = AppTheme.defaultRGB
    @AppStorage("showConversion") private var showConversion = true
    @AppStorage("conversionCurrency") private var conversionCurrency = "USD"
    @StateObject private var exchange = ExchangeRateStore()
    private var theme: AppTheme { AppTheme(rgb: accentRGB) }
    let card: SpendingCard
    var showsNavigationArrow = true
    var body: some View {
        let spent = card.spent(); let carry = card.carriedOver(); let allowance = card.limitCents + carry; let remaining = allowance - spent
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) { Text(card.name).font(.headline); Text("••••  \(card.lastFour)").font(.subheadline).foregroundColor(theme.foreground) }
                Spacer()
                if showsNavigationArrow { Image(systemName: "arrow.up.right").font(.subheadline.weight(.bold)).foregroundColor(theme.foreground) }
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(remaining < 0 ? "OVER LIMIT" : "LEFT TO SPEND").font(.system(size: 10, weight: .bold)).tracking(1.5).foregroundColor(theme.highlight)
                Text(money(abs(remaining), currency: card.currencyCode)).font(.system(size: 32, weight: .bold, design: .rounded)).minimumScaleFactor(0.6).lineLimit(1)
                if showConversion && card.currencyCode != conversionCurrency {
                    if let table = exchange.table, let rate = table.rates[conversionCurrency], rate > 0 {
                        let formatter = NumberFormatter()
                        let _ = { formatter.numberStyle = .currency; formatter.currencyCode = conversionCurrency }()
                        let amount = NSDecimalNumber(decimal: Decimal(abs(remaining)) / 100 * rate)
                        Text("≈ \(formatter.string(from: amount) ?? "—") \(conversionCurrency) · rate \(Date(timeIntervalSince1970: table.time_last_update_unix).formatted(date: .abbreviated, time: .omitted))").font(.caption).foregroundColor(theme.foreground)
                        Link("Rates By Exchange Rate API", destination: URL(string: "https://www.exchangerate-api.com")!).font(.caption2).underline().foregroundColor(theme.foreground)
                    } else if exchange.isLoading {
                        Text("Loading conversion…").font(.caption).foregroundColor(theme.foreground)
                    } else if exchange.unavailable {
                        Text("Conversion unavailable").font(.caption).foregroundColor(theme.foreground)
                    }
                }
            }
            GeometryReader { geo in ZStack(alignment: .leading) { Capsule().fill(theme.foreground.opacity(0.25)); Capsule().fill(theme.highlight).frame(width: geo.size.width * min(1, max(0, CGFloat(spent) / CGFloat(max(allowance, 1))))) } }.frame(height: 6)
            HStack { Text("\(money(spent, currency: card.currencyCode)) spent"); Spacer(); Text("of \(money(allowance, currency: card.currencyCode))") }.font(.caption).foregroundColor(theme.foreground)
            if carry > 0 { Text("Includes \(money(carry, currency: card.currencyCode)) rolled over").font(.caption).foregroundColor(theme.foreground) }
            HStack { Image(systemName: "arrow.clockwise"); Text("Resets \(card.period().end.formatted(date: .abbreviated, time: .omitted))"); Spacer(); Text(card.schedule.label) }.font(.caption.weight(.medium)).foregroundColor(theme.foreground)
        }.padding(22).foregroundColor(theme.foreground).background(theme.color, in: RoundedRectangle(cornerRadius: 24))
            .task(id: "\(showConversion)-\(card.currencyCode)-\(conversionCurrency)") {
                if showConversion { await exchange.load(base: card.currencyCode, target: conversionCurrency) }
            }
    }
}

struct CardDetailView: View {
    @AppStorage("accentRGB") private var accentRGB = AppTheme.defaultRGB
    private var theme: AppTheme { AppTheme(rgb: accentRGB) }
    @EnvironmentObject private var store: CardStore
    @Environment(\.dismiss) private var dismiss
    let cardID: UUID
    @State private var adding = false
    @State private var editing = false
    @State private var deleting = false
    var card: SpendingCard? { store.cards.first { $0.id == cardID } }
    var body: some View {
        Group {
            if let card = card {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        CardTile(card: card, showsNavigationArrow: false)
                        Button { adding = true } label: { Label("Add a purchase", systemImage: "plus").fontWeight(.semibold).frame(maxWidth: .infinity).padding().background(theme.color, in: RoundedRectangle(cornerRadius: 16)).foregroundColor(theme.foreground) }
                        HStack { VStack(alignment: .leading, spacing: 4) { Text("Activity").font(.title2.bold()); Text("All recorded purchases").font(.caption).foregroundColor(.secondary) }; Spacer() }
                        if card.purchases.isEmpty { Text("No purchases yet. Add one to see your spending here.").font(.subheadline).foregroundColor(.secondary).padding(20).frame(maxWidth: .infinity, alignment: .leading).background(surface, in: RoundedRectangle(cornerRadius: 18)) }
                        else {
                            VStack(spacing: 0) {
                                ForEach(card.purchases.sorted { $0.date > $1.date }) { purchase in
                                    HStack(spacing: 12) {
                                        Image(systemName: "arrow.up.right").foregroundColor(theme.pageAccent).frame(width: 40, height: 40).background(canvas, in: RoundedRectangle(cornerRadius: 13))
                                        VStack(alignment: .leading, spacing: 4) { Text(purchase.title).font(.subheadline.weight(.semibold)); Text(purchase.date.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundColor(.secondary) }
                                        Spacer()
                                        Text("−\(money(purchase.amountCents, currency: card.currencyCode))").font(.subheadline.weight(.semibold))
                                        Button(role: .destructive) { var updated = card; updated.purchases.removeAll { $0.id == purchase.id }; store.put(updated) } label: { Image(systemName: "trash").font(.caption).foregroundColor(.secondary).padding(8) }.accessibilityLabel("Delete \(purchase.title)")
                                    }.padding(.vertical, 12)
                                    if purchase.id != card.purchases.sorted(by: { $0.date > $1.date }).last?.id { Divider() }
                                }
                            }.padding(.horizontal, 16).background(surface, in: RoundedRectangle(cornerRadius: 18))
                        }
                    }.padding(22)
                }.background(canvas.ignoresSafeArea()).navigationTitle(card.name).navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Menu { Button { editing = true } label: { Label("Edit card", systemImage: "pencil") }; Button(role: .destructive) { deleting = true } label: { Label("Delete card", systemImage: "trash") } } label: { Image(systemName: "ellipsis.circle") } } }
                    .sheet(isPresented: $adding) { PurchaseForm(card: card) }
                    .sheet(isPresented: $editing) { CardForm(existing: card) }
                    .confirmationDialog("Delete this card and all its purchases?", isPresented: $deleting, titleVisibility: .visible) { Button("Delete card", role: .destructive) { store.remove(card); dismiss() } }
            } else { EmptyView() }
        }
    }
}

struct AppearanceView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("accentRGB") private var accentRGB = AppTheme.defaultRGB
    private var theme: AppTheme { AppTheme(rgb: accentRGB) }
    @AppStorage("showConversion") private var showConversion = true
    @AppStorage("conversionCurrency") private var conversionCurrency = "USD"
    private let presets: [(String, Int)] = [("Forest", 0x1F4A3D), ("Ocean", 0x155C87), ("Violet", 0x6650A4), ("Rose", 0xAF4563), ("Sunshine", 0xF1BD40), ("Charcoal", 0x363A40)]
    private var selectedColor: Binding<Color> {
        Binding(get: { theme.color }, set: { color in
            let ui = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            guard ui.getRed(&r, green: &g, blue: &b, alpha: &a) else { return }
            accentRGB = (Int((r * 255).rounded()) << 16) | (Int((g * 255).rounded()) << 8) | Int((b * 255).rounded())
        })
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ColorPicker("Choose any color", selection: selectedColor, supportsOpacity: false)
                    HStack(spacing: 12) {
                        ForEach(presets, id: \.1) { preset in
                            Button { accentRGB = preset.1 } label: {
                                Circle().fill(AppTheme(rgb: preset.1).color).frame(width: 36, height: 36)
                                    .overlay { if accentRGB == preset.1 { Image(systemName: "checkmark").font(.caption.bold()).foregroundColor(AppTheme(rgb: preset.1).foreground) } }
                            }.buttonStyle(.plain).accessibilityLabel(preset.0).accessibilityAddTraits(accentRGB == preset.1 ? .isSelected : [])
                        }
                    }.padding(.vertical, 4)
                } header: { Text("Accent color") } footer: { Text("Your color is saved on this device and used across the app. Text adapts for readability.") }
                Section {
                    Toggle("Show converted balance", isOn: $showConversion)
                    if showConversion {
                        Picker("Convert to", selection: $conversionCurrency) {
                            ForEach(Locale.commonISOCurrencyCodes.sorted(), id: \.self) { code in
                                Text("\(code) — \(Locale.current.localizedString(forCurrencyCode: code) ?? code)").tag(code)
                            }
                        }
                    }
                } header: { Text("Currency conversion") } footer: { Text("Shows an approximate amount using reference rates, which may differ from your bank. Only the card currency is sent to the rate provider.") }
                Section("Preview") {
                    HStack { VStack(alignment: .leading, spacing: 5) { Text("Your card").font(.headline); Text("LEFT TO SPEND").font(.caption.bold()); Text("1,250.00").font(.title.bold()) }; Spacer() }
                        .foregroundColor(theme.foreground).padding(20).frame(maxWidth: .infinity, alignment: .leading).background(theme.color, in: RoundedRectangle(cornerRadius: 18)).listRowBackground(Color.clear).listRowInsets(EdgeInsets())
                }
                Section { Button("Reset to forest green") { accentRGB = AppTheme.defaultRGB } }
            }.navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }.tint(theme.pageAccent)
        }
    }
}

struct CardForm: View {
    @EnvironmentObject private var store: CardStore
    @Environment(\.dismiss) private var dismiss
    var existing: SpendingCard?
    @State private var name = ""
    @State private var lastFour = ""
    @State private var limit = ""
    @State private var currency = Locale.current.currency?.identifier ?? "USD"
    @State private var schedule: ResetSchedule = .monthly
    @State private var weekday = 2
    @State private var monthDay = 1
    @State private var rollover = false
    @State private var attempted = false
    private var valid: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && lastFour.count == 4 && lastFour.allSatisfy { $0.isASCII && $0.isNumber } && cents(from: limit) != nil && currency.count == 3 && currency.allSatisfy { $0.isASCII && $0.isLetter } }
    var body: some View {
        NavigationStack {
            Form {
                Section { TextField("Card name", text: $name); TextField("Last four digits", text: $lastFour).keyboardType(.numberPad).onChange(of: lastFour) { lastFour = String($0.filter { $0.isASCII && $0.isNumber }.prefix(4)) } } header: { Text("Card details") } footer: { Text("Use a nickname and the last four digits only. No full card number is needed.") }
                Section { TextField("Spending limit", text: $limit).keyboardType(.decimalPad); TextField("Currency code, e.g. USD", text: $currency).textInputAutocapitalization(.characters).autocorrectionDisabled().onChange(of: currency) { currency = String($0.uppercased().filter { $0.isASCII && $0.isLetter }.prefix(3)) } } header: { Text("Your allowance") } footer: { Text("Enter an amount with up to two decimal places and a three-letter currency code.") }
                Section {
                    Picker("Repeats", selection: $schedule) { ForEach(ResetSchedule.allCases) { Text($0.label).tag($0) } }
                    if schedule == .weekly {
                        Picker("Resets on", selection: $weekday) { ForEach(1...7, id: \.self) { day in Text(Calendar.current.weekdaySymbols[day - 1]).tag(day) } }
                    } else {
                        Picker("Resets on", selection: $monthDay) { ForEach(1...31, id: \.self) { day in Text("Day \(day)").tag(day) } }
                    }
                } header: { Text("Reset schedule") } footer: { Text(schedule == .monthly ? "For shorter months, the limit resets on the last day of the month." : "Your allowance resets at the start of the selected day.") }
                Section {
                    Toggle("Roll over unused balance", isOn: $rollover)
                } header: { Text("Rollover") } footer: { Text("Unused allowance carries forward and can accumulate. Overspending does not carry as debt. Changing the limit, currency, or reset schedule restarts rollover in the current period.") }
                if attempted && !valid { Text("Enter a name, four digits, a valid limit, and a three-letter currency code.").foregroundColor(.red).font(.footnote) }
            }.navigationTitle(existing == nil ? "Add card" : "Edit card").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { attempted = true; guard valid, let amount = cents(from: limit) else { return }; var card = existing ?? SpendingCard(name: "", lastFour: "", limitCents: 0, currencyCode: currency, schedule: schedule, resetDay: 1); let newResetDay = schedule == .weekly ? weekday : monthDay; let restartsRollover = card.rolloverStart == nil || card.limitCents != amount || card.currencyCode != currency || card.schedule != schedule || card.resetDay != newResetDay; card.name = name.trimmingCharacters(in: .whitespacesAndNewlines); card.lastFour = lastFour; card.limitCents = amount; card.currencyCode = currency; card.schedule = schedule; card.resetDay = newResetDay; if rollover { if restartsRollover { card.rolloverStart = Date() } } else { card.rolloverStart = nil }; store.put(card); dismiss() } } }
                .onAppear { if let card = existing { name = card.name; lastFour = card.lastFour; let formatter = NumberFormatter(); formatter.numberStyle = .decimal; formatter.maximumFractionDigits = 2; limit = formatter.string(from: NSDecimalNumber(decimal: Decimal(card.limitCents) / 100)) ?? ""; currency = card.currencyCode; schedule = card.schedule; rollover = card.rolloverStart != nil; if card.schedule == .weekly { weekday = card.resetDay } else { monthDay = card.resetDay } } }
        }
    }
}

struct PurchaseForm: View {
    @EnvironmentObject private var store: CardStore
    @Environment(\.dismiss) private var dismiss
    let card: SpendingCard
    @State private var title = ""
    @State private var amount = ""
    @State private var date = Date()
    @State private var attempted = false
    var body: some View {
        NavigationStack {
            Form {
                Section("Purchase") { TextField("What was it for?", text: $title); TextField("Amount (\(card.currencyCode))", text: $amount).keyboardType(.decimalPad); DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: .date) }
                Section { Text("Purchases count toward the period that contains their date. You can delete an entry from the activity list.").font(.footnote).foregroundColor(.secondary) }
                if attempted && (title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || cents(from: amount) == nil) { Text("Enter a description and a valid amount with up to two decimal places.").foregroundColor(.red).font(.footnote) }
            }.navigationTitle("Add purchase").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { attempted = true; guard let value = cents(from: amount), !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }; var updated = card; updated.purchases.append(Purchase(title: title.trimmingCharacters(in: .whitespacesAndNewlines), amountCents: value, date: date)); store.put(updated); dismiss() } } }
        }
    }
}

#endif
