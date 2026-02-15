import SwiftUI

struct AppIconView: View {
    let letter: String
    let color: Color
    var size: CGFloat = 32

    var body: some View {
        Text(letter.uppercased())
            .font(.system(size: size * 0.45, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(color.gradient)
            )
    }
}
