import SwiftUI

struct DurationWheelPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let onSave: (RetentionDuration) -> Void

    @State private var days: Int
    @State private var hours: Int
    @State private var minutes: Int

    init(
        title: String,
        initialDuration: RetentionDuration,
        onSave: @escaping (RetentionDuration) -> Void
    ) {
        self.title = title
        self.onSave = onSave
        let safe = initialDuration.clamped
        _days = State(initialValue: safe.days)
        _hours = State(initialValue: safe.hours)
        _minutes = State(initialValue: safe.minutes)
    }

    private var currentDuration: RetentionDuration {
        RetentionDuration(days: days, hours: hours, minutes: minutes)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text(currentDuration.title)
                        .font(.title.bold())
                        .foregroundStyle(.orange)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                HStack(spacing: 0) {
                    Picker("Gün", selection: $days) {
                        ForEach(0...30, id: \.self) { day in
                            Text("\(day) gün").tag(day)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .clipped()

                    Picker("Saat", selection: $hours) {
                        ForEach(0...23, id: \.self) { hour in
                            Text("\(hour) saat").tag(hour)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .clipped()

                    Picker("Dakika", selection: $minutes) {
                        ForEach(0...59, id: \.self) { minute in
                            Text("\(minute) dk").tag(minute)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .clipped()
                }
                .frame(height: 210)
                .padding(.horizontal, 8)
                .onChange(of: days) { _, _ in enforceMinimumMinute() }
                .onChange(of: hours) { _, _ in enforceMinimumMinute() }
                .onChange(of: minutes) { _, _ in enforceMinimumMinute() }

                Spacer()
            }
            .padding(.top, 16)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") {
                        onSave(currentDuration)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func enforceMinimumMinute() {
        if days == 0 && hours == 0 && minutes == 0 {
            withAnimation(.snappy) {
                minutes = 1
            }
        }
    }
}
