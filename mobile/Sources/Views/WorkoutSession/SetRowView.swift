import SwiftUI

private let bandColors = ["Yellow", "Red", "Blue", "Green", "Black", "Purple", "Orange", "Gray"]
private let lbPlates: [Double] = [45, 35, 25, 10, 5, 2.5]
private let kgPlates: [Double] = [25, 20, 15, 10, 5, 2.5, 1.25]

struct SetRowView: View {
    let set: SessionSet
    let weightType: Int
    let configuredWarmupSets: Int
    let barbellWeight: Double
    let unitPreference: String
    let onSave: (Int?, Double?, Int?, Double?, Bool, [String], String?) -> Void

    @State private var reps = ""
    @State private var weight = ""
    @State private var duration = ""
    @State private var distance = ""
    @State private var bandColor = ""
    @State private var hasLoadedInitial = false
    @State private var isApplyingModelValues = false
    @State private var autosaveTask: Task<Void, Never>?
    @State private var isSetExpanded = true
    @State private var isPlateEditorExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            setHeader

            if isSetExpanded {
                HStack(spacing: 10) {
                    TextField("Reps", text: $reps)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 84)

                    if showsWeightInput {
                        switch WeightType(rawValue: weightType) {
                        case .rawWeight, .dumbbells:
                            TextField("Weight", text: $weight)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                            Text(unitPreference)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        case .timeBased:
                            TextField("Seconds", text: $duration)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.roundedBorder)
                        case .distance:
                            TextField(unitPreference == "lbs" ? "Miles" : "KM", text: $distance)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                        case .bands:
                            Picker("Band Color", selection: $bandColor) {
                                Text("Band Color").tag("")
                                ForEach(bandColors, id: \.self) { color in
                                    Text(color).tag(color)
                                }
                            }
                            .pickerStyle(.menu)
                        default:
                            Text("Bodyweight")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if WeightType(rawValue: weightType) == .plates {
                    plateSelector
                }

                Text(helperText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text(compactSummary)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

        }
        .padding(.vertical, 6)
        .onAppear {
            applyModelValues(from: set)
        }
        .onChange(of: set) { _, updatedSet in
            applyModelValues(from: updatedSet)
        }
        .onDisappear {
            autosaveTask?.cancel()
        }
        .onChange(of: reps) { _, _ in schedulePersist() }
        .onChange(of: weight) { _, _ in schedulePersist() }
        .onChange(of: duration) { _, _ in schedulePersist() }
        .onChange(of: distance) { _, _ in schedulePersist() }
        .onChange(of: bandColor) { _, _ in schedulePersist() }
    }

    private var setHeader: some View {
        HStack(spacing: 8) {
            Text("Set \(set.setNumber)")
                .font(.subheadline.monospacedDigit().weight(.semibold))

            if showWarmupBadge {
                Text("WARM-UP")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppTheme.surfaceMuted, in: Capsule())
            }

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isSetExpanded.toggle()
                }
            } label: {
                Image(systemName: isSetExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var showWarmupBadge: Bool {
        self.set.isWarmup || (configuredWarmupSets > 0 && self.set.setNumber <= configuredWarmupSets)
    }

    private var showsWeightInput: Bool {
        return true
    }

    private var helperText: String {
        switch WeightType(rawValue: weightType) {
        case .dumbbells:
            if let value = Double(weight) {
                return "2x \(formatNumber(value, digits: 2)) \(unitPreference)"
            }
            return "Per dumbbell (\(unitPreference))"
        case .plates:
            let perSide = Double(weight) ?? 0
            let total = (perSide * 2) + barbellWeight
            return "\(formatNumber(perSide, digits: 2))/side + \(formatNumber(barbellWeight, digits: 2)) \(unitPreference) bar = \(formatNumber(total, digits: 2)) \(unitPreference)"
        case .rawWeight:
            return "\(unitPreference) total"
        case .bodyweight:
            return "Bodyweight"
        case .bands:
            return bandColor.isEmpty ? "Select band color" : "\(bandColor) band"
        case .timeBased:
            return "Duration in seconds"
        case .distance:
            return unitPreference == "lbs" ? "Distance in miles" : "Distance in km"
        default:
            return ""
        }
    }

    private var plateSelector: some View {
        let sizes = unitPreference == "lbs" ? lbPlates : kgPlates
        let currentPerSide = max(0, Double(weight) ?? 0)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TextField("Per side", text: $weight)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 140)
                Text("\(unitPreference)/side")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Total \(formatNumber((currentPerSide * 2) + barbellWeight, digits: 2)) \(unitPreference)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            DisclosureGroup(isExpanded: $isPlateEditorExpanded) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(sizes, id: \.self) { size in
                        HStack(spacing: 10) {
                            Text("\(formatNumber(size, digits: 2)) \(unitPreference)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                                .frame(width: 88, alignment: .leading)

                            Button {
                                let currentCount = bindingForPlateCount(size).wrappedValue
                                bindingForPlateCount(size).wrappedValue = max(0, currentCount - 1)
                            } label: {
                                Image(systemName: "minus")
                                    .frame(width: 22, height: 22)
                            }
                            .buttonStyle(.bordered)
                            .disabled(bindingForPlateCount(size).wrappedValue == 0)

                            Text("\(bindingForPlateCount(size).wrappedValue) / side")
                                .font(.caption.monospacedDigit())
                                .frame(minWidth: 68, alignment: .leading)

                            Button {
                                let currentCount = bindingForPlateCount(size).wrappedValue
                                bindingForPlateCount(size).wrappedValue = currentCount + 1
                            } label: {
                                Image(systemName: "plus")
                                    .frame(width: 22, height: 22)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppTheme.gymboBlue)

                            Spacer()
                        }
                    }

                    Button("Reset Plate Counts") {
                        weight = "0"
                    }
                    .font(.caption)
                    .foregroundStyle(AppTheme.gymboBlue)
                }
                .padding(.top, 4)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundStyle(AppTheme.gymboBlue)
                    Text("Plate Editor")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                    Text("\(formatNumber(currentPerSide, digits: 2))/side")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
    }

    private func persist() {
        let parsedReps = Int(reps)
        let parsedWeight = (WeightType(rawValue: weightType) == .bodyweight || WeightType(rawValue: weightType) == .bands) ? nil : Double(weight)
        let parsedDuration = Int(duration)
        let parsedDistance = Double(distance)
        onSave(
            parsedReps,
            parsedWeight,
            parsedDuration,
            parsedDistance,
            set.isWarmup,
            set.usedAccessories,
            bandColor.isEmpty ? nil : bandColor
        )
    }

    private func schedulePersist() {
        guard hasLoadedInitial, !isApplyingModelValues else { return }
        autosaveTask?.cancel()
        autosaveTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                persist()
            }
        }
    }

    private func applyModelValues(from set: SessionSet) {
        isApplyingModelValues = true
        reps = set.reps.map(String.init) ?? ""
        weight = set.weight.map { formatNumber($0, digits: 2) } ?? ""
        duration = set.durationSecs.map(String.init) ?? ""
        distance = set.distance.map { formatNumber($0, digits: 2) } ?? ""
        bandColor = set.bandColor ?? ""
        hasLoadedInitial = true

        Task { @MainActor in
            // Delay clearing this guard until after state propagation, so onChange handlers
            // from programmatic assignments don't trigger autosave network calls.
            isApplyingModelValues = false
        }
    }

    private func formatNumber(_ value: Double, digits: Int) -> String {
        if value == floor(value) {
            return String(Int(value))
        }
        return String(format: "%.\(digits)f", value)
    }

    private var compactSummary: String {
        switch WeightType(rawValue: weightType) {
        case .rawWeight, .dumbbells, .plates:
            let repsText = reps.isEmpty ? "-" : reps
            let weightText = weight.isEmpty ? "-" : weight
            return "\(repsText) reps • \(weightText) \(unitPreference)"
        case .timeBased:
            let repsText = reps.isEmpty ? "-" : reps
            let durationText = duration.isEmpty ? "-" : duration
            return "\(repsText) reps • \(durationText)s"
        case .distance:
            let repsText = reps.isEmpty ? "-" : reps
            let distanceText = distance.isEmpty ? "-" : distance
            return "\(repsText) reps • \(distanceText) \(unitPreference == "lbs" ? "mi" : "km")"
        case .bands:
            let repsText = reps.isEmpty ? "-" : reps
            let bandText = bandColor.isEmpty ? "No band" : bandColor
            return "\(repsText) reps • \(bandText)"
        case .bodyweight:
            let repsText = reps.isEmpty ? "-" : reps
            return "\(repsText) reps • Bodyweight"
        default:
            return helperText
        }
    }

    private func plateCounts(for perSide: Double) -> [Double: Int] {
        let sizes = unitPreference == "lbs" ? lbPlates : kgPlates
        var counts: [Double: Int] = Dictionary(uniqueKeysWithValues: sizes.map { ($0, 0) })
        var remaining = max(0, perSide)

        for size in sizes {
            let count = Int((remaining + 0.0001) / size)
            counts[size] = count
            remaining -= Double(count) * size
        }
        return counts
    }

    private func perSideWeight(from counts: [Double: Int]) -> Double {
        counts.reduce(0) { partial, entry in
            let (size, count) = entry
            return partial + (size * Double(max(0, count)))
        }
    }

    private func bindingForPlateCount(_ size: Double) -> Binding<Int> {
        Binding<Int>(
            get: {
                let counts = plateCounts(for: max(0, Double(weight) ?? 0))
                return counts[size] ?? 0
            },
            set: { newValue in
                let currentPerSide = max(0, Double(weight) ?? 0)
                var counts = plateCounts(for: currentPerSide)
                counts[size] = max(0, newValue)
                let next = perSideWeight(from: counts)
                weight = formatNumber(next, digits: 2)
            }
        )
    }
}
