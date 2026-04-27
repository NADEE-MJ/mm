import SwiftUI

extension View {
    func appScreenBackground() -> some View {
        background(AppTheme.heroGradient.ignoresSafeArea())
            .preferredColorScheme(.dark)
    }

    func appListContainer() -> some View {
        listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AppTheme.heroGradient.ignoresSafeArea())
            .preferredColorScheme(.dark)
    }

    func appFormContainer() -> some View {
        scrollContentBackground(.hidden)
            .background(AppTheme.heroGradient.ignoresSafeArea())
            .preferredColorScheme(.dark)
    }
}
