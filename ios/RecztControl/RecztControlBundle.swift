import WidgetKit
import SwiftUI

@main
struct RecztControlBundle: WidgetBundle {
    var body: some Widget {
        RecztControlControl()
        RecztRecognitionLiveActivityWidget()

        if #available(iOS 27.0, *) {
            RecztIdentifySongControl()
            RecztQuickIdentifyWidget()
        }
    }
}
