/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A single row to be displayed in a list of landmarks.
*/

import SwiftUI

struct TrailRowView: View {
    var trail: Trail
    var landmark: Landmark?

    init(trail: Trail) {
        self.trail = trail
        let landmarks = landmarkService.getLandmarksByTrailId(id: trail.id)
        self.landmark = landmarks.first { $0.category == .Trail } ?? landmarks.first
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                if let landmark {
                    AsyncImage(url: landmark.imageUrl) { image in
                        image.resizable().scaledToFit()
                    } placeholder: { ProgressView() }
                    .frame(width: 75, height: 75)
                    .accessibilityHidden(true)
                } else {
                    Image(systemName: "figure.hiking")
                        .font(.system(size: 34))
                        .foregroundStyle(.secondary)
                        .frame(width: 75, height: 75)
                        .accessibilityHidden(true)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(trail.name).modifier(LabelStyle())
                    Text("\(MapService.getLandmarksOnTrail(trail: trail).count) points of interest")
                        .modifier(SmallGrayStyle())
                }
                Spacer()
            }

            Text(trail.trailDistanceDescription)
                .modifier(SmallGrayStyle())
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let count = MapService.getLandmarksOnTrail(trail: trail).count
        return "\(trail.name), \(trail.trailDistanceDescription), \(count) points of interest"
    }
}

struct TrailRowView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            TrailRowView(trail: landmarkService.getTrails()[0])
        }
        .previewLayout(.fixed(width: 300, height: 70))
    }
}
