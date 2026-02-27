@available(iOS 26.0, *)
struct WalkthroughPage: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    var showDismiss: Bool = false
    var action: (() -> Void)? = nil
    
    var body: some View {
        // 1. Wrap in a ScrollView so nothing is ever permanently cut off
        ScrollView(showsIndicators: false) {
            // 2. Reduce the spacing between elements for landscape
            VStack(spacing: 16) { 
                
                Image(systemName: icon)
                    // 3. Shrink the icon size slightly 
                    .font(.system(size: 64, weight: .light)) 
                    .foregroundColor(iconColor)
                    .padding(.top, 40)
                
                Text(title)
                    // 4. Use .title instead of .largeTitle
                    .font(.title) 
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    // 5. Force the text to grow vertically instead of truncating
                    .fixedSize(horizontal: false, vertical: true) 
                
                if showDismiss {
                    Button(action: { action?() }) {
                        Text("Get Started")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: 220)
                            .padding()
                            .background(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                } else {
                    // Invisible placeholder to keep the layout consistent
                    Color.clear
                        .frame(height: 50)
                        .padding(.top, 24)
                        .padding(.bottom, 40)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}