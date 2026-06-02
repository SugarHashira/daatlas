import WidgetKit
import SwiftUI

@main
struct GlucoseWidgetBundle: WidgetBundle {
    var body: some Widget {
        if #available(iOS 16.2, *) {
            GlucoseLiveActivity()
        }
    }
}
