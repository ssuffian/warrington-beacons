/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A single row to be displayed in a list of landmarks.
*/

import SwiftUI

struct TrailRowView: View {
    var landmark: Landmark
    var trail: Trail?

    init(landmark: Landmark) {
        self.landmark = landmark
        self.trail = landmarkService.getTrailById(id: landmark.id)
    }
    
    var body: some View {
        HStack {
            AsyncImage(url: landmark.imageUrl) { image in
                image
                    .resizable()
                    .scaledToFit()
            } placeholder: {
                ProgressView()
            }
            .frame(width: 75)
            .accessibilityHidden(true)
            VStack(alignment: .leading) {
                Text(landmark.name).modifier(LabelStyle())
                if self.trail != nil {
                    HStack {
                        Text(self.trail!.trailDistanceDescription).modifier(SmallGrayStyle())
                        Text("|").modifier(SmallGrayStyle()).accessibilityHidden(true)
                        Text("\(MapService.getLandmarksOnTrail(trail: self.trail!).count) points of interest").modifier(SmallGrayStyle())
                    }
                }
            }
            Spacer()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        guard let trail else { return landmark.name }
        let count = MapService.getLandmarksOnTrail(trail: trail).count
        return "\(landmark.name), \(trail.trailDistanceDescription), \(count) points of interest"
    }
}

struct TrailRowView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            TrailRowView(landmark: landmarkService.getLandmarks()[0])
        }
        .previewLayout(.fixed(width: 300, height: 70))
    }
}
