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
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                AsyncImage(url: landmark.imageUrl) { image in
                    image
                        .resizable()
                        .scaledToFit()
                } placeholder: {
                    ProgressView()
                }
                .frame(width: 75, height: 75)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 6) {
                    Text(landmark.name).modifier(LabelStyle())
                    if let trail {
                        Text("\(MapService.getLandmarksOnTrail(trail: trail).count) points of interest")
                            .modifier(SmallGrayStyle())
                    }
                }
                Spacer()
            }

            if let trail {
                Text(trail.trailDistanceDescription)
                    .modifier(SmallGrayStyle())
                    .fixedSize(horizontal: false, vertical: true)
            }
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
